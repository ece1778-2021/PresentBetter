//
//  ScoresView.swift
//  PresentBetter
//
//  Created by dyf on 2021-03-27.
//

import SwiftUI
import Firebase

struct ScoresView: View {
    @EnvironmentObject var userInfo: UserInfo
    @Environment(\.presentationMode) var mode
    @State var scores: Array<String> = []
    @State var timestamps: Array<String> = []
    @State var timestampsRaw = [Date]()
    @State var lastScore = "0%"
    @State var highScore = 0
    
    @State var totalSmiles = [Int]()
    @State var totalHandMoves = [Int]()
    @State var totalLooks = [Int]()
    
    let lightBlueColor = Color(red: 0.0/255.0, green: 224.0/255.0, blue: 249.0/255.0)
    
    var body: some View {
        ZStack{
            lightBlueColor
            VStack{
                Spacer()
                HStack{
                    Text("SCORES")
                        .foregroundColor(.white)
                        .font(.custom("Spartan-Bold", size: 37))
                        .multilineTextAlignment(.center)
                        .padding(.leading, 40)
                    Spacer()
                }
                ExDivider()
                    //ScrollView{
                        //LazyVGrid(columns: [GridItem()]) {
                            ForEach(0..<scores.count, id: \.self) { i in
                                HStack{
                                    Button(action: {
                                        navigateToFeedbackUI(item: i)
                                    }){
                                        Text(timestamps[i])
                                            .foregroundColor(.white)
                                            .font(.custom("Montserrat-SemiBold", size: 22))
                                        Text(scores[i])
                                            .foregroundColor(.white)
                                            .font(.custom("Montserrat-SemiBold", size: 22))
                                    }
                                }
                            }
                        //}
                    //}
                Spacer()
                Spacer()
            }
            .alignmentGuide(.top) { d in d[.top] }
            .padding(.top, 30)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            self.mode.wrappedValue.dismiss()
        }, label: {
            Text("BACK")
                .frame(width: 100, height: 35, alignment: .center)
                .foregroundColor(.white)
                .font(.custom("MontSerrat-SemiBold", size: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 2)
                )
                .padding(.top, 7)
                .padding(.leading, 15)
        }))
        .onAppear{
            self.getScore()
        }
    }
    
    func test(){
        
    }
    
    func navigateToFeedbackUI(item: Int) {
        if let window = UIApplication.shared.windows.first {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let viewController = storyboard.instantiateViewController(identifier: "FeedbackViewController") as? FeedbackViewController else {
                return
            }
            
            viewController.timestamp = timestampsRaw[item]
            viewController.totalSmiles = totalSmiles[item]
            viewController.totalLooks = totalLooks[item]
            viewController.totalHandMoves = totalHandMoves[item]
            viewController.mode = .viewExisting
        
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromRight, animations: nil, completion: nil)
        }
    }
    
    func getScore(){
        let db = Firestore.firestore()
        let userid = Auth.auth().currentUser?.uid
        //let dispatch = DispatchGroup()
        
        
        db.collection("grades").whereField("uid", isEqualTo: userid as Any).order(by: "timestamp", descending: true)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        let score = document.data()["totalScore"] as! String
                        let timestamp = document.data()["timestamp"] as! Int
                        let totalLooks = document.data()["totalLooks"] as! Int
                        let totalSmiles = document.data()["totalSmiles"] as! Int
                        let totalHandMoves = document.data()["totalHandMoves"] as! Int
                        
                        self.totalLooks.append(totalLooks)
                        self.totalSmiles.append(totalSmiles)
                        self.totalHandMoves.append(totalHandMoves)
                        
                        timestamps.append(changeTimestamp(timeStamp: timestamp))
                        let timestampRaw = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        timestampsRaw.append(timestampRaw)
                        
                        scores.append(score)
                        if self.highScore < Int(score.dropLast())!{
                            self.highScore = Int(score.dropLast())!
                        }
                    }
                    self.lastScore = scores[0]
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
}

struct ExDivider: View {
    let color: Color = .white
    let width: CGFloat = 2
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 350, height: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}

struct ScoresView_Previews: PreviewProvider {
    static var previews: some View {
        ScoresView()
    }
}
