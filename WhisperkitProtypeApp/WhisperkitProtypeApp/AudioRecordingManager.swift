//
//  AudioRecordingManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import AVFoundation
import WhisperKit


// MARK: - AudioRecordingManager Delegate
protocol AudioRecordingManagerDelegate: AnyObject {
    func audioRecordingManager(_ manager: AudioRecordingManager, didStartRecording: Bool)
    func audioRecordingManager(_ manager: AudioRecordingManager, didStopRecording: Bool)
    func audioRecordingManager(_ manager: AudioRecordingManager, didProduceAudioFrames frames: [Float])
    func audioRecordingManager(_ manager: AudioRecordingManager, didFailWith error: Error)
    func audioRecordingManager(_ manager: AudioRecordingManager, didTranscribeFile filePath: String)
}

/// Менеджер для записи аудио и конвертации в формат 16kHz PCM
/// Manager for audio recording and conversion to 16kHz PCM format
class AudioRecordingManager: NSObject {
    
    // MARK: - Properties
    private let audioEngine: AVAudioEngine
    private let audioConverter: AVAudioConverter?
    private var isRecording = false
    
    // MARK: - Debug Properties
    private var debugAudioFile: AVAudioFile?
    private var debugAudioBuffer: [Float] = []
    
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
        
        #else
        // На macOS настройка аудио сессии не требуется
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
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Теперь устанавливаем tap после запуска движка
        setupAudioTap()
        
        // Создаем отладочный аудио файл
        do {
            try await setupDebugAudioFile()
        } catch {
            print("❌ Ошибка создания отладочного файла: \(error)")
        }
        
        isRecording = true
        
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
        
        // Завершаем отладочную запись в файл
        await finishDebugAudioFile()
        
        isRecording = false
        
        
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
    }
    
    /// Возобновление записи
    /// Resume recording
    func resumeRecording() async throws {
        guard isRecording else {
            throw AudioRecordingError.notRecording
        }
        
        try audioEngine.start()
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
        
    }
    
    private func setupAudioTap() {
        let inputNode = audioEngine.inputNode
        
        // Настраиваем формат для tap
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Устанавливаем tap с правильным форматом
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Конвертируем аудио в нужный формат
        if let convertedFrames = convertBufferTo16kHzPCM(buffer) {
            // Записываем отладочные данные в файл
            writeDebugAudioToFile(convertedFrames)
            
            // Отправляем фреймы через delegate
            DispatchQueue.main.async {
                self.delegate?.audioRecordingManager(self, didProduceAudioFrames: convertedFrames)
            }
        }
    }
    
    /// Конвертация буфера аудио в PCM 16kHz
    /// Convert audio buffer to 16kHz PCM
    private func convertBufferTo16kHzPCM(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let inputFormat = buffer.format
        let targetSampleRate: Double = 16000
        
        
        // Если уже 16kHz, просто возвращаем данные
        if inputFormat.sampleRate == targetSampleRate {
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }
        
        // Ресэмплинг для изменения sample rate
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
            return normalizedFrames
        } else {
            let amplifiedFrames = outputFrames.map { $0 * 50.0 }
            return amplifiedFrames
        }
    }
    
    // MARK: - Debug Audio File Methods
    
    /// Настройка отладочного аудио файла для записи
    /// Setup debug audio file for recording
    private func setupDebugAudioFile() async throws {
        // Создаем директорию для отладочных файлов
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let debugDirectory = documentsPath.appendingPathComponent("DebugAudio")
        
        // Создаем директорию если не существует
        try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Создаем уникальное имя файла с временной меткой
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "debug_audio_\(timestamp).wav"
        let fileURL = debugDirectory.appendingPathComponent(fileName)
        
        // Настраиваем формат для записи (16kHz, 16-bit, mono)
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        
        // Создаем аудио файл
        debugAudioFile = try AVAudioFile(forWriting: fileURL, settings: audioFormat.settings)
        debugAudioBuffer.removeAll()
        
        print("🎵 Отладочный файл создан: \(fileURL.lastPathComponent)")
    }
    
    /// Запись отладочных аудио данных в файл
    /// Write debug audio data to file
    private func writeDebugAudioToFile(_ frames: [Float]) {
        guard let audioFile = debugAudioFile else { 
            return 
        }
        
        // Логируем информацию о фреймах
        if frames.count > 0 {
            let maxAmplitude = frames.map { abs($0) }.max() ?? 0
            print("🎵 Записываем \(frames.count) фреймов, макс. амплитуда: \(maxAmplitude)")
        }
        
        // Добавляем фреймы в буфер
        debugAudioBuffer.append(contentsOf: frames)
        
        // Записываем в файл каждые 1000 фреймов (примерно 62.5ms при 16kHz)
        if debugAudioBuffer.count >= 1000 {
            let framesToWrite = Array(debugAudioBuffer.prefix(1000))
            debugAudioBuffer.removeFirst(1000)
            
            // Создаем PCM буфер для записи
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(framesToWrite.count))!
            buffer.frameLength = AVAudioFrameCount(framesToWrite.count)
            
            // Копируем данные в буфер
            if let channelData = buffer.floatChannelData?[0] {
                for (index, sample) in framesToWrite.enumerated() {
                    channelData[index] = sample
                }
            }
            
            // Записываем в файл
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("❌ Ошибка записи в отладочный файл: \(error)")
            }
        }
    }
    
    /// Завершение записи отладочного аудио файла
    /// Finish debug audio file recording
    private func finishDebugAudioFile() async {
        guard let audioFile = debugAudioFile else { return }
        
        print("🔄 Завершаем запись отладочного файла. Осталось фреймов: \(debugAudioBuffer.count)")
        
        // Записываем оставшиеся данные
        if !debugAudioBuffer.isEmpty {
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(debugAudioBuffer.count))!
            buffer.frameLength = AVAudioFrameCount(debugAudioBuffer.count)
            
            if let channelData = buffer.floatChannelData?[0] {
                for (index, sample) in debugAudioBuffer.enumerated() {
                    channelData[index] = sample
                }
            }
            
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("❌ Ошибка записи оставшихся данных: \(error)")
            }
        }
        
        // Закрываем файл
        let fileURL = audioFile.url
        debugAudioFile = nil
        debugAudioBuffer.removeAll()
        
        print("✅ Отладочный файл сохранен: \(fileURL.lastPathComponent)")
        
        // Отправляем файл на распознавание через WhisperKit
        await transcribeAudioFile(fileURL)
    }
    
    /// Транскрипция аудио файла через WhisperKit
    /// Transcribe audio file using WhisperKit
    private func transcribeAudioFile(_ fileURL: URL) async {
        print("🎵 Начинаем файловую транскрипцию: \(fileURL.lastPathComponent)")
        
        // Проверяем размер файла
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = fileAttributes[.size] as? NSNumber {
                print("📁 Размер файла: \(fileSize.intValue) байт")
                if fileSize.intValue < 1000 {
                    print("⚠️ Файл слишком маленький! Возможно, аудио не записалось.")
                }
            }
        } catch {
            print("⚠️ Не удалось получить размер файла: \(error)")
        }
        
        do {
            // Используем тот же WhisperKit, что и для потокового распознавания
            // Передаем путь к файлу через delegate для транскрипции
            print("🔄 Отправляем файл на транскрипцию через RecognitionPresenter...")
            
            // Отправляем файл через delegate для транскрипции
            await MainActor.run {
                self.delegate?.audioRecordingManager(self, didTranscribeFile: fileURL.path)
            }
            return
            
        } catch {
            print("❌ Ошибка при отправке файла на транскрипцию: \(error.localizedDescription)")
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
