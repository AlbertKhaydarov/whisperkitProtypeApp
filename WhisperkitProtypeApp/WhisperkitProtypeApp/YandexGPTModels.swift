//
//  YandexGPTModels.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation

/// Модели данных для работы с Yandex GPT API
/// Data models for working with Yandex GPT API

// MARK: - API Request Models

/// Сообщение для API запроса
/// Message for API request
struct Message: Codable {
    let role: String
    let text: String
}

/// Запрос на завершение текста
/// Completion request
struct CompletionRequest: Codable {
    let modelUri: String
    let completionOptions: CompletionOptions
    let messages: [Message]
}

/// Опции завершения
/// Completion options
struct CompletionOptions: Codable {
    let stream: Bool
    let temperature: Double
    let maxTokens: String
}

// MARK: - API Response Models

/// Ответ от API
/// API response
struct CompletionResponse: Codable {
    let result: Result
    
    struct Result: Codable {
        let alternatives: [Alternative]
        let usage: Usage
        
        struct Alternative: Codable {
            let message: Message
            let status: String
        }
        
        struct Usage: Codable {
            let inputTextTokens: String
            let completionTokens: String
            let totalTokens: String
        }
    }
}

// MARK: - Grammar Analysis Models

/// Грамматическая ошибка
/// Grammar error
struct GrammarError: Codable {
    let errorText: String
    let correction: String
    let explanation: String
}

/// Обратная связь по грамматике
/// Grammar feedback
struct GrammarFeedback: Codable {
    let originalText: String
    let feedback: String
    let errors: [GrammarError]
}
