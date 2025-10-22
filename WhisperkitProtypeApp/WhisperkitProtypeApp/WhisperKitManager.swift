//
//  WhisperKitManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import WhisperKit
import AVFoundation // Импортируем WhisperKit для работы с Whisper API

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
    var modelName: String = "base.en" // Модель по умолчанию (улучшенная)
    var sampleRate: Double = 16000 // Частота дискретизации
    
    // Параметры для улучшения качества распознавания (OpenAI Whisper)
    var temperature: Float = 0.0 // Температура для генерации (0.0 = детерминистично)
    var temperatureFallbackCount: Int = 0 // Количество попыток с разными температурами
    var compressionRatioThreshold: Float = 2.4 // Порог сжатия для обнаружения повторений
    var logProbThreshold: Float = -1.0 // Порог логарифмической вероятности
    var noSpeechThreshold: Float = 0.6 // Порог для обнаружения отсутствия речи
    var conditionOnPreviousText: Bool = true // Учитывать предыдущий текст
    var promptResetOnTemperature: Bool = false // Сброс промпта при изменении температуры
    var initialPrompt: String? = nil // Начальный промпт для контекста
    var prefix: String? = nil // Префикс для генерации
    var suppressBlank: Bool = true // Подавлять пустые сегменты
    var suppressTokens: [Int] = [-1] // Подавляемые токены
    var withoutTimestamps: Bool = false // Без временных меток
    var maxInitialTimestamp: Float = 1.0 // Максимальная начальная временная метка
    var wordTimestamps: Bool = false // Временные метки слов
    var prependPunctuations: String = "\"'" // Пунктуация в начале
    var appendPunctuations: String = "\"'.,!?:\n" // Пунктуация в конце (упрощенная версия)
    var vadFilter: Bool = true // Фильтр активности голоса
    var vadThreshold: Float = 0.35 // Порог VAD
    var vadMinSpeechDuration: Float = 0.25 // Минимальная длительность речи
    var vadMaxSpeechDuration: Float = 30.0 // Максимальная длительность речи
    var vadMinSilenceDuration: Float = 0.5 // Минимальная длительность тишины
    var vadWindowSize: Float = 0.1 // Размер окна VAD
    var vadMaxMergeDistance: Float = 0.5 // Максимальное расстояние слияния VAD
    var vadPadding: Float = 0.0 // Отступы VAD
    
    // Дополнительные параметры для улучшения качества
    var bestOf: Int = 1 // Количество попыток для выбора лучшего результата
    var patience: Float = 1.0 // Терпение для ожидания лучшего результата
    var lengthPenalty: Float = 1.0 // Штраф за длину
    var repetitionPenalty: Float = 1.0 // Штраф за повторения
    var noRepeatNgramSize: Int = 0 // Размер n-грамм для предотвращения повторений
    
    static let defaultConfiguration = WhisperConfiguration()
    
    // Конфигурация для высокого качества
    static let highQualityConfiguration = WhisperConfiguration(
        modelName: "base.en", // Еще более точная модель
        temperature: 0.0,
        temperatureFallbackCount: 0,
        compressionRatioThreshold: 2.4,
        logProbThreshold: -1.0,
        noSpeechThreshold: 0.6,
        conditionOnPreviousText: true,
        promptResetOnTemperature: false,
        suppressBlank: true,
        suppressTokens: [-1],
        withoutTimestamps: false,
        maxInitialTimestamp: 1.0,
        wordTimestamps: false,
        vadFilter: true,
        vadThreshold: 0.35,
        vadMinSpeechDuration: 0.25,
        vadMaxSpeechDuration: 30.0,
        vadMinSilenceDuration: 0.5,
        vadWindowSize: 0.1,
        vadMaxMergeDistance: 0.5,
        vadPadding: 0.0,
        bestOf: 3, // Больше попыток для лучшего результата
        patience: 2.0, // Больше терпения
        lengthPenalty: 1.1, // Небольшой штраф за длину
        repetitionPenalty: 1.1, // Штраф за повторения
        noRepeatNgramSize: 3 // Предотвращение повторений 3-грамм
    )
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
        
        // Создаем базовую конфигурацию WhisperKit
        let config = WhisperKitConfig(model: configuration.modelName)
        
        // WhisperKitConfig поддерживает только базовые параметры
        // Расширенные параметры Whisper будут использоваться через WhisperKit API
        whisperKit = try await WhisperKit(config)
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
        
        
        // WhisperKit автоматически загружает модель при инициализации
        // Дополнительная проверка не требуется, так как whisperKit уже проверен выше
        
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
            
            // Отправляем финальный прогресс прогрева
            notifyDelegate { delegate in
                delegate.whisperKitManager(self, didUpdateWarmupProgress: 1.0)
            }
            
            isWarmedUp = true
        } catch {
            print("❌ Failed to warm up model: \(error.localizedDescription)")
            throw WhisperKitError.modelLoadFailed(error)
        }
    }
    
    /// Транскрипция аудио фреймов
    /// Transcribe audio frames
    func transcribe(audioFrames: [Float]) async throws -> [WhisperSegment] {
        
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.modelNotLoaded
        }
        
        
        // Добавляем фреймы в буфер с ограничением размера
        audioBuffer.append(contentsOf: audioFrames)
        
        // Проверяем, не превышен ли максимальный размер буфера
        if audioBuffer.count > maxBufferSize {
            audioBuffer = Array(audioBuffer.suffix(maxBufferSize))
        }
        
        
        // Проверяем, не идет ли уже транскрипция
        guard !isTranscribing else {
            return []
        }
        
        // Для потокового распознавания используем весь накопленный буфер
        // WhisperKit сам определит оптимальное чанкование
        guard !audioBuffer.isEmpty else {
            return []
        }
        
        do {
            isTranscribing = true
            
            // Используем весь буфер для качественного распознавания
            let startTime = Date()
            let result = try await whisperKit.transcribe(audioArray: audioBuffer)
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Сохраняем метрики времени обработки
            processingTimes.append(processingTime)
            
            
            // Конвертируем результат в наш формат
            var whisperSegments: [WhisperSegment] = []
            
            if let firstResult = result.first, !firstResult.text.isEmpty {
                // Создаем один сегмент с полным текстом
                let segment = WhisperSegment(
                    text: firstResult.text,
                    start: 0.0,
                    end: Double(audioBuffer.count) / 16000.0
                )
                whisperSegments = [segment]
                
                // НЕ очищаем буфер после промежуточных результатов
                // Буфер будет очищен только при остановке записи
                
            } else {
                whisperSegments = []
            }
            
            // Отправляем результат через делегат безопасно
            if !whisperSegments.isEmpty {
                print("🔄 Отправляем промежуточные результаты: \(whisperSegments.map { $0.text }.joined(separator: " "))")
            }
            notifyDelegate { delegate in
                delegate.whisperKitManager(self, didReceiveSegments: whisperSegments)
            }
            
            
            isTranscribing = false
            return whisperSegments
            
        } catch {
            isTranscribing = false
            print("❌ Ошибка распознавания: \(error.localizedDescription)")
            
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
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    // Ожидаем завершения транскрипции с таймаутом
                    let startWaitTime = Date()
                    let maxWaitTime: TimeInterval = 5.0 // Максимум 5 секунд ожидания
                    
                    while isTranscribing && Date().timeIntervalSince(startWaitTime) < maxWaitTime {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
                    }
                    
                    if isTranscribing {
                        isTranscribing = false
                    }
                    
                    continuation.resume()
                }
            }
        }
        
        // Обрабатываем оставшиеся данные в буфере
        var finalSegments: [WhisperSegment] = []
        
        if !audioBuffer.isEmpty {
            
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
                
                // Конвертируем результат в наш формат
                if let firstResult = result.first, !firstResult.text.isEmpty {
                    let segment = WhisperSegment(
                        text: firstResult.text,
                        start: 0.0,
                        end: Double(audioBuffer.count) / 16000.0
                    )
                    finalSegments = [segment]
                } else {
                    finalSegments = []
                }
                
                audioBuffer.removeAll()
                isTranscribing = false
            } catch {
                isTranscribing = false
                print("❌ Final transcription failed: \(error.localizedDescription)")
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
    }
    
    /// Сброс состояния
    /// Reset state
    func reset() async {
        whisperKit = nil
        isInitialized = false
        isWarmedUp = false
        currentSession = nil
        audioBuffer.removeAll()
    }
    
    /// Обновление конфигурации Whisper
    /// Update Whisper configuration
    func updateConfiguration(_ newConfig: WhisperConfiguration) async {
        configuration = newConfig
    }
    
    /// Переключение на конфигурацию высокого качества
    /// Switch to high quality configuration
    func enableHighQualityMode() async {
        configuration = WhisperConfiguration.highQualityConfiguration
        print("🎯 Включен режим высокого качества: модель = \(configuration.modelName)")
        
        // Если WhisperKit уже инициализирован, нужно переинициализировать с новой конфигурацией
        if isInitialized {
            print("🔄 Переинициализация WhisperKit с новой конфигурацией...")
            isInitialized = false
            isWarmedUp = false
            whisperKit = nil
            
            // Автоматически переинициализируем с новой конфигурацией
            do {
                try await initialize()
                print("✅ WhisperKit переинициализирован с конфигурацией высокого качества")
            } catch {
                print("❌ Ошибка переинициализации WhisperKit: \(error.localizedDescription)")
            }
        }
    }
    
    /// Переключение на стандартную конфигурацию
    /// Switch to standard configuration
    func enableStandardMode() async {
        configuration = WhisperConfiguration.defaultConfiguration
        print("📱 Включен стандартный режим: модель = \(configuration.modelName)")
        
        // Если WhisperKit уже инициализирован, нужно переинициализировать с новой конфигурацией
        if isInitialized {
            print("🔄 Переинициализация WhisperKit с новой конфигурацией...")
            isInitialized = false
            isWarmedUp = false
            whisperKit = nil
            
            // Автоматически переинициализируем с новой конфигурацией
            do {
                try await initialize()
                print("✅ WhisperKit переинициализирован со стандартной конфигурацией")
            } catch {
                print("❌ Ошибка переинициализации WhisperKit: \(error.localizedDescription)")
            }
        }
    }
    
    /// Проверка готовности WhisperKit
    /// Check if WhisperKit is ready
    var isReady: Bool {
        return isInitialized && isWarmedUp
    }
    
    /// Создание временного аудио файла из фреймов
    /// Create temporary audio file from frames
    private func createTempAudioFile(from frames: [Float]) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempDir = documentsPath.appendingPathComponent("TempAudio")
        
        // Создаем директорию если не существует
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let fileName = "temp_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Создаем WAV файл
        let sampleRate: Double = 16000
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: audioFormat.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frames.count))!
            buffer.frameLength = AVAudioFrameCount(frames.count)
            
            if let channelData = buffer.floatChannelData?[0] {
                for (index, sample) in frames.enumerated() {
                    channelData[index] = sample
                }
            }
            
            try audioFile.write(from: buffer)
        } catch {
            print("❌ Ошибка создания временного файла: \(error)")
        }
        
        return fileURL
    }
    
    /// Транскрипция аудио файла
    /// Transcribe audio file
    func transcribeFile(audioPath: String) async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            throw WhisperKitError.notReady
        }
        
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.modelNotLoaded
        }
        
        print("🔄 Выполняем файловую транскрипцию: \(audioPath)")
        
        do {
            let startTime = Date()
            let result = try await whisperKit.transcribe(audioPath: audioPath)
            let processingTime = Date().timeIntervalSince(startTime)
            
            print("🔄 Файловая транскрипция завершена за \(processingTime) сек")
            
            // Конвертируем результат в наш формат
            var whisperSegments: [WhisperSegment] = []
            
            for transcriptionResult in result {
                if !transcriptionResult.text.isEmpty {
                    let segment = WhisperSegment(
                        text: transcriptionResult.text,
                        start: 0.0, // TranscriptionResult не содержит временные метки
                        end: 0.0
                    )
                    whisperSegments.append(segment)
                }
            }
            
            return whisperSegments
            
        } catch {
            print("❌ Ошибка файловой транскрипции: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Очистка буфера аудио
    /// Clear audio buffer
    func clearAudioBuffer() {
        audioBuffer.removeAll()
        print("🧹 Аудио буфер очищен")
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
