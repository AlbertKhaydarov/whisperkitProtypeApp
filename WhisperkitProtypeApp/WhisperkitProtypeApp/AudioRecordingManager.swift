//
//  AudioRecordingManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import AVFoundation


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
        print("🔄 Получен аудио буфер: \(buffer.frameLength) фреймов, формат: \(buffer.format)")
        
        // Анализ входящего буфера для отладки
        if let channelData = buffer.floatChannelData?[0] {
            let frameCount = Int(buffer.frameLength)
            let samplesToPrint = min(5, frameCount)
            
            var samplesInfo = "Первые \(samplesToPrint) сэмплов: "
            for i in 0..<samplesToPrint {
                samplesInfo += String(format: "%.4f ", channelData[i])
            }
            print("🎵 \(samplesInfo)")
            
            // Анализ амплитуды для определения наличия речи
            let maxAmplitude = (0..<frameCount).map { abs(channelData[$0]) }.max() ?? 0
            print("📊 Максимальная амплитуда: \(maxAmplitude)")
            
            if maxAmplitude < 0.01 {
                print("⚠️ Низкая амплитуда - возможно тишина или шум")
            }
        }
        
        // Конвертация в 16kHz PCM используя стандартную конвертацию AVFoundation
        print("🔄 Начинаем конвертацию аудио...")
        
        if let convertedFrames = convertBufferTo16kHzPCM(buffer) {
            print("✅ Успешная конвертация: \(convertedFrames.count) фреймов")
            
            // Анализ конвертированных данных
            if !convertedFrames.isEmpty {
                let samplesToPrint = min(5, convertedFrames.count)
                var samplesInfo = "Первые \(samplesToPrint) конвертированных сэмплов: "
                for i in 0..<samplesToPrint {
                    samplesInfo += String(format: "%.4f ", convertedFrames[i])
                }
                print("🎵 \(samplesInfo)")
                
                let maxAmplitude = convertedFrames.map { abs($0) }.max() ?? 0
                print("📊 Максимальная амплитуда после конвертации: \(maxAmplitude)")
            }
            
            // Отправляем фреймы через delegate
            DispatchQueue.main.async {
                print("📤 Отправляем \(convertedFrames.count) фреймов для распознавания")
                self.delegate?.audioRecordingManager(self, didProduceAudioFrames: convertedFrames)
            }
        } else {
            print("❌ Не удалось конвертировать аудио")
        }
    }
    
    /// Конвертация буфера аудио в PCM 16kHz
    /// Convert audio buffer to 16kHz PCM
    private func convertBufferTo16kHzPCM(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let inputFormat = buffer.format
        let targetSampleRate: Double = 16000
        
        print("🔊 Converting audio from \(inputFormat.sampleRate)Hz to \(targetSampleRate)Hz")
        
        // Если уже 16kHz, просто возвращаем данные
        if inputFormat.sampleRate == targetSampleRate {
            print("🔊 Audio already at target sample rate, no conversion needed")
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }
        
        // Ресэмплинг для изменения sample rate
        let ratio = targetSampleRate / inputFormat.sampleRate
        let outputFrameCount = Int(Double(frameCount) * ratio)
        
        print("🔊 Resampling ratio: \(ratio), output frame count: \(outputFrameCount)")
        
        var outputFrames: [Float] = []
        outputFrames.reserveCapacity(outputFrameCount)
        
        // Линейная интерполяция для ресэмплинга
        for i in 0..<outputFrameCount {
            let sourceIndex = Double(i) / ratio
            let lowerIndex = Int(sourceIndex)
            let upperIndex = min(lowerIndex + 1, frameCount - 1)
            let fraction = sourceIndex - Double(lowerIndex)
            
            if lowerIndex >= frameCount || upperIndex >= frameCount {
                continue
            }
            
            let lowerValue = channelData[lowerIndex]
            let upperValue = channelData[upperIndex]
            let interpolatedValue = lowerValue + Float(fraction) * (upperValue - lowerValue)
            
            outputFrames.append(interpolatedValue)
        }
        
        // Нормализация амплитуды для улучшения распознавания
        let maxAmplitude = outputFrames.map { abs($0) }.max() ?? 1.0
        if maxAmplitude > 0.01 {
            let normalizedFrames = outputFrames.map { $0 / maxAmplitude * 0.9 }
            print("🔊 Audio normalized with max amplitude: \(maxAmplitude)")
            return normalizedFrames
        } else {
            print("⚠️ Very low amplitude, amplifying signal")
            let amplifiedFrames = outputFrames.map { $0 * 50.0 }
            return amplifiedFrames
        }
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
