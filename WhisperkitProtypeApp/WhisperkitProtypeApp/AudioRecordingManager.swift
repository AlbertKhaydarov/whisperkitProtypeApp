//
//  AudioRecordingManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import AVFoundation
import SwiftWhisper


// MARK: - AudioRecordingManager Delegate
protocol AudioRecordingManagerDelegate: AnyObject {
    func audioRecordingManager(_ manager: AudioRecordingManager, didStartRecording: Bool)
    func audioRecordingManager(_ manager: AudioRecordingManager, didStopRecording: Bool)
    func audioRecordingManager(_ manager: AudioRecordingManager, didProduceAudioFrames frames: [Float])
    func audioRecordingManager(_ manager: AudioRecordingManager, didFailWith error: Error)
}

/// Менеджер для записи аудио и конвертации в формат 16kHz PCM
/// Manager for audio recording and conversion to 16kHz PCM format
class AudioRecordingManager: NSObject {
    
    // MARK: - Properties
    private let audioEngine: AVAudioEngine
    private let audioConverter: AVAudioConverter?
    private var isRecording = false
    
    // MARK: - Delegate
    weak var delegate: AudioRecordingManagerDelegate?
    
    // MARK: - Initialization
    override init() {
        self.audioEngine = AVAudioEngine()
        self.audioConverter = nil
        super.init()
        // Не настраиваем движок в init, делаем это при старте записи
    }
    
    // MARK: - Public Methods
    
    /// Запрос разрешения на использование микрофона
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        // На macOS разрешение не требуется
        return true
        #endif
    }
    
    /// Настройка аудио сессии
    /// Configure audio session
    func configureAudioSession() async throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        
        print("🎤 Audio session configured successfully")
        #else
        // На macOS настройка аудио сессии не требуется
        print("🎤 Audio session configured for macOS")
        #endif
    }
    
    /// Начало записи
    /// Start recording
    func startRecording() async throws {
        guard !isRecording else {
            print("⚠️ Already recording")
            return
        }
        
        // Проверяем разрешение на микрофон
        guard await requestMicrophonePermission() else {
            throw AudioRecordingError.microphonePermissionDenied
        }
        
        // Настраиваем аудио сессию
        try await configureAudioSession()
        
        // Полностью останавливаем движок
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Настраиваем аудио движок БЕЗ tap
        setupAudioEngineWithoutTap()
        
        // Запускаем движок сначала
        do {
            try audioEngine.start()
            print("🎤 Audio engine started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Теперь устанавливаем tap после запуска движка
        setupAudioTap()
        
        isRecording = true
        print("🎤 Recording started")
        
        await MainActor.run {
            delegate?.audioRecordingManager(self, didStartRecording: true)
        }
    }
    
    /// Остановка записи
    /// Stop recording
    func stopRecording() async throws {
        guard isRecording else {
            print("⚠️ Not recording")
            return
        }
        
        // Удаляем tap с входного узла
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        // Останавливаем аудио движок
        audioEngine.stop()
        
        isRecording = false
        
        print("⏹️ Recording stopped")
        
        await MainActor.run {
            delegate?.audioRecordingManager(self, didStopRecording: true)
        }
    }
    
    /// Пауза записи
    /// Pause recording
    func pauseRecording() async throws {
        guard isRecording else {
            throw AudioRecordingError.notRecording
        }
        
        audioEngine.pause()
        print("⏸️ Recording paused")
    }
    
    /// Возобновление записи
    /// Resume recording
    func resumeRecording() async throws {
        guard isRecording else {
            throw AudioRecordingError.notRecording
        }
        
        try audioEngine.start()
        print("▶️ Recording resumed")
    }
    
    /// Проверка статуса записи
    /// Check recording status
    func isCurrentlyRecording() -> Bool {
        return isRecording
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngineWithoutTap() {
        // Просто подготавливаем движок без tap
        let inputNode = audioEngine.inputNode
        
        // Удаляем все существующие tap
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        print("🎤 Audio engine prepared (without tap)")
    }
    
    private func setupAudioTap() {
        let inputNode = audioEngine.inputNode
        
        // Настраиваем формат для tap
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        
        // Устанавливаем tap с правильным форматом
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        print("🎤 Audio tap installed successfully")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Простая конвертация в 16kHz PCM используя AudioKit подход
        guard let convertedFrames = convertBufferTo16kHzPCM(buffer) else {
            print("❌ Failed to convert audio buffer")
            return
        }
        
        // Отправляем фреймы через delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.audioRecordingManager(self!, didProduceAudioFrames: convertedFrames)
        }
    }
    
    private func convertBufferTo16kHzPCM(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let inputFormat = buffer.format
        let targetSampleRate: Double = 16000
        
        // Если уже 16kHz, просто возвращаем данные
        if inputFormat.sampleRate == targetSampleRate {
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }
        
        // Простая ресэмплинг для изменения sample rate
        let ratio = targetSampleRate / inputFormat.sampleRate
        let outputFrameCount = Int(Double(frameCount) * ratio)
        
        var outputFrames: [Float] = []
        outputFrames.reserveCapacity(outputFrameCount)
        
        // Линейная интерполяция для ресэмплинга
        for i in 0..<outputFrameCount {
            let sourceIndex = Double(i) / ratio
            let lowerIndex = Int(sourceIndex)
            let upperIndex = min(lowerIndex + 1, frameCount - 1)
            let fraction = sourceIndex - Double(lowerIndex)
            
            let lowerValue = channelData[lowerIndex]
            let upperValue = channelData[upperIndex]
            let interpolatedValue = lowerValue + Float(fraction) * (upperValue - lowerValue)
            
            outputFrames.append(interpolatedValue)
        }
        
        return outputFrames
    }
}

// MARK: - Audio Recording Errors
enum AudioRecordingError: Error, LocalizedError {
    case microphonePermissionDenied
    case audioSessionConfigurationFailed
    case audioEngineSetupFailed
    case notRecording
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Разрешение на использование микрофона не предоставлено"
        case .audioSessionConfigurationFailed:
            return "Ошибка настройки аудио сессии"
        case .audioEngineSetupFailed:
            return "Ошибка настройки аудио движка"
        case .notRecording:
            return "Запись не активна"
        case .recordingFailed:
            return "Ошибка записи аудио"
        }
    }
}
