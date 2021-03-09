//
//  LoginView.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI
import Firebase

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var error = ""
    @State private var isLogin = false
    @State private var isAlert = false
    
    let lightBlueColor = Color(red: 0.0/255.0, green: 224.0/255.0, blue: 249.0/255.0)
    
    var body: some View {
        NavigationView{
            VStack{
                Spacer()
                VStack{
                    Text("PRESENT\nBETTER")
                        .foregroundColor(.white)
                        .font(.system(size: 45, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
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
                    

                    
                }
                Spacer()
                NavigationLink(
                    destination: HomeView(),
                    isActive: $isLogin,
                    label: {
                        Button(action: login){
                            Text("Sign in")
                                .foregroundColor(lightBlueColor)
                                .font(.system(size: 20, weight: .bold, design: .default))
                        }
                        .alert(isPresented: $isAlert, content: {
                            Alert(title: Text(error)
                            )
                        })
                    })
                    .frame(width: 150, height: 50, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    .clipped()
                    .cornerRadius(30)
                    .background(Color.white)
                    .padding(.bottom, 10.0)
                
                NavigationLink(
                    destination: SignupView(),
                    label: {
                        Text("Sign Up?")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold, design: .default))
                    })
                Spacer()
            }
            .adaptsToKeyboard()
            .background(lightBlueColor)
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    
    func login(){
        Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
            if let error = error {
                self.error = error.localizedDescription
                self.isAlert = true
            }
            else{
                self.isLogin = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
