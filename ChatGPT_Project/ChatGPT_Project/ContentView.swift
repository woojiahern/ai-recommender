//
//  ContentView.swift
//  ChatGPT_Project
//
//  Created by Matthew Woo on 2024/03/05.
//

import SwiftUI
import Foundation
import NaturalLanguage
import SVDB
import SwiftCSV
import Accelerate
import CoreML
import SimilaritySearchKit

struct ContentView: View {

    @Environment(\.colorScheme) var colorScheme
    @StateObject var vm = ViewModel(api: GPTAPI())
    @FocusState var isTextFieldFocused: Bool
    
    var body: some View {
        
        VStack(spacing: 0) {
            chatListView
                .navigationTitle("AI Assistant")
//                .toolbar {
//                    ToolbarItem(placement: .principal) {
//                        Text("AI Assistant")
//                            .bold()
//                            .font(.title2) // Make the font smaller than the default title size
//                            .foregroundColor(.primary) // Use the primary color
//                    }
//                }
        }

    }
    
    
    var chatListView: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.messages) { message in MessageRowView(message: message) { message in
                            Task { @MainActor in
                                await vm.retry(message:message)}
                        }}
                    }
                    .onTapGesture {
                        isTextFieldFocused = false
                    }
                }
                //Divider()
                bottomView(proxy: proxy)
                Spacer()
            }
            .onChange(of: vm.messages.last?.responseText) { _ in scrollToBottom(proxy: proxy)}
        
        }
        .background(colorScheme == .light ? .white : Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 0.0))
    }
    
    func bottomView(proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: 8) {
//            Image("profile")
//                .resizable()
//                .frame(width:25, height: 25)
            
            TextField("Message", text: $vm.inputMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .disabled(vm.isInteractingWithAI)
            
            Button {
                Task { @MainActor in
                    isTextFieldFocused = false
                    scrollToBottom(proxy: proxy)
                    await vm.sendTapped()
                }
                
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size:28))
            }
            .disabled(vm.inputMessage
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
            
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let id = vm.messages.last?.id else { return }
        proxy.scrollTo(id, anchor: .bottomTrailing)
    }
    
}
    

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContentView()
        }
    }
}
