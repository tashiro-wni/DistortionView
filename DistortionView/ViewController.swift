//
//  ViewController.swift
//  DistortionView
//
//  Created by Tashiro Tomohiro on 2020/07/27.
//  Copyright © 2020 weathernews. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    private let imageView = UIImageView()
    private let toolBar = UIView()
    
    private var distortionView: WNDistortionView?
    private let distortionAnimationDuration: CFTimeInterval = 0.3
    private var distortionAnimationStartTimeInterval: CFTimeInterval = 0.0
    private var distortionTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        
        imageView.frame = view.bounds
        imageView.image = UIImage(named: "sampleImage")
        imageView.contentMode = .scaleAspectFill
        view.addSubview(imageView)
        
        toolBar.frame = CGRect(x: 0, y: view.bounds.maxY - 44, width: view.bounds.width, height: 44)
        toolBar.backgroundColor = .darkGray
        view.addSubview(toolBar)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async { [weak self] in
            self?.startDistortionAnimation()
        }
    }

    func startDistortionAnimation() {
        UIGraphicsBeginImageContext(self.view.bounds.size)
        imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let clearFrame = CGRect(x: 0, y: toolBar.frame.minY, width: imageView.bounds.width, height: toolBar.frame.height)
        let context = UIGraphicsGetCurrentContext()!
        context.clear(clearFrame)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        distortionView?.removeFromSuperview()
        distortionView = WNDistortionView(frame: view.bounds, image: image)
        if let distortionView = distortionView {
            distortionView.centerPoint = CGPoint(x: view.center.x, y: toolBar.center.y)
            distortionView.theta = 0.0
            view.addSubview(distortionView)
            distortionView.draw()
        }
        
        imageView.isHidden = true
        
        distortionAnimationStartTimeInterval = CACurrentMediaTime()
        distortionTimer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target: self, selector: #selector(distortionAnimationTimerFired), userInfo: nil, repeats: true)
    }
    
    @objc func distortionAnimationTimerFired() {
        let now = CACurrentMediaTime()
        var theta = (now - distortionAnimationStartTimeInterval) / distortionAnimationDuration
        if theta > 1.0 {
            distortionTimer?.invalidate()
            distortionTimer = nil
            
            distortionView?.removeFromSuperview()
            distortionView = nil
            
            UIView.animate(withDuration: 0.5) {
                self.toolBar.alpha = 0.0
            }
            
            distortionAnimationFinished()
            return
        }
        
        let gammaAdj = 0.1
        theta = pow(theta, 1.0/(1.0 - gammaAdj))
        distortionView?.theta = CGFloat(theta)
        distortionView?.draw()
    }
    
    private func distortionAnimationFinished() {
        print("animation done.")
    }
}
