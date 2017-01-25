//
//  MYPlayer.swift
//  MYVideoPlayer
//
//  Created by 朱益锋 on 2017/1/15.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

@objc enum MYPlayerErrorCode: Int, CustomStringConvertible {
    case videoBlocked = 900
    case fetchStreamError
    case streamNotFound
    case assetLoadError
    case durationLoadError
    case playerFail
    case playerItemFail
    case playerItemEndFail
    case unknow
    
    var description: String {
        switch self.rawValue {
        case 900:
            return "videoBlocked"
        case 901:
            return "fetchStreamError"
        case 902:
            return "streamNotFound"
        case 903:
            return "assetLoadError"
        case 904:
            return "durationLoadError"
        case 905:
            return "playerFail"
        case 906:
            return "playerItemFail"
        case 907:
            return "playerItemEndFail"
        default:
            return "unknow"
        }
    }
}

@objc enum MYPlayerTimeOut: Int, CustomStringConvertible {
    case load = 0
    case seek
    case buffer
    
    var description: String {
        switch self.rawValue {
        case 0:
            return "load"
        case 1:
            return "seek"
        default:
            return "buffer"
        }
    }
}

@objc enum MYPlayerState: Int, CustomStringConvertible {
    case unkown = 0
    case requestURL
    case loading
    case readToPlay
    case playing
    case paused
    case buffering
    case seeking
    case stopped
    case failed
    
    var description: String {
        switch self.rawValue {
        case 0:
            return "unkown"
        case 1:
            return "requestURL"
        case 2:
            return "loading"
        case 3:
            return "readToPlay"
        case 4:
            return "playing"
        case 5:
            return "paused"
        case 6:
            return "buffering"
        case 7:
            return "seeking"
        case 8:
            return "stopped"
        default:
            return "failed"
        }
    }
    
    
}

// player KVO
fileprivate let kPlayerTracksKey = "tracks"
fileprivate let kPlayerPlayableKey = "playable"
fileprivate let kPlayerDurationKey = "duration"

// playerItem KVO
fileprivate let kPlayerStatusKey = "status"
fileprivate let kPlayerBufferEmptyKey = "playbackBufferEmpty"
fileprivate let kPlayerLikelyTokeepUpKey = "playbackLikelyToKeepUp"
fileprivate let kPlayerLoadedTimeRangesKey = "loadedTimeRanges"

// time out
fileprivate let kPlayerTimeOut: TimeInterval = 60

@objc protocol MYPlayerDelegate: NSObjectProtocol {
    //播放状态
    @objc optional func my_player(player: MYPlayer, shouldPlayTrack track: MYPlayerTrack) -> Bool
    @objc optional func my_player(player: MYPlayer, willPlayTrack track: MYPlayerTrack)
    @objc optional func my_player(player: MYPlayer, didEndToPlayTrack track: MYPlayerTrack)
    @objc optional func my_player(player: MYPlayer, shouldChangeToState toState: MYPlayerState) -> Bool
    @objc optional func my_player(player: MYPlayer, track: MYPlayerTrack, willChangeToState toState: MYPlayerState, fromState: MYPlayerState)
    @objc optional func my_player(player: MYPlayer, track: MYPlayerTrack, didChangeToState toState: MYPlayerState, fromState: MYPlayerState)
    @objc optional func my_player(player: MYPlayer, track: MYPlayerTrack, didUpdateCurrentTime currentTime: TimeInterval)
    @objc optional func my_player(player: MYPlayer, track: MYPlayerTrack, didUpdateBufferTime bufferTime: TimeInterval)
    @objc optional func my_player(player: MYPlayer, track: MYPlayerTrack, receivedTimeout timeOut: MYPlayerTimeOut)
    @objc optional func my_player(player: MYPlayer, track: MYPlayerTrack, receivedErrorCode errorCode: MYPlayerErrorCode, error: Error?)
}

class MYPlayer: NSObject {
    
    fileprivate var asset: AVURLAsset!
    
