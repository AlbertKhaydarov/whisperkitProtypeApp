//
//  WhisperKitManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import WhisperKit // Импортируем WhisperKit для работы с Whisper API

// MARK: - WhisperSegment Model
struct WhisperSegment {
    let text: String
    let start: Double
    let end: Double
}

// MARK: - WhisperConfiguration
struct WhisperConfiguration {
    var language: String = "en" // По умолчанию английский
    var translate: Bool = false // Не переводить
    var modelName: String = "tiny.en" // Модель по умолчанию
    var sampleRate: Double = 16000 // Частота дискретизации
    
    static let defaultConfiguration = WhisperConfiguration()
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
    private var whisperKit: WhisperKit?
    private var isInitialized = false
    private var isWarmedUp = false
    private var currentSession: String? // ID текущей сессии транскрипции
    private var audioBuffer: [Float] = []
    private let minBufferSize = 8000 // Минимум 0.5 секунды аудио (16kHz)
    private let maxBufferSize = 160000 // Максимум ~10 секунд аудио (16kHz)
    private var isTranscribing = false // Флаг для предотвращения одновременных транскрипций
    
    // MARK: - Configuration
    private var configuration: WhisperConfiguration = WhisperConfiguration.defaultConfiguration
    
    // MARK: - Delegate
    weak var delegate: WhisperKitManagerDelegate?
    
    // MARK: - Metrics
    private var processingTimes: [TimeInterval] = []
    private var averageProcessingTime: TimeInterval {
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    // MARK: - Private Initializer
    private init() {}
    
    /// Безопасно вызывает делегат на главном потоке
    /// Safely calls delegate on the main thread
    private func notifyDelegate(_ action: @escaping (WhisperKitManagerDelegate) -> Void) {
        guard let delegate = delegate else { return }
        
        Task { @MainActor in
            action(delegate)
        }
    }
    
    // MARK: - Public Methods
    
    /// Инициализация WhisperKit
    /// Initialize WhisperKit
    func initialize() async throws {
        guard !isInitialized else {
            print("⚠️ WhisperKit already initialized")
            return
        }
        
        print("🚀 Initializing WhisperKit...")
        
        // Инициализируем WhisperKit с конфигурацией
        let config = WhisperKitConfig(model: configuration.modelName)
        
        whisperKit = try await WhisperKit(config)
        print("✅ WhisperKit initialized successfully")
        isInitialized = true
    }
    
    /// Загрузка модели Whisper (автоматически через WhisperKit)
    /// Load Whisper model (automatically through WhisperKit)
    func loadModel() async throws {
        guard isInitialized else {
            throw WhisperKitError.notInitialized
        }
        
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.notInitialized
        }
        
        print("📥 Loading Whisper model: \(configuration.modelName)")
        
        // WhisperKit автоматически загружает модель при инициализации
        // Дополнительная проверка не требуется, так как whisperKit уже проверен выше
        
        print("✅ Model loaded successfully")
    }
    
    /// Прогрев модели
    /// Warm up the model
    func warmup() async throws {
        guard isInitialized else {
            throw WhisperKitError.notInitialized
        }
        
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.modelNotLoaded
        }
        
        guard !isWarmedUp else {
            print("⚠️ Model already warmed up")
            // Даже если модель уже прогрета, отправляем сигнал о 100% прогреве
            notifyDelegate { delegate in
                delegate.whisperKitManager(self, didUpdateWarmupProgress: 1.0)
            }
            return
        }
        
        print("🔥 Warming up model...")
        
        // Отправляем начальный прогресс прогрева
        notifyDelegate { delegate in
            delegate.whisperKitManager(self, didUpdateWarmupProgress: 0.1)
        }
        
        // Создаем тестовые аудио данные для прогрева
        var warmupData = [Float](repeating: 0.0, count: 16000) // 1 секунда аудио
        for i in 0..<16000 {
            // Создаем синусоидальный сигнал частотой 440 Гц
            warmupData[i] = sin(2.0 * Float.pi * 440.0 * Float(i) / 16000.0) * 0.5
        }
        
        // Отправляем промежуточный прогресс прогрева
        notifyDelegate { delegate in
            delegate.whisperKitManager(self, didUpdateWarmupProgress: 0.5)
        }
        
