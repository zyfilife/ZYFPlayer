//
//  MYPlayerErrorView.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/26.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

enum MYPlayerEventType {
    case replay
    case tryToAgain
    case noAction
}

class MYPlayerErrorView: UIView {
    
    let widthOfErrorView: CGFloat = 80
    let heightOfErrorView: CGFloat = 80
    
    var didClickErrorButtonActionHandler: ((_ eventType: MYPlayerEventType) -> Void)?
    
    var title: String? {
        get {
            return self.titleLabel.text
        }
        set {
            self.titleLabel.text = newValue
        }
    }
    
    var eventType: MYPlayerEventType = .replay

    lazy var errorButton: UIButton = {
        let button = UIButton(type: UIButtonType.custom)
        button.setImage(UIImage.my_image(named: "replay"), for: UIControlState.normal)
        button.addTarget(self, action: #selector(MYPlayerErrorView.clickErrorButtonAction(_:)), for: UIControlEvents.touchUpInside)
        return button
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    init(alpha: CGFloat = 0.0) {
        super.init(frame: CGRect.zero)
        self.alpha = alpha
        self.addSubview(self.errorButton)
        self.addSubview(self.titleLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.errorButton.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        self.errorButton.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.titleLabel.frame = CGRect(x: 0, y: self.errorButton.frame.maxY, width: self.bounds.width, height: 18)
        
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: self.widthOfErrorView, height: self.heightOfErrorView)
    }
    
    func clickErrorButtonAction(_ sender: UIButton) {
        self.didClickErrorButtonActionHandler?(self.eventType)
    }
    

}
