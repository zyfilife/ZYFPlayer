//
//  ZYFPlayer.swift
//  ZYFPlayerExample
//
//  Created by 朱益锋 on 2017/1/15.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

@objc enum ZYFPlayerErrorCode: Int, CustomStringConvertible {
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

@objc enum ZYFPlayerTimeOut: Int, CustomStringConvertible {
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

@objc enum ZYFPlayerState: Int, CustomStringConvertible {
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
fileprivate let kPlayerTimeOut: TimeInterval = 20

@objc protocol ZYFPlayerDelegate: NSObjectProtocol {
    //播放状态
    @objc optional func zyf_player(player: ZYFPlayer, shouldPlayTrack track: ZYFPlayerTrack) -> Bool
    @objc optional func zyf_player(player: ZYFPlayer, willPlayTrack track: ZYFPlayerTrack)
    @objc optional func zyf_player(player: ZYFPlayer, didEndToPlayTrack track: ZYFPlayerTrack)
    @objc optional func zyf_player(player: ZYFPlayer, shouldChangeToState toState: ZYFPlayerState) -> Bool
    @objc optional func zyf_player(player: ZYFPlayer, track: ZYFPlayerTrack, willChangeToState toState: ZYFPlayerState, fromState: ZYFPlayerState)
    @objc optional func zyf_player(player: ZYFPlayer, track: ZYFPlayerTrack, didChangeToState toState: ZYFPlayerState, fromState: ZYFPlayerState)
    @objc optional func zyf_player(player: ZYFPlayer, track: ZYFPlayerTrack, didUpdateCurrentTime currentTime: TimeInterval)
    @objc optional func zyf_player(player: ZYFPlayer, track: ZYFPlayerTrack, didUpdateBufferTime bufferTime: TimeInterval)
    @objc optional func zyf_player(player: ZYFPlayer, track: ZYFPlayerTrack, receivedTimeout timeOut: ZYFPlayerTimeOut)
    @objc optional func zyf_player(player: ZYFPlayer, track: ZYFPlayerTrack, receivedErrorCode errorCode: ZYFPlayerErrorCode, error: Error?)
}

class ZYFPlayer: NSObject {
    
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
    
    var track: ZYFPlayerTrack! {
        didSet {
            self.playerItem = nil
            self.avPlayer = nil
        }
    }
    
    fileprivate var playerLayerView: ZYFPlayerLayerView?
    
    fileprivate var timeObserver: Any? = nil {
        didSet {
            if let oldTimeObserver = oldValue {
                self.avPlayer?.removeTimeObserver(oldTimeObserver)
            }
        }
    }
    
    fileprivate var isEndToSeek = false
    
    weak var delegate: ZYFPlayerDelegate?
    
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
                return view.playerLayer.videoGravity.rawValue
            }
           return nil
        }
        set {
            if newValue != nil {
                self.playerLayerView?.playerLayer.videoGravity = AVLayerVideoGravity(rawValue: newValue!)
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
    
    var state: ZYFPlayerState = .unkown {
        didSet {
            guard let delegate = self.delegate else {
                return
            }
            if delegate.responds(to: #selector(ZYFPlayerDelegate.zyf_player(player:shouldChangeToState:))) {
                if !delegate.zyf_player!(player: self, shouldChangeToState: oldValue) {
                    return
                }
            }
            delegate.zyf_player?(player: self, track: self.track, willChangeToState: self.state, fromState: oldValue)
            if oldValue == self.state {
                if !self.isPlaying && self.state == .playing {
                    self.avPlayer?.play()
                }
                return
            }
            
            switch oldValue {
            case .loading:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ZYFPlayer.urlAssetTimeOut), object: nil)
            case .seeking:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ZYFPlayer.seekingTimeOut), object: nil)
            case .buffering:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ZYFPlayer.bufferingTimeOut), object: nil)
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
                self.perform(#selector(ZYFPlayer.urlAssetTimeOut), with: nil, afterDelay: kPlayerTimeOut)
                break
            case .readToPlay:
                self.track.hasVideoBeenLoadedBefore = true
            case .seeking:
                self.perform(#selector(ZYFPlayer.seekingTimeOut), with: nil, afterDelay: kPlayerTimeOut)
                break
            case .buffering:
                self.perform(#selector(ZYFPlayer.bufferingTimeOut), with: nil, afterDelay: kPlayerTimeOut)
            case .playing:
                if !self.isPlaying{
                    self.avPlayer?.play()
                }
            case .paused:
                self.avPlayer?.pause()
            case .failed:
                self.avPlayer?.pause()
                self.saveLastWatchTimeWithOldState(oldState: oldValue)
                self.notifyErrorCode(errorCode: ZYFPlayerErrorCode.playerFail, error: nil)
            case .stopped:
                self.cancelAllTimeOut()
                self.playerItem?.cancelPendingSeeks()
                self.avPlayer?.pause()
                self.asset.cancelLoading()
                self.saveLastWatchTimeWithOldState(oldState: oldValue)
                self.releasePlayer()
            default:
                break
            }
            self.ZYFLog(string: "currentState", item: self.state)
            self.delegate?.zyf_player?(player: self, track: self.track, didChangeToState: self.state, fromState: oldValue)
        }
    }
    
    
    
