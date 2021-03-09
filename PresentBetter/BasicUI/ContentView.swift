//
//  ContentView.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI
import Firebase

struct ContentView: View {
    var body: some View {
        
        Group{
            if Auth.auth().currentUser != nil {
                HomeView()
            } else {
                LoginView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
