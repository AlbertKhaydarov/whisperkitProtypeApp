//
//  WhisperKitManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import SwiftWhisper

// MARK: - WhisperSegment Model
struct WhisperSegment {
    let text: String
    let start: Double
    let end: Double
}

// MARK: - WhisperKitManager Delegate
protocol WhisperKitManagerDelegate: AnyObject {
    func whisperKitManager(_ manager: WhisperKitManager, didUpdateWarmupProgress progress: Double)
    func whisperKitManager(_ manager: WhisperKitManager, didReceiveSegments segments: [WhisperSegment])
    func whisperKitManager(_ manager: WhisperKitManager, didCompleteWithSegments segments: [WhisperSegment])
    func whisperKitManager(_ manager: WhisperKitManager, didFailWith error: Error)
}

/// Центральный менеджер для координации всех операций с WhisperKit
/// Central manager for coordinating all WhisperKit operations
actor WhisperKitManager {
    
    // MARK: - Singleton
    static let shared = WhisperKitManager()
    
    // MARK: - Properties
    private var whisper: Whisper?
    private var isInitialized = false
    private var isWarmedUp = false
    private var currentSession: Any? // Placeholder for WhisperSession
    
    // MARK: - Delegate
    weak var delegate: WhisperKitManagerDelegate?
    
    // MARK: - Private Initializer
    private init() {}
    
    // MARK: - Public Methods
    
    /// Инициализация SwiftWhisper
    /// Initialize SwiftWhisper
    func initialize() async throws {
        guard !isInitialized else {
            print("⚠️ SwiftWhisper already initialized")
            return
        }
        
        print("🚀 Initializing SwiftWhisper...")
        
        // Инициализируем SwiftWhisper (требует URL файла модели)
        // whisper = try Whisper() // Нельзя инициализировать без модели
        
        isInitialized = true
        print("✅ SwiftWhisper initialized successfully")
    }
    
    /// Загрузка модели Whisper
    /// Load Whisper model
    func loadModel(from url: URL) async throws {
        guard isInitialized else {
            throw WhisperKitError.notInitialized
        }
        
        print("📥 Loading Whisper model from: \(url.lastPathComponent)")
        
        // Загружаем модель из файла
        whisper = try Whisper(fromFileURL: url, withParams: .default)
        
        print("✅ Model loaded successfully")
    }
    
    /// Прогрев модели
    /// Warm up the model
    func warmup() async throws {
        guard isInitialized else {
            throw WhisperKitError.notInitialized
        }
        
        guard let whisper = whisper else {
            throw WhisperKitError.modelNotLoaded
        }
        
        guard !isWarmedUp else {
            print("⚠️ Model already warmed up")
            return
        }
        
        print("🔥 Warming up model...")
        
        // Прогреваем модель с реальными данными
        let warmupData = Array(repeating: Float(0.0), count: 16000) // 1 секунда тишины
        _ = try await whisper.transcribe(audioFrames: warmupData)
        
        // Отправляем прогресс прогрева
        delegate?.whisperKitManager(self, didUpdateWarmupProgress: 1.0)
        
        isWarmedUp = true
        print("✅ Model warmed up successfully")
    }
    
    /// Транскрипция аудио фреймов
    /// Transcribe audio frames
    func transcribe(audioFrames: [Float]) async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        guard let whisper = whisper else {
            throw WhisperKitError.modelNotLoaded
        }
        
        // Логируем получение аудио данных
        print("🎵 Received \(audioFrames.count) audio frames for transcription")
        
        // Выполняем реальную транскрипцию с SwiftWhisper
        let segments = try await whisper.transcribe(audioFrames: audioFrames)
        
        // Конвертируем в наш формат
        let whisperSegments = segments.map { segment in
            WhisperSegment(
                text: segment.text,
                start: Double(segment.startTime),
                end: Double(segment.endTime)
            )
        }
        
        // Отправляем результат через делегат
        delegate?.whisperKitManager(self, didReceiveSegments: whisperSegments)
        
        return whisperSegments
    }
    
    /// Финализация транскрипции
    /// Finalize transcription
    func finalize() async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        // Финализируем транскрипцию (SwiftWhisper не имеет finalize, возвращаем пустой массив)
        let whisperSegments: [WhisperSegment] = []
        
        delegate?.whisperKitManager(self, didCompleteWithSegments: whisperSegments)
        
        return whisperSegments
    }
    
    /// Установка делегата
    /// Set delegate
    func setDelegate(_ delegate: WhisperKitManagerDelegate?) async {
        self.delegate = delegate
    }
    
    /// Создание новой сессии транскрипции
    /// Create new transcription session
    func startNewSession() async throws {
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        // Создаем новую сессию (SwiftWhisper не имеет createSession, используем placeholder)
        currentSession = "session_\(Date().timeIntervalSince1970)"
        print("🆕 New transcription session started")
    }
    
    /// Сброс состояния
    /// Reset state
    func reset() async {
        whisper = nil
        isInitialized = false
        isWarmedUp = false
        currentSession = nil
        print("🔄 SwiftWhisper state reset")
    }
    
    /// Проверка готовности WhisperKit
    /// Check if WhisperKit is ready
    var isReady: Bool {
        return isInitialized && isWarmedUp
    }
}

// MARK: - WhisperKit Errors
enum WhisperKitError: Error, LocalizedError {
    case notInitialized
    case notReady
    case modelNotLoaded
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit не инициализирован"
        case .notReady:
            return "WhisperKit не готов к работе"
        case .modelNotLoaded:
            return "Модель не загружена"
        case .transcriptionFailed:
            return "Ошибка транскрипции"
        }
    }
}
