//
//  RecognitionPresenter.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation

// MARK: - RecognitionPresenter Delegate
protocol RecognitionPresenterDelegate: AnyObject {
    func recognitionPresenter(_ presenter: RecognitionPresenter, didUpdateStatus status: AppStatus)
    func recognitionPresenter(_ presenter: RecognitionPresenter, didUpdateProgress progress: Double)
    func recognitionPresenter(_ presenter: RecognitionPresenter, didUpdateTranscription text: String)
    func recognitionPresenter(_ presenter: RecognitionPresenter, didEncounterError error: Error)
}

// MARK: - App Status
enum AppStatus {
    case loading
    case downloadingModel(progress: Double)
    case warmingModel(progress: Double)
    case ready
    case recording
    case processing
    case error(Error)
}

/// Презентер для управления транскрипцией речи
/// Presenter for managing speech transcription
class RecognitionPresenter {
    
    // MARK: - Properties
    private let whisperManager: WhisperKitManager
    private let audioManager: AudioRecordingManager
    private let downloadManager: ModelDownloadManager
    private var currentTranscription = ""
    private var isTranscribing = false
    
    // MARK: - Model Selection
    private var selectedModel: String = "tiny.en" // По умолчанию tiny.en (WhisperKit формат)
    
    // MARK: - Delegate
    weak var delegate: RecognitionPresenterDelegate?
    
    // MARK: - Initialization
    init(
        whisperManager: WhisperKitManager = WhisperKitManager.shared,
        audioManager: AudioRecordingManager = AudioRecordingManager(),
        downloadManager: ModelDownloadManager = ModelDownloadManager()
    ) {
        self.whisperManager = whisperManager
        self.audioManager = audioManager
        self.downloadManager = downloadManager
        
        setupDelegates()
    }
    
    // MARK: - Public Methods
    
    /// Выбор модели для транскрипции
    /// Select model for transcription
    func selectModel(_ modelName: String) {
        // Поддерживаем модели WhisperKit с расширением .en
        guard ["tiny.en", "base.en", "small.en", "medium.en", "large-v3"].contains(modelName) else {
            print("❌ Unsupported model: \(modelName)")
            return
        }
        selectedModel = modelName
        print("📱 Model selected: \(modelName)")
        
        // Настраиваем конфигурацию WhisperKit
        Task {
            await updateWhisperConfiguration(modelName: modelName, language: "en")
        }
    }
    
    /// Получить доступные модели
    /// Get available models
    func getAvailableModels() -> [String] {
        return downloadManager.getAvailableModels()
    }
    
    /// Получить текущую выбранную модель
    /// Get currently selected model
    func getSelectedModel() -> String {
        return selectedModel
    }
    
