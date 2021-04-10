import ARKit
import Firebase
import SwiftUI
import UIKit

enum FeedbackMode {
    case new
    case viewExisting
}

class FeedbackViewController: UIViewController {
    @IBOutlet var lblFacialExpressionScore: UILabel!
    @IBOutlet var lblFacialExpressionFeedback: UILabel!
    @IBOutlet var lblGesturesScore: UILabel!
    @IBOutlet var lblGesturesFeedback: UILabel!
    @IBOutlet var lblEyeContactScore: UILabel!
    @IBOutlet var lblEyeContactFeedback: UILabel!
    @IBOutlet var btnHome: UIButton!
    @IBOutlet var totalScoreView: UIView!
    @IBOutlet var lblTotalScore: UILabel!
    @IBOutlet var lblRank: UILabel!
    
    var totalSmiles = 0
    var totalHandMoves = 0
    var totalLooks = 0
    var highScore = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        btnHome.layer.cornerRadius = 15.0
        
        var totalScore = 0, avgScore = 0
        var score = 0, feedback = ""
        (score, feedback) = NonverbalProvider.calculateFacialExpressionScore(totalSmiles)
        totalScore += score
        lblFacialExpressionScore.text = "\(score)%"
        lblFacialExpressionFeedback.text = "Tip: \(feedback)"
        lblFacialExpressionFeedback.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showFacialExpressionTip)))
        lblFacialExpressionFeedback.isUserInteractionEnabled = true
        
        (score, feedback) = NonverbalProvider.calculateGestureScore(totalHandMoves)
        totalScore += score
        lblGesturesScore.text = "\(score)%"
        lblGesturesFeedback.text = "Tip: \(feedback)"
        lblGesturesFeedback.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showGestureTip)))
        lblGesturesFeedback.isUserInteractionEnabled = true
        
        if ARFaceTrackingConfiguration.isSupported {
            (score, feedback) = NonverbalProvider.calculateEyeContactScore(totalLooks)
            totalScore += score
            lblEyeContactScore.text = "\(score)%"
            lblEyeContactFeedback.text = "Tip: \(feedback)"
            lblEyeContactFeedback.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showEyeContactTip)))
            lblEyeContactFeedback.isUserInteractionEnabled = true
            view.addConstraint(NSLayoutConstraint(item: totalScoreView!, attribute: .top, relatedBy: .equal, toItem: lblEyeContactFeedback, attribute: .bottom, multiplier: 1, constant: 30))
        } else {
            // Phones without TrueDepth camera will not support presentation video recording.
            totalScore += 100
            lblEyeContactScore.isHidden = true
            lblEyeContactFeedback.isHidden = true
            view.addConstraint(NSLayoutConstraint(item: totalScoreView!, attribute: .top, relatedBy: .equal, toItem: lblGesturesFeedback, attribute: .bottom, multiplier: 1, constant: 30))
        }
        
        avgScore = totalScore / 3
        lblTotalScore.text = "\(avgScore)%"
        lblRank.text = "\(highScore)%"
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func showFacialExpressionTip() {
        PresentationTipViewController.showView(self, mode: .facialExpression)
    }
    
    @objc func showGestureTip() {
        PresentationTipViewController.showView(self, mode: .gesture)
    }
    
    @objc func showEyeContactTip() {
        PresentationTipViewController.showView(self, mode: .eyeContact)
    }
}
