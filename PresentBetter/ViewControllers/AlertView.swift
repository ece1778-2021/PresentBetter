import SwiftUI
import UIKit

class NoCameraViewController: UIViewController {
    @IBOutlet var btnBack: UIButton!
    
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
            window.rootViewController = UIHostingController(rootView: ContentView())
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
}
