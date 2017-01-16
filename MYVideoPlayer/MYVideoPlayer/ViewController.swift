//
//  ViewController.swift
//  MYVideoPlayer
//
//  Created by 朱益锋 on 2017/1/15.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

class ViewController: UIViewController, PlayerDelegate {
    
    var player: Player?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.player = Player()
        self.player?.delegate = self
        self.player?.loadVideoWithStreamURL(streamURL: URL(string: "http://baobab.wdjcdn.com/1456117847747a_x264.mp4")!)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.player?.stop()
        self.player?.releasePlayer()
    }
    
    deinit {
        print("已销毁：\(self.classForCoder)")
    }
    
    func player(player: Player, track: PlayerTrack, didChangeToState toState: PlayerState, fromState: PlayerState) {
        switch toState {
        case .readToPlay:
            player.play()
        default:
            break
        }
    }
    
    func player(player: Player, track: PlayerTrack, didUpdateCurrentTime currentTime: TimeInterval) {
        print("currentTime: \(currentTime)")
    }
}

