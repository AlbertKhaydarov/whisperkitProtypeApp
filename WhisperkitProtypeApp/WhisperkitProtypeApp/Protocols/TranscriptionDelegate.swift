//
//  TranscriptionDelegate.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation

/// Протокол для получения результатов транскрипции в реальном времени
/// Protocol for receiving real-time transcription results
protocol TranscriptionDelegate: AnyObject {
    /// Получить промежуточный результат транскрипции
    /// Receive intermediate transcription result
    func didReceiveIntermediateResult(_ text: String)
    
    /// Получить финальный результат транскрипции
    /// Receive final transcription result
    func didReceiveFinalResult(_ text: String)
    
    /// Обновить прогресс транскрипции
    /// Update transcription progress
    func didUpdateProgress(_ progress: Float)
    
    /// Обработать ошибку транскрипции
    /// Handle transcription error
    func didEncounterError(_ error: Error)
    
    /// Обнаружена неанглийская речь
    /// Non-English speech detected
    func didDetectNonEnglishSpeech()
}