        // Прогреваем модель
        do {
            _ = try await whisperKit.transcribe(audioArray: warmupData)
            print("🔥 Model warmed up with test transcription")
            
            // Отправляем финальный прогресс прогрева
            notifyDelegate { delegate in
                delegate.whisperKitManager(self, didUpdateWarmupProgress: 1.0)
            }
            
            isWarmedUp = true
            print("✅ Model warmed up successfully")
        } catch {
            print("❌ Failed to warm up model: \(error.localizedDescription)")
            throw WhisperKitError.modelLoadFailed(error)
        }
    }
    
    /// Транскрипция аудио фреймов
    /// Transcribe audio frames
    func transcribe(audioFrames: [Float]) async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            print("❌ WhisperKit не готов: initialized=\(isInitialized), warmedUp=\(isWarmedUp)")
            throw WhisperKitError.notReady
        }
        
        guard let whisperKit = whisperKit else {
            print("❌ WhisperKit не инициализирован")
            throw WhisperKitError.modelNotLoaded
        }
        
        // Анализ входящих аудио фреймов
        if !audioFrames.isEmpty {
            let samplesToPrint = min(5, audioFrames.count)
            var samplesInfo = "Первые \(samplesToPrint) входящих сэмплов: "
            for i in 0..<samplesToPrint {
                samplesInfo += String(format: "%.4f ", audioFrames[i])
            }
            print("🎵 \(samplesInfo)")
            
            let maxAmplitude = audioFrames.map { abs($0) }.max() ?? 0
            print("📊 Максимальная амплитуда входящих данных: \(maxAmplitude)")
            
            if maxAmplitude < 0.01 {
                print("⚠️ Низкая амплитуда входящих данных - возможно тишина")
            }
        }
        
        // Добавляем фреймы в буфер с ограничением размера
        audioBuffer.append(contentsOf: audioFrames)
        
        // Проверяем, не превышен ли максимальный размер буфера
        if audioBuffer.count > maxBufferSize {
            print("⚠️ Аудио буфер превышает максимальный размер (\(audioBuffer.count) > \(maxBufferSize)), обрезаем...")
            audioBuffer = Array(audioBuffer.suffix(maxBufferSize))
        }
        
        print("🎵 Получено \(audioFrames.count) аудио фреймов, размер буфера: \(audioBuffer.count)")
        
        // Проверяем, достаточно ли данных для транскрипции
        guard audioBuffer.count >= minBufferSize else {
            print("⏳ Недостаточно аудио данных для распознавания, буферизуем...")
            return []
        }
        
        // Проверяем, не идет ли уже транскрипция
        guard !isTranscribing else {
            print("⏳ Транскрипция уже выполняется, буферизуем...")
            return []
        }
        
        // Берем данные из буфера для транскрипции
        let framesToProcess = Array(audioBuffer.prefix(minBufferSize))
        audioBuffer.removeFirst(minBufferSize)
        
        // Анализ данных для обработки
        let maxAmplitudeToProcess = framesToProcess.map { abs($0) }.max() ?? 0
        print("🔄 Обработка \(framesToProcess.count) аудио фреймов для распознавания (макс. амплитуда: \(maxAmplitudeToProcess))")
        
        do {
            isTranscribing = true
            
            // Выполняем транскрипцию с WhisperKit
            print("🔄 Starting transcription with WhisperKit...")
            
            let startTime = Date()
            let result = try await whisperKit.transcribe(audioArray: framesToProcess)
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Сохраняем метрики времени обработки
            processingTimes.append(processingTime)
            print("⏱️ Processing time: \(String(format: "%.2f", processingTime))s (avg: \(String(format: "%.2f", averageProcessingTime))s)")
            
            // Конвертируем результат в наш формат
            var whisperSegments: [WhisperSegment] = []
            
            if let firstResult = result.first, !firstResult.text.isEmpty {
                // Создаем один сегмент с полным текстом
                let segment = WhisperSegment(
                    text: firstResult.text,
                    start: 0.0,
                    end: Double(framesToProcess.count) / 16000.0
                )
                whisperSegments = [segment]
                
                print("✅ Успешно распознано: '\(firstResult.text)'")
            } else {
                print("⚠️ Empty transcription result")
                whisperSegments = []
            }
            
            // Отправляем результат через делегат безопасно
            notifyDelegate { delegate in
                delegate.whisperKitManager(self, didReceiveSegments: whisperSegments)
            }
            
            print("✅ Transcription completed: \(whisperSegments.count) segments")
            if !whisperSegments.isEmpty {
                for segment in whisperSegments {
                    print("📝 Segment: '\(segment.text)' (\(segment.start)-\(segment.end)s)")
                }
            } else {
                print("⚠️ No speech detected in audio segment")
            }
            
            isTranscribing = false
            return whisperSegments
            
        } catch {
            isTranscribing = false
            print("❌ Ошибка распознавания: \(error)")
            print("❌ Детали ошибки: \(error.localizedDescription)")
            
            // Логируем диагностическую информацию
            print("📊 Диагностика ошибки:")
            print("   - Размер обрабатываемых данных: \(framesToProcess.count) фреймов")
            let maxAmplitude = framesToProcess.map { abs($0) }.max() ?? 0
            print("   - Максимальная амплитуда: \(maxAmplitude)")
            
            if maxAmplitude < 0.01 {
                print("⚠️ Возможная причина: слишком тихий звук (амплитуда < 0.01)")
            }
            
            // Отправляем пустой результат через делегат
            notifyDelegate { delegate in
                delegate.whisperKitManager(self, didFailWith: error)
            }
            
            // Всегда выбрасываем ошибку для правильной обработки
            throw WhisperKitError.transcriptionFailed
        }
    }
    
    /// Финализация транскрипции
    /// Finalize transcription
    func finalize() async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        // Ждем завершения текущей транскрипции
        if isTranscribing {
            print("⏳ Waiting for current transcription to complete...")
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    // Ожидаем завершения транскрипции с таймаутом
                    let startWaitTime = Date()
                    let maxWaitTime: TimeInterval = 5.0 // Максимум 5 секунд ожидания
                    
                    while isTranscribing && Date().timeIntervalSince(startWaitTime) < maxWaitTime {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
                    }
                    
                    if isTranscribing {
                        print("⚠️ Transcription wait timeout exceeded, proceeding anyway")
                        isTranscribing = false
                    }
                    
                    continuation.resume()
                }
            }
        }
        
        // Обрабатываем оставшиеся данные в буфере
        var finalSegments: [WhisperSegment] = []
        
        if !audioBuffer.isEmpty {
            print("🔄 Processing remaining \(audioBuffer.count) audio frames...")
            
            do {
                isTranscribing = true
                
                guard let whisperKit = whisperKit else {
                    throw WhisperKitError.modelNotLoaded
                }
                
                let startTime = Date()
                let result = try await whisperKit.transcribe(audioArray: audioBuffer)
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Сохраняем метрики времени обработки
                processingTimes.append(processingTime)
                print("⏱️ Final processing time: \(String(format: "%.2f", processingTime))s")
                
                // Конвертируем результат в наш формат
                if let firstResult = result.first, !firstResult.text.isEmpty {
                    let segment = WhisperSegment(
                        text: firstResult.text,
                        start: 0.0,
                        end: Double(audioBuffer.count) / 16000.0
                    )
                    finalSegments = [segment]
                    print("✅ Финальное распознавание завершено: '\(firstResult.text)'")
                } else {
                    print("⚠️ Empty final transcription result")
                    finalSegments = []
                }
                
                audioBuffer.removeAll()
                print("✅ Final transcription completed: \(finalSegments.count) segments")
                if !finalSegments.isEmpty {
                    for segment in finalSegments {
                        print("📝 Final segment: '\(segment.text)' (\(segment.start)-\(segment.end)s)")
                    }
                }
                isTranscribing = false
            } catch {
                isTranscribing = false
                print("❌ Final transcription failed: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                audioBuffer.removeAll()
                
                // Уведомляем делегат об ошибке
                notifyDelegate { delegate in
                    delegate.whisperKitManager(self, didFailWith: error)
                }
                
                throw WhisperKitError.transcriptionFailed
            }
        }
        
        // Безопасно уведомляем делегат о завершении
        notifyDelegate { delegate in
            delegate.whisperKitManager(self, didCompleteWithSegments: finalSegments)
        }
        
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
        
        // Очищаем буфер для новой сессии
        audioBuffer.removeAll()
        currentSession = "session_\(Date().timeIntervalSince1970)"
        print("🆕 New transcription session started")
    }
    
    /// Сброс состояния
    /// Reset state
    func reset() async {
        whisperKit = nil
        isInitialized = false
        isWarmedUp = false
        currentSession = nil
        audioBuffer.removeAll()
        print("🔄 WhisperKit state reset")
    }
    
    /// Обновление конфигурации Whisper
    /// Update Whisper configuration
    func updateConfiguration(_ newConfig: WhisperConfiguration) async {
        configuration = newConfig
        print("🔄 WhisperKit configuration updated")
        print("🌍 Language: \(configuration.language)")
        print("🔄 Translate: \(configuration.translate)")
        print("🤖 Model: \(configuration.modelName)")
        print("📊 Sample Rate: \(configuration.sampleRate)Hz")
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
    case initializationFailed(Error)
    
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
        case .initializationFailed(let error):
            return "Ошибка инициализации WhisperKit: \(error.localizedDescription)"
        }
    }
}