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
    }
    
    /// Начать real-time транскрипцию
    /// Start real-time transcription
    func startRealtimeTranscription(delegate: TranscriptionDelegate) async throws {
        guard isInitialized, let whisperKit = whisperKit else {
            throw WhisperKitError.notInitialized
        }
        
        // Создать audio recording manager если нет
        // Create audio recording manager if not exists
        if audioRecordingManager == nil {
            audioRecordingManager = AudioRecordingManager()
        }
        
        // Настроить decoding options
        // Setup decoding options
        let decodingOptions = createDecodingOptions(delegate: delegate)
        
        // Начать запись
        // Start recording
        try await audioRecordingManager?.startRecording(
            whisperKit: whisperKit,
            decodingOptions: decodingOptions,
            delegate: delegate
        )
    }
    
    /// Остановить транскрипцию
    /// Stop transcription
    func stopTranscription() async {
        audioRecordingManager?.stopRecording()
    }
    
    /// Проверить готовность
    /// Check if ready
    func isReady() -> Bool {
        return isInitialized && whisperKit != nil
    }
    
    /// Выгрузить модель (для экономии памяти)
    /// Unload model (for memory saving)
    func unloadModels() async {
        await whisperKit?.unloadModels()
        isInitialized = false
        print("♻️ Models unloaded")
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
