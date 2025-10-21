//
//  WhisperKitManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import SwiftWhisper // Импортируем SwiftWhisper для работы с Whisper API

// MARK: - WhisperSegment Model
struct WhisperSegment {
    let text: String
    let start: Double
    let end: Double
}

// MARK: - WhisperConfiguration
struct WhisperConfiguration {
    var language: String = "english" // По умолчанию английский
    var translate: Bool = false      // Не переводить
    var beamSize: Int = 5            // Размер луча для декодирования
    var sampleRate: Double = 16000   // Частота дискретизации
    
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
    private var whisper: Whisper?
    private var isInitialized = false
    private var isWarmedUp = false
    private var currentSession: Any? // Placeholder for WhisperSession
    private var audioBuffer: [Float] = []
    private let minBufferSize = 8000 // Минимум 0.5 секунды аудио (16kHz) - уменьшен для более быстрого отклика
    private let maxBufferSize = 160000 // Максимум ~10 секунд аудио (16kHz)
    private var isTranscribing = false // Флаг для предотвращения одновременных транскрипций
    
    // MARK: - Configuration
    private var configuration: WhisperConfiguration = WhisperConfiguration(language: "english", translate: false, beamSize: 5, sampleRate: 16000)
    
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
    
    /// Инициализация SwiftWhisper
    /// Initialize SwiftWhisper
    func initialize() async throws {
        guard !isInitialized else {
            print("⚠️ SwiftWhisper already initialized")
            return
        }
        
        print("🚀 Initializing SwiftWhisper...")
        
        // Проверка доступности библиотеки SwiftWhisper
        // Примечание: в реальной реализации нужно добавить метод проверки доступности
        // В текущей версии SwiftWhisper такого метода нет, поэтому используем заглушку
        do {
            // Проверяем доступность фреймворка
            let frameworkBundle = Bundle(for: Whisper.self)
            guard frameworkBundle.isLoaded else {
                throw WhisperKitError.initializationFailed(NSError(
                    domain: "WhisperKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "SwiftWhisper framework not loaded"]
                ))
            }
            
            print("✓ SwiftWhisper framework is available")
            isInitialized = true
            print("✅ SwiftWhisper initialized successfully")
        } catch {
            print("❌ Failed to initialize SwiftWhisper: \(error.localizedDescription)")
            throw WhisperKitError.initializationFailed(error)
        }
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
            
            // Создаем параметры на основе текущей конфигурации
            var params = WhisperParams.default
            
            // Устанавливаем только английский язык для распознавания
            params.language = .english
            print("🌍 Установлен английский язык распознавания")
            
            // Устанавливаем другие параметры из конфигурации
            params.translate = configuration.translate
            // Предполагаем, что в WhisperParams есть свойство beamSize
            // params.beamSize = configuration.beamSize
            
            print("🌍 Language set to: \(configuration.language)")
            print("🔄 Translate: \(configuration.translate)")
            
            // Инициализируем Whisper с нашими параметрами
            whisper = try Whisper(fromFileURL: url, withParams: params)
            print("✅ Model loaded successfully with \(configuration.language) language")
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
        
        // Прогреваем модель с реальными данными (1 секунда синусоидального сигнала)
        // Используем синусоидальный сигнал вместо тишины для лучшего прогрева
        var warmupData = [Float](repeating: 0.0, count: 16000) // 1 секунда аудио
        for i in 0..<16000 {
            // Создаем синусоидальный сигнал частотой 440 Гц (нота ля первой октавы)
            warmupData[i] = sin(2.0 * Float.pi * 440.0 * Float(i) / 16000.0) * 0.5
        }
        print("🔥 Warming up with English language detection...")
        _ = try await whisper.transcribe(audioFrames: warmupData)
        
        // Отправляем прогресс прогрева через безопасный метод
        notifyDelegate { delegate in
            delegate.whisperKitManager(self, didUpdateWarmupProgress: 1.0)
        }
        
        isWarmedUp = true
        print("✅ Model warmed up successfully")
    }
    
