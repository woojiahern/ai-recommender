//
//  GPTAPI.swift
//  ChatGPT_Project
//
//  Created by Matthew Woo on 2024/03/05.
//

import Foundation
import NaturalLanguage
import SVDB
import SwiftCSV
import Accelerate
import CoreML
import SimilaritySearchKit
import SimilaritySearchKitDistilbert

class GPTAPI: @unchecked Sendable {
    static let shared = GPTAPI()
    // API Setup
    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")! // completion api
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {urlRequest.setValue($1, forHTTPHeaderField: $0)}
        return urlRequest
    }
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    
    private var headers: [String: String] {
        [
            
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
            
        ]
    }
    
    // ***
    
    func uploadCSV() throws -> CSV<Named> {
        
        let csv: CSV = try CSV<Named>(url: URL(fileURLWithPath: "sephora_15_test.csv"))
        print("CSV successfully uploaded.")
        return csv
    }
    
    
    private var similarityIndex: SimilarityIndex?
    
    func loadIndex() {
        Task {
            self.similarityIndex = await SimilarityIndex(name: "sephora", model: NativeEmbeddings(), metric: CosineSimilarity())
            
            print("Index loaded.")
            
        }
    }
    
    func createIndex() {
        guard let index = similarityIndex else { return }
        
        Task {
            
            do {
                let csv = try uploadCSV()
                print(csv)
                
                let headersOrder = ["product_name", "brand_name", "product_sub_category", "product_type", "currency", "product_price", "product_image_url", "product_webpage_url", "product_description", "target_skin_concerns", "how_to_use"]
                
                for (id, row) in csv.rows.enumerated() {
                    let concatenatedRowData: String = headersOrder.compactMap { row[$0] }.joined(separator: " ")
                    let itemId = "id\(id + 1)"
                    await index.addItem(id: itemId, text: concatenatedRowData, metadata: ["source": "csv"])
                    
                }
                print("Successfully created embeddings.")
                
            } catch {
                print("Failed to create embeddings")
            }
            
        }

        
    }
    
    
    var searchText: String = ""
    var searchResults: [Message] = []
    
    func searchDocuments(withQuery text: String) async -> [Message] {
        guard let index = similarityIndex else { return [] }
        
        print("Searching database for query: \(text)")
        
        let results = await index.search(text)
        
        searchResults = results.map { Message(role: "assistant", content: "Latest Context: \($0.text)") }
        
        print("Search Results: \(searchResults)")

        return searchResults
        
    }
    
    
    // LLM Setup
    private let apiKey: String
    private var systemMessage: Message
    private var temperature: Double
    private var model: String
    private var memoryList = [Message]() // memoryList
    
    init(apiKey: String? = nil,
         model: String? = nil,
         systemPrompt: String? = nil,
         temperature: Double? = nil) {
        
        self.apiKey = apiKey ?? "API KEY"
        self.model = model ?? "gpt-4-0125-preview"
        self.systemMessage = .init(role: "system", content: systemPrompt ?? defaultSystemPrompt)
        self.temperature = temperature ?? 0.5
        
        loadIndex()
        createIndex()
        
    }

    private let defaultSystemPrompt = """
    Role:
    You are a sales chatbot.

    Tone:
    Speak in a friendly tone.

    Rules:
    1. Interact with the user normally. Use the Latest Context to answer to the user input ONLY IF needed, else ignore Latest Context.
    2. ONLY IF user input is asking for a recommendation, you are tasked personalized a product through a conversational commerce experience using Latest Context.
    3. IF you cannot answer to a response, use Previous Context. ELSE clarify with the user which product they are referring to and, if needed, what do they want to know.
    """
    
    
    private func generateMessages(from text: String) async throws -> [Message] {

        let memoryWindow = memoryList.suffix(6)
        
        let rag = await searchDocuments(withQuery: text)
        
        let messages = [systemMessage] + memoryWindow + rag + [Message(role: "user", content: "User Input: \(text)")]
        
        print("All Messages:", messages)
        
        return messages
    }
    
    
    
    // Call the API with JSON
    private func callAPI(text: String, stream: Bool = true) async throws -> Data {
        let request = try await Request(
            model: model,
            temperature: temperature,
            messages: generateMessages(from: text), //Contains system message, memoryList & user input
            stream: stream)
        
        return try JSONEncoder().encode(request)
    }
    
    // Append user input & API response to memoryList
    private func appendtoMemory(userText: String, responseText: String) {
        self.memoryList.append(.init(role: "user", content: "Previous User Input: \(userText)")) // memoryList of user input
        self.memoryList.append(.init(role: "assistant", content: responseText)) // memoryList of AI response
        
        //print(memoryList)
    }
    
    // Define custom error types
    enum ChatAPIError: Error {
        case invalidResponse
        case badResponse(statusCode: Int, message: String?)
    }
    
    
    // Send Message & stream it
    func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try await callAPI(text: text) // call API with user input
        
        let (result, response) = try await urlSession.bytes(for: urlRequest)
        
        // Handle error
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
                errorText += line
            }
            
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            
            throw ChatAPIError.badResponse(statusCode: httpResponse.statusCode, message: errorText)
        }
        
        // Streaming
        return AsyncThrowingStream<String, Error> {continuation in
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    var responseText = ""
                    for try await line in result.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let response = try? self.jsonDecoder.decode(StreamCompletionResponse.self, from: data), // decode JSON result
                           let text = response.choices.first?.delta.content { // Get LLM response
                            responseText += text
                            continuation.yield(text)
                        }
                        
                    }
                    self.appendtoMemory(userText: text, responseText: responseText) //Append to memoryList
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
        }
        
    }
    
    // Send message but without streaming
    func sendMessage(_ text: String) async throws -> String {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try await callAPI(text: text, stream: false) //Call API with text
        
        // Error handling
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }
        
        //error handling
        guard 200...299 ~= httpResponse.statusCode else {
            var error = "Bad Response: \(httpResponse.statusCode)"
            if let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            
            throw ChatAPIError.invalidResponse
        }
        
        
        do {
            let completionResponse = try self.jsonDecoder.decode(CompletionResponse.self, from: data) // decode the JSON output
            let responseText = completionResponse.choices.first?.message.content ?? "" // Get LLM's response
            self.appendtoMemory(userText: text, responseText: responseText) // Append to memoryList
            //print("Memory: \(memoryList)")
            return responseText
        } catch {
            
            throw error
            
        }
        
    }
    
    func deleteMemory() {
        self.memoryList.removeAll()
    }
    
}
