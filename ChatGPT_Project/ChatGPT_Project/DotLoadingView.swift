//
//  DotLoadingView.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 02/02/23.
//

import SwiftUI

struct DotLoadingView: View {
    
    @State private var showCircles = false
    
    var body: some View {
        HStack {
            Circle()
                .opacity(showCircles ? 1 : 0)
        }
        .foregroundColor(.black)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever()) {
                self.showCircles.toggle()
            }
        }
    }
}

struct DotLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        DotLoadingView()
    }
}

