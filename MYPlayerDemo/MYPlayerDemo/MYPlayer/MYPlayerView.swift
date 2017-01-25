//
//  MYPlayerView.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AVFoundation

class MYPlayerView: UIView, MYPlayerDelegate {
    
    var player: MYPlayer!
    
    var isSliderDraging = false
    
    var streamURL: URL? {
        get {
            return self.player.streamURL
        }
        set {
            self.player.streamURL = newValue
        }
    }
    
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
        let view = MYLoadingView()
        return view
    }()
    

    init(streamURL: URL?) {
        super.init(frame: CGRect.zero)
        self.backgroundColor = .black
        self.addSubview(self.playerLayerView)
        self.addSubview(self.bottomView)
        self.addSubview(self.loadingView)
        self.bottomView.didClickPlayButtonActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.bottomView.isPlaying {
                self?.player.play()
            }else {
                self?.player.pause()
            }
        }
        self.bottomView.didStartDragSliderActionHandler = { [weak self] (sender) -> Void in
            
            guard let strongSelf = self else {
                return
            }
            strongSelf.isSliderDraging = true
            if strongSelf.player.isPlaying {
                strongSelf.player.pause()
            }
        }
        self.bottomView.didDragingSliderActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.player.isPlaying {
                strongSelf.player.pause()
            }
            let time = TimeInterval(sender.value)*strongSelf.player.maximumDuration
            strongSelf.player.seekToTime(time: time, completion: { (finished) in
                if finished {
                    strongSelf.bottomView.isPlaying = true
                }
            })
        }
        self.bottomView.didEndDragSliderActionHandler = { [weak self] (sender) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isSliderDraging = false
            let time = TimeInterval(sender.value)*strongSelf.player.maximumDuration
            strongSelf.player.seekToTime(time: time, completion: { (finished) in
                if finished {
                    strongSelf.bottomView.isPlaying = true
                }
            })
        }
        self.bottomView.didTouchSliderActionHandler = { [weak self] (progress) -> Void in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.player.isPlaying {
                strongSelf.player.pause()
            }
            if !strongSelf.isSliderDraging {
                let time = TimeInterval(progress)*strongSelf.player.maximumDuration
                strongSelf.player.seekToTime(time: time, completion: { (finished) in
                    if finished {
                        strongSelf.bottomView.isPlaying = true
                    }
                })
            }
            strongSelf.isSliderDraging = false
        }
        self.player = MYPlayer(delegate: self, playerLayerView: self.playerLayerView)
        self.player.streamURL = streamURL
        self.player.videoGravity = AVLayerVideoGravityResizeAspect
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.playerLayerView.frame = self.bounds
        self.bottomView.frame = CGRect(x: 0, y: self.frame.size.height-50, width: self.frame.size.width, height: 50)
        self.loadingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.loadingView.center = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height/2)
        
    }
    
    func my_player(player: MYPlayer, track: MYPlayerTrack, didChangeToState toState: MYPlayerState, fromState: MYPlayerState) {
        switch toState {
        case .requestURL:
            self.bottomView.isPlaying = false
            self.loadingView.startAnimating()
        case .loading:
            break
        case .readToPlay:
            self.bottomView.totalTime = player.maximumDuration
            player.play()
        case .paused:
            self.bottomView.isPlaying = false
        case .playing:
            self.bottomView.isPlaying = true
            self.loadingView.stopAnimating()
        case .buffering:
            self.bottomView.isPlaying = false
            self.loadingView.startAnimating()
        case.failed:
            self.bottomView.isPlaying = false
            self.loadingView.stopAnimating()
        case .seeking:
            self.bottomView.isPlaying = false
            self.loadingView.startAnimating()
        default:
            break
        }
    }
    
    func my_player(player: MYPlayer, track: MYPlayerTrack, didUpdateBufferTime bufferTime: TimeInterval) {
        self.bottomView.bufferProgress = Float(bufferTime/player.maximumDuration)
    }
    
    func my_player(player: MYPlayer, track: MYPlayerTrack, didUpdateCurrentTime currentTime: TimeInterval) {
        if self.isSliderDraging {
            return
        }
        self.bottomView.currentTime = currentTime
        self.bottomView.playProgress = Float(currentTime/player.maximumDuration)
    }
    
    func my_player(player: MYPlayer, track: MYPlayerTrack, receivedTimeout timeOut: MYPlayerTimeOut) {
        
    }
    
    func my_player(player: MYPlayer, didEndToPlayTrack track: MYPlayerTrack) {
        
    }
    
    func my_player(player: MYPlayer, shouldPlayTrack track: MYPlayerTrack) -> Bool {
        return true
    }
    
    func my_player(player: MYPlayer, shouldChangeToState toState: MYPlayerState) -> Bool {
        return true
    }
    
    func my_player(player: MYPlayer, track: MYPlayerTrack, willChangeToState toState: MYPlayerState, fromState: MYPlayerState) {
        
    }
    
    func my_player(player: MYPlayer, willPlayTrack track: MYPlayerTrack) {
        
    }
    
    func my_player(player: MYPlayer, track: MYPlayerTrack, receivedErrorCode errorCode: MYPlayerErrorCode, error: Error?) {
        
    }
    
    
}
