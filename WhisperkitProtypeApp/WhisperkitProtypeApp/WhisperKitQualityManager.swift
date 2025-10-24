//
//  WhisperKitQualityManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 24.01.2025.
//

import Foundation
import WhisperKit
import UIKit

// MARK: - Quality Configuration Models

/// Конфигурация качества для WhisperKit
/// Quality configuration for WhisperKit
struct WhisperQualityConfiguration {
    let modelName: String
    let description: String
    let expectedWER: Double
    let expectedRTF: Double
    let memoryUsage: UInt64
    
    static let optimizedForEnglish = WhisperQualityConfiguration(
        modelName: "large-v3",  // Используем ту же модель, что и в WhisperKitManager
        description: "Максимальное качество для английского языка",
        expectedWER: 3.5,
        expectedRTF: 0.25,
        memoryUsage: 1_600_000_000  // 1.6 GB
    )
    
    static let balancedQuality = WhisperQualityConfiguration(
        modelName: "small.en",  // Используем ту же модель, что и в WhisperKitManager
        description: "Сбалансированное качество и производительность",
        expectedWER: 6.1,
        expectedRTF: 0.12,
        memoryUsage: 600_000_000  // 600 MB
    )
    
    static let fastProcessing = WhisperQualityConfiguration(
        modelName: "base.en",  // Используем ту же модель, что и в WhisperKitManager
        description: "Быстрая обработка с базовым качеством",
        expectedWER: 9.2,
        expectedRTF: 0.08,
        memoryUsage: 250_000_000  // 250 MB
    )
    
    static let ultraFast = WhisperQualityConfiguration(
        modelName: "tiny.en",  // Самая быстрая модель из WhisperKitManager
        description: "Ультра-быстрая обработка",
        expectedWER: 12.0,
        expectedRTF: 0.05,
        memoryUsage: 100_000_000  // 100 MB
    )
}

/// Уровень качества распознавания
/// Quality level for speech recognition
enum QualityLevel: String, CaseIterable {
    case optimized = "optimized"      // Максимальное качество для A16+
    case balanced = "balanced"        // Сбалансированное качество
    case fast = "fast"               // Быстрая обработка
    case ultraFast = "ultraFast"     // Ультра-быстрая обработка
    case adaptive = "adaptive"       // Автоматический выбор
    
    var configuration: WhisperQualityConfiguration {
        switch self {
        case .optimized:
            return .optimizedForEnglish
        case .balanced:
            return .balancedQuality
        case .fast:
            return .fastProcessing
        case .ultraFast:
            return .ultraFast
        case .adaptive:
            return Self.selectOptimalConfiguration()
        }
    }
    
    var displayName: String {
        switch self {
        case .optimized:
            return "🎯 Максимальное качество"
        case .balanced:
            return "⚖️ Сбалансированное"
        case .fast:
            return "⚡ Быстрая обработка"
        case .ultraFast:
            return "🚀 Ультра-быстрая"
        case .adaptive:
            return "🤖 Автоматический выбор"
        }
    }
    
    var description: String {
        switch self {
        case .optimized:
            return "Лучшее качество для A16+ устройств (3.5% WER)"
        case .balanced:
            return "Оптимальный баланс качества и скорости (6.1% WER)"
        case .fast:
            return "Быстрая обработка для старых устройств (9.2% WER)"
        case .ultraFast:
            return "Ультра-быстрая обработка (12.0% WER)"
        case .adaptive:
            return "Автоматический выбор на основе устройства"
        }
    }
    
    /// Автоматический выбор конфигурации на основе устройства
    /// Automatic configuration selection based on device
    static func selectOptimalConfiguration() -> WhisperQualityConfiguration {
        let deviceModel = UIDevice.current.model
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Определяем возможности устройства
        let isA16Plus = deviceModel.contains("iPhone15") || deviceModel.contains("iPhone16") || deviceModel.contains("iPhone17")
        let isM1Plus = deviceModel.contains("iPad") && totalMemory > 4_000_000_000
        let hasEnoughMemory = totalMemory > 3_000_000_000
        
        if isA16Plus || isM1Plus {
            return .optimizedForEnglish
        } else if hasEnoughMemory {
            return .balancedQuality
        } else {
            return .fastProcessing
        }
    }
}

