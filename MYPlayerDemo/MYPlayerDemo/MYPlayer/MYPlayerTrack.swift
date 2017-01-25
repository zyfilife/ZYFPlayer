//
//  MYPlayerTrack.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

enum MYPlayerTrackType: Int {
    case vod = 0
    case live
    case local
}

class MYPlayerTrack: NSObject {
    
    var videoType: MYPlayerTrackType = .vod
    var streamURL: URL
    var isPlayedToEnd = false
    
    var hasVideoBeenLoadedBefore = false
    var videoTime: TimeInterval = 0
    var videoDuration: TimeInterval = 0
    var continueLastWatchTime = false
    var lastTimeInSeconds: TimeInterval = 0
    
    init(streamURL: URL) {
        self.streamURL = streamURL
        super.init()
    }
    
    func getStreamURL(completed: (_ url: URL)-> Void) {
        completed(self.streamURL)
    }
    
    func resetTrack() {
        self.isPlayedToEnd = false
        self.hasVideoBeenLoadedBefore = false
        self.continueLastWatchTime = false
        self.lastTimeInSeconds = 0
    }
}
