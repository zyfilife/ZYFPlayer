//
//  ViewController.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

class ViewController: UIViewController, MYPlayerViewDelegate {
    
    var playerView: MYPlayerView?
    
    var isHiddenStatusBar: Bool = false
    
    override var prefersStatusBarHidden: Bool {
        return self.isHiddenStatusBar
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: "http://baobab.wdjcdn.com/1456117847747a_x264.mp4")
        self.playerView = MYPlayerView(streamURL: url, delegate: self)
        self.view.addSubview(self.playerView!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.playerView?.frame = self.view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
        NotificationCenter.default.removeObserver(self)
    }
    
    func my_player(playerView: MYPlayerView, didClickPlayButton sender: UIButton) {
        
    }
    
    func my_player(playerView: MYPlayerView, didClickCloseButton sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func my_player(playerView: MYPlayerView, didClickFullScreenButton sender: UIButton) {
    }
    
    func my_player(playerView: MYPlayerView, didChangeControlViewDisplay isHiddenControlView: Bool) {
        self.isHiddenStatusBar = isHiddenControlView
        self.setNeedsStatusBarAppearanceUpdate()
    }

}

