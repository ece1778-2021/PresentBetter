//
//  HomeView.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI
import Firebase

struct HomeView: View {
    @State var isSignOut = false
    
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
                        Text("WELCOME BACK,\nUSER!")
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
                                Text("0%")
                                    .foregroundColor(.white)
                                    .font(.custom("Oswald-Regular_Bold", size: 70))
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                            VStack{
                                Text("RANK")
                                    .foregroundColor(.white)
                                    .font(.custom("Lato-Bold", size: 17))
                                    .multilineTextAlignment(.center)
                                Text("1st")
                                    .foregroundColor(.white)
                                    .font(.custom("Oswald-Regular_Bold", size: 70))
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        Spacer()
                        Button(action: {
                            navigateToPresentationUI()
                        }, label: {
                            Image("Present")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100, alignment: .center)
                                .foregroundColor(.white)
                        })
                        Text("PRACTICE PRESENTING")
                            .foregroundColor(.white)
                            .font(.custom("Montserrat-SemiBold", size: 20))
                            .multilineTextAlignment(.center)
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
        }
    }
    
    func navigateToPresentationUI() {
        if let window = UIApplication.shared.windows.first {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let viewController = storyboard.instantiateViewController(identifier: "RootNavigation")
        
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromRight, animations: nil, completion: nil)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