    fileprivate var avPlayer: AVPlayer? = nil {
        didSet {
            self.timeObserver = nil
            if let oldPlayer = oldValue {
                self.removePlayerObservers(player: oldPlayer)
            }
            if let player = self.avPlayer {
                self.addPlayerObservers(player: player)
            }
        }
    }
    
    fileprivate var playerItem: AVPlayerItem? = nil {
        didSet {
            if let oldPlayerItem = oldValue {
                self.removePlayerItemObservers(playerItem: oldPlayerItem)
            }
            if let playerItem = self.playerItem {
                self.addPlayerItemObservers(playerItem: playerItem)
            }
        }
    }
    
    fileprivate var track: MYPlayerTrack! {
        didSet {
            self.playerItem = nil
            self.avPlayer = nil
        }
    }
    
    fileprivate var playerLayerView: MYPlayerLayerView?
    
    fileprivate var timeObserver: Any? = nil {
        didSet {
            if let oldTimeObserver = oldValue {
                self.avPlayer?.removeTimeObserver(oldTimeObserver)
            }
        }
    }
    
    fileprivate var isEndToSeek = false
    
    weak var delegate: MYPlayerDelegate?
    
    var streamURL: URL? {
        didSet {
            if self.streamURL != nil {
               self.loadVideoWithStreamURL(streamURL: self.streamURL!)
            }
            
        }
    }
    
    var rate: Float {
        get {
            guard let player = self.avPlayer else {
                return 0.00
            }
            return player.rate
        }
        set {
            if self.state == .playing {
                self.avPlayer?.rate = newValue
            }
        }
    }
    
    var volume: Float {
        get {
            guard let player = self.avPlayer else {
                return 0.00
            }
            return player.volume
        }
        set {
            self.avPlayer?.volume = newValue
        }
    }
    
    var muted: Bool {
        get {
            guard let player = self.avPlayer else {
                return false
            }
            return player.isMuted
        }
        set {
            self.avPlayer?.isMuted = newValue
        }
    }
    
    var videoGravity: String? {
        get {
            if let view = self.playerLayerView {
                return view.playerLayer.videoGravity
            }
           return nil
        }
        set {
            if newValue != nil {
                self.playerLayerView?.playerLayer.videoGravity = newValue!
            }
        }
    }
    
    var playbackLoops: Bool {
        get {
            guard let player = self.avPlayer else {
                return false
            }
            return player.actionAtItemEnd == .none
        }
        set {
            self.avPlayer?.actionAtItemEnd = newValue ? .none: .pause
        }
    }
    
    var playbackFreezesAtEnd: Bool = false
    
    var isPlaying: Bool {
        return self.avPlayer != nil && self.avPlayer!.rate != 0.0
    }
    
    var currentTime: TimeInterval {
        get {
            if let playerItem = self.playerItem {
                return CMTimeGetSeconds(playerItem.currentTime())
            }else {
                return max(CMTimeGetSeconds(kCMTimeIndefinite), self.track.lastTimeInSeconds)
            }
        }
    }
    
    var maximumDuration: TimeInterval {
        if let playerItem = self.playerItem {
            return CMTimeGetSeconds(playerItem.duration)
        }else {
            return CMTimeGetSeconds(kCMTimeIndefinite)
        }
    }
    
    var bufferTime: TimeInterval {
        guard let playerItem = self.playerItem else {
            return 0.00
        }
        let ranges = playerItem.loadedTimeRanges
        guard let timeRange = ranges.first?.timeRangeValue else {
            return 0.00
        }
        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        
        return startSeconds + durationSeconds
    }
    
