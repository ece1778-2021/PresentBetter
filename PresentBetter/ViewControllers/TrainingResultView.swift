import SwiftUI
import UIKit

class TrainingResultViewController: UIViewController {
    @IBOutlet var lblTip: UILabel!
    @IBOutlet var lblTitle: UILabel!
    @IBOutlet var btnLearnMore: UIButton!
    @IBOutlet var btnHome: UIButton!
    
    var mode: PresentationTipMode = .facialExpression
    var totalPasses = 0
    var userInfo = UserInfo()
    
    let facialTips = [
        "Work Hard!\nYou need to smile more frequently.",
        "Good Job!\nExcellent facial expressions!",
        "Good Job!\nNext time, try to smile a little bit less."
    ]
    
    let gestureTips = [
        "Work Hard!\nYou need to move your hands more frequently.",
        "Good Job!\nExcellent gestures!",
        "Good Job!\nNext time, try to move your hands a little bit less."
    ]
    
    let eyeContactTips = [
        "Work Hard!\nYou need to look at the camera more frequently.",
        "Good Job!\nExcellent eye contact!",
        "Good Job!\nNext time, try not to look at the camera the entire time."
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        btnLearnMore.layer.cornerRadius = 35.0
        btnHome.layer.cornerRadius = 15.0
        showTip()
    }
    
    func showTip() {
        var tipText: [String]
        if mode == .facialExpression {
            tipText = facialTips
        } else if mode == .gesture {
            tipText = gestureTips
        } else {
            tipText = eyeContactTips
        }
        
        if totalPasses < 30 {
            lblTip.text = tipText[0]
        } else if totalPasses >= 30 && totalPasses <= 48 {
            lblTip.text = tipText[1]
        } else {
            lblTip.text = tipText[2]
        }
    }
    
    @IBAction func btnLearnMoreClicked(_ sender: UIButton) {
        PresentationTipViewController.showView(self, mode: mode)
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(userInfo))
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
}
