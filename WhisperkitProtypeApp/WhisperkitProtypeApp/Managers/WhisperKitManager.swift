//
//  WhisperKitManager.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation
import WhisperKit

/// Singleton менеджер для управления WhisperKit
/// Singleton manager for WhisperKit management
class WhisperKitManager {
    // MARK: - Singleton
    static let shared = WhisperKitManager()
    
    // MARK: - Properties
    private var whisperKit: WhisperKit?
    private let modelDownloadManager: ModelDownloadManager
    private let retryManager: RetryManager
    private var audioRecordingManager: AudioRecordingManager?
    private let errorHandler: ErrorHandler
    
    private var isInitialized = false
    
    // MARK: - Initialization
    private init() {
        self.modelDownloadManager = ModelDownloadManager()
        self.retryManager = RetryManager(maxRetries: 3, baseDelay: 1.0)
        self.errorHandler = ErrorHandler()
    }
    
    // MARK: - Public Methods
    
    /// Инициализация WhisperKit с моделью tiny-en
    /// Initialize WhisperKit with tiny-en model
    func initialize() async throws {
        guard !isInitialized else {
            print("✅ WhisperKit already initialized")
            return
        }
        
        do {
            try await retryManager.retry { [self] in
                // 1. Скачать модель если нужно
                // 1. Download model if needed
                print("📥 Downloading model if needed...")
                try await modelDownloadManager.downloadModelIfNeeded()
                
                // 2. Настроить конфигурацию
                // 2. Setup configuration
                let config = createConfig()
                
                // 3. Инициализировать WhisperKit
                // 3. Initialize WhisperKit
                print("🚀 Initializing WhisperKit...")
                self.whisperKit = try await WhisperKit(config)
                
                self.isInitialized = true
                print("✅ WhisperKit initialized successfully")
            }
        } catch {
            // Обрабатываем ошибки инициализации
            // Handle initialization errors
            print("❌ Failed to initialize WhisperKit: \(error)")
            errorHandler.handle(error)
            throw error
        }
    }
    
    /// Начать real-time транскрипцию
    /// Start real-time transcription
    func startRealtimeTranscription(delegate: TranscriptionDelegate) async throws {
        guard isInitialized, let whisperKit = whisperKit else {
            let error = WhisperKitError.notInitialized
            errorHandler.handle(error)
            throw error
        }
        
        do {
            // Создать audio recording manager если нет
            // Create audio recording manager if not exists
            if audioRecordingManager == nil {
                audioRecordingManager = AudioRecordingManager()
            }
            
            // Настроить decoding options
            // Setup decoding options
            let decodingOptions = createDecodingOptions(delegate: delegate)
            
            // Начать запись (теперь с await для actor)
            // Start recording (now with await for actor)
            try await audioRecordingManager?.startRecording(
                whisperKit: whisperKit,
                decodingOptions: decodingOptions,
                delegate: delegate
            )
            
            print("🎤 Real-time transcription started successfully")
        } catch {
            print("❌ Failed to start transcription: \(error)")
            errorHandler.handle(error)
            throw error
        }
    }
    
    /// Остановить транскрипцию
    /// Stop transcription
    func stopTranscription() async {
        guard let audioRecordingManager = audioRecordingManager else {
            print("⚠️ No active recording to stop")
            return
        }
        
        // Останавливаем запись асинхронно через actor
        // Stop recording asynchronously through actor
        await audioRecordingManager.stopRecording()
        print("🛑 Transcription stopped successfully")
    }
    
    /// Проверить готовность
    /// Check if ready
    func isReady() -> Bool {
        return isInitialized && whisperKit != nil
    }
    
    /// Проверить, активна ли запись
    /// Check if recording is active
    func isRecording() async -> Bool {
        // Проверяем, существует ли audioRecordingManager
        // Check if audioRecordingManager exists
        return audioRecordingManager != nil
    }
    
    /// Получить статус записи от AudioRecordingManager
    /// Get recording status from AudioRecordingManager
    func getRecordingStatus() async -> (isRecording: Bool, hasError: Bool) {
        // В будущем можно добавить метод в AudioRecordingManager для получения статуса
        // In the future, we can add a method in AudioRecordingManager to get status
        // Пока возвращаем упрощенную информацию
        // For now, return simplified information
        return (audioRecordingManager != nil, false)
    }
    
    /// Выгрузить модель (для экономии памяти)
    /// Unload model (for memory saving)
    func unloadModels() async {
        // Сначала останавливаем запись если активна
        // First stop recording if active
        await stopTranscription()
        
        // Затем выгружаем модели
        // Then unload models
        await whisperKit?.unloadModels()
        isInitialized = false
        audioRecordingManager = nil
        print("♻️ Models unloaded and recording stopped")
    }
    
    /// Сбросить состояние менеджера
    /// Reset manager state
    func reset() async {
        await stopTranscription()
        await unloadModels()
        print("🔄 WhisperKitManager reset completed")
    }
    
    // MARK: - Private Methods
    
    /// Создать конфигурацию WhisperKit
    /// Create WhisperKit configuration
    private func createConfig() -> WhisperKitConfig {
        let config = WhisperKitConfig(
            model: "openai_whisper-small.en", // Используем правильное имя модели
            modelFolder: nil, // Не указываем modelFolder, чтобы WhisperKit сам загрузил
            verbose: false,
            prewarm: true,
            load: true,
            download: true
        )
        
        // Устанавливаем downloadBase для загрузки моделей
        // Set downloadBase for model downloading
        config.downloadBase = modelDownloadManager.getCachePath().deletingLastPathComponent().deletingLastPathComponent()
        
        // Настроить compute options для Neural Engine
        // Setup compute options for Neural Engine
        var computeOptions = ModelComputeOptions()
        computeOptions.audioEncoderCompute = .cpuAndNeuralEngine
        computeOptions.textDecoderCompute = .cpuAndNeuralEngine
        config.computeOptions = computeOptions
        
        return config
    }
    
    /// Создать decoding options
    /// Create decoding options
    private func createDecodingOptions(delegate: TranscriptionDelegate) -> DecodingOptions {
        var options = DecodingOptions()
        
        // Базовые настройки
        // Basic settings
        options.language = "en"
        options.task = .transcribe
        options.temperature = 0.0
        options.wordTimestamps = true
        options.detectLanguage = true
        
        // Колбэки будут настроены в AudioRecordingManager
        // Callbacks will be configured in AudioRecordingManager
        
        return options
    }
}
