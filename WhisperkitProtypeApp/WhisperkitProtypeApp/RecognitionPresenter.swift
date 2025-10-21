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
    private var selectedModel: String = "tiny.en" // По умолчанию tiny.en (самая быстрая)
    
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
        guard ["tiny.en", "base.en", "small.en"].contains(modelName) else {
            print("❌ Unsupported model: \(modelName)")
            return
        }
        selectedModel = modelName
        print("📱 Model selected: \(modelName)")
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
            // Обновляем статус
            await updateStatus(.loading)
            
            // Инициализируем WhisperKit
            try await whisperManager.initialize()
            
            // Загружаем выбранную модель
            let modelURL = try await downloadManager.downloadModel(selectedModel)
            try await whisperManager.loadModel(from: modelURL)
            
            // Прогреваем модель
            try await whisperManager.warmup()
            
            // Создаем новую сессию транскрипции
            try await whisperManager.startNewSession()
            
            // Система готова
            print("🎯 Setting status to READY for model: \(selectedModel)")
            await updateStatus(.ready)
            print("✅ Transcription system ready for model: \(selectedModel)")
            
        } catch {
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
            print("⚠️ Not transcribing")
            return
        }
        
        do {
            // Останавливаем запись
            try await audioManager.stopRecording()
            
            // Финализируем транскрипцию
            await updateStatus(.processing)
            let finalSegments = try await whisperManager.finalize()
            
            // Обновляем финальный текст
            let finalText = finalSegments.map(\.text).joined(separator: " ")
            currentTranscription = finalText
            
            await updateTranscription(finalText)
            await updateStatus(.ready)
            
            isTranscribing = false
            
            print("⏹️ Transcription stopped")
            
        } catch {
            await handleError(error)
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
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            delegate?.recognitionPresenter(self, didEncounterError: error)
        }
    }
}

// MARK: - WhisperKitManager Delegate
extension RecognitionPresenter: WhisperKitManagerDelegate {
    func whisperKitManager(_ manager: WhisperKitManager, didUpdateWarmupProgress progress: Double) {
        Task {
            await updateProgress(progress)
            // Обновляем статус только если прогресс меньше 0.9 (90%)
            // После 90% статус будет установлен в .ready в initializeTranscription()
            if progress < 0.9 {
                await updateStatus(.warmingModel(progress: progress))
            }
        }
    }
    
    func whisperKitManager(_ manager: WhisperKitManager, didReceiveSegments segments: [WhisperSegment]) {
        Task {
            let newText = segments.map { $0.text }.joined(separator: " ")
            currentTranscription += newText
            await updateTranscription(currentTranscription)
        }
    }
    
    func whisperKitManager(_ manager: WhisperKitManager, didCompleteWithSegments segments: [WhisperSegment]) {
        Task {
            let finalText = segments.map { $0.text }.joined(separator: " ")
            currentTranscription = finalText
            await updateTranscription(currentTranscription)
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
    
    func modelDownloadManager(_ manager: ModelDownloadManager, didCompleteDownloadFor modelName: String, at localURL: URL) {
        Task {
            print("✅ Download completed for \(modelName)")
            // Не обновляем статус здесь, так как это делается в initializeTranscription()
            // Status update is handled in initializeTranscription()
        }
    }
    
    func modelDownloadManager(_ manager: ModelDownloadManager, didFailDownloadFor modelName: String, with error: Error) {
        Task {
            await handleError(error)
        }
    }
}