    // MARK: - Object lifecycle
    init(delegate: ZYFPlayerDelegate, playerLayerView: ZYFPlayerLayerView?) {
        super.init()
        self.playerLayerView = playerLayerView
        self.delegate = delegate
        self.state = .unkown
        self.addRouteObservers()
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
        self.releasePlayer()
        self.removeRouteObservers()
    }
}

// MARK: - Load Video URL
extension ZYFPlayer {
    
    func loadVideoWithStreamURL(streamURL: URL, playerLayerView: ZYFPlayerLayerView?=nil) {
        let track = ZYFPlayerTrack(streamURL: streamURL)
        self.loadVideoWithTrack(track: track, playerLayerView: playerLayerView)
    }
    
    func loadVideoWithTrack(track: ZYFPlayerTrack, playerLayerView: ZYFPlayerLayerView?=nil) {
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
    
    func reloadVideoTrack(track: ZYFPlayerTrack) {
        self.state = .requestURL
        switch self.state {
        case .requestURL:
            self.playWithTrack(track: track)
        default:
            break
        }
    }
    
    func reloadCurrentVideoTrack() {
        if !self.track.isPlayedToEnd && self.track.continueToWatchInLastTime && self.track.hasVideoBeenLoadedBefore {
            self.saveLastWatchTimeWithOldState(oldState: self.state)
        }

        switch self.state {
        case .buffering, .loading, .requestURL, .seeking, .paused, .stopped, .failed:
            self.reloadVideoTrack(track: self.track)
        case .playing:
            self.pauseContentCompletion(completion: { 
                self.reloadVideoTrack(track: self.track)
            })
        default:
            break
        }
    }
    
    fileprivate func playWithTrack(track: ZYFPlayerTrack) {
        if !self.shouldPlayTrack(track: track) {
            return
        }
        self.releasePlayer()
        self.getStreamURLWithTrack(track: track)
    }
    
    fileprivate func getStreamURLWithTrack(track: ZYFPlayerTrack) {
        track.getStreamURL { [weak self] (url) in
            self?.playWithStreamURL(streamURL: url, playerLayerView: self?.playerLayerView)
        }
    }
}

// MARK: - Play Video URL
extension ZYFPlayer {
    fileprivate func playWithStreamURL(streamURL: URL, playerLayerView: UIView?) {
        if self.state == .stopped {
            return
        }
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
                }else if status == .loaded {
                    let duration: TimeInterval = CMTimeGetSeconds(self.asset.duration)
                    self.track.totalTime = duration
                    if streamURL.isFileURL {
                        self.track.resourceType = .local
                    }else if duration == 0 || duration.isNaN {
                        self.track.resourceType = .live
                        self.track.totalTime = 0
                    }else {
                        self.track.resourceType = .vod
                    }
                    self.playerItem = AVPlayerItem(asset: self.asset)
                    if self.track.lastTimeInSeconds > self.track.totalTime {
                        self.track.lastTimeInSeconds = 0
                    }
                    if self.track.continueToWatchInLastTime && self.track.lastTimeInSeconds > 0 && self.track.resourceType != .live {
                        self.playerItem?.seek(to: CMTime(seconds: self.track.lastTimeInSeconds, preferredTimescale: self.playerItem!.currentTime().timescale))
                    }
                    self.avPlayer = AVPlayer(playerItem: self.playerItem)
                    if self.playerLayerView != nil {
                        self.playerLayerView?.playerLayer.player = self.avPlayer
                    }
                }else if status == .failed || status == .unknown {
                    self.state = .failed
                    self.notifyErrorCode(errorCode: ZYFPlayerErrorCode.assetLoadError, error: error)
                    return
                }
                
                if !self.asset.isPlayable {
                    self.state = .failed
                    self.notifyErrorCode(errorCode: ZYFPlayerErrorCode.assetLoadError, error: error)
                    return
                }
            })
        }
    }
}

// MARK: - Play lifecylce 
extension ZYFPlayer {
    
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
    
    fileprivate func saveLastWatchTimeWithOldState(oldState: ZYFPlayerState) {
        if oldState != .loading && oldState != .requestURL {
            self.track.lastTimeInSeconds = self.currentTime
            self.track.hasVideoBeenLoadedBefore = false
        }
    }
    
