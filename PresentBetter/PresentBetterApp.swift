//
//  PresentBetter_SwiftUIApp.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI
import Firebase

@main
struct PresentBetterApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var userInfo = UserInfo()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(userInfo)
        }
    }
}

class AppDelegate: NSObject,UIApplicationDelegate{
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            
        print("setting up firebase")
        FirebaseApp.configure()
        
        return true
    }
}
