//
//  ViewController.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var playerView: MYPlayerView?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: "http://baobab.wdjcdn.com/1456117847747a_x264.mp4")
        self.playerView = MYPlayerView(streamURL: url)
        self.view.addSubview(self.playerView!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.playerView?.frame = self.view.bounds
    }
    
    

}

