//
//  ZYFPlayerLayerView.swift
//  ZYFPlayerExample
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit
import AVFoundation

class ZYFPlayerLayerView: UIView {
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    // Override UIView property
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
    }
}
