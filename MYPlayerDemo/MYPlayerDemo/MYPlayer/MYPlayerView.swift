//
//  MYPlayerView.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AVFoundation

protocol MYPlayerViewDelegate: NSObjectProtocol {
    func my_player(playerView: MYPlayerView, didClickPlayButton sender: UIButton)
    func my_player(playerView: MYPlayerView, didClickCloseButton sender: UIButton)
    func my_player(playerView: MYPlayerView, didClickFullScreenButton sender: UIButton)
    func my_player(playerView: MYPlayerView, didChangeControlViewDisplay isHiddenControlView: Bool)
}

class MYPlayerView: UIView, MYPlayerDelegate {
    
    fileprivate var player: MYPlayer?
    
    fileprivate var isSliderDraging = false
    
    fileprivate var streamURL: URL? {
        get {
            return self.player?.streamURL
        }
        set {
            self.player?.streamURL = newValue
        }
    }
    
    fileprivate var isFullScreen: Bool {
        get {
            return self.bottomView.fullScreenButton.isSelected
        }
        set {
            self.bottomView.fullScreenButton.isSelected = newValue
        }
    }
    
    fileprivate var isHiddenControlView: Bool {
        get {
            return self.bottomView.isHidden && self.topView.isHidden
        }
        set {
            if !self.allowAutoHideControlView {
                return
            }
            if newValue {
                UIView.animate(withDuration: 0.1, animations: {
                    self.bottomView.alpha = 0
                    self.topView.alpha = 0
                }, completion: { (finished) in
                    self.bottomView.isHidden = true
                    self.topView.isHidden = true
                })
            }else {
                self.bottomView.isHidden = false
                self.topView.isHidden = false
                UIView.animate(withDuration: 0.1, animations: {
                    self.bottomView.alpha = 1
                    self.topView.alpha = 1
                }, completion: { (finished) in
                })
            }
            self.delegate.my_player(playerView: self, didChangeControlViewDisplay: newValue)
        }
    }
    
    fileprivate var isHiddenControlViewForced: Bool = false {
        didSet {
            if self.isHiddenControlViewForced {
                UIView.animate(withDuration: 0.1, animations: {
                    self.bottomView.alpha = 0
                    self.topView.alpha = 0
                }, completion: { (finished) in
                    self.bottomView.isHidden = true
                    self.topView.isHidden = true
                })
            }else {
                self.bottomView.isHidden = false
                self.topView.isHidden = false
                UIView.animate(withDuration: 0.1, animations: {
                    self.bottomView.alpha = 1
                    self.topView.alpha = 1
                }, completion: { (finished) in
                })
            }
        }
    }
    
    fileprivate var allowAutoHideControlView = false
    
    fileprivate var timer: Timer?
    
    var lastOrientation: UIDeviceOrientation!
    
    weak var delegate: MYPlayerViewDelegate!
    
    lazy var playerLayerView: MYPlayerLayerView = {
        let layerView = MYPlayerLayerView()
        return layerView
    }()
    
    lazy var contentView: UIView = {
        return UIView()
    }()
    
    lazy var bottomView: MYPlayerBottomView = {
        return MYPlayerBottomView()
    }()
    
    lazy var loadingView: MYLoadingView = {
        return MYLoadingView()
    }()
    
    lazy var topView: MYPlayerTopView = {
        return MYPlayerTopView()
    }()
    
    lazy var errorView: MYPlayerErrorView = {
        return MYPlayerErrorView()
    }()
    

