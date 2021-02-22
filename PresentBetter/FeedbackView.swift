import UIKit

class FeedbackViewController: UIViewController {
    @IBOutlet var lblFacialExpressionScore: UILabel!
    @IBOutlet var lblFacialExpressionFeedback: UILabel!
    
    var totalSmiles = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        var score = 0, feedback = ""
        (score, feedback) = calculateScore()
        
        lblFacialExpressionScore.text = "\(score)%"
        lblFacialExpressionFeedback.text = "Tip: \(feedback)"
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    func calculateScore() -> (Int, String) {
        var score: CGFloat = 0
        var feedback = ""
        
        if totalSmiles <= 15 {
            score = CGFloat(totalSmiles) / 15.0 * 100
            
            if score < 50 {
                feedback = "Smile more"
            } else if score < 80 {
                feedback = "Smile slightly more"
            } else {
                feedback = "Nothing to change"
            }
        } else {
            score = 100 - 25 * (CGFloat(totalSmiles - 15) / 15.0)
            feedback = "Smile slightly less"
        }
        
        return (Int(score), feedback)
    }
}
