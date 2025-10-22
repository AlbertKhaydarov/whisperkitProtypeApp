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
    
    // MARK: - Data Models
    
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
    
    // MARK: - Initialization
    
    /// Инициализация менеджера
    /// Initialize manager
    /// - Parameters:
    ///   - apiKey: API ключ Yandex (опционально, если не указан - будет загружен из окружения)
    ///   - folderID: ID папки в Yandex Cloud (опционально, если не указан - будет загружен из окружения)
    init(apiKey: String? = nil, folderID: String? = nil) {
        // Сначала проверяем переданные параметры
        if let apiKey = apiKey, let folderID = folderID {
            self.apiKey = apiKey
            self.folderID = folderID
        } else {
            // Загружаем из переменных окружения системы
            var loadedApiKey = ProcessInfo.processInfo.environment["YANDEX_API_KEY"] ?? ""
            var loadedFolderID = ProcessInfo.processInfo.environment["YANDEX_FOLDER_ID"] ?? ""
            
            // Если не найдены в системных переменных, пробуем загрузить из .env файла
            if loadedApiKey.isEmpty || loadedFolderID.isEmpty {
                let envValues = YandexGPTManager.loadFromEnvFile()
                if loadedApiKey.isEmpty {
                    loadedApiKey = envValues["YANDEX_API_KEY"] ?? ""
                }
                if loadedFolderID.isEmpty {
                    loadedFolderID = envValues["YANDEX_FOLDER_ID"] ?? ""
                }
            }
            
            self.apiKey = loadedApiKey
            self.folderID = loadedFolderID
        }
        
        if self.apiKey.isEmpty || self.folderID.isEmpty {
            print("⚠️ Yandex API ключи не найдены. Проверьте:")
            print("   1. Переменные окружения системы")
            print("   2. Файл .env в корне проекта")
            print("   3. Правильность ключей в .env файле")
        } else {
            print("✅ YandexGPTManager инициализирован с API ключами")
            print("   API Key: \(String(self.apiKey.prefix(8)))...")
            print("   Folder ID: \(self.folderID)")
        }
    }
    
    /// Загрузить переменные из .env файла
    /// Load variables from .env file
    private static func loadFromEnvFile() -> [String: String] {
        var envVariables: [String: String] = [:]
        
        // Ищем .env файл в разных местах
        let possiblePaths = [
            Bundle.main.bundlePath + "/.env",
            Bundle.main.bundlePath + "/../.env",
            Bundle.main.bundlePath + "/../../.env",
            Bundle.main.path(forResource: ".env", ofType: nil) ?? ""
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                do {
                    let content = try String(contentsOfFile: path, encoding: .utf8)
                    envVariables = YandexGPTManager.parseEnvContent(content)
                    print("✅ Загружен .env файл из: \(path)")
                    break
                } catch {
                    print("❌ Ошибка чтения .env файла: \(error.localizedDescription)")
                }
            }
        }
        
        return envVariables
    }
    
    /// Парсить содержимое .env файла
    /// Parse .env file content
    private static func parseEnvContent(_ content: String) -> [String: String] {
        var envVariables: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Пропускаем пустые строки и комментарии
            guard !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") else { continue }
            
            // Ищем знак равенства
            guard let equalIndex = trimmedLine.firstIndex(of: "=") else { continue }
            
            let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmedLine[trimmedLine.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
            
            // Убираем кавычки если есть
            let cleanValue = value.replacingOccurrences(of: "\"", with: "")
            
            envVariables[key] = cleanValue
        }
        
        return envVariables
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