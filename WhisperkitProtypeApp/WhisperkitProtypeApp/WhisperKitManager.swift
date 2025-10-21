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
    private var audioBuffer: [Float] = []
    private let minBufferSize = 16000 // Минимум 1 секунда аудио (16kHz)
    
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
        
        // Проверяем существование файла модели
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Model file not found at path: \(url.path)")
            throw WhisperKitError.modelFileNotFound
        }
        
        // Проверяем размер файла модели
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? NSNumber {
                let sizeInMB = fileSize.doubleValue / (1024 * 1024)
                print("📊 Model file size: \(String(format: "%.2f", sizeInMB)) MB")
                
                // Проверяем минимальный размер файла (обычно модели Whisper весят больше 100MB)
                if sizeInMB < 10 {
                    print("⚠️ Warning: Model file seems too small (\(String(format: "%.2f", sizeInMB)) MB)")
                }
            }
        } catch {
            print("⚠️ Could not get file attributes: \(error.localizedDescription)")
        }
        
        // Загружаем модель из файла с обработкой ошибок
        do {
            print("🔄 Attempting to initialize Whisper with file: \(url.lastPathComponent)")
            // Инициализируем Whisper напрямую (он может выбросить исключение, но не возвращает nil)
            whisper = try Whisper(fromFileURL: url, withParams: .default)
            print("✅ Model loaded successfully")
        } catch {
            print("❌ Failed to load model: \(error.localizedDescription)")
            print("❌ Model file path: \(url.path)")
            print("❌ Model file exists: \(FileManager.default.fileExists(atPath: url.path))")
            throw WhisperKitError.modelLoadFailed(error)
        }
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
        
        // Добавляем фреймы в буфер
        audioBuffer.append(contentsOf: audioFrames)
        print("🎵 Received \(audioFrames.count) audio frames, buffer size: \(audioBuffer.count)")
        
        // Проверяем, достаточно ли данных для транскрипции
        guard audioBuffer.count >= minBufferSize else {
            print("⏳ Not enough audio data yet, buffering...")
            return []
        }
        
        // Берем данные из буфера для транскрипции
        let framesToProcess = Array(audioBuffer.prefix(minBufferSize))
        audioBuffer.removeFirst(minBufferSize)
        
        print("🔄 Processing \(framesToProcess.count) audio frames for transcription")
        
        do {
            // Выполняем реальную транскрипцию с SwiftWhisper
            let segments = try await whisper.transcribe(audioFrames: framesToProcess)
            
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
            
            print("✅ Transcription completed: \(whisperSegments.count) segments")
            return whisperSegments
            
        } catch {
            print("❌ Transcription failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw WhisperKitError.transcriptionFailed
        }
    }
    
    /// Финализация транскрипции
    /// Finalize transcription
    func finalize() async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        // Обрабатываем оставшиеся данные в буфере
        var finalSegments: [WhisperSegment] = []
        
        if !audioBuffer.isEmpty {
            print("🔄 Processing remaining \(audioBuffer.count) audio frames...")
            
            do {
                let segments = try await whisper?.transcribe(audioFrames: audioBuffer) ?? []
                finalSegments = segments.map { segment in
                    WhisperSegment(
                        text: segment.text,
                        start: Double(segment.startTime),
                        end: Double(segment.endTime)
                    )
                }
                audioBuffer.removeAll()
                print("✅ Final transcription completed: \(finalSegments.count) segments")
            } catch {
                print("❌ Final transcription failed: \(error)")
                audioBuffer.removeAll()
            }
        }
        
        delegate?.whisperKitManager(self, didCompleteWithSegments: finalSegments)
        
        return finalSegments
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
        audioBuffer.removeAll()
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
    case modelFileNotFound
    case modelFileCorrupted
    case modelLoadFailed(Error)
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit не инициализирован"
        case .notReady:
            return "WhisperKit не готов к работе"
        case .modelNotLoaded:
            return "Модель не загружена"
        case .modelFileNotFound:
            return "Файл модели не найден"
        case .modelFileCorrupted:
            return "Файл модели поврежден или имеет неправильный формат"
        case .modelLoadFailed(let error):
            return "Ошибка загрузки модели: \(error.localizedDescription)"
        case .transcriptionFailed:
            return "Ошибка транскрипции"
        }
    }
}
