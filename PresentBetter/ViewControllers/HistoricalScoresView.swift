import Firebase
import SwiftUI
import UIKit

class HistoricalScoresViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    @IBOutlet var lblLastScore: UILabel!
    @IBOutlet var lblHighScore: UILabel!
    @IBOutlet var btnBack: UIButton!
    
    var scores: Array<String> = []
    var timestamps: Array<String> = []
    var timestampsRaw = [Date]()
    var lastScore = "0%"
    var highScore = 0
    
    var totalSmiles = [Int]()
    var totalHandMoves = [Int]()
    var totalLooks = [Int]()
    var averageWordsPerMinute = [CGFloat]()
    
    var navigateToIndex = 0
    
    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        tableView.delegate = self
        tableView.dataSource = self
        
        btnBack.layer.cornerRadius = 17.0
        
        getScore() { err in
            if err == nil {
                self.lblLastScore.text = self.lastScore
                self.lblHighScore.text = "\(self.highScore)%"
                self.tableView.reloadData()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "forwardToReport" {
            if let viewController = segue.destination as? PresentationReportViewController {
                viewController.timestamp = timestampsRaw[navigateToIndex]
                viewController.totalSmiles = totalSmiles[navigateToIndex]
                viewController.totalLooks = totalLooks[navigateToIndex]
                viewController.totalHandMoves = totalHandMoves[navigateToIndex]
                viewController.averageWordsPerMinute = averageWordsPerMinute[navigateToIndex]
                viewController.highScore = highScore
                viewController.mode = .viewExisting
            }
        }
    }
    
    @objc func forwardToFeedback(sender: UITapGestureRecognizer) {
        if let tag = sender.view?.tag {
            navigateToIndex = tag - 100
            performSegue(withIdentifier: "forwardToReport", sender: self)
        }
    }
    
    @IBAction func btnBackClicked(_ sender: UIButton) {
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(UserInfo()))
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
    
    func getScore(completion: ((_ err: Error?) -> Void)?){
        let db = Firestore.firestore()
        let userid = Auth.auth().currentUser?.uid
        
        db.collection("grades").whereField("uid", isEqualTo: userid as Any).order(by: "timestamp", descending: true)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                    completion?(err)
                } else {
                    for document in querySnapshot!.documents {
                        let score = document.data()["totalScore"] as! String
                        let timestamp = document.data()["timestamp"] as! Int
                        let totalLooks = document.data()["totalLooks"] as! Int
                        let totalSmiles = document.data()["totalSmiles"] as! Int
                        let totalHandMoves = document.data()["totalHandMoves"] as! Int
                        let averageWordsPerMinute: CGFloat = document.data()["wordsPerMinute"] as? CGFloat ?? 0
                        
                        self.totalLooks.append(totalLooks)
                        self.totalSmiles.append(totalSmiles)
                        self.totalHandMoves.append(totalHandMoves)
                        self.averageWordsPerMinute.append(averageWordsPerMinute)
                        
                        self.timestamps.append(self.changeTimestamp(timeStamp: timestamp))
                        let timestampRaw = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        self.timestampsRaw.append(timestampRaw)
                        
                        self.scores.append(score)
                        if self.highScore < Int(score.dropLast())!{
                            self.highScore = Int(score.dropLast())!
                        }
                    }
                    self.lastScore = self.scores[0]
                    completion?(nil)
                }
            }
    }
    
    func changeTimestamp(timeStamp:Int) -> String{
        let timeInterval:TimeInterval = TimeInterval(timeStamp)
        let date = Date(timeIntervalSince1970: timeInterval)
        let dformatter = DateFormatter()
        dformatter.dateFormat = "MMM d, h:mm a"
        let reformedDate = dformatter.string(from: date)
        return reformedDate
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scores.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scoreCell", for: indexPath)
        let row = indexPath.row
        
        cell.tag = 100 + row
        cell.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(forwardToFeedback)))
        
        if let lblTime = cell.viewWithTag(1) as? UILabel {
            lblTime.text = timestamps[row]
        }
        
        if let lblScore = cell.viewWithTag(2) as? UILabel {
            lblScore.text = scores[row]
        }
        
        return cell
    }
}
