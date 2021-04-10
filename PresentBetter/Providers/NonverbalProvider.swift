import UIKit

class NonverbalProvider {
    static func calculateFacialExpressionScore(_ totalSmiles: Int) -> (Int, String) {
        var score: CGFloat = 0
        var feedback = ""
        
        if totalSmiles < 15 {
            score = CGFloat(totalSmiles) / 15.0 * 60
            if score < 30 {
                feedback = "Your face was neutral. Your need to smile from time to time to show you are interested in your presentation. "
            } else {
                feedback = "Try smiling a bit more frequently."
            }
        } else if totalSmiles <= 22 {
            score = 80 + 20 * CGFloat(totalSmiles - 15) / 7.0
            feedback = "Excellent facial expressions!"
        } else {
            score = 80 - 20 * CGFloat(totalSmiles - 22) / 8.0
            feedback = "It's great to smile when presenting, but try to smile a little less."
        }
        
        return (Int(score), feedback)
    }
    
    static func calculateGestureScore(_ totalHandMoves: Int) -> (Int, String) {
        var score: CGFloat = 0
        var feedback = ""
        
        if totalHandMoves < 15 {
            score = CGFloat(totalHandMoves) / 15.0 * 60
            if score < 30 {
                feedback = "You rarely moved your arms. Try moving your hands to add emphasis to your presentation. "
            } else {
                feedback = "Try moving your hands more frequently."
            }
        } else if totalHandMoves <= 22 {
            score = 80 + 20 * CGFloat(totalHandMoves - 15) / 7.0
            feedback = "Excellent gestures!"
        } else {
            score = 80 - 20 * CGFloat(totalHandMoves - 22) / 8.0
            feedback = "It's great to move your hands when presenting, but try to move them a bit less."
        }
        
        return (Int(score), feedback)
    }
    
    static func calculateEyeContactScore(_ totalLooks: Int) -> (Int, String) {
        var score: CGFloat = 0
        var feedback = ""
        
        if totalLooks < 15 {   // ~50%
            score = CGFloat(totalLooks) / 15.0 * 60
            if score < 30 {
                feedback = "You rarely made eye contact. Look at the camera 50-75% of the time you are presenting."
            } else {
                feedback = "Try moving making eye contact by looking at the camera more frequently."
            }
        } else if totalLooks <= 22 {    // ~75%
            score = 80 + 20 * CGFloat(totalLooks - 15) / 7.0
            feedback = "Excellent eye contact!"
        } else {
            score = 80 - 20 * CGFloat(totalLooks - 22) / 8.0
            feedback = "It's great to make eye contact, but try not to look at the camera the entire time. "
        }
        
        return (Int(score), feedback)
    }
}
