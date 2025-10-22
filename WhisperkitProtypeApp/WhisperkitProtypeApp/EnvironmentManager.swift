//
//  EnvironmentManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation

/// Менеджер для работы с переменными окружения и .env файлами
/// Manager for working with environment variables and .env files
class EnvironmentManager {
    
    // MARK: - Properties
    private static var envVariables: [String: String] = [:]
    private static var isLoaded = false
    
    // MARK: - Public Methods
    
    /// Получить значение переменной окружения
    /// Get environment variable value
    /// - Parameter key: Ключ переменной
    /// - Returns: Значение переменной или nil
    static func get(_ key: String) -> String? {
        loadEnvIfNeeded()
        
        // Сначала проверяем системные переменные окружения
        if let systemValue = ProcessInfo.processInfo.environment[key], !systemValue.isEmpty {
            return systemValue
        }
        
        // Затем проверяем .env файл
        return envVariables[key]
    }
    
    /// Получить значение переменной окружения с значением по умолчанию
    /// Get environment variable value with default
    /// - Parameters:
    ///   - key: Ключ переменной
    ///   - defaultValue: Значение по умолчанию
    /// - Returns: Значение переменной или значение по умолчанию
    static func get(_ key: String, defaultValue: String) -> String {
        return get(key) ?? defaultValue
    }
    
    // MARK: - Private Methods
    
    /// Загрузить .env файл если еще не загружен
    /// Load .env file if not loaded yet
    private static func loadEnvIfNeeded() {
        guard !isLoaded else { return }
        
        loadEnvFile()
        isLoaded = true
    }
    
    /// Загрузить переменные из .env файла
    /// Load variables from .env file
    private static func loadEnvFile() {
        guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("⚠️ .env file not found in bundle")
            return
        }
        
        do {
            let envContent = try String(contentsOfFile: envPath)
            parseEnvContent(envContent)
            print("✅ .env file loaded successfully")
        } catch {
            print("❌ Error loading .env file: \(error.localizedDescription)")
        }
    }
    
    /// Парсить содержимое .env файла
    /// Parse .env file content
    /// - Parameter content: Содержимое файла
    private static func parseEnvContent(_ content: String) {
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
    }
}
