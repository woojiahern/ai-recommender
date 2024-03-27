//
//  MessageRow.swift
//  ChatGPT_Project
//
//  Created by Matthew Woo on 2024/03/20.
//

import SwiftUI

// A single message row. Represents send text and response text.

struct MessageRow: Identifiable {
    
    let id = UUID()
    
    var isInteractingWithAI: Bool
    
    let sendImage: String
    let sendText: String
    
    let responseImage: String
    var responseText: String?
    
    var responseError: String?
    
    
    
}
