//
//  RetryManager.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation

/// Менеджер для повторных попыток с экспоненциальной задержкой
/// Manager for retry attempts with exponential backoff
class RetryManager {
    let maxRetries: Int
    let baseDelay: TimeInterval
    
    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }
    
    /// Выполнить операцию с автоматическими повторами
    /// Execute operation with automatic retries
    func retry<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                // Попытка выполнить операцию
                // Attempt to execute operation
                return try await operation()
            } catch {
                lastError = error
                
                // Логирование
                // Logging
                print("⚠️ Attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Если это последняя попытка, прокинуть ошибку
                // If this is the last attempt, throw error
                if attempt == maxRetries - 1 {
                    throw error
                }
                
                // Вычислить задержку
                // Calculate delay
                let delay = calculateBackoff(attempt: attempt + 1)
                print("⏳ Retrying in \(delay) seconds...")
                
                // Подождать перед следующей попыткой
                // Wait before next attempt
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Не должно сюда попадать, но для безопасности
        // Should not reach here, but for safety
        throw lastError ?? NSError(
            domain: "RetryManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All retries failed"]
        )
    }
    
    /// Вычислить экспоненциальную задержку
    /// Calculate exponential backoff delay
    private func calculateBackoff(attempt: Int) -> TimeInterval {
        return baseDelay * pow(2.0, Double(attempt - 1))
    }
}
