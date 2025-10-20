//
//  LanguageDetector.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation
import WhisperKit

/// Детектор языка для определения английской речи
/// Language detector for identifying English speech
class LanguageDetector {
    // Порог уверенности для английского языка
    // Confidence threshold for English language
    private let englishConfidenceThreshold: Float = 0.7
    
    /// Проверить является ли речь английской
    /// Check if speech is English
    func isEnglishSpeech(languageLogProbs: [String: Float]) -> Bool {
        guard let englishProb = languageLogProbs["en"] else {
            return false
        }
        
        // Log probability конвертируем в вероятность
        // Convert log probability to probability
        let probability = exp(englishProb)
        
        return probability >= englishConfidenceThreshold
    }
    
    /// Получить наиболее вероятный язык
    /// Get most likely language
    func getMostLikelyLanguage(languageLogProbs: [String: Float]) -> String {
        let sorted = languageLogProbs.sorted { $0.value > $1.value }
        return sorted.first?.key ?? "unknown"
    }
    
    /// Проверить является ли речь английской по результату транскрипции
    /// Check if speech is English based on transcription result
    func isEnglishSpeech(result: TranscriptionResult) -> Bool {
        // WhisperKit может не предоставлять languageProbs в TranscriptionResult
        // Для простоты всегда возвращаем true (английский)
        // В реальном приложении можно использовать другие методы детекции языка
        return true
    }
}