    init(streamURL: URL?, delegate: MYPlayerViewDelegate) {
        super.init(frame: CGRect.zero)
        self.delegate = delegate
        self.backgroundColor = .black
        self.addSubview(self.playerLayerView)
        self.addSubview(self.bottomView)
        self.addSubview(self.loadingView)
        self.addSubview(self.topView)
        self.addSubview(self.errorView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(MYPlayerView.singleTapPlayerView(_:)))
        self.addGestureRecognizer(tap)
        self.bottomView.didClickPlayButtonActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.bottomView.isPlaying {
                strongSelf.player?.play()
                strongSelf.addTimerToAutoHideControlView()
            }else {
                strongSelf.player?.pause()
            }
            strongSelf.delegate?.my_player(playerView: strongSelf, didClickPlayButton: sender)
        }
        self.bottomView.didClickFullScreenButtonActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.addTimerToAutoHideControlView()
            switch strongSelf.isFullScreen {
            case false:
                strongSelf.toOrientation(orientation: UIInterfaceOrientation.landscapeRight)
                strongSelf.isFullScreen = true
            case true:
                strongSelf.toOrientation(orientation: UIInterfaceOrientation.portrait)
                strongSelf.isFullScreen = false
            }
            strongSelf.delegate?.my_player(playerView: strongSelf, didClickFullScreenButton: sender)
        }
        self.bottomView.didStartDragSliderActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self, let player = self?.player else {
                return
            }
            strongSelf.isSliderDraging = true
            if player.isPlaying {
                player.pause()
            }
            strongSelf.removeTimer()
        }
        self.bottomView.didDragingSliderActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self, let player = self?.player else {
                return
            }
            if player.isPlaying {
                player.pause()
            }
            let time = TimeInterval(sender.value)*player.maximumDuration
            player.seekToTime(time: time, completion: { (finished) in
                if finished {
                    strongSelf.bottomView.isPlaying = true
                }
            })
            strongSelf.removeTimer()
        }
        self.bottomView.didEndDragSliderActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self, let player = self?.player else {
                return
            }
            strongSelf.isSliderDraging = false
            let time = TimeInterval(sender.value)*player.maximumDuration
            player.seekToTime(time: time, completion: { (finished) in
                if finished {
                    strongSelf.bottomView.isPlaying = true
                    strongSelf.addTimerToAutoHideControlView()
                }
            })
        }
        self.bottomView.didTouchSliderActionHandler = { [weak self] (progress) -> Void in
            guard let strongSelf = self, let player = self?.player else {
                return
            }
            if player.isPlaying {
                player.pause()
            }
            strongSelf.removeTimer()
            if !strongSelf.isSliderDraging {
                let time = TimeInterval(progress)*player.maximumDuration
                player.seekToTime(time: time, completion: { (finished) in
                    if finished {
                        strongSelf.bottomView.isPlaying = true
                        strongSelf.addTimerToAutoHideControlView()
                    }
                })
            }
            strongSelf.isSliderDraging = false
        }
        self.topView.didClickCloseButtonActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.isFullScreen {
                strongSelf.toOrientation(orientation: UIInterfaceOrientation.portrait)
                strongSelf.isFullScreen = false
                strongSelf.addTimerToAutoHideControlView()
            }else {
                strongSelf.stop()
                strongSelf.removeTimer()
                strongSelf.delegate.my_player(playerView: strongSelf, didClickCloseButton: sender)
            }
            
        }
        self.errorView.didClickErrorButtonActionHandler = { [weak self] (eventType) -> Void in
            guard let strongSelf = self else {
                return
            }
            switch eventType {
            case .replay:
                self?.player?.streamURL = streamURL
                strongSelf.errorView.alpha = 0
            case .tryToAgain:
                self?.player?.track.continueToWatchInLastTime = true
                self?.player?.reloadCurrentVideoTrack()
                strongSelf.errorView.alpha = 0
            default:
                break
            }
            strongSelf.removeTimer()
        }
        self.player = MYPlayer(delegate: self, playerLayerView: self.playerLayerView)
        self.player?.streamURL = streamURL
        self.player?.videoGravity = AVLayerVideoGravityResizeAspect
        
        self.lastOrientation = UIDevice.current.orientation
        NotificationCenter.default.addObserver(self, selector: #selector(MYPlayerView.deviceOrientationDidChanged(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.topView.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: 64)
        self.errorView.frame = self.bounds
        self.bottomView.frame = CGRect(x: 0, y: self.frame.size.height-50, width: self.frame.size.width, height: 50)
        self.loadingView.sizeToFit()
        self.loadingView.center = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height/2)
        self.playerLayerView.frame = self.bounds
    }
    
    @objc fileprivate func singleTapPlayerView(_ sender: UITapGestureRecognizer) {
        self.isHiddenControlView = !self.isHiddenControlView
        self.addTimerToAutoHideControlView()
    }
    
    fileprivate func addTimerToAutoHideControlView() {
        self.removeTimer()
        if !self.isHiddenControlView {
            self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(MYPlayerView.autoHideControlView(_:)), userInfo: nil, repeats: false)
            RunLoop.current.add(self.timer!, forMode: RunLoopMode.commonModes)
        }
    }
    
    fileprivate func removeTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    @objc fileprivate func autoHideControlView(_ sender: Timer) {
        if self.allowAutoHideControlView {
            self.isHiddenControlView = true
        }
    }
    
    func play() {
        self.player?.play()
    }
    
    func pause() {
        self.player?.pause()
    }
    
    func stop() {
        self.player?.stop()
    }
    
    @objc fileprivate func deviceOrientationDidChanged(_ sender: Notification) {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            self.isFullScreen = true
        case .portrait:
            self.isFullScreen = false
        case .portraitUpsideDown:
            if self.lastOrientation.isLandscape {
                self.isFullScreen = true
            }else {
                self.isFullScreen = false
            }
        default:
            break
        }
        self.lastOrientation = UIDevice.current.orientation
    }
    
    fileprivate func toOrientation(orientation: UIInterfaceOrientation) {
        switch orientation {
        case .landscapeRight:
            UIDevice.current.setValue(UIDeviceOrientation.landscapeRight.rawValue, forKey: "orientation")
        case .landscapeLeft:
            UIDevice.current.setValue(UIDeviceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        case .portrait:
            UIDevice.current.setValue(UIDeviceOrientation.portrait.rawValue, forKey: "orientation")
        default:
            break
        }
    }
    
    internal func my_player(player: MYPlayer, track: MYPlayerTrack, didChangeToState toState: MYPlayerState, fromState: MYPlayerState) {
        
        switch toState {
        case .playing, .paused, .readToPlay, .stopped, .failed:
            self.loadingView.stopAnimating()
        default:
            self.loadingView.startAnimating()
        }
        
        switch toState {
        case .playing:
            self.bottomView.isPlaying = true
            self.allowAutoHideControlView = true
        case .buffering:
            self.bottomView.isPlaying = false
            self.allowAutoHideControlView = true
        default:
            self.bottomView.isPlaying = false
            self.allowAutoHideControlView = false
        }
        
        switch toState {
        case .readToPlay:
            self.bottomView.totalTime = player.maximumDuration
            player.play()
        default:
            break
        }
        
        switch toState {
        case .requestURL, .loading, .readToPlay, .paused, .seeking:
            self.isHiddenControlView = false
        case .failed:
            self.isHiddenControlViewForced = true
        case .buffering:
            self.isHiddenControlViewForced = false
        default:
            break
        }
    }
    
    internal func my_player(player: MYPlayer, track: MYPlayerTrack, didUpdateBufferTime bufferTime: TimeInterval) {
        self.bottomView.bufferProgress = Float(bufferTime/player.maximumDuration)
    }
    
    internal func my_player(player: MYPlayer, track: MYPlayerTrack, didUpdateCurrentTime currentTime: TimeInterval) {
        if self.isSliderDraging {
            return
        }
        self.bottomView.currentTime = currentTime
        self.bottomView.playProgress = Float(currentTime/player.maximumDuration)
    }
    
    internal func my_player(player: MYPlayer, track: MYPlayerTrack, receivedTimeout timeOut: MYPlayerTimeOut) {
        self.loadingView.stopAnimating()
        self.isHiddenControlViewForced = false
        self.errorView.title = "重试"
        self.errorView.eventType = .tryToAgain
        UIView.animate(withDuration: 0.03) {
            self.errorView.alpha = 1
        }
    }
    
    internal func my_player(player: MYPlayer, didEndToPlayTrack track: MYPlayerTrack) {
        self.isHiddenControlViewForced = true
        self.errorView.title = "重播"
        self.errorView.eventType = .replay
        UIView.animate(withDuration: 0.03) { 
            self.errorView.alpha = 1
        }
    }
    
    internal func my_player(player: MYPlayer, shouldPlayTrack track: MYPlayerTrack) -> Bool {
        return true
    }
    
    internal func my_player(player: MYPlayer, shouldChangeToState toState: MYPlayerState) -> Bool {
        return true
    }
    
    internal func my_player(player: MYPlayer, track: MYPlayerTrack, willChangeToState toState: MYPlayerState, fromState: MYPlayerState) {
        
    }
    
    internal func my_player(player: MYPlayer, willPlayTrack track: MYPlayerTrack) {
        
    }
    
    internal func my_player(player: MYPlayer, track: MYPlayerTrack, receivedErrorCode errorCode: MYPlayerErrorCode, error: Error?) {
        self.errorView.title = "重试"
        self.errorView.eventType = .tryToAgain
        UIView.animate(withDuration: 0.03) {
            self.errorView.alpha = 1
        }
    }
}
