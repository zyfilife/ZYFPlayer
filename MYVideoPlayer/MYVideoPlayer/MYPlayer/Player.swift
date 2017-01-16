//
//  Player.swift
//  MYVideoPlayer
//
//  Created by 朱益锋 on 2017/1/15.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

@objc enum PlayerErrorCode: Int, CustomStringConvertible {
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

@objc enum PlayerTimeOut: Int, CustomStringConvertible {
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

@objc enum PlayerState: Int, CustomStringConvertible {
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

// time out
fileprivate let kPlayerTimeOut: TimeInterval = 60

@objc protocol PlayerDelegate: NSObjectProtocol {
    //播放状态
    @objc optional func player(player: Player, shouldPlayTrack track: PlayerTrack) -> Bool
    @objc optional func player(player: Player, willPlayTrack track: PlayerTrack)
    @objc optional func player(player: Player, didEndToPlayTrack track: PlayerTrack)
    @objc optional func player(player: Player, shouldChangeToState toState: PlayerState) -> Bool
    @objc optional func player(player: Player, track: PlayerTrack, willChangeToState toState: PlayerState, fromState: PlayerState)
    @objc optional func player(player: Player, track: PlayerTrack, didChangeToState toState: PlayerState, fromState: PlayerState)
    @objc optional func player(player: Player, track: PlayerTrack, didUpdateCurrentTime currentTime: TimeInterval)
    @objc optional func player(player: Player, track: PlayerTrack, didUpdateBufferTime bufferTime: TimeInterval)
    @objc optional func player(player: Player, track: PlayerTrack, receivedTimeout timeOut: PlayerTimeOut)
    @objc optional func player(player: Player, track: PlayerTrack, receivedErrorCode errorCode: PlayerErrorCode, error: Error?)
}

class Player: NSObject {
    
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
    
    fileprivate var track: PlayerTrack! {
        didSet {
            self.playerItem = nil
            self.avPlayer = nil
        }
    }
    
    fileprivate var playerLayerView: UIView?
    
    fileprivate var timeObserver: Any? = nil {
        didSet {
            if let oldTimeObserver = oldValue {
                self.avPlayer?.removeTimeObserver(oldTimeObserver)
            }
        }
    }
    
    fileprivate var isEndToSeek = false
    
    weak var delegate: PlayerDelegate?
    
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
    
    var state: PlayerState = .unkown {
        didSet {
            guard let delegate = self.delegate else {
                return
            }
            if delegate.responds(to: #selector(PlayerDelegate.player(player:shouldChangeToState:))) {
                if !delegate.player!(player: self, shouldChangeToState: oldValue) {
                    print("shouldChangeToState: false")
                    return
                }
            }
            print("willChangeToState: \(self.state)")
            delegate.player?(player: self, track: self.track, willChangeToState: self.state, fromState: oldValue)
            
            if oldValue == self.state {
                if !self.isPlaying && self.state == .playing {
                    self.avPlayer?.play()
                }
                return
            }
            
            switch oldValue {
            case .loading:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Player.urlAssetTimeOut(_:)), object: oldValue)
            case .seeking:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Player.seekingTimeOut(_:)), object: oldValue)
            case .buffering:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Player.bufferingTimeOut(_:)), object: oldValue)
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
                self.perform(#selector(Player.urlAssetTimeOut), with: nil, afterDelay: kPlayerTimeOut)
            case .readToPlay:
                self.track.hasVideoBeenLoadedBefore = true
            case .seeking:
                self.perform(#selector(Player.seekingTimeOut), with: nil, afterDelay: kPlayerTimeOut)
            case .playing:
                if !self.isPlaying{
                    self.avPlayer?.play()
                }
            case .paused:
                self.avPlayer?.pause()
            case .failed:
                self.avPlayer?.pause()
                self.saveLastWatchTimeWithOldState(oldState: oldValue)
                self.notifyErrorCode(errorCode: PlayerErrorCode.playerFail, error: nil)
            case .stopped:
                self.cancelAllTimeOut()
                self.playerItem?.cancelPendingSeeks()
                self.avPlayer?.pause()
                self.saveLastWatchTimeWithOldState(oldState: oldValue)
                self.releasePlayer()
            default:
                break
            }
            print("didChangeToState:\(self.state), fromState:\(oldValue)")
            self.delegate?.player?(player: self, track: self.track, didChangeToState: self.state, fromState: oldValue)
        }
    }
    
    
    
    // MARK: - Object lifecycle
    override init() {
        super.init()
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
extension Player {
    func loadVideoWithStreamURL(streamURL: URL) {
        self.loadVideoWithStreamURL(streamURL: streamURL, playerLayerView: nil)
    }
    
    func loadVideoWithStreamURL(streamURL: URL, playerLayerView: UIView?) {
        let track = PlayerTrack(streamURL: streamURL)
        self.loadVideoWithTrack(track: track, playerLayerView: playerLayerView)
    }
    
    fileprivate func loadVideoWithTrack(track: PlayerTrack) {
        self.loadVideoWithTrack(track: track, playerLayerView: nil)
    }
    
    fileprivate func loadVideoWithTrack(track: PlayerTrack, playerLayerView: UIView?) {
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
    
    fileprivate func reloadVideoTrack(track: PlayerTrack) {
        self.state = .requestURL
        switch self.state {
        case .requestURL:
            self.playWithTrack(track: track)
        default:
            break
        }
    }
    
    fileprivate func playWithTrack(track: PlayerTrack) {
        if !self.shouldPlayTrack(track: track) {
            return
        }
        self.releasePlayer()
        self.getStreamURLWithTrack(track: track)
    }
    
    fileprivate func getStreamURLWithTrack(track: PlayerTrack) {
        track.getStreamURL { [weak self] (url) in
            print("playVideoWithStreamURL:\(url)")
            self?.playWithStreamURL(streamURL: url, playerLayerView: self?.playerLayerView)
        }
    }
}

// MARK: - Play Video URL
extension Player {
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
                    print("asset.status == loading")
                }else if status == .loaded {
                    print("asset.status == loaded")
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
                }else if status == .failed || status == .unknown {
                    self.state = .failed
                    self.notifyErrorCode(errorCode: PlayerErrorCode.assetLoadError, error: error)
                    return
                }
                
                if !self.asset.isPlayable {
                    self.state = .failed
                    self.notifyErrorCode(errorCode: PlayerErrorCode.assetLoadError, error: error)
                    return
                }
            })
        }
    }
}