/// Метрики качества распознавания
/// Quality metrics for speech recognition
struct QualityMetrics {
    let processingTime: TimeInterval
    let realtimeFactor: Double
    let wordErrorRate: Double?
    let memoryPeak: UInt64
    let modelName: String
    let qualityLevel: QualityLevel
    let timestamp: Date
    
    var performanceScore: Double {
        // Комбинированная оценка производительности (0-100)
        let speedScore = min(100, max(0, 100 - (realtimeFactor * 100)))
        let memoryScore = min(100, max(0, 100 - (Double(memoryPeak) / 1_000_000_000 * 10)))
        return (speedScore + memoryScore) / 2
    }
}

// MARK: - WhisperKitQualityManager Delegate

protocol WhisperKitQualityManagerDelegate: AnyObject {
    func qualityManager(_ manager: WhisperKitQualityManager, didUpdateQualityLevel level: QualityLevel)
    func qualityManager(_ manager: WhisperKitQualityManager, didUpdateMetrics metrics: QualityMetrics)
    func qualityManager(_ manager: WhisperKitQualityManager, didEncounterError error: Error)
    func qualityManager(_ manager: WhisperKitQualityManager, didCompleteInitialization success: Bool)
}

/// Менеджер качества для WhisperKit
/// Quality manager for WhisperKit
actor WhisperKitQualityManager {
    
    // MARK: - Singleton
    static let shared = WhisperKitQualityManager()
    
    // MARK: - Properties
    private var whisperKit: WhisperKit?
    private var currentQualityLevel: QualityLevel = .adaptive
    private var isInitialized = false
    private var metricsHistory: [QualityMetrics] = []
    private var currentMetrics: QualityMetrics?
    
    // MARK: - Audio Buffering (как в WhisperKitManager)
    private var audioBuffer: [Float] = []
    private var maxBufferSize = 16000 * 30 // 30 секунд аудио
    private var isTranscribing = false
    
    // MARK: - Delegate
    weak var delegate: WhisperKitQualityManagerDelegate?
    
    // MARK: - Private Initializer
    private init() {}
    
    // MARK: - Public Methods
    
    /// Инициализация с выбранным уровнем качества
    /// Initialize with selected quality level
    func initialize(qualityLevel: QualityLevel = .adaptive) async throws {
        print("🚀 [QUALITY] Initializing WhisperKit with quality level: \(qualityLevel.rawValue)")
        
        currentQualityLevel = qualityLevel
        let config = qualityLevel.configuration
        
        // Создаем конфигурацию WhisperKit
        let whisperKitConfig = WhisperKitConfig(model: config.modelName)
        
        do {
            // Инициализируем WhisperKit
            print("🔄 [QUALITY] Creating WhisperKit instance...")
            whisperKit = try await WhisperKit(whisperKitConfig)
            
            // Проверяем, что WhisperKit действительно инициализирован
            guard whisperKit != nil else {
                throw WhisperKitError.notInitialized
            }
            
            isInitialized = true
            
            print("✅ [QUALITY] WhisperKit initialized with model: \(config.modelName)")
            print("📊 [QUALITY] Expected WER: \(config.expectedWER)%, RTF: \(config.expectedRTF)")
            
            // Уведомляем делегат
            await notifyDelegate { delegate in
                delegate.qualityManager(self, didCompleteInitialization: true)
            }
            
        } catch {
            print("❌ [QUALITY] Failed to initialize WhisperKit: \(error.localizedDescription)")
            whisperKit = nil
            isInitialized = false
            await notifyDelegate { delegate in
                delegate.qualityManager(self, didEncounterError: error)
            }
            throw error
        }
    }
    
    /// Переключение уровня качества
    /// Switch quality level
    func switchQualityLevel(to level: QualityLevel) async throws {
        guard level != currentQualityLevel else {
            print("⚠️ [QUALITY] Already using quality level: \(level.rawValue)")
            return
        }
        
        print("🔄 [QUALITY] Switching to quality level: \(level.rawValue)")
        
        // Сбрасываем текущее состояние
        whisperKit = nil
        isInitialized = false
        
        // Инициализируем с новым уровнем качества
        try await initialize(qualityLevel: level)
        
        // Уведомляем делегат
        await notifyDelegate { delegate in
            delegate.qualityManager(self, didUpdateQualityLevel: level)
        }
    }
    
    /// Транскрипция с отслеживанием метрик (как в WhisperKitManager)
    /// Transcribe with metrics tracking (like WhisperKitManager)
    func transcribe(audioArray: [Float]) async throws -> String {
        guard isInitialized, let whisperKit = whisperKit else {
            print("❌ [QUALITY] WhisperKit not initialized or nil")
            throw WhisperKitError.notInitialized
        }
        
        // Добавляем фреймы в буфер с ограничением размера (как в WhisperKitManager)
        audioBuffer.append(contentsOf: audioArray)
        
        // Проверяем, не превышен ли максимальный размер буфера
        if audioBuffer.count > maxBufferSize {
            audioBuffer = Array(audioBuffer.suffix(maxBufferSize))
        }
        
        // Проверяем, не идет ли уже транскрипция
        guard !isTranscribing else {
            return ""
        }
        
        // Для потокового распознавания используем весь накопленный буфер
        guard !audioBuffer.isEmpty else {
            return ""
        }
        
        let startTime = Date()
        let memoryBefore = getCurrentMemoryUsage()
        
        do {
            isTranscribing = true
            print("🎤 [QUALITY] Transcribing \(audioBuffer.count) buffered audio samples...")
            
            // Используем весь буфер для качественного распознавания (как в WhisperKitManager)
            let result = try await whisperKit.transcribe(audioArray: audioBuffer)
            
            let processingTime = Date().timeIntervalSince(startTime)
            let memoryAfter = getCurrentMemoryUsage()
            let audioLength = Double(audioBuffer.count) / 16000.0
            let realtimeFactor = processingTime / audioLength
            
            // Создаем метрики
            let metrics = QualityMetrics(
                processingTime: processingTime,
                realtimeFactor: realtimeFactor,
                wordErrorRate: nil, // WER требует ground truth
                memoryPeak: max(memoryBefore, memoryAfter),
                modelName: currentQualityLevel.configuration.modelName,
                qualityLevel: currentQualityLevel,
                timestamp: Date()
            )
            
            // Сохраняем метрики
            currentMetrics = metrics
            metricsHistory.append(metrics)
            
            // Ограничиваем историю до 100 записей
            if metricsHistory.count > 100 {
                metricsHistory.removeFirst()
            }
            
            print("📊 [QUALITY] Metrics - RTF: \(String(format: "%.2f", realtimeFactor)), Time: \(String(format: "%.2f", processingTime))s")
            
            // Уведомляем делегат
            await notifyDelegate { delegate in
                delegate.qualityManager(self, didUpdateMetrics: metrics)
            }
            
            // Обрабатываем результат как в WhisperKitManager
            var combinedText = ""
            if !result.isEmpty {
                // Объединяем все сегменты в один текст (как в WhisperKitManager)
                let allText = result.map { $0.text }.joined(separator: " ")
                
                // Фильтруем шумовые токены из объединенного текста
                let filteredText = filterNoiseTokens(from: allText)
                
                // Создаем результат только если остался значимый текст
                if !filteredText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    combinedText = filteredText
                }
            }
            
            print("🎯 [QUALITY] Raw result: \(result.count) segments, filtered: '\(combinedText)'")
            isTranscribing = false
            return combinedText
            
        } catch {
            isTranscribing = false
            print("❌ [QUALITY] Transcription failed: \(error.localizedDescription)")
            await notifyDelegate { delegate in
                delegate.qualityManager(self, didEncounterError: error)
            }
            throw error
        }
    }
    
    /// Получение текущих метрик
    /// Get current metrics
    func getCurrentMetrics() -> QualityMetrics? {
        return currentMetrics
    }
    
    /// Получение истории метрик
    /// Get metrics history
    func getMetricsHistory() -> [QualityMetrics] {
        return metricsHistory
    }
    
    /// Очистка аудио буфера (как в WhisperKitManager)
    /// Clear audio buffer (like WhisperKitManager)
    func clearAudioBuffer() {
        audioBuffer.removeAll()
        print("🧹 [QUALITY] Audio buffer cleared")
    }
    
    /// Подавление шумовых токенов (улучшенная версия без фильтрации коротких слов)
    /// Filter noise tokens (improved version without short word filtering)
    private func filterNoiseTokens(from text: String) -> String {
        var filteredText = text
        
        // Список шумовых паттернов для удаления
        let noisePatterns = [
            // Основные шумовые токены
            "\\[Music\\]", "\\[music\\]", "\\[MUSIC\\]",
            "\\[Noise\\]", "\\[noise\\]", "\\[NOISE\\]",
            "\\[Silence\\]", "\\[silence\\]", "\\[SILENCE\\]",
            "\\[Breathing\\]", "\\[breathing\\]", "\\[BREATHING\\]",
            "\\[Sighing\\]", "\\[sighing\\]", "\\[SIGHING\\]",
            "\\[Whooshing\\]", "\\[whooshing\\]", "\\[WHOOSHING\\]",
            "\\[Blank Audio\\]", "\\[blank audio\\]", "\\[BLANK AUDIO\\]",
            "\\[Background Noise\\]", "\\[background noise\\]", "\\[BACKGROUND NOISE\\]",
            "\\[Static\\]", "\\[static\\]", "\\[STATIC\\]",
            "\\[Wind\\]", "\\[wind\\]", "\\[WIND\\]",
            "\\[Audio\\]", "\\[audio\\]", "\\[AUDIO\\]",
            "\\[Sound\\]", "\\[sound\\]", "\\[SOUND\\]",
            "\\[Ambient\\]", "\\[ambient\\]", "\\[AMBIENT\\]",
            "\\[Atmospheric\\]", "\\[atmospheric\\]", "\\[ATMOSPHERIC\\]",
            "\\[Environmental\\]", "\\[environmental\\]", "\\[ENVIRONMENTAL\\]",
            "\\[Acoustic\\]", "\\[acoustic\\]", "\\[ACOUSTIC\\]",
            "\\[Electronic\\]", "\\[electronic\\]", "\\[ELECTRONIC\\]",
            "\\[Vocal\\]", "\\[vocal\\]", "\\[VOCAL\\]",
            "\\[Instrument\\]", "\\[instrument\\]", "\\[INSTRUMENT\\]",
            "\\[Instrumental\\]", "\\[instrumental\\]", "\\[INSTRUMENTAL\\]",
            "\\[Melody\\]", "\\[melody\\]", "\\[MELODY\\]",
            "\\[Rhythm\\]", "\\[rhythm\\]", "\\[RHYTHM\\]",
            "\\[Beat\\]", "\\[beat\\]", "\\[BEAT\\]",
            "\\[Song\\]", "\\[song\\]", "\\[SONG\\]",
            "\\[Tune\\]", "\\[tune\\]", "\\[TUNE\\]",
            "\\[Gasp\\]", "\\[gasp\\]", "\\[GASP\\]"
        ]
        
        // Удаляем каждый паттерн
        for pattern in noisePatterns {
            filteredText = filteredText.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Универсальные паттерны для захвата любых шумовых токенов
        // Удаляем любые токены в квадратных скобках (кроме обычных слов)
        filteredText = filteredText.replacingOccurrences(
            of: "\\[[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )
        
        // Удаляем любые токены в круглых скобках, содержащие музыкальные термины
        let musicTerms = ["music", "beat", "rhythm", "melody", "tune", "song", "audio", "sound", "noise", "silence", "breathing", "sighing", "whooshing", "static", "wind", "ambient", "atmospheric", "environmental", "acoustic", "electronic", "vocal", "instrument", "instrumental", "upbeat", "background"]
        
        for term in musicTerms {
            let pattern = "\\([^)]*\(term)[^)]*\\)"
            filteredText = filteredText.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Удаляем множественные пробелы и переносы строк
        filteredText = filteredText.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // Удаляем пробелы в начале и конце
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ФИЛЬТРАЦИЯ ПОВТОРЕНИЙ И ГАЛЛЮЦИНАЦИЙ
        // Удаляем повторяющиеся фразы (более 2 раз подряд)
        let sentences = filteredText.components(separatedBy: ". ")
        var uniqueSentences: [String] = []
        var lastSentence = ""
        var repeatCount = 0
        
        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSentence.isEmpty { continue }
            
            if trimmedSentence == lastSentence {
                repeatCount += 1
                if repeatCount < 2 {  // Разрешаем максимум 2 повторения
                    uniqueSentences.append(trimmedSentence)
                }
            } else {
                repeatCount = 0
                lastSentence = trimmedSentence
                uniqueSentences.append(trimmedSentence)
            }
        }
        
        filteredText = uniqueSentences.joined(separator: ". ")
        
        // Удаляем изолированные слова (вероятно галлюцинации) - но только если это не важные короткие слова
        let words = filteredText.components(separatedBy: " ")
        if words.count == 1 && filteredText.count < 10 {
            // Проверяем, не является ли это важным коротким словом
            let importantShortWords = ["I", "a", "an", "is", "it", "we", "he", "she", "my", "me", "us", "or", "of", "to", "in", "on", "at", "by", "as", "be", "do", "go", "so", "up", "if", "no", "oh", "hi", "ok", "am", "do", "go", "no", "oh", "ah", "eh", "uh", "um", "er", "hm", "mm", "yeah", "yes", "no", "ok", "hi", "bye"]
            let cleanWord = filteredText.trimmingCharacters(in: .punctuationCharacters)
            if !importantShortWords.contains(cleanWord) {
                filteredText = ""
            }
        }
        
        return filteredText
    }
    
    /// Файловая транскрипция (как в WhisperKitManager)
    /// File transcription (like WhisperKitManager)
    func transcribeFile(audioPath: String) async throws -> String {
        guard isInitialized, let whisperKit = whisperKit else {
            print("❌ [QUALITY] WhisperKit not initialized or nil")
            throw WhisperKitError.notInitialized
        }
        
        print("🔄 [QUALITY] Performing file transcription: \(audioPath)")
        
        do {
            let startTime = Date()
            let result = try await whisperKit.transcribe(audioPath: audioPath)
            let processingTime = Date().timeIntervalSince(startTime)
            
            print("🔄 [QUALITY] File transcription completed in \(processingTime) sec")
            
            // Обрабатываем результат
            var combinedText = ""
            for transcriptionResult in result {
                if !transcriptionResult.text.isEmpty {
                    let text = transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        if !combinedText.isEmpty {
                            combinedText += " "
                        }
                        combinedText += text
                    }
                }
            }
            
            print("🎉 [QUALITY] FILE TRANSCRIPTION: '\(combinedText)'")
            return combinedText
            
        } catch {
            print("❌ [QUALITY] File transcription failed: \(error.localizedDescription)")
            await notifyDelegate { delegate in
                delegate.qualityManager(self, didEncounterError: error)
            }
            throw error
        }
    }
    
    /// Получение средних метрик
    /// Get average metrics
    func getAverageMetrics() -> QualityMetrics? {
        guard !metricsHistory.isEmpty else { return nil }
        
        let avgProcessingTime = metricsHistory.map { $0.processingTime }.reduce(0, +) / Double(metricsHistory.count)
        let avgRTF = metricsHistory.map { $0.realtimeFactor }.reduce(0, +) / Double(metricsHistory.count)
        let avgMemory = metricsHistory.map { $0.memoryPeak }.reduce(0, +) / UInt64(metricsHistory.count)
        
        return QualityMetrics(
            processingTime: avgProcessingTime,
            realtimeFactor: avgRTF,
            wordErrorRate: nil,
            memoryPeak: avgMemory,
            modelName: currentQualityLevel.configuration.modelName,
            qualityLevel: currentQualityLevel,
            timestamp: Date()
        )
    }
    
    /// Получение доступных уровней качества
    /// Get available quality levels
    func getAvailableQualityLevels() -> [QualityLevel] {
        return QualityLevel.allCases
    }
    
    /// Получение текущего уровня качества
    /// Get current quality level
    func getCurrentQualityLevel() -> QualityLevel {
        return currentQualityLevel
    }
    
    /// Проверка готовности
    /// Check if ready
    var isReady: Bool {
        return isInitialized && whisperKit != nil
    }
    
    // MARK: - Private Methods
    
    /// Безопасное уведомление делегата
    /// Safe delegate notification
    private func notifyDelegate(_ action: @escaping (WhisperKitQualityManagerDelegate) -> Void) {
        guard let delegate = delegate else { 
            print("⚠️ [QUALITY] No delegate set, skipping notification")
            return 
        }
        
        Task { @MainActor in
            action(delegate)
        }
    }
    
    /// Получение текущего использования памяти
    /// Get current memory usage
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Установка делегата
    /// Set delegate
    func setDelegate(_ delegate: WhisperKitQualityManagerDelegate?) async {
        self.delegate = delegate
    }
    
    /// Сброс состояния
    /// Reset state
    func reset() async {
        whisperKit = nil
        isInitialized = false
        currentMetrics = nil
        metricsHistory.removeAll()
        print("🔄 [QUALITY] Quality manager reset")
    }
}