    var state: MYPlayerState = .unkown {
        didSet {
            self.myLog(string: "currentState", item: self.state)
            guard let delegate = self.delegate else {
                return
            }
            if delegate.responds(to: #selector(MYPlayerDelegate.my_player(player:shouldChangeToState:))) {
                if !delegate.my_player!(player: self, shouldChangeToState: oldValue) {
                    self.myLog(string: "shouldChangeToState", item: false)
                    return
                }
            }
            delegate.my_player?(player: self, track: self.track, willChangeToState: self.state, fromState: oldValue)
            self.myLog(string: "willChangeToState", item: self.state)
            if oldValue == self.state {
                if !self.isPlaying && self.state == .playing {
                    self.avPlayer?.play()
                }
                return
            }
            
            switch oldValue {
            case .loading:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MYPlayer.urlAssetTimeOut(_:)), object: oldValue)
            case .seeking:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MYPlayer.seekingTimeOut(_:)), object: oldValue)
            case .buffering:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MYPlayer.bufferingTimeOut(_:)), object: oldValue)
            case .stopped:
                if self.state == .playing {
                    return
                }
            default:
                break
            }
            
            switch self.state {
            case .requestURL:
                if oldValue == .playing && self.isPlaying {
                    self.avPlayer?.pause()
                }
            case .loading:
                self.perform(#selector(MYPlayer.urlAssetTimeOut), with: nil, afterDelay: kPlayerTimeOut)
            case .readToPlay:
                self.track.hasVideoBeenLoadedBefore = true
            case .seeking:
                self.perform(#selector(MYPlayer.seekingTimeOut), with: nil, afterDelay: kPlayerTimeOut)
            case .playing:
                if !self.isPlaying{
                    self.avPlayer?.play()
                }
            case .paused:
                self.avPlayer?.pause()
            case .failed:
                self.avPlayer?.pause()
                self.saveLastWatchTimeWithOldState(oldState: oldValue)
                self.notifyErrorCode(errorCode: MYPlayerErrorCode.playerFail, error: nil)
            case .stopped:
                self.cancelAllTimeOut()
                self.playerItem?.cancelPendingSeeks()
                self.avPlayer?.pause()
                self.saveLastWatchTimeWithOldState(oldState: oldValue)
                self.releasePlayer()
            default:
                break
            }
            self.delegate?.my_player?(player: self, track: self.track, didChangeToState: self.state, fromState: oldValue)
            self.myLog(string: "didChangeToState", item: self.state)
        }
    }
    
    
    
    // MARK: - Object lifecycle
    init(delegate: MYPlayerDelegate, playerLayerView: MYPlayerLayerView?) {
        super.init()
        self.playerLayerView = playerLayerView
        self.delegate = delegate
        self.state = .unkown
        self.addRouteObservers()
    }
    
    deinit {
        self.delegate = nil
        self.releasePlayer()
        self.removeRouteObservers()
    }
}

// MARK: - Load Video URL
extension MYPlayer {
    
    func loadVideoWithStreamURL(streamURL: URL, playerLayerView: MYPlayerLayerView?=nil) {
        let track = MYPlayerTrack(streamURL: streamURL)
        self.loadVideoWithTrack(track: track, playerLayerView: playerLayerView)
    }
    
    func loadVideoWithTrack(track: MYPlayerTrack, playerLayerView: MYPlayerLayerView?=nil) {
        if self.state != .failed  || self.state != .unkown {
            self.stop()
        }
        if playerLayerView != nil {
            self.playerLayerView = playerLayerView
        }
        self.track = track
        self.track.isPlayedToEnd = false
        self.reloadVideoTrack(track: track)
    }
    
    fileprivate func reloadVideoTrack(track: MYPlayerTrack) {
        self.state = .requestURL
        switch self.state {
        case .requestURL:
            self.playWithTrack(track: track)
        default:
            break
        }
    }
    
    fileprivate func playWithTrack(track: MYPlayerTrack) {
        if !self.shouldPlayTrack(track: track) {
            return
        }
        self.releasePlayer()
        self.getStreamURLWithTrack(track: track)
    }
    
    fileprivate func getStreamURLWithTrack(track: MYPlayerTrack) {
        track.getStreamURL { [weak self] (url) in
            self?.playWithStreamURL(streamURL: url, playerLayerView: self?.playerLayerView)
        }
    }
}

// MARK: - Play Video URL
extension MYPlayer {
    fileprivate func playWithStreamURL(streamURL: URL, playerLayerView: UIView?) {
        if self.state == .stopped {
            return
        }
        self.myLog(string: "playVideoWithStreamURL", item: streamURL)
        self.track.streamURL = streamURL
        self.state = .loading
        
        self.willPlayTrack(track: self.track)
        self.asynLoadURLAssetWithStreamURL(streamURL: streamURL)
    }
    