    fileprivate func shouldPlayTrack(track: ZYFPlayerTrack) -> Bool {
        guard let delegate = self.delegate else {
            return true
        }
        if delegate.responds(to: #selector(ZYFPlayerDelegate.zyf_player(player:shouldPlayTrack:))) {
            return delegate.zyf_player!(player: self, shouldPlayTrack: track)
        }else {
            return true
        }
    }
    
    fileprivate func willPlayTrack(track: ZYFPlayerTrack) {
        self.delegate?.zyf_player?(player: self, willPlayTrack: track)
    }
    
    fileprivate func notifyErrorCode(errorCode: ZYFPlayerErrorCode, error: Error?) {
        self.cancelAllTimeOut()
        self.delegate?.zyf_player?(player: self, track: self.track, receivedErrorCode: errorCode, error: error)
        self.ZYFLog(string: "receivedErrorCode", item: errorCode)
    }
    
    func releasePlayer() {
        self.playerItem = nil
        self.avPlayer = nil
    }
}

// MARK: - Time Out
extension ZYFPlayer {
    @objc fileprivate func urlAssetTimeOut() {
        self.notifyTimeOut(timeOut: ZYFPlayerTimeOut.load)
    }
    
    @objc fileprivate func seekingTimeOut() {
        self.notifyTimeOut(timeOut: ZYFPlayerTimeOut.seek)
    }
    
    @objc fileprivate func bufferingTimeOut() {
        self.notifyTimeOut(timeOut: ZYFPlayerTimeOut.buffer)
    }
    
    @objc fileprivate func notifyTimeOut(timeOut: ZYFPlayerTimeOut) {
        self.dispatch_main_async_safe { 
            self.avPlayer?.pause()
            self.delegate?.zyf_player?(player: self, track: self.track, receivedTimeout: timeOut)
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
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ZYFPlayer.urlAssetTimeOut), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ZYFPlayer.seekingTimeOut), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ZYFPlayer.bufferingTimeOut), object: nil)
    }
}

// MARK: - Add Remove Observers

extension ZYFPlayer {
    
    fileprivate func removeRouteObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    }
    
    fileprivate func addRouteObservers() {
        self.removeRouteObservers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ZYFPlayer.routeChange(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ZYFPlayer.routeInterrypt(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
        
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
                strongSelf.track.currentTime = timeInSeconds
                strongSelf.delegate?.zyf_player?(player: strongSelf, track: strongSelf.track, didUpdateCurrentTime: timeInSeconds)
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
        NotificationCenter.default.addObserver(self, selector: #selector(ZYFPlayer.playerItemDidPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(ZYFPlayer.playerItemFailedPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
}

// MARK: - KVO

extension ZYFPlayer {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if self.avPlayer == object as? AVPlayer {
            if keyPath == kPlayerStatusKey {
                switch self.avPlayer?.status {
                case .some(.readyToPlay):
                    self.state = .readToPlay
                case .some(.failed):
                    self.state = .failed
                    self.notifyErrorCode(errorCode: ZYFPlayerErrorCode.playerFail, error: self.avPlayer?.error)
                default:
                    break
                }
            }
        }else if self.playerItem == object as? AVPlayerItem {
            guard let playerItem = self.playerItem else {
                return
            }
            if keyPath == kPlayerBufferEmptyKey {
                let isBufferEmpty = self.currentTime > 0 && (self.currentTime < self.maximumDuration - 1 || self.track.resourceType == .live)
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
                    self.notifyErrorCode(errorCode: ZYFPlayerErrorCode.playerItemFail, error: playerItem.error)
                default:
                    break
                }
            }else if keyPath == kPlayerLoadedTimeRangesKey {
                // PlayerLoadedTimeRangesKey
                
                if let item = self.playerItem {
                    
                    let timeRanges = item.loadedTimeRanges
                    let timeRange: CMTimeRange = timeRanges[0].timeRangeValue
                    let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                    
                    self.delegate?.zyf_player?(player: self, track: self.track, didUpdateBufferTime: bufferedTime)
                }
            }
        }
    }
}

// MARK: - Notifications

extension ZYFPlayer {
    
    @objc fileprivate func playerItemDidPlayToEndTime(_ notification: Notification) {
        self.track.isPlayedToEnd = true
        self.pauseContentCompletion { [weak self] () -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.delegate?.zyf_player?(player: strongSelf, didEndToPlayTrack: strongSelf.track)
        }
    }
    
    @objc fileprivate func playerItemFailedPlayToEndTime(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        self.notifyErrorCode(errorCode: ZYFPlayerErrorCode.playerItemEndFail, error: error)
    }
    
    @objc fileprivate func routeChange(_ notification: Notification) {
        
    }
    
    @objc fileprivate func routeInterrypt(_ notification: Notification) {
        
    }
}

extension ZYFPlayer {
    func ZYFLog(string: String, item: Any) {
        print("************************  \(string):  \(item)")
    }
}
