import UIKit

class FeedbackViewController: UIViewController {
    @IBOutlet var lblFacialExpressionScore: UILabel!
    @IBOutlet var lblFacialExpressionFeedback: UILabel!
    @IBOutlet var lblGesturesScore: UILabel!
    @IBOutlet var lblGesturesFeedback: UILabel!
    
    var totalSmiles = 0
    var totalHandMoves = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        var score = 0, feedback = ""
        
        (score, feedback) = calculateFacialExpressionScore()
        lblFacialExpressionScore.text = "\(score)%"
        lblFacialExpressionFeedback.text = "Tip: \(feedback)"
        (score, feedback) = calculateGestureScore()
        lblGesturesScore.text = "\(score)%"
        lblGesturesFeedback.text = "Tip: \(feedback)"
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    func calculateFacialExpressionScore() -> (Int, String) {
        var score: CGFloat = 0
        var feedback = ""
        
        if totalSmiles <= 15 {
            score = CGFloat(totalSmiles) / 15.0 * 100
            
            if score < 50 {
                feedback = "Your face was neutral. Your need to smile from time to time to show you are interested in your presentation. "
            } else if score < 80 {
                feedback = "Try smiling a bit more frequently."
            } else {
                feedback = "Excellent facial expressions!"
            }
        } else {
            score = 100 - 25 * (CGFloat(totalSmiles - 15) / 15.0)
            feedback = "It's great to smile when presenting, but try to smile a little less."
        }
        
        return (Int(score), feedback)
    }
    
    func calculateGestureScore() -> (Int, String) {
        var score: CGFloat = 0
        var feedback = ""
        
        if totalHandMoves <= 24 {
            score = CGFloat(totalHandMoves) / 24.0 * 100
            
            if score < 50 {
                feedback = "You rarely moved your arms. Try moving your hands to add emphasis to your presentation. "
            } else if score < 80 {
                feedback = "Try moving your hands more frequently."
            } else {
                feedback = "Excellent gestures!"
            }
        } else {
            score = 100 - 25 * (CGFloat(totalHandMoves - 24) / 6.0)
            feedback = "It's great to move your hands when presenting, but try to move them a bit less."
        }
        
        return (Int(score), feedback)
    }
}