    /// Инициализация системы транскрипции
    /// Initialize transcription system
    func initializeTranscription() async {
        do {
            // Сбрасываем состояние WhisperKit перед новой инициализацией
            await whisperManager.reset()
            
            // Обновляем статус
            await updateStatus(.loading)
            print("🚀 Starting transcription system initialization...")
            
            // Настраиваем конфигурацию WhisperKit
            await updateWhisperConfiguration(modelName: selectedModel, language: "en")
            print("🌍 Установлен язык распознавания: en")
            
            // Инициализируем WhisperKit (автоматически загружает модель)
            print("📱 Initializing WhisperKit with model: \(selectedModel)")
            try await whisperManager.initialize()
            print("✅ WhisperKit initialized")
            
            // Загружаем модель (WhisperKit делает это автоматически)
            print("📥 Loading model: \(selectedModel)")
            await updateStatus(.downloadingModel(progress: 0.2))
            try await whisperManager.loadModel()
            print("✅ Model loaded")
            
            // Прогреваем модель
            print("🔥 Warming up model...")
            await updateStatus(.warmingModel(progress: 0.0))
            try await whisperManager.warmup()
            print("✅ Model warmed up")
            
            // Создаем новую сессию транскрипции
            print("🆕 Creating new transcription session...")
            try await whisperManager.startNewSession()
            print("✅ Transcription session created")
            
            // Система готова
            print("🎯 Setting status to READY for model: \(selectedModel)")
            await updateStatus(.ready)
            print("✅ Transcription system ready for model: \(selectedModel)")
            
        } catch {
            print("❌ Failed to initialize transcription system: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            await updateStatus(.error(error))
            await handleError(error)
        }
    }
    
    /// Начало транскрипции
    /// Start transcription
    func startTranscription() async {
        guard !isTranscribing else {
            print("⚠️ Already transcribing")
            return
        }
        
        do {
            isTranscribing = true
            currentTranscription = ""
            
            await updateStatus(.recording)
            
            // Начинаем запись аудио
            try await audioManager.startRecording()
            
            print("🎤 Transcription started")
            
        } catch {
            await handleError(error)
        }
    }
    
    /// Остановка транскрипции
    /// Stop transcription
    func stopTranscription() async {
        guard isTranscribing else {
            print("⚠️ Транскрипция не активна")
            return
        }
        
        print("⏹️ Останавливаем транскрипцию...")
        
        do {
            // Останавливаем запись
            try await audioManager.stopRecording()
            
            // Финализируем транскрипцию
            await updateStatus(.processing)
            print("🔄 Финализируем результаты распознавания...")
            
            let finalSegments = try await whisperManager.finalize()
            
            // Обновляем финальный текст
            if !finalSegments.isEmpty {
                let finalText = finalSegments.map(\.text).joined(separator: " ")
                print("✅ Финальный текст: \"\(finalText)\"")
                currentTranscription = finalText
                await updateTranscription(finalText)
            } else {
                print("ℹ️ Финальный результат пустой")
                // Если финальный результат пустой, но у нас есть накопленный текст, используем его
                if !currentTranscription.isEmpty {
                    print("✅ Используем накопленный текст: \"\(currentTranscription)\"")
                    await updateTranscription(currentTranscription)
                } else {
                    print("⚠️ Распознавание не дало результатов")
                    await updateTranscription("Речь не распознана")
                }
            }
            
            await updateStatus(.ready)
            isTranscribing = false
            print("⏹️ Транскрипция остановлена")
            
        } catch {
            print("❌ Ошибка при остановке транскрипции: \(error.localizedDescription)")
            await handleError(error)
            isTranscribing = false
            await updateStatus(.ready)
        }
    }
    
    /// Получение текущей транскрипции
    /// Get current transcription
    func getCurrentTranscription() -> String {
        return currentTranscription
    }
    
    /// Очистка транскрипции
    /// Clear transcription
    func clearTranscription() async {
        currentTranscription = ""
        await updateTranscription("")
    }
    
    // MARK: - Private Methods
    
    private func setupDelegates() {
        // Настраиваем делегаты для всех менеджеров
        Task {
            await whisperManager.setDelegate(self)
        }
        audioManager.delegate = self
        downloadManager.delegate = self
    }
    
    private func updateStatus(_ status: AppStatus) async {
        await MainActor.run {
            delegate?.recognitionPresenter(self, didUpdateStatus: status)
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            delegate?.recognitionPresenter(self, didUpdateProgress: progress)
        }
    }
    
    private func updateTranscription(_ text: String) async {
        await MainActor.run {
            delegate?.recognitionPresenter(self, didUpdateTranscription: text)
        }
    }
    
    /// Добавляем метод для обновления конфигурации WhisperKit
    private func updateWhisperConfiguration(modelName: String, language: String) async {
        // Создаем конфигурацию с параметром автоматического прогрева
        let config = WhisperConfiguration(
            language: language,
            translate: false,
            modelName: modelName,
            sampleRate: 16000
        )
        await whisperManager.updateConfiguration(config)
        print("🔄 Обновлена конфигурация WhisperKit: модель = \(modelName), язык = \(language)")
    }
    
    private func handleError(_ error: Error) async {
        print("❌ Ошибка распознавания: \(error.localizedDescription)")
        
        // Определяем тип ошибки для лучшей диагностики
        if let whisperError = error as? WhisperKitError {
            switch whisperError {
            case .transcriptionFailed:
                print("⚠️ Ошибка процесса транскрипции")
                // Если у нас есть накопленный текст, используем его
                if !currentTranscription.isEmpty {
                    print("✅ Используем накопленный текст несмотря на ошибку: \"\(currentTranscription)\"")
                }
            case .modelNotLoaded:
                print("⚠️ Модель не загружена")
            case .notReady:
                print("⚠️ Система распознавания не готова")
            default:
                print("⚠️ Другая ошибка WhisperKit: \(whisperError)")
            }
        }
        
        // Обновляем статус и уведомляем делегат
        await updateStatus(.error(error))
        
        await MainActor.run {
            delegate?.recognitionPresenter(self, didEncounterError: error)
        }
        
        // Сбрасываем флаг транскрипции
        isTranscribing = false
    }
}

// MARK: - WhisperKitManager Delegate
extension RecognitionPresenter: WhisperKitManagerDelegate {
    func whisperKitManager(_ manager: WhisperKitManager, didUpdateWarmupProgress progress: Double) {
        Task {
            await updateProgress(progress)
            // Обновляем статус для любого прогресса
            await updateStatus(.warmingModel(progress: progress))
            
            // Если прогрев завершен (100%), обновляем статус на ready
            if progress >= 1.0 {
                await updateStatus(.ready)
            }
        }
    }
    
