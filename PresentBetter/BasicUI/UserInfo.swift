//
//  UserInfo.swift
//  PresentBetter
//
//  Created by dyf on 2021-03-26.
//

import Foundation
import SwiftUI
import Firebase

class UserInfo: UIViewController, ObservableObject {
    @Published var name:Any = ""
    
    func GetName(){
        let db = Firestore.firestore()

        db.collection("users").document(Auth.auth().currentUser!.uid).getDocument { (document, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                print(123)
                //print("\(document.documentID) => \(document.data())")
                if let document = document, document.exists {
                        let userData = document.data()
                        self.name = userData!["Name"] as Any
                    } else {
                        print("Document does not exist")
                }
            }
        }
    }
}
