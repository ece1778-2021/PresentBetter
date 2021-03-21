
import UIKit

enum PresentationTipMode {
    case facialExpression
    case gesture
    case eyeContact
}

class PresentationTipViewController: UIViewController {
    @IBOutlet var btnClose: UIButton!
    @IBOutlet var lblTip: UILabel!
    @IBOutlet var dialogBackgroundView: UIView!
    
    var mode: PresentationTipMode = .facialExpression
    
    let tips: [PresentationTipMode: String] = [
        .facialExpression: "Avoid a blank face by smiling from time to time to show the audience you are human.\n\nSmiling will also engage your audience and show them you are passionate about your subject matter.\n\nHowever, do not smile the entire presentation. This looks insincere.",
        .gesture: "\"Show what you are saying, move your hands. Audiences listen with their ears and their eyes\" (Neff, 2020).\n\nMoving your hands during a virtual presentation will also make your more dynamic and your presentation less boring.\n\nHowever, do not move your hands too much. This could distract your audience from the focus of your presentation.",
        .eyeContact: "Eye contact invites your audience into your presentation.\n\nHowever, eye contact can be tricky in a virtual presentation because you are not actually looking at another person \"in the eye.\"\n\nTo make eye contact online, you need to look into the camera from time to time, likely about 50-75% of the presentation."
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        dialogBackgroundView.layer.cornerRadius = 10.0
        btnClose.layer.cornerRadius = 22.0
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        lblTip.text = tips[mode]
    }
    
    @IBAction func btnCloseClicked(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
}

extension PresentationTipViewController {
    static func showView(_ parentViewController: UIViewController, mode: PresentationTipMode) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let viewController = storyboard.instantiateViewController(identifier: "PresentationTipViewController") as? PresentationTipViewController {
            viewController.modalTransitionStyle = .crossDissolve
            viewController.modalPresentationStyle = .overFullScreen
            viewController.mode = mode
        
            parentViewController.present(viewController, animated: true, completion: nil)
        }
    }
}
