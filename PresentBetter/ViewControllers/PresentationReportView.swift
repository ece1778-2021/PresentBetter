import ARKit
import Firebase
import SwiftUI
import UIKit

class PresentationReportViewController: UIViewController {
    @IBOutlet var btnHome: UIButton!
    @IBOutlet var viewRecording: UIStackView!
    @IBOutlet var viewNonverbal: UIView!
    @IBOutlet var viewVerbal: UIView!
    @IBOutlet var lblNonverbalScore: UILabel!
    @IBOutlet var lblVerbalScore: UILabel!
    @IBOutlet var lblVerbalPace: UILabel!
    
    var userInfo = UserInfo()
    
    var totalSmiles = 0
    var totalHandMoves = 0
    var totalLooks = 0
    var timestamp: Date?
    var highScore = 0
    
    var mode: FeedbackMode = .new
    var videoURL: URL?
    var averageNonverbalScore = 0
    var averageWordsPerMinute: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        btnHome.layer.cornerRadius = 17.0
        
        let (facialScore, _) = NonverbalProvider.calculateFacialExpressionScore(totalSmiles)
        let (gestureScore, _) = NonverbalProvider.calculateGestureScore(totalHandMoves)
        let (eyeContactScore, _) = NonverbalProvider.calculateEyeContactScore(totalLooks)
        
        if ARFaceTrackingConfiguration.isSupported {
            averageNonverbalScore = (facialScore + gestureScore + eyeContactScore) / 3
        } else {
            averageNonverbalScore = (facialScore + gestureScore + 100) / 3
        }
        lblNonverbalScore.text = "\(averageNonverbalScore)/100"
        viewNonverbal.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewNonverbalClicked)))
        viewNonverbal.isUserInteractionEnabled = true
        
        lblVerbalPace.text = "(\(Int(averageWordsPerMinute)) wpm)"
        lblVerbalScore.text = VerbalProvider.calculateVerbalRating(averageWordsPerMinute)
        viewVerbal.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewVerbalClicked)))
        viewVerbal.isUserInteractionEnabled = true
        
        if mode == .new {
            timestamp = Date()
            if videoURL != nil {
                videoURL = processRecordedVideo(originalURL: videoURL!, timestamp: timestamp!)
            }
            storeVars()
        } else {
            btnHome.setTitle("BACK", for: .normal)
            if let timestamp = timestamp,
               let documentRoot = getDocumentRoot(),
               let UID = Auth.auth().currentUser?.uid {
                let dateString = formatTime(timestamp: timestamp)
                let newDir = documentRoot.appendingPathComponent("Videos").appendingPathComponent("\(dateString)_\(UID).mp4")
                
                if FileManager.default.fileExists(atPath: newDir.path) {
                    videoURL = newDir
                }
            }
        }
        
        if videoURL != nil {
            viewRecording.isHidden = false
        } else {
            viewRecording.isHidden = true
        }
        viewRecording.isUserInteractionEnabled = true
        viewRecording.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(btnPlaybackClicked)))
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "forwardToFeedback" {
            let destination = segue.destination as! FeedbackViewController
            destination.highScore = highScore
            destination.totalLooks = totalLooks
            destination.totalSmiles = totalSmiles
            destination.totalHandMoves = totalHandMoves
        }
    }
    
    func formatTime(timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = formatter.string(from: timestamp)
        
        return dateString
    }
    
    func getDocumentRoot() -> URL? {
        let documentRoots = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentRoot = documentRoots.first else {
            return nil
        }
        return documentRoot
    }
    
    func processRecordedVideo(originalURL: URL, timestamp: Date) -> URL? {
        guard let documentRoot = getDocumentRoot() else {
            return nil
        }
        let dateString = formatTime(timestamp: timestamp)
        
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
    
    func storeVars(){
        let userid = Auth.auth().currentUser!.uid
        let db = Firestore.firestore()
        let timestamp = Int(self.timestamp!.timeIntervalSince1970)
        
        let _: DocumentReference? = db.collection("grades").addDocument(data: [
            "uid": userid,
            "totalSmiles": self.totalSmiles,
            "totalHandMoves": self.totalHandMoves,
            "totalLooks": self.totalLooks,
            "totalScore": "\(self.averageNonverbalScore)%",
            "wordsPerMinute": self.averageWordsPerMinute,
            "timestamp": timestamp
        ]) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Successfully!")
            }
        }
    }
    
    @objc func videoDeleted() {
        NotificationCenter.default.removeObserver(self)
        videoURL = nil
        viewRecording.isHidden = true
    }
    
    @objc func btnPlaybackClicked() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(videoDeleted), name: Notification.presentationVideoDeleted, object: nil)
        PlaybackViewController.showView(self, videoURL: videoURL)
    }
    
    @objc func viewNonverbalClicked() {
        performSegue(withIdentifier: "forwardToFeedback", sender: self)
    }
    
    @objc func viewVerbalClicked() {
        PresentationTipViewController.showView(self, mode: .speech)
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        if mode == .new {
            if let window = UIApplication.shared.windows.first {
                window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(userInfo))
                window.makeKeyAndVisible()
                UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
            }
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}
