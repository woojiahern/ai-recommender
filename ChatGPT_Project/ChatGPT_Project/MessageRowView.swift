//
//  MessageRowView.swift
//  ChatGPT_Project
//
//  Created by Matthew Woo on 2024/03/20.
//

import SwiftUI

struct MessageRowView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    let message: MessageRow
    let retryCallback: (MessageRow) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            
            messageRow(text: message.sendText, image: message.sendImage, bgColor: colorScheme == .light ? .white : Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 0), indicateAIorUser: "You")
            
            if let text = message.responseText {
                //Divider()
                messageRow(text: text, image: message.responseImage, bgColor: colorScheme == .light ? .white: Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 0), indicateAIorUser: "AI Assistant", responseError: message.responseError, showDotLoading: message.isInteractingWithAI)
                //Divider()
            }
            
        }
        
       
    }
    
    func messageRow(text: String, image: String, bgColor: Color, indicateAIorUser: String, responseError: String? = nil, showDotLoading: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if image.hasPrefix("http"), let url = URL(string: image) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .frame(width: 25, height: 25)
                        .background(Color.white)
                        .clipShape(Circle())
                        .scaledToFit()

                        
                    
                } placeholder: {
                    ProgressView()
                }
                
            } else {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .padding(indicateAIorUser == "AI Assistant" ? 5 : 0)
                    .frame(width: 30, height: 30)
                    .background(Color.white)
                    .clipShape(Circle())
                    .colorMultiply(indicateAIorUser == "AI Assistant" && colorScheme == .light ? .white : .white)
                    
            }
            
            
            
            VStack(alignment: .leading) {
                if !text.isEmpty {
                    Text(indicateAIorUser)
                        .padding(2)
                        .bold()
                    Text(text)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                    
                } else if showDotLoading {
                    DotLoadingView().frame(width:20, height:20).padding(.top)
                }
                
                
                if let error = responseError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(/*@START_MENU_TOKEN@*/.leading/*@END_MENU_TOKEN@*/)
                    
                    Button("Regenerate response") {
                        retryCallback(message)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.top)
                    
                }
                
                
            }
            
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        
    }
    
    
    
}



struct MessageRowView_Previews: PreviewProvider {
    
    static let message = MessageRow(
        isInteractingWithAI: false,
        sendImage: "profile",
        sendText: "Hello",
        responseImage: "openai",
        responseText: "Hello. How may I assist you?")
    
    
    static var previews: some View {
        NavigationStack {
            ScrollView {
                MessageRowView(message: message,
                               retryCallback: { messageRow in
                    
                })
                .frame(width: 400)
                .previewLayout(.sizeThatFits)
            }
        }
    }
}

