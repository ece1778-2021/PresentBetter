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
    let pinkColor = Color(red: 253.0/255.0, green: 151.0/255.0, blue: 143.0/255.0)
    
    var body: some View {
        NavigationView{
            VStack{
                ZStack {
                    VStack {
                        GeometryReader { geometry in
                            Image("ShapeArt")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: geometry.size.height / 2)
                        }
                    }
                    VStack {
                        Spacer()
                        Spacer()
                        VStack{
                            Text("PRESENT\nBETTER")
                                .foregroundColor(.white)
                                .font(.custom("Montserrat-Bold", size: 45))
                                .multilineTextAlignment(.center)
                            HStack{
                                Image(systemName: "person")
                                    .resizable()
                                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                                    .foregroundColor(.white)
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.leading, 30)
                                TextField("", text: $email)
                                    .font(Font.custom("Montserrat-SemiBold", size: 20))
                                    .frame(height: 45)
                                    .cornerRadius(5)
                                    .background(Color.white)
                                    .autocapitalization(.none)
                                    .padding(.trailing, 30)
                            }
                            HStack{
                                Image(systemName: "lock")
                                    .resizable()
                                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                                    .foregroundColor(.white)
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.leading, 30)
                                SecureField("", text: $password)
                                    .font(Font.custom("Montserrat-SemiBold", size: 20))
                                    .frame(height: 45)
                                    .cornerRadius(5)
                                    .background(Color.white)
                                    .autocapitalization(.none)
                                    .padding(.trailing, 30)
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
                                        .font(.custom("Montserrat-SemiBold", size: 20))
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
                                    .font(.custom("Montserrat-SemiBold", size: 20))
                            })
                            .navigationBarHidden(true)
                        Spacer()
                    }
                }
            }
            .adaptsToKeyboard()
            .background(pinkColor)
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