    /// Транскрипция аудио фреймов
    /// Transcribe audio frames
    func transcribe(audioFrames: [Float]) async throws -> [WhisperSegment] {
        guard isInitialized && isWarmedUp else {
            print("❌ WhisperKit не готов: initialized=\(isInitialized), warmedUp=\(isWarmedUp)")
            throw WhisperKitError.notReady
        }
        
        guard let whisper = whisper else {
            print("❌ Модель Whisper не загружена")
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
            
            // Выполняем реальную транскрипцию с SwiftWhisper с измерением времени
            print("🔄 Starting transcription with English language...")
            
            let startTime = Date()
            let segments = try await whisper.transcribe(audioFrames: framesToProcess)
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Сохраняем метрики времени обработки
            processingTimes.append(processingTime)
            print("⏱️ Processing time: \(String(format: "%.2f", processingTime))s (avg: \(String(format: "%.2f", averageProcessingTime))s)")
            
            // Конвертируем в наш формат
            // Проверяем, не пустой ли результат
            var whisperSegments: [WhisperSegment] = []
            
            if segments.isEmpty {
                // Если распознавание не дало результатов, логируем это
                print("⚠️ Empty segments received from SwiftWhisper")
                // Возвращаем пустой массив вместо моковых данных
                whisperSegments = []
                
                // Проверяем амплитуду аудио для диагностики
                let maxAmplitude = framesToProcess.map { abs($0) }.max() ?? 0
                print("📊 Диагностика: максимальная амплитуда аудио: \(maxAmplitude)")
                
                if maxAmplitude < 0.01 {
                    print("⚠️ Возможная причина: слишком тихий звук (амплитуда < 0.01)")
                } else if maxAmplitude > 0.9 {
                    print("⚠️ Возможная причина: слишком громкий звук (амплитуда > 0.9)")
                }
            } else {
                // Обычная конвертация сегментов
                whisperSegments = segments.map { segment in
                    // Проверяем доступность свойств в сегменте
                    let text = segment.text ?? "Нет текста"
                    let start = segment.startTime != nil ? Double(segment.startTime) : 0.0
                    let end = segment.endTime != nil ? Double(segment.endTime) : 1.0
                    
                    return WhisperSegment(
                        text: text,
                        start: start,
                        end: end
                    )
                }
                
                print("✅ Успешно распознано \(whisperSegments.count) сегментов речи")
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
        
        // Ждем завершения текущей транскрипции с использованием continuation
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
                
                // Убеждаемся, что whisper не nil
                guard let whisper = whisper else {
                    throw WhisperKitError.modelNotLoaded
                }
                
                let startTime = Date()
                let segments = try await whisper.transcribe(audioFrames: audioBuffer)
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Сохраняем метрики времени обработки
                processingTimes.append(processingTime)
                print("⏱️ Final processing time: \(String(format: "%.2f", processingTime))s")
                
                // Конвертируем в наш формат с проверкой на пустой результат
                if segments.isEmpty {
                    // Если распознавание не дало результатов, логируем это
                    print("⚠️ Empty segments received in finalize")
                    
                    // Возвращаем пустой массив вместо моковых данных
                    finalSegments = []
                    
                    // Проверяем амплитуду аудио для диагностики
                    if !audioBuffer.isEmpty {
                        let maxAmplitude = audioBuffer.map { abs($0) }.max() ?? 0
                        print("📊 Финальная диагностика: максимальная амплитуда аудио: \(maxAmplitude)")
                        
                        if maxAmplitude < 0.01 {
                            print("⚠️ Возможная причина: слишком тихий звук (амплитуда < 0.01)")
                        } else if maxAmplitude > 0.9 {
                            print("⚠️ Возможная причина: слишком громкий звук (амплитуда > 0.9)")
                        }
                    }
                } else {
                    // Обычная конвертация сегментов
                    finalSegments = segments.map { segment in
                        // Проверяем доступность свойств в сегменте
                        let text = segment.text ?? "Нет текста"
                        let start = segment.startTime != nil ? Double(segment.startTime) : 0.0
                        let end = segment.endTime != nil ? Double(segment.endTime) : 1.0
                        
                        return WhisperSegment(
                            text: text,
                            start: start,
                            end: end
                        )
                    }
                    
                    print("✅ Финальное распознавание завершено: \(finalSegments.count) сегментов")
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
    
    /// Обновление конфигурации Whisper
    /// Update Whisper configuration
    func updateConfiguration(_ newConfig: WhisperConfiguration) async {
        configuration = newConfig
        print("🔄 WhisperKit configuration updated")
        print("🌍 Language: \(configuration.language)")
        print("🔄 Translate: \(configuration.translate)")
        print("🔢 Beam Size: \(configuration.beamSize)")
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
