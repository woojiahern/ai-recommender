//
//  ViewModel.swift
//  ChatGPT_Project
//
//  Created by Matthew Woo on 2024/03/20.
//

import Foundation
import SwiftUI
import SimilaritySearchKit
import SwiftCSV

class ViewModel: ObservableObject {
    
    @Published var isInteractingWithAI = false
    @Published var messages: [MessageRow] = []
    @Published var inputMessage: String = ""
    @State private var similarityIndex: SimilarityIndex?
    
    
    private let api: GPTAPI
    
    init(api: GPTAPI) {
        self.api = api
    }
    
    @MainActor
    func sendTapped() async {
        let text = inputMessage
        inputMessage = ""
        await send(text: text)
    }
    
    @MainActor
    func retry(message: MessageRow) async {
        guard let index = messages.firstIndex(where: {$0.id == message.id}) else {
            return
        }
        self.messages.remove(at: index)
        await send(text: message.sendText)
    }
    
    
    @MainActor
    private func send(text: String) async {
        isInteractingWithAI = true
        var streamText = ""
        var messageRow = MessageRow(
            isInteractingWithAI: true,
            sendImage: "profile",
            sendText: text,
            responseImage: "openai",
            responseText: streamText,
            responseError: nil)
        
        self.messages.append(messageRow)
        
        do {
            let stream = try await api.sendMessageStream(text: text)
            for try await text in stream {
                streamText += text
                messageRow.responseText = streamText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.messages[self.messages.count - 1] = messageRow
            }
            
        } catch {
            messageRow.responseError = error.localizedDescription
        }
        
        messageRow.isInteractingWithAI = false
        self.messages[self.messages.count - 1] = messageRow
        isInteractingWithAI = false
    }
}

