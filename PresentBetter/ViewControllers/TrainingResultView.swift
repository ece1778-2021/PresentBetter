import SwiftUI
import UIKit

class TrainingResultViewController: UIViewController {
    @IBOutlet var lblTip: UILabel!
    @IBOutlet var lblTitle: UILabel!
    @IBOutlet var btnLearnMore: UIButton!
    @IBOutlet var btnHome: UIButton!
    
    var mode: PresentationTipMode = .facialExpression
    var totalPasses = 0
    var averageWordsPerMinute = 0
    var userInfo = UserInfo()
    
    let facialTips = [
        "Keep Going!\nYou need to smile more frequently.",
        "Good Job!\nExcellent facial expressions!",
        "Good Job!\nNext time, try to smile a little bit less."
    ]
    
    let gestureTips = [
        "Keep Going!\nYou need to move your hands more frequently.",
        "Good Job!\nExcellent gestures!",
        "Good Job!\nNext time, try to move your hands a little bit less."
    ]
    
    let eyeContactTips = [
        "Keep Going!\nYou need to look at the camera more frequently.",
        "Good Job!\nExcellent eye contact!",
        "Good Job!\nNext time, try not to look at the camera the entire time."
    ]
    
    let speechTips = [
        "It's better to speak a bit faster next time.",
        "Good Job!\nExcellent speech pace!",
        "It's better to speak a bit slower next time."
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
        } else if mode == .eyeContact {
            tipText = eyeContactTips
        } else {
            tipText = speechTips
        }
        
        if mode != .speech {
            if totalPasses < 20 {
                lblTip.text = tipText[0]
            } else if totalPasses >= 20 && totalPasses <= 32 {
                lblTip.text = tipText[1]
            } else {
                lblTip.text = tipText[2]
            }
        } else {
            if averageWordsPerMinute < 140 {
                lblTip.text = tipText[0]
            } else if averageWordsPerMinute >= 140 && averageWordsPerMinute <= 160 {
                lblTip.text = tipText[1]
            } else {
                lblTip.text = tipText[2]
            }
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
