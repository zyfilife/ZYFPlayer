//
//  ZYFPlayerTrack.swift
//  ZYFPlayerExample
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

enum ZYFPlayerResourceType: Int {
    case vod = 0
    case live
    case local
}

class ZYFPlayerTrack: NSObject {
    
    var resourceType: ZYFPlayerResourceType = .vod
    var streamURL: URL
    var isPlayedToEnd = false
    var hasVideoBeenLoadedBefore = false
    var currentTime: TimeInterval = 0
    var totalTime: TimeInterval = 0
    var continueToWatchInLastTime = false
    var lastTimeInSeconds: TimeInterval = 0
    
    init(streamURL: URL) {
        self.streamURL = streamURL
        super.init()
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
    }
    
    func getStreamURL(completed: (_ url: URL)-> Void) {
        completed(self.streamURL)
    }
    
    func resetTrack() {
        self.isPlayedToEnd = false
        self.hasVideoBeenLoadedBefore = false
        self.continueToWatchInLastTime = false
        self.lastTimeInSeconds = 0
    }
}
