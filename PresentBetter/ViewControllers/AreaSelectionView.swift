import SwiftUI
import UIKit

class AreaSelectionViewController: UIViewController {
    @IBOutlet var btnFacialExpressions: UIButton!
    @IBOutlet var btnEyeContact: UIButton!
    @IBOutlet var btnGestures: UIButton!
    @IBOutlet var btnHome: UIButton!
    
    var mode: PresentationMode = .trainingFacial
    var userInfo = UserInfo()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        btnFacialExpressions.layer.cornerRadius = 45
        btnEyeContact.layer.cornerRadius = 45
        btnGestures.layer.cornerRadius = 45
        btnHome.layer.cornerRadius = 17.0
        
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "forwardToPresentation" {
            guard let dest = segue.destination as? PresentationViewController else {
                return
            }
            dest.mode = mode
            dest.isPresentationRecorded = false
        }
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(userInfo))
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
    
    @IBAction func btnFacialExpressionClicked(_ sender: UIButton) {
        mode = .trainingFacial
        performSegue(withIdentifier: "forwardToPresentation", sender: self)
    }
    
    @IBAction func btnEyeContactClicked(_ sender: UIButton) {
        mode = .trainingEye
        performSegue(withIdentifier: "forwardToPresentation", sender: self)
    }
    
    @IBAction func btnGesturesClicked(_ sender: UIButton) {
        mode = .trainingGesture
        performSegue(withIdentifier: "forwardToPresentation", sender: self)
    }
    
}