    fileprivate func asynLoadURLAssetWithStreamURL(streamURL: URL) {
        if self.asset != nil {
            self.asset.cancelLoading()
        }
        self.asset = AVURLAsset(url: streamURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        let keys = [kPlayerTracksKey, kPlayerPlayableKey, kPlayerDurationKey]
        self.asset.loadValuesAsynchronously(forKeys: keys) { 
            self.dispatch_main_async_safe(block: { 
                if self.state == .stopped {
                    return
                }
                var error: NSError?
                let status = self.asset.statusOfValue(forKey: kPlayerTracksKey, error: &error)
                
                if status == .loading {
                    self.myLog(string: "asset.status", item: "loading")
                }else if status == .loaded {
                    self.myLog(string: "asset.status", item: "loaded")
                    let duration: TimeInterval = CMTimeGetSeconds(self.asset.duration)
                    self.track.videoDuration = duration
                    if streamURL.isFileURL {
                        self.track.videoType = .local
                    }else if duration == 0 || duration.isNaN {
                        self.track.videoType = .live
                        self.track.videoDuration = 0
                    }else {
                        self.track.videoType = .vod
                    }
                    
                    self.playerItem = AVPlayerItem(asset: self.asset)
                    self.avPlayer = AVPlayer(playerItem: self.playerItem)
                    if self.playerLayerView != nil {
                        self.playerLayerView?.playerLayer.player = self.avPlayer
                    }
                }else if status == .failed || status == .unknown {
                    self.state = .failed
                    self.notifyErrorCode(errorCode: MYPlayerErrorCode.assetLoadError, error: error)
                    return
                }
                
                if !self.asset.isPlayable {
                    self.state = .failed
                    self.notifyErrorCode(errorCode: MYPlayerErrorCode.assetLoadError, error: error)
                    return
                }
            })
        }
    }
}

// MARK: - Play lifecylce 
extension MYPlayer {
    
    func play() {
        if self.state == .loading || self.state == .unkown || (self.state == .playing && self.isPlaying) {
            return
        }
        self.playContent()
    }
    
    fileprivate func playContent() {
        self.dispatch_main_async_safe { 
            self.state = .playing
        }
    }
    
    func pause() {
        if !self.isPlaying {
            return
        }
        self.pauseContent()
    }
    
    fileprivate func pauseContent() {
        self.pauseContentCompletion(completion: nil)
    }
    
    fileprivate func pauseContentCompletion(completion: (() -> Void)?) {
        self.dispatch_main_async_safe {
            guard let playerItem = self.playerItem else {
                return
            }
            switch playerItem.status {
            case .unknown:
                self.state = .loading
                completion?()
                return
            case .failed:
                self.state = .failed
                return
            default:
                break
            }
            guard let player = self.avPlayer else {
                return
            }
            switch player.status {
            case .unknown:
                self.state = .loading
                return
            case .failed:
                self.state = .failed
                return
            default:
                break
            }
            
            switch self.state {
            case .loading, .readToPlay, .playing, .paused, .buffering, .seeking, .failed:
                self.state = .paused
                completion?()
            default:
                break
            }
        }
    }
    
    func stop() {
        self.dispatch_main_async_safe { 
            if self.state == .unkown || (self.state == .stopped && self.avPlayer == nil && self.playerItem == nil) {
                return
            }
            self.state = .stopped
        }
    }
    
    func seekToTime(time: TimeInterval, completion: ((_ finished: Bool)-> Void)?=nil) {
        if self.state == .loading {
            return
        }
        self.state = .seeking
        self.seekToTimeInSecond(tiem: time) { (finished) in
            print("finished:\(finished), time:\(time)")
            completion?(finished)
            self.playContent()
            
        }
        
    }
    
