import SwiftUI
import UIKit

class NoCameraViewController: UIViewController {
    @IBOutlet var btnBack: UIButton!
    var userInfo = UserInfo()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        btnBack.layer.cornerRadius = 17.0
        btnBack.layer.borderWidth = 2.0
        btnBack.layer.borderColor = UIColor.white.cgColor
    }
    
    static func showView(_ parentViewController: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = storyboard.instantiateViewController(identifier: "NoCameraViewController")
        viewController.modalTransitionStyle = .crossDissolve
        viewController.modalPresentationStyle = .overFullScreen
        
        parentViewController.present(viewController, animated: false, completion: nil)
    }
    
    @IBAction func btnBackClicked(_ sender: UIButton) {
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(userInfo))
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
}

class LoadingViewController: UIViewController {
    @IBOutlet var loadingBackgroundView: UIView!
    @IBOutlet var loadingAnimationView: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        view.alpha = 0
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1
        })
        
        loadingBackgroundView.layer.cornerRadius = 15.0
        
        let loadingPath = UIBezierPath(ovalIn: loadingAnimationView.bounds)
        let loadingLayer = CAShapeLayer()
        loadingLayer.path = loadingPath.cgPath
        loadingLayer.lineWidth = 8.0
        loadingLayer.fillColor = UIColor.clear.cgColor
        loadingLayer.strokeColor = UIColor.orange.cgColor
        loadingLayer.strokeStart = 0
        loadingLayer.strokeEnd = 0.8
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.orange.cgColor, UIColor.red.cgColor]
        gradientLayer.frame = loadingLayer.frame
        loadingLayer.addSublayer(gradientLayer)
        
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = 2 * CGFloat.pi
        rotateAnimation.duration = 0.7
        rotateAnimation.repeatCount = .infinity
        loadingAnimationView.layer.add(rotateAnimation, forKey: "transform.rotation")
        
        loadingAnimationView.layer.addSublayer(loadingLayer)
    }
    
    func myViewWillDisappear(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 0
        }) { _ in
            completion?()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        myViewWillDisappear(completion: nil)
    }
    
    static func showView(_ parentViewController: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = storyboard.instantiateViewController(identifier: "LoadingViewController")
        viewController.modalTransitionStyle = .crossDissolve
        viewController.modalPresentationStyle = .overFullScreen
        
        parentViewController.present(viewController, animated: false, completion: nil)
    }
}
