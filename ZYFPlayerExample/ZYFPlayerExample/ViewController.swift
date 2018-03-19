//
//  ViewController.swift
//  ZYFPlayerExample
//
//  Created by 朱益锋 on 2018/3/19.
//  Copyright © 2018年 com.zhuyifeng. All rights reserved.
//

import UIKit

class ViewController: UIViewController, ZYFPlayerViewDelegate {
    
    var playerView: ZYFPlayerView?
    
    var isHiddenStatusBar: Bool = false
    
    override var prefersStatusBarHidden: Bool {
        return self.isHiddenStatusBar
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: "http://xy-smartplayer-rec.oss-cn-hangzhou.aliyuncs.com/video/course/%E6%B5%B7%E4%BC%A6-%E7%BB%B4%E4%B9%9F%E7%BA%B3%E9%9F%B3%E4%B9%90%E4%B9%8B%E6%97%85%EF%BC%88%E4%BA%9A%E9%87%87%E5%85%8B%C2%B7%E7%A7%91%E5%B0%94%E5%A1%94%E6%96%AF%EF%BC%89.mp4")
        self.playerView = ZYFPlayerView(streamURL: url, delegate: self)
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
    
    func zyf_player(playerView: ZYFPlayerView, didClickPlayButton sender: UIButton) {
        
    }
    
    func zyf_player(playerView: ZYFPlayerView, didClickCloseButton sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func zyf_player(playerView: ZYFPlayerView, didClickFullScreenButton sender: UIButton) {
    }
    
    func zyf_player(playerView: ZYFPlayerView, didChangeControlViewDisplay isHiddenControlView: Bool) {
        self.isHiddenStatusBar = isHiddenControlView
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
}

