//
//  ZYFPlayerTopView.swift
//  ZYFPlayerExample
//
//  Created by 朱益锋 on 2017/1/26.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

class ZYFPlayerTopView: UIView {
    
    var didClickCloseButtonActionHandler: ZYFPlayerClickButtonActionBlock?

    lazy var closeButton: UIButton = {
        let button = UIButton(type: UIButtonType.custom)
        button.setImage(UIImage.zyf_image(named: "ba_back"), for: UIControlState.normal)
        button.addTarget(self, action: #selector(ZYFPlayerTopView.clickCloseButtonAction(_:)), for: UIControlEvents.touchUpInside)
        return button
    }()
    
    lazy var backgroundView: UIImageView = {
        return UIImageView(image: UIImage.zyf_image(named: "top_shadow"))
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.backgroundView)
        self.addSubview(self.closeButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("\(self.classForCoder)已销毁")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundView.frame = self.bounds
        self.closeButton.frame = CGRect(x: 10, y: 20, width: 30, height: 30)
        self.closeButton.center.y = self.frame.size.height/2 + 20/2
    }
    
    @objc func clickCloseButtonAction(_ sender: UIButton) {
        self.didClickCloseButtonActionHandler?(sender)
    }

}
