//
//  LoadingView.swift
//  PresentBetter
//
//  Created by dyf on 2021-03-15.
//

import SwiftUI

struct LoadingView: View {
    @State var animate = false
    
    var body: some View {
        VStack{
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(AngularGradient(gradient: .init(colors: [.red,.orange]), center: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/ ), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 45, height: 45, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                .rotationEffect(.init(degrees: self.animate ? 360 : 0))
                .animation(Animation.linear(duration: 0.7).repeatForever(autoreverses: false))
            Text("Please waiting...").padding(.top)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .onAppear{
            self.animate.toggle()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