    func seekToTimeInSecond(tiem: TimeInterval, completion: @escaping (_ finished: Bool)-> Void) {
        self.isEndToSeek = false
        guard let playerItem = self.playerItem else {
            return
        }
        self.avPlayer?.seek(to: CMTime(seconds: tiem, preferredTimescale: playerItem.currentTime().timescale), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: completion)
    }
    
    fileprivate func saveLastWatchTimeWithOldState(oldState: MYPlayerState) {
        if oldState != .loading && oldState != .requestURL {
            self.track.lastTimeInSeconds = self.currentTime
            self.track.hasVideoBeenLoadedBefore = false
        }
    }
    
    fileprivate func shouldPlayTrack(track: MYPlayerTrack) -> Bool {
        guard let delegate = self.delegate else {
            return true
        }
        if delegate.responds(to: #selector(MYPlayerDelegate.my_player(player:shouldPlayTrack:))) {
            return delegate.my_player!(player: self, shouldPlayTrack: track)
        }else {
            return true
        }
    }
    
    fileprivate func willPlayTrack(track: MYPlayerTrack) {
        self.delegate?.my_player?(player: self, willPlayTrack: track)
    }
    
    fileprivate func notifyErrorCode(errorCode: MYPlayerErrorCode, error: Error?) {
        self.cancelAllTimeOut()
        self.delegate?.my_player?(player: self, track: self.track, receivedErrorCode: errorCode, error: error)
        self.myLog(string: "receivedErrorCode", item: errorCode)
    }
    
    func releasePlayer() {
        self.avPlayer = nil
        self.playerItem = nil
    }
}

// MARK: - Time Out
extension MYPlayer {
    @objc fileprivate func urlAssetTimeOut(_ oldState: MYPlayerState) {
        if oldState == .loading {
            self.notifyTimeOut(timeOut: MYPlayerTimeOut.load)
        }
    }
    
    @objc fileprivate func seekingTimeOut(_ oldState: MYPlayerState) {
        if oldState == .seeking {
            self.notifyTimeOut(timeOut: MYPlayerTimeOut.seek)
        }
    }
    
    @objc fileprivate func bufferingTimeOut(_ oldState: MYPlayerState) {
        if oldState == .buffering {
            self.notifyTimeOut(timeOut: MYPlayerTimeOut.buffer)
        }
    }
    
    @objc fileprivate func notifyTimeOut(timeOut: MYPlayerTimeOut) {
        self.dispatch_main_async_safe { 
            self.avPlayer?.pause()
            self.delegate?.my_player?(player: self, track: self.track, receivedTimeout: timeOut)
        }
    }
    
    @objc fileprivate func dispatch_main_async_safe(block: @escaping ()-> Void) {
        if Thread.isMainThread {
            block()
        }else {
            DispatchQueue.main.async(execute: {
                block()
            })
        }
    }
    
    fileprivate func cancelAllTimeOut() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MYPlayer.urlAssetTimeOut(_:)), object: self.state)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MYPlayer.seekingTimeOut(_:)), object: self.state)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MYPlayer.bufferingTimeOut(_:)), object: self.state)
    }
}

// MARK: - Add Remove Observers

extension MYPlayer {
    
