//
//  PresentationViewSUI.swift
//  PresentBetter_SwiftUI
//
//  Created by dyf on 2021-03-06.
//

import SwiftUI

struct PresentationViewSUI: UIViewControllerRepresentable {
        
    typealias UIViewControllerType = PresentationViewController
        
      func makeUIViewController(context: UIViewControllerRepresentableContext<PresentationViewSUI>) -> PresentationViewSUI.UIViewControllerType {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "PresentationViewController") as! PresentationViewController
    }
        
      func updateUIViewController(_ uiViewController: PresentationViewSUI.UIViewControllerType, context: UIViewControllerRepresentableContext<PresentationViewSUI>) {}
    
}