// MARK: - Quality Level Extensions

extension QualityLevel {
    /// Проверка совместимости с устройством
    /// Check device compatibility
    func isCompatibleWithDevice() -> Bool {
        let deviceModel = UIDevice.current.model
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        switch self {
        case .optimized:
            // Требует A16+ или M1+ с достаточной памятью
            let isA16Plus = deviceModel.contains("iPhone15") || deviceModel.contains("iPhone16") || deviceModel.contains("iPhone17")
            let isM1Plus = deviceModel.contains("iPad") && totalMemory > 4_000_000_000
            return isA16Plus || isM1Plus
            
        case .balanced:
            // Требует A14+ или достаточную память
            let isA14Plus = deviceModel.contains("iPhone13") || deviceModel.contains("iPhone14") || deviceModel.contains("iPhone15") || deviceModel.contains("iPhone16") || deviceModel.contains("iPhone17")
            return isA14Plus || totalMemory > 2_000_000_000
            
        case .fast:
            // Совместимо со всеми устройствами
            return true
            
        case .ultraFast:
            // Совместимо со всеми устройствами
            return true
            
        case .adaptive:
            // Всегда совместимо (автоматический выбор)
            return true
        }
    }
    
    /// Получение рекомендации для устройства
    /// Get device recommendation
    static func recommendedForDevice() -> QualityLevel {
        let deviceModel = UIDevice.current.model
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // A16+ или M1+ с достаточной памятью
        let isA16Plus = deviceModel.contains("iPhone15") || deviceModel.contains("iPhone16") || deviceModel.contains("iPhone17")
        let isM1Plus = deviceModel.contains("iPad") && totalMemory > 4_000_000_000
        
        if isA16Plus || isM1Plus {
            return .optimized
        }
        
        // A14+ или достаточная память
        let isA14Plus = deviceModel.contains("iPhone13") || deviceModel.contains("iPhone14")
        if isA14Plus || totalMemory > 2_000_000_000 {
            return .balanced
        }
        
        // Старые устройства
        return .fast
    }
}
