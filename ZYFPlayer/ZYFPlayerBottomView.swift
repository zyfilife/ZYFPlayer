//
//  ZYFPlayerBottomView.swift
//  ZYFPlayerExample
//
//  Created by 朱益锋 on 2017/1/24.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

typealias ZYFPlayerClickButtonActionBlock = (_ sender: UIButton) -> Void
typealias ZYFPlayerDragSliderActionBlock = (_ sender: UISlider) -> Void
typealias ZYFPlayerTouchSliderActionBlock = (_ progress: Float) -> Void

class ZYFPlayerBottomView: UIView {
    
    var didClickPlayButtonActionHandler: ZYFPlayerClickButtonActionBlock?
    
    var didClickFullScreenButtonActionHandler: ZYFPlayerClickButtonActionBlock?
    
    var didStartDragSliderActionHandler: ZYFPlayerDragSliderActionBlock?
    var didDragingSliderActionHandler: ZYFPlayerDragSliderActionBlock?
    var didEndDragSliderActionHandler: ZYFPlayerDragSliderActionBlock?
    
    var didTouchSliderActionHandler: ZYFPlayerTouchSliderActionBlock?
    
    var isDraging = false
    
    var isPlaying: Bool {
        get {
            return self.playButton.isSelected
        }
        set {
            self.playButton.isSelected = newValue
        }
    }
    
    var isFullScreen: Bool {
        get {
            return self.fullScreenButton.isSelected
        }
        set {
            self.fullScreenButton.isSelected = newValue
        }
    }
    
    var currentTime: TimeInterval {
        get {
            return self.currentTime
        }
        set {
            self.currentTimeLabel.text = self.string(time: newValue)
        }
    }
    
    var totalTime: TimeInterval {
        get {
            return self.totalTime
        }
        set {
            self.totalTimeLabel.text = self.string(time: newValue)
        }
    }
    
    var playProgress: Float {
        get {
            return self.progressSlider.value
        }
        set {
            self.progressSlider.value = newValue
        }
    }
    
    var bufferProgress: Float {
        get {
            return self.progressView.progress
        }
        set {
            self.progressView.progress = newValue
        }
    }
    
    lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11)
        label.textAlignment = .left
        return label
    }()
    
    lazy var totalTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11)
        label.textAlignment = .right
        return label
    }()
    
    lazy var playButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.zyf_image(named: "play"), for: UIControlState.normal)
        button.setImage(UIImage.zyf_image(named: "pause"), for: UIControlState.selected)
        button.addTarget(self, action: #selector(ZYFPlayerBottomView.clickPlayButtonAction(_:)), for: UIControlEvents.touchUpInside)
        return button
    }()
    
    lazy var fullScreenButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.zyf_image(named: "fullscreen"), for: UIControlState.normal)
        button.setImage(UIImage.zyf_image(named: "nonfullscreen"), for: UIControlState.selected)
        button.addTarget(self, action: #selector(ZYFPlayerBottomView.clickFullScreenButtonAction(_:)), for: UIControlEvents.touchUpInside)
        return button
    }()
    
    lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: UIProgressViewStyle.default)
        progress.progressTintColor = UIColor(white: 1, alpha: 0.5)
        progress.trackTintColor = UIColor.clear
        return progress
    }()
    
    lazy var progressSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        slider.setThumbImage(UIImage.zyf_image(named: "dot"), for: UIControlState.normal)
        slider.minimumTrackTintColor = .green
        slider.maximumTrackTintColor = UIColor(white: 0.5, alpha: 0.5)
        slider.value = 0.0
        slider.addTarget(self, action: #selector(ZYFPlayerBottomView.sliderTouchDownAction(_:)), for: UIControlEvents.touchDown)
        slider.addTarget(self, action: #selector(ZYFPlayerBottomView.sliderDragAction(_:)), for: UIControlEvents.valueChanged)
        slider.addTarget(self, action: #selector(ZYFPlayerBottomView.sliderTouchUpAction(_:)), for: [.touchUpOutside,.touchUpInside])
        let tap = UITapGestureRecognizer(target: self, action: #selector(ZYFPlayerBottomView.clickProgressSliderAction(_:)))
        slider.addGestureRecognizer(tap)
        return slider
    }()
    
    lazy var backgroundView: UIImageView = {
        return UIImageView(image: UIImage.zyf_image(named: "bottom_shadow"))
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.backgroundView)
        self.addSubview(self.currentTimeLabel)
        self.addSubview(self.totalTimeLabel)
        self.addSubview(self.playButton)
        self.addSubview(self.fullScreenButton)
        self.addSubview(self.progressView)
        self.addSubview(self.progressSlider)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addSubview(self.backgroundView)
        self.addSubview(self.currentTimeLabel)
        self.addSubview(self.totalTimeLabel)
        self.addSubview(self.playButton)
        self.addSubview(self.fullScreenButton)
        self.addSubview(self.progressView)
        self.addSubview(self.progressSlider)
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundView.frame = self.bounds
        self.playButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        self.playButton.center.y = self.frame.size.height/2
        
        self.progressSlider.frame = CGRect(x: self.playButton.frame.maxX, y: 0, width: self.frame.size.width - self.playButton.frame.maxX*2, height: 30)
        self.progressSlider.center.y = self.frame.size.height/2-3
        
        self.progressView.frame = CGRect(x: self.playButton.frame.maxX, y: 0, width: self.frame.size.width - self.playButton.frame.maxX*2-4, height: 30)
        self.progressView.center = self.progressSlider.center
        
        self.fullScreenButton.frame = CGRect(x: self.frame.size.width-50, y: 0, width: 50, height: 50)
        self.fullScreenButton.center.y = self.frame.size.height/2
        
        self.currentTimeLabel.frame = CGRect(x: self.playButton.frame.maxX, y: self.frame.size.height-20, width: self.progressView.frame.size.width/2, height: 20)
        self.totalTimeLabel.frame = CGRect(x: 0, y: self.frame.size.height-20, width: self.progressView.frame.size.width/2, height: 20)
        self.totalTimeLabel.frame.origin.x = self.frame.size.width-self.totalTimeLabel.frame.size.width-self.fullScreenButton.frame.size.width
    }
    
    @objc func clickPlayButtonAction(_ sender: UIButton) {
        self.isPlaying = !self.isPlaying
        self.didClickPlayButtonActionHandler?(sender)
    }
    
    @objc func clickFullScreenButtonAction(_ sender: UIButton) {
        self.didClickFullScreenButtonActionHandler?(sender)
    }
    
    @objc func sliderTouchDownAction(_ sender: UISlider) {
        self.didStartDragSliderActionHandler?(sender)
    }
    
    @objc func sliderDragAction(_ sender: UISlider) {
        self.didDragingSliderActionHandler?(sender)
    }
    
    @objc func sliderTouchUpAction(_ sender: UISlider) {
        self.didEndDragSliderActionHandler?(sender)
    }
    
    @objc func clickProgressSliderAction(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: self.progressSlider)
        let progress = point.x / self.progressSlider.frame.size.width
        self.didTouchSliderActionHandler?(Float(progress))
    }
}

extension ZYFPlayerBottomView {
    internal func string(time: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: time)
        let formatter = DateFormatter()
        if time / 3600 >= 1 {
            formatter.dateFormat = "HH:mm:ss"
        }else {
            formatter.dateFormat = "mm:ss"
        }
        return formatter.string(from: date)
    }
}

extension UIImage {
    
    class func zyf_image(named: String) -> UIImage? {
        return UIImage(named: "ZYFPlayer.bundle/\(named)")
    }
}
