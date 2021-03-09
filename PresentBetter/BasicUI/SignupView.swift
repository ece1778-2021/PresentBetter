//
//  SignupView.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI
import Firebase

enum ActiveAlert {
    case first, second, third, forth
}

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var error: String = ""
    @State private var isSigned = false
    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .first
    
    let lightBlueColor = Color(red: 0.0/255.0, green: 224.0/255.0, blue: 249.0/255.0)
    
    var body: some View {
        VStack{
            Spacer()
            Text("Sign Up")
                .foregroundColor(.white)
                .font(.system(size: 45, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
            Spacer()
            HStack{
                Image(systemName: "person")
                    .resizable()
                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    .padding(.leading)
                TextField("", text: $email)
                    .font(Font.custom("Arial", size: 40))
                    .cornerRadius(5)
                    .background(Color.white)
                    .autocapitalization(.none)
                    .padding(.trailing)
            }
            HStack{
                Image(systemName: "lock")
                    .resizable()
                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    .padding(.leading)
                SecureField("", text: $password)
                    .font(Font.custom("Arial", size: 40))
                    .cornerRadius(5)
                    .background(Color.white)
                    .autocapitalization(.none)
                    .padding(.trailing)
            }
            Spacer()
            NavigationLink(
                destination: HomeView(),
                isActive: $isSigned,
                label: {
                    Button(action: check){
                        Text("Sign Up")
                            .foregroundColor(lightBlueColor)
                            .font(.system(size: 20, weight: .bold, design: .default))
                    }
                    .alert(isPresented: $showAlert){
                        switch activeAlert{
                        case .first:
                            return Alert(title: Text("Please fill out the blank area!"))
                        case .second:
                            return Alert(title: Text("Two passwords do not match!"))
                        case .third:
                            return Alert(title: Text("Please set up a picture!"))
                        case .forth:
                            return Alert(title: Text(self.error))
                        }
                    }
                })
                .frame(width: 150, height: 50, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                .clipped()
                .cornerRadius(30)
                .background(Color.white)
                .padding(.bottom, 3.0)
            Spacer()
        }
        .adaptsToKeyboard()
        .background(lightBlueColor)
        .ignoresSafeArea()
    }
    func check() {
        if email.isEmpty||password.isEmpty{
            self.showAlert = true
            self.activeAlert = .first
        }
        else{
            SignUp()
        }
    }
    
    func SignUp(){
        Auth.auth().createUser(withEmail: email.description, password: password.description) { (result, error) in
            if let error = error{
                self.error = error.localizedDescription
                self.showAlert = true
                self.activeAlert = .forth
            }else{
                print("successfully")
                self.isSigned = true
                //register()
            }
        }
    }
    func register(){
        
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}
