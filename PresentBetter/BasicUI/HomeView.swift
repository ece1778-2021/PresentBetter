//
//  HomeView.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI
import Firebase

struct HomeView: View {
    @EnvironmentObject var userInfo: UserInfo
    @State var isSignOut = false
    @State var lastScore = "0%"
    @State var highScore = 0
    
    let lightBlueColor = Color(red: 0.0/255.0, green: 224.0/255.0, blue: 249.0/255.0)
    
    var body: some View {
        if self.isSignOut {
            LoginView()
        }
        else {
            NavigationView{
                ZStack{
                    lightBlueColor
                    VStack{
                        Spacer()
                        Text("WELCOME BACK,\n\(GetUserName())!")
                            .foregroundColor(.white)
                            .font(.custom("Spartan-Bold", size: 45))
                            .multilineTextAlignment(.center)
                        Spacer()
                        HStack{
                            Spacer()
                            VStack{
                                Text("HIGH SCORE")
                                    .foregroundColor(.white)
                                    .font(.custom("Lato-Bold", size: 17))
                                    .multilineTextAlignment(.center)
                                Text("\(self.highScore)%")
                                    .foregroundColor(.white)
                                    .font(.custom("Oswald-Regular_Bold", size: 70))
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                            VStack{
                                Text("LAST SCORE")
                                    .foregroundColor(.white)
                                    .font(.custom("Lato-Bold", size: 17))
                                    .multilineTextAlignment(.center)
                                Text(self.lastScore)
                                    .foregroundColor(.white)
                                    .font(.custom("Oswald-Regular_Bold", size: 70))
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        Spacer()
                        Image("Present")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180, alignment: .center)
                            .foregroundColor(.white)
                        HStack {
                            Button(action: {
                                navigateToPresentationUI(mode: .trainingFacial)
                            }, label: {
                                Text("TRAIN")
                                    .foregroundColor(lightBlueColor)
                                    .font(.custom("Montserrat-SemiBold", size: 20))
                                    .multilineTextAlignment(.center)
                            })
                            .frame(width: 150, height: 50, alignment: .center)
                            .background(Color.white)
                            .cornerRadius(25)
                            
                            Button(action: {
                                navigateToPresentationUI(mode: .presenting)
                            }, label: {
                                Text("PRACTICE")
                                    .foregroundColor(lightBlueColor)
                                    .font(.custom("Montserrat-SemiBold", size: 20))
                                    .multilineTextAlignment(.center)
                            })
                            .frame(width: 150, height: 50, alignment: .center)
                            .background(Color.white)
                            .cornerRadius(25)
                            NavigationLink("Scores", destination: ScoresView())
                        }
                        .padding(.top, 30)
                        
                        Spacer()
                    }
                }
                .ignoresSafeArea()
                .navigationBarItems(trailing: Button(action: {
                    self.isSignOut = true
                    do {
                        try Auth.auth().signOut()
                    } catch let signOutError as NSError {
                        print ("Error signing out: %@", signOutError)
                    }
                }, label: {
                    Image(systemName:"arrow.right.circle.fill")
                }))
                .foregroundColor(.white)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .onAppear(){
                self.userInfo.GetName()
                self.getScore()
            }
        }
    }
    
    func GetUserName() -> String{
        return self.userInfo.name as! String
    }
    func navigateToPresentationUI(mode: PresentationMode = .presenting) {
        var viewControllerName = "RootNavigationTraining"
        if mode == .presenting {
            viewControllerName = "RootNavigation"
        }
        
        if let window = UIApplication.shared.windows.first {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let viewController = storyboard.instantiateViewController(identifier: viewControllerName)
        
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromRight, animations: nil, completion: nil)
        }
    }
    func getScore(){
        let db = Firestore.firestore()
        let userid = Auth.auth().currentUser?.uid
        //let dispatch = DispatchGroup()
        var scores: Array<String> = []
        
        
        db.collection("grades").whereField("uid", isEqualTo: userid as Any).order(by: "timestamp", descending: true)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        let score = document.data()["totalScore"] as! String
                        scores.append(score)
                        if self.highScore < Int(score.dropLast())!{
                            self.highScore = Int(score.dropLast())!
                        }
                    }
                    self.lastScore = scores[0]
                }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
