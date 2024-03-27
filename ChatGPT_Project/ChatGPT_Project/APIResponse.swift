//
//  ChatGPTAPIModels.swift
//  ChatGPT_Project
//
//  Created by Matthew Woo on 2024/03/09.
//

import Foundation

struct Message: Codable {
    let role: String
    let content: String
    
}

extension Array where Element == Message {
    
    var contentCount: Int {reduce(0, {0 + $1.content.count})} // for counting tokens in the array
}

struct Request: Codable {
    let model: String
    let temperature: Double
    let messages: [Message]
    let stream: Bool
}

struct ErrorRootResponse: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let message: String
    let type: String?
    
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
}

struct CompletionResponse: Decodable {
    let choices: [Choices]
    let usage: Usage?
}

struct Usage: Decodable { // Token usage from API
    let promptTokens: Int?
    let completionTokens: Int?
    let totalToken: Int?

}

struct Choices: Decodable {
    
    let message: Message
    let finishReason: String?
    
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
    
}

struct StreamMessage: Decodable {
    let role: String?
    let content: String?
    
}