    fileprivate func removeRouteObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    }
    
    fileprivate func addRouteObservers() {
        self.removeRouteObservers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(MYPlayer.routeChange(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MYPlayer.routeInterrypt(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
        
    }
    
    fileprivate func removePlayerObservers(player: AVPlayer) {
        player.replaceCurrentItem(with: nil)
        player.removeObserver(self, forKeyPath: kPlayerStatusKey)
    }
    
    fileprivate func addPlayerObservers(player: AVPlayer) {
        player.addObserver(self, forKeyPath: kPlayerStatusKey, options: ([.old, .new]), context: nil)
        self.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: DispatchQueue.main, using: { [weak self] (time) in
            guard let strongSelf = self else {
                return
            }
            
            let timeInSeconds: TimeInterval = CMTimeGetSeconds(time)
            if timeInSeconds <= 0 {
                return
            }
            if strongSelf.state == .playing {
                
                strongSelf.track.videoTime = timeInSeconds
                strongSelf.delegate?.my_player?(player: strongSelf, track: strongSelf.track, didUpdateCurrentTime: timeInSeconds)
            }
        })
    }
    
    fileprivate func removePlayerItemObservers(playerItem: AVPlayerItem) {
        playerItem.removeObserver(self, forKeyPath: kPlayerStatusKey)
        playerItem.removeObserver(self, forKeyPath: kPlayerBufferEmptyKey)
        playerItem.removeObserver(self, forKeyPath: kPlayerLikelyTokeepUpKey)
        playerItem.removeObserver(self, forKeyPath: kPlayerLoadedTimeRangesKey)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    fileprivate func addPlayerItemObservers(playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: kPlayerStatusKey, options: ([.old, .new]), context: nil)
        playerItem.addObserver(self, forKeyPath: kPlayerBufferEmptyKey, options: ([.old, .new]), context: nil)
        playerItem.addObserver(self, forKeyPath: kPlayerLikelyTokeepUpKey, options: ([.old, .new]), context: nil)
        playerItem.addObserver(self, forKeyPath: kPlayerLoadedTimeRangesKey, options: ([.new, .old]), context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MYPlayer.playerItemDidPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(MYPlayer.playerItemFailedPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
}

// MARK: - KVO

extension MYPlayer {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if self.avPlayer == object as? AVPlayer {
            if keyPath == kPlayerStatusKey {
                switch self.avPlayer?.status {
                case .some(.readyToPlay):
                    self.state = .readToPlay
                case .some(.failed):
                    self.notifyErrorCode(errorCode: MYPlayerErrorCode.playerFail, error: self.avPlayer?.error)
                default:
                    break
                }
            }
        }else if self.playerItem == object as? AVPlayerItem {
            guard let playerItem = self.playerItem else {
                return
            }
            if keyPath == kPlayerBufferEmptyKey {
                let isBufferEmpty = self.currentTime > 0 && (self.currentTime < self.maximumDuration - 1 || self.track.videoType == .live)
                if playerItem.isPlaybackBufferEmpty && isBufferEmpty && (self.state == .playing || self.state == .seeking) {
                    self.state = .buffering
                }
            }else if keyPath == kPlayerLikelyTokeepUpKey {
                if playerItem.isPlaybackLikelyToKeepUp {
                    self.isEndToSeek = true
                    if self.isPlaying && self.state == .playing {
                        self.avPlayer?.play()
                    }
                    if self.state == .buffering {
                        self.state = .playing
                    }
                }
            }else if keyPath == kPlayerStatusKey {
                switch playerItem.status {
                case .readyToPlay:
                    self.state = .readToPlay
                case .failed:
                    self.state = .failed
                    self.notifyErrorCode(errorCode: MYPlayerErrorCode.playerItemFail, error: playerItem.error)
                default:
                    break
                }
            }else if keyPath == kPlayerLoadedTimeRangesKey {
                // PlayerLoadedTimeRangesKey
                
                if let item = self.playerItem {
                    
                    let timeRanges = item.loadedTimeRanges
                    let timeRange: CMTimeRange = timeRanges[0].timeRangeValue
                    let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                    
                    self.delegate?.my_player?(player: self, track: self.track, didUpdateBufferTime: bufferedTime)
                }
            }
        }
    }
}

// MARK: - Notifications

extension MYPlayer {
    
    @objc fileprivate func playerItemDidPlayToEndTime(_ notification: Notification) {
        self.track.isPlayedToEnd = true
        self.pauseContentCompletion { [weak self] () -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.delegate?.my_player?(player: strongSelf, didEndToPlayTrack: strongSelf.track)
        }
    }
    
    @objc fileprivate func playerItemFailedPlayToEndTime(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        self.notifyErrorCode(errorCode: MYPlayerErrorCode.playerItemEndFail, error: error)
    }
    
    @objc fileprivate func routeChange(_ notification: Notification) {
        
    }
    
    @objc fileprivate func routeInterrypt(_ notification: Notification) {
        
    }
}

extension MYPlayer {
    func myLog(string: String, item: Any) {
        print("************\(string):\n************\(item)")
    }
}
