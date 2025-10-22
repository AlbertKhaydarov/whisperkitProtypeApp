//
//  YandexGPTManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation

/// Менеджер для работы с Yandex GPT API
/// Manager for working with Yandex GPT API
class YandexGPTManager {
    
    // MARK: - Properties
    private let apiKey: String
    private let folderID: String
    private let apiURL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"
    
    
    // MARK: - Initialization
    
    /// Инициализация менеджера
    /// Initialize manager
    /// - Parameters:
    ///   - apiKey: API ключ Yandex
    ///   - folderID: ID папки в Yandex Cloud
    init(apiKey: String, folderID: String) {
        self.apiKey = apiKey
        self.folderID = folderID
    }
    
    // MARK: - Public Methods
    
    /// Анализ английского текста на грамматические ошибки
    /// Analyze English text for grammar errors
    /// - Parameter text: Текст для анализа
    /// - Returns: Обратная связь по грамматике
    func analyzeEnglishText(_ text: String) async throws -> GrammarFeedback {
        let systemPrompt = """
        Вы - опытный преподаватель английского языка. Проанализируйте предоставленный текст на английском языке и:
        1. Определите грамматические ошибки, игнорируй ошибки пунктуации
        2. Укажите правильный вариант для каждой ошибки
        3. Дайте краткое объяснение каждой ошибки
        4. Оцените общий уровень владения английским языком
        
        Формат ответа:
        УРОВЕНЬ: [A1/A2/B1/B2/C1/C2]
        
        ОШИБКИ:
        1. Ошибка: [текст с ошибкой]
           Исправление: [правильный вариант]
           Объяснение: [краткое объяснение]
        
        2. ...
        
        ОБЩАЯ ОБРАТНАЯ СВЯЗЬ:
        [Общие комментарии о речи, рекомендации по улучшению]
        """
        
        let userPrompt = "Проанализируйте следующий текст на английском: \"\(text)\""
        
        let feedback = try await generateText(systemPrompt: systemPrompt, userPrompt: userPrompt)
        
        return parseGrammarFeedback(originalText: text, feedback: feedback)
    }
    
    // MARK: - Private Methods
    
    /// Генерация текста через Yandex GPT API
    /// Generate text via Yandex GPT API
    /// - Parameters:
    ///   - systemPrompt: Системный промпт
    ///   - userPrompt: Пользовательский промпт
    /// - Returns: Сгенерированный текст
    private func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw NSError(domain: "InvalidURL", code: -1, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(folderID, forHTTPHeaderField: "x-folder-id")
        
        let requestBody = CompletionRequest(
            modelUri: "gpt://\(folderID)/yandexgpt/latest",
            completionOptions: CompletionOptions(
                stream: false,
                temperature: 0.6,
                maxTokens: "2000"
            ),
            messages: [
                Message(role: "system", text: systemPrompt),
                Message(role: "user", text: userPrompt)
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "HTTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        let completionResponse = try JSONDecoder().decode(CompletionResponse.self, from: data)
        
        return completionResponse.result.alternatives.first?.message.text ?? ""
    }
    
    /// Парсинг обратной связи по грамматике
    /// Parse grammar feedback
    /// - Parameters:
    ///   - originalText: Исходный текст
    ///   - feedback: Обратная связь от API
    /// - Returns: Структурированная обратная связь
    private func parseGrammarFeedback(originalText: String, feedback: String) -> GrammarFeedback {
        var errors: [GrammarError] = []
        
        let lines = feedback.components(separatedBy: .newlines)
        var currentError: (error: String, correction: String, explanation: String)?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.starts(with: "Ошибка:") {
                if let error = currentError {
                    errors.append(GrammarError(
                        errorText: error.error,
                        correction: error.correction,
                        explanation: error.explanation
                    ))
                }
                currentError = (
                    error: trimmed.replacingOccurrences(of: "Ошибка:", with: "").trimmingCharacters(in: .whitespaces),
                    correction: "",
                    explanation: ""
                )
            } else if trimmed.starts(with: "Исправление:") {
                currentError?.correction = trimmed.replacingOccurrences(of: "Исправление:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Объяснение:") {
                currentError?.explanation = trimmed.replacingOccurrences(of: "Объяснение:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        if let error = currentError {
            errors.append(GrammarError(
                errorText: error.error,
                correction: error.correction,
                explanation: error.explanation
            ))
        }
        
        return GrammarFeedback(
            originalText: originalText,
            feedback: feedback,
            errors: errors
        )
    }
}