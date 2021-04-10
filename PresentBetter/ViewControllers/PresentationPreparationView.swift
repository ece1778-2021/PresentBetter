import SwiftUI
import UIKit

extension Notification {
    static let popoverDismissed = Notification.Name("popoverDismissed")
    static let presentationVideoDeleted = Notification.Name("presentationVideoDeleted")
    static let localNotificationSet = Notification.Name("localNotificationSet")
}

class PresentationPreparationViewController: UIViewController {
    @IBOutlet var personOutlineView: UIView!
    @IBOutlet var btnPresent: UIButton!
    @IBOutlet var btnBack: UIButton!
    
    var isPresentationMode = true
    var myParentViewController: UIViewController?
    var userInfo = UserInfo()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btnPresent.layer.borderColor = UIColor.white.cgColor
        btnPresent.layer.borderWidth = 3.0
        btnPresent.layer.cornerRadius = 30.0
        
        btnBack.layer.cornerRadius = 17.0
        btnBack.layer.borderWidth = 2.0
        btnBack.layer.borderColor = UIColor.white.cgColor
    }
    
    override func viewDidLayoutSubviews() {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 5.0
        layer.lineDashPattern = [20, 30]
        
        let path = CustomGraphics.pathForHumanUpperBody(personOutlineView.bounds)
        layer.path = path.cgPath
        personOutlineView.layer.addSublayer(layer)
    }
    
    @IBAction func btnPresentClicked(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
        NotificationCenter.default.post(name: Notification.popoverDismissed, object: nil)
    }
    
    @IBAction func btnBackClicked(_ sender: UIButton) {
        if isPresentationMode {
            if let window = UIApplication.shared.windows.first {
                window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(userInfo))
                window.makeKeyAndVisible()
                UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
            }
        } else {
            dismiss(animated: true, completion: nil)
            myParentViewController?.navigationController?.popViewController(animated: true)
        }
    }
}

extension PresentationPreparationViewController {
    static func showView(_ parentViewController: UIViewController, mode: Bool = true) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let viewController = storyboard.instantiateViewController(identifier: "PresentationPreparationViewController") as? PresentationPreparationViewController {
            viewController.modalTransitionStyle = .crossDissolve
            viewController.modalPresentationStyle = .overFullScreen
            
            viewController.isPresentationMode = mode
            viewController.myParentViewController = parentViewController
        
            parentViewController.present(viewController, animated: false, completion: nil)
        }
    }
}
