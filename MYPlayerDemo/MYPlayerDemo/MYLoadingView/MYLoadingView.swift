//
//  MYLoadingView.swift
//  MYPlayerDemo
//
//  Created by 朱益锋 on 2017/1/25.
//  Copyright © 2017年 朱益锋. All rights reserved.
//

import UIKit

class MYLoadingView: UIView {
    
    var lineWidth:CGFloat!
    
    var lineColor: UIColor!
    
    var isAnimating = false
    
    var anglePer:CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var displayerLink: CADisplayLink? = nil {
        willSet {
            if self.displayerLink != nil {
                self.displayerLink?.invalidate()
                self.displayerLink = nil
            }
            self.displayerLink = newValue
        }
    }
    
    init(frame: CGRect = CGRect.zero, lineWidth: CGFloat=1.5, lineColor: UIColor=UIColor.white) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.lineWidth = lineWidth
        self.lineColor = lineColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startAnimating() {
        
        if self.isAnimating {
            self.stopAnimating()
            self.layer.removeAllAnimations()
        }
        
        self.isAnimating = true
        self.anglePer = 0.0
        self.alpha = 1.0
        self.displayerLink = CADisplayLink(target: self, selector: #selector(MYLoadingView.drawPathAnimation(_:)))
        self.displayerLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
    }
    
    @objc fileprivate func drawPathAnimation(_ sender: CADisplayLink) {
        self.anglePer += 0.03
        if self.anglePer > 1 {
            self.anglePer = 1
            self.displayerLink = nil
            self.startAnimationWithRotation()
        }
    }
    
    fileprivate func startAnimationWithRotation() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.duration = 0.23
        animation.toValue = M_PI/2
        animation.fillMode = kCAFillModeForwards
        animation.isCumulative = true
        animation.repeatCount = MAXFLOAT
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        self.layer.add(animation, forKey: "keyFrameAnimation")
    }
    
    func stopAnimating() {
        self.isAnimating = false
        self.displayerLink = nil
        UIView.animate(withDuration: 0.3, animations: { 
            self.alpha = 0.0
        }) { (done) in
            self.anglePer = 0
            self.layer.removeAllAnimations()
        }
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(self.lineWidth)
        context?.setStrokeColor(self.lineColor.cgColor)
        context?.addArc(center: CGPoint(x: self.bounds.width/2, y: self.bounds.height/2), radius: self.bounds.width/2-self.lineWidth, startAngle: self.toAngle(angle: 120), endAngle: self.toAngle(angle: 120)+self.toAngle(angle: 330*self.anglePer), clockwise: false)
        context?.strokePath()
    }
    
    fileprivate func toAngle(angle: CGFloat) -> CGFloat {
        return CGFloat(M_PI)*2/360*angle
    }

}
