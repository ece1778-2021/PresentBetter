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
    @Environment(\.presentationMode) var mode
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var error: String = ""
    @State private var isSigned = false
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var activeAlert: ActiveAlert = .first
    
    let lightBlueColor = Color(red: 0.0/255.0, green: 224.0/255.0, blue: 249.0/255.0)
    let pinkColor = Color(red: 253.0/255.0, green: 151.0/255.0, blue: 143.0/255.0)
    
    var body: some View {
        ZStack {
            NavigationView {
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
                            Text("REGISTER\nPB ACCOUNT")
                                .foregroundColor(.white)
                                .font(.custom("Montserrat-Bold", size: 45))
                                .multilineTextAlignment(.center)
                            Spacer()
                            HStack{
                                Image(systemName: "person.crop.square")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                                    .foregroundColor(.white)
                                    .padding(.leading, 30)
                                TextField("Name", text: $name)
                                    .font(Font.custom("Montserrat-SemiBold", size: 20))
                                    .frame(height: 45)
                                    .background(Color.white)
                                    .autocapitalization(.none)
                                    .cornerRadius(10)
                                    .padding(.trailing, 30)
                            }
                            HStack{
                                Image("User")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                                    .foregroundColor(.white)
                                    .padding(.leading, 30)
                                TextField("User", text: $email)
                                    .font(Font.custom("Montserrat-SemiBold", size: 20))
                                    .frame(height: 45)
                                    .background(Color.white)
                                    .autocapitalization(.none)
                                    .cornerRadius(10)
                                    .padding(.trailing, 30)
                            }
                            HStack{
                                Image("Password")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                                    .foregroundColor(.white)
                                    .padding(.leading, 30)
                                SecureField("Password", text: $password)
                                    .font(Font.custom("Montserrat-SemiBold", size: 20))
                                    .frame(height: 45)
                                    .background(Color.white)
                                    .autocapitalization(.none)
                                    .cornerRadius(10)
                                    .padding(.trailing, 30)
                            }
                            Spacer()
                            NavigationLink(
                                destination: HomeView(),
                                isActive: $isSigned,
                                label: {
                                    Button(action: check){
                                        Text("JOIN!")
                                            .foregroundColor(lightBlueColor)
                                            .font(.custom("Montserrat-SemiBold", size: 20))
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
                                .background(Color.white)
                                .cornerRadius(25)
                            Spacer()
                        }
                    }
                }
                .adaptsToKeyboard()
                .background(pinkColor)
                .ignoresSafeArea()
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
                        .padding(.top, 30)
                        .padding(.leading, 15)
                }))

            }
            .navigationBarHidden(true)
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            
            if isLoading{
                GeometryReader{ geometry in
                    LoadingView()
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }
                .background(Color.black.opacity(0.45).edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/))
                
            }
        }
    }
    
    func check() {
        self.isLoading.toggle()
        if email.isEmpty||password.isEmpty{
            self.isLoading.toggle()
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
                self.isLoading.toggle()
                self.error = error.localizedDescription
                self.showAlert = true
                self.activeAlert = .forth
            }else{
                register()
            }
        }
    }
    func register(){
        let db = Firestore.firestore()
        let userid = Auth.auth().currentUser?.uid
        
        if let userid = userid{
            //var ref: DocumentReference? = nil
            db.document("users/\(userid)").setData([
                //"author": user?.uid as Any,
                "Name": name.description
            ]) { err in
                if let err = err {
                    print("Error adding document: \(err)")
                } else {
                   // print("Document added with ID: \(ref!.documentID)"
                    print("successfully")
                    self.isLoading.toggle()
                    self.isSigned = true
                }
            }
        }
        else{
            print("Filed to create user!")
        }
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}