// MARK: - Play lifecylce 
extension Player {
    
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
    }
    
    fileprivate func pauseContent() {
        
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
            case .failed:
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
    
    fileprivate func saveLastWatchTimeWithOldState(oldState: PlayerState) {
        if oldState != .loading && oldState != .requestURL {
            self.track.lastTimeInSeconds = self.currentTime
            self.track.hasVideoBeenLoadedBefore = false
        }
    }
    
    fileprivate func shouldPlayTrack(track: PlayerTrack) -> Bool {
        guard let delegate = self.delegate else {
            return true
        }
        if delegate.responds(to: #selector(PlayerDelegate.player(player:shouldPlayTrack:))) {
            return delegate.player!(player: self, shouldPlayTrack: track)
        }else {
            return true
        }
    }
    
    fileprivate func willPlayTrack(track: PlayerTrack) {
        self.delegate?.player?(player: self, willPlayTrack: track)
    }
    
    fileprivate func notifyErrorCode(errorCode: PlayerErrorCode, error: Error?) {
        self.cancelAllTimeOut()
        self.delegate?.player?(player: self, track: self.track, receivedErrorCode: errorCode, error: error)
    }
    
    func releasePlayer() {
        self.avPlayer = nil
        self.playerItem = nil
    }
}

// MARK: - Time Out
extension Player {
    @objc fileprivate func urlAssetTimeOut(_ oldState: PlayerState) {
        if oldState == .loading {
            self.notifyTimeOut(timeOut: PlayerTimeOut.load)
        }
    }
    
    @objc fileprivate func seekingTimeOut(_ oldState: PlayerState) {
        if oldState == .seeking {
            self.notifyTimeOut(timeOut: PlayerTimeOut.seek)
        }
    }
    
    @objc fileprivate func bufferingTimeOut(_ oldState: PlayerState) {
        if oldState == .buffering {
            self.notifyTimeOut(timeOut: PlayerTimeOut.buffer)
        }
    }
    
    @objc fileprivate func notifyTimeOut(timeOut: PlayerTimeOut) {
        self.dispatch_main_async_safe { 
            self.avPlayer?.pause()
            self.delegate?.player?(player: self, track: self.track, receivedTimeout: timeOut)
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
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Player.urlAssetTimeOut(_:)), object: self.state)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Player.seekingTimeOut(_:)), object: self.state)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Player.bufferingTimeOut(_:)), object: self.state)
    }
}

// MARK: - Add Remove Observers

extension Player {
    
    fileprivate func removeRouteObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    }
    
    fileprivate func addRouteObservers() {
        self.removeRouteObservers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(Player.routeChange(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Player.routeInterrypt(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
        
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
                strongSelf.delegate?.player?(player: strongSelf, track: strongSelf.track, didUpdateCurrentTime: timeInSeconds)
            }
        })
    }
    
    fileprivate func removePlayerItemObservers(playerItem: AVPlayerItem) {
        playerItem.removeObserver(self, forKeyPath: kPlayerStatusKey)
        playerItem.removeObserver(self, forKeyPath: kPlayerBufferEmptyKey)
        playerItem.removeObserver(self, forKeyPath: kPlayerLikelyTokeepUpKey)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    fileprivate func addPlayerItemObservers(playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: kPlayerStatusKey, options: ([.old, .new]), context: nil)
        playerItem.addObserver(self, forKeyPath: kPlayerBufferEmptyKey, options: ([.old, .new]), context: nil)
        playerItem.addObserver(self, forKeyPath: kPlayerLikelyTokeepUpKey, options: ([.old, .new]), context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(Player.playerItemDidPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(Player.playerItemFailedPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
}

// MARK: - KVO

extension Player {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if self.avPlayer == object as? AVPlayer {
            if keyPath == kPlayerStatusKey {
                switch self.avPlayer?.status {
                case .some(.readyToPlay):
                    self.state = .readToPlay
                case .some(.failed):
                    self.notifyErrorCode(errorCode: PlayerErrorCode.playerFail, error: self.avPlayer?.error)
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
                if playerItem.isPlaybackBufferEmpty && isBufferEmpty && self.state == .playing {
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
                    self.notifyErrorCode(errorCode: PlayerErrorCode.playerItemFail, error: playerItem.error)
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Notifications

extension Player {
    
    @objc fileprivate func playerItemDidPlayToEndTime(_ notification: Notification) {
        self.track.isPlayedToEnd = true
        self.pauseContentCompletion { [weak self] () -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.delegate?.player?(player: strongSelf, didEndToPlayTrack: strongSelf.track)
        }
    }
    
    @objc fileprivate func playerItemFailedPlayToEndTime(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        self.notifyErrorCode(errorCode: PlayerErrorCode.playerItemEndFail, error: error)
    }
    
    @objc fileprivate func routeChange(_ notification: Notification) {
        
    }
    
    @objc fileprivate func routeInterrypt(_ notification: Notification) {
        
    }
}