    func whisperKitManager(_ manager: WhisperKitManager, didReceiveSegments segments: [WhisperSegment]) {
        Task {
            // Проверяем, не пустой ли массив сегментов
            if !segments.isEmpty {
                let newText = segments.map { $0.text }.joined(separator: " ")
                print("🔊 Получены промежуточные результаты распознавания: \"\(newText)\"")
                currentTranscription += newText
                await updateTranscription(currentTranscription)
            } else {
                print("ℹ️ Получен пустой промежуточный результат распознавания")
            }
        }
    }
    
    func whisperKitManager(_ manager: WhisperKitManager, didCompleteWithSegments segments: [WhisperSegment]) {
        Task {
            if !segments.isEmpty {
                let finalText = segments.map { $0.text }.joined(separator: " ")
                print("🔊 Получены финальные результаты распознавания: \"\(finalText)\"")
                currentTranscription = finalText
                await updateTranscription(currentTranscription)
            } else {
                print("ℹ️ Получен пустой финальный результат распознавания")
                // Если финальный результат пустой, но у нас есть накопленный текст, сохраняем его
                if !currentTranscription.isEmpty {
                    print("✅ Используем накопленный текст: \"\(currentTranscription)\"")
                    await updateTranscription(currentTranscription)
                } else {
                    print("⚠️ Распознавание не дало результатов")
                    await updateTranscription("Речь не распознана")
                }
            }
        }
    }
    
    func whisperKitManager(_ manager: WhisperKitManager, didFailWith error: Error) {
        Task {
            await handleError(error)
        }
    }
}

// MARK: - AudioRecordingManager Delegate
extension RecognitionPresenter: AudioRecordingManagerDelegate {
    func audioRecordingManager(_ manager: AudioRecordingManager, didStartRecording: Bool) {
        print("🎤 Audio recording started")
    }
    
    func audioRecordingManager(_ manager: AudioRecordingManager, didStopRecording: Bool) {
        print("⏹️ Audio recording stopped")
    }
    
    func audioRecordingManager(_ manager: AudioRecordingManager, didProduceAudioFrames frames: [Float]) {
        // Отправляем аудио фреймы в WhisperKit для транскрипции
        Task {
            do {
                _ = try await whisperManager.transcribe(audioFrames: frames)
            } catch {
                await handleError(error)
            }
        }
    }
    
    func audioRecordingManager(_ manager: AudioRecordingManager, didFailWith error: Error) {
        Task {
            await handleError(error)
        }
    }
}

// MARK: - ModelDownloadManager Delegate
extension RecognitionPresenter: ModelDownloadManagerDelegate {
    func modelDownloadManager(_ manager: ModelDownloadManager, didUpdateProgress progress: Double) {
        Task {
            await updateProgress(progress)
            await updateStatus(.downloadingModel(progress: progress))
        }
    }
    
    func modelDownloadManager(_ manager: ModelDownloadManager, didCompleteDownloadFor modelName: String) {
        Task {
            print("✅ Download completed for \(modelName)")
            // Обновляем статус на ready после завершения загрузки модели
            // Это важно, так как в initializeTranscription() мы только устанавливаем прогресс
            await updateStatus(.ready)
        }
    }
    
    func modelDownloadManager(_ manager: ModelDownloadManager, didFailDownloadFor modelName: String, with error: Error) {
        Task {
            await handleError(error)
        }
    }
}
