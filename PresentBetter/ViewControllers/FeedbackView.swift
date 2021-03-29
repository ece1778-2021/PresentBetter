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
    @IBOutlet var btnPlayback: UIButton!
    @IBOutlet var totalScoreView: UIView!
    @IBOutlet var lblTotalScore: UILabel!
    @IBOutlet var lblRank: UILabel!
    
    var userInfo = UserInfo()
    var totalSmiles = 0
    var totalHandMoves = 0
    var totalLooks = 0
    
    var mode: FeedbackMode = .new
    var videoURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        btnHome.layer.cornerRadius = 15.0
        
        if mode == .new && videoURL != nil {
            videoURL = processRecordedVideo(originalURL: videoURL!, timestamp: Date())
        }
        
        var totalScore = 0, avgScore = 0
        var score = 0, feedback = ""
        (score, feedback) = calculateFacialExpressionScore()
        totalScore += score
        lblFacialExpressionScore.text = "\(score)%"
        lblFacialExpressionFeedback.text = "Tip: \(feedback)"
        lblFacialExpressionFeedback.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showFacialExpressionTip)))
        lblFacialExpressionFeedback.isUserInteractionEnabled = true
        (score, feedback) = calculateGestureScore()
        totalScore += score
        lblGesturesScore.text = "\(score)%"
        lblGesturesFeedback.text = "Tip: \(feedback)"
        lblGesturesFeedback.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showGestureTip)))
        lblGesturesFeedback.isUserInteractionEnabled = true
        
        if ARFaceTrackingConfiguration.isSupported {
            btnPlayback.isHidden = true
            if let _ = videoURL {
                btnPlayback.isHidden = false
            }
            
            (score, feedback) = calculateEyeContactScore()
            totalScore += score
            lblEyeContactScore.text = "\(score)%"
            lblEyeContactFeedback.text = "Tip: \(feedback)"
            lblEyeContactFeedback.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showEyeContactTip)))
            lblEyeContactFeedback.isUserInteractionEnabled = true
            view.addConstraint(NSLayoutConstraint(item: totalScoreView!, attribute: .top, relatedBy: .equal, toItem: lblEyeContactFeedback, attribute: .bottom, multiplier: 1, constant: 30))
        } else {
            // Phones without TrueDepth camera will not support presentation video recording.
            btnPlayback.isHidden = true
            
            totalScore += 100
            lblEyeContactScore.isHidden = true
            lblEyeContactFeedback.isHidden = true
            view.addConstraint(NSLayoutConstraint(item: totalScoreView!, attribute: .top, relatedBy: .equal, toItem: lblGesturesFeedback, attribute: .bottom, multiplier: 1, constant: 30))
        }
        
        avgScore = totalScore / 3
        lblTotalScore.text = "\(avgScore)%"
        storeVars()
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        if let URL = videoURL {
            do {
                try FileManager.default.removeItem(at: URL)
            } catch let e {
                print(e)
            }
        }
        
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(userInfo))
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
    
    @IBAction func btnPlaybackClicked(_ sender: UIButton) {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(videoDeleted), name: Notification.presentationVideoDeleted, object: nil)
        PlaybackViewController.showView(self, videoURL: videoURL)
    }
    
    @objc func videoDeleted() {
        NotificationCenter.default.removeObserver(self)
        videoURL = nil
        btnPlayback.isHidden = true
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
    
    func processRecordedVideo(originalURL: URL, timestamp: Date) -> URL? {
        let documentRoots = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentRoot = documentRoots.first else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = formatter.string(from: timestamp)
        
        let newDir = documentRoot.appendingPathComponent("Videos")
        do {
            try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true, attributes: nil)
        } catch let e {
            print(e)
            return nil
        }
        
        guard let UID = Auth.auth().currentUser?.uid else {
            return nil
        }
        let newURL = newDir.appendingPathComponent("\(dateString)_\(UID).mp4")
        print(newURL)
        
        do {
            try FileManager.default.moveItem(at: originalURL, to: newURL)
        } catch let e {
            print(e)
            return nil
        }
        
        return newURL
    }
    
    func calculateFacialExpressionScore() -> (Int, String) {
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
    
    func calculateGestureScore() -> (Int, String) {
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
    
    func calculateEyeContactScore() -> (Int, String) {
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
    func storeVars(){
        let userid = Auth.auth().currentUser!.uid
        let db = Firestore.firestore()
        let timestamp = Int(NSDate().timeIntervalSince1970)
        
        var ref: DocumentReference? = nil
        ref = db.collection("grades").addDocument(data: [
            "uid": userid,
            "totalSmiles": self.totalSmiles,
            "totalHandMoves": self.totalHandMoves,
            "totalLooks": self.totalLooks,
            "totalScore": lblTotalScore.text,
            "timestamp": timestamp
        ]) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Successfully!")
            }
        }
    }
}
