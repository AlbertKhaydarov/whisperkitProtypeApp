//
//  AudioRecordingManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation
import AVFoundation
import AudioKit


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
        
        // Конвертация в 16kHz PCM используя AudioKit
        print("🔄 Начинаем конвертацию аудио через AudioKit...")
        convertBufferToPCMWithAudioKit(buffer) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let convertedFrames):
                print("✅ Успешная конвертация через AudioKit: \(convertedFrames.count) фреймов")
                
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
            case .failure(let error):
                print("❌ Ошибка конвертации через AudioKit: \(error.localizedDescription)")
                print("⚠️ Используем запасной метод конвертации")
                
                // Пробуем запасной метод конвертации
                if let convertedFrames = self.convertBufferTo16kHzPCMFallback(buffer) {
                    print("✅ Запасной метод успешно конвертировал \(convertedFrames.count) фреймов")
                    DispatchQueue.main.async {
                        self.delegate?.audioRecordingManager(self, didProduceAudioFrames: convertedFrames)
                    }
                } else {
                    print("❌ Запасной метод также не смог конвертировать аудио")
                }
            }
        }
    }
    
    /// Конвертация буфера аудио в PCM 16kHz с использованием AudioKit
    /// Convert audio buffer to 16kHz PCM using AudioKit
    private func convertBufferToPCMWithAudioKit(_ buffer: AVAudioPCMBuffer, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
        print("🔄 Converting audio buffer using AudioKit...")
        
        // Сохраняем буфер во временный файл
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".wav")
        
        do {
            // Создаем временный файл из буфера
            try saveBufferToWavFile(buffer, url: tempURL)
            print("✅ Temporary WAV file created at: \(tempURL.path)")
            
            // Используем AudioKit для конвертации
            convertAudioFileToPCMArray(fileURL: tempURL) { result in
                // Удаляем временный файл
                try? FileManager.default.removeItem(at: tempURL)
                
                switch result {
                case .success(let frames):
                    print("✅ AudioKit conversion successful: \(frames.count) frames")
                    completionHandler(.success(frames))
                case .failure(let error):
                    print("❌ AudioKit conversion failed: \(error.localizedDescription)")
                    completionHandler(.failure(error))
                }
            }
        } catch {
            print("❌ Failed to save buffer to WAV: \(error.localizedDescription)")
            completionHandler(.failure(error))
        }
    }
    
    /// Сохранение буфера аудио в WAV файл
    /// Save audio buffer to WAV file
    private func saveBufferToWavFile(_ buffer: AVAudioPCMBuffer, url: URL) throws {
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: buffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try audioFile.write(from: buffer)
    }
    
    /// Конвертация аудио файла в массив PCM с помощью AudioKit
    /// Convert audio file to PCM array using AudioKit
    private func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 16
        options.channels = 1
        options.isInterleaved = false

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        print("🔧 AudioKit конвертация: настройки:")
        print("   - Входной файл: \(fileURL.lastPathComponent)")
        print("   - Выходной файл: \(tempURL.lastPathComponent)")
        print("   - Частота дискретизации: \(options.sampleRate) Hz")
        print("   - Битовая глубина: \(options.bitDepth) бит")
        print("   - Каналов: \(options.channels)")
        
        // Проверяем существование входного файла
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? NSNumber {
                    print("   - Размер входного файла: \(fileSize.intValue) байт")
                }
            } catch {
                print("⚠️ Не удалось получить атрибуты входного файла: \(error.localizedDescription)")
            }
        } else {
            print("❌ Входной файл не существует!")
            completionHandler(.failure(NSError(domain: "AudioKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Входной файл не существует"])))
            return
        }
        
        let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
        
        print("🔄 Начинаем конвертацию формата через AudioKit...")
        converter.start { error in
            if let error = error {
                print("❌ Ошибка конвертации AudioKit: \(error.localizedDescription)")
                completionHandler(.failure(error))
                return
            }

            do {
                let data = try Data(contentsOf: tempURL)
                print("✅ Размер конвертированного файла: \(data.count) байт")
                
                // Проверка правильности формата WAV
                if data.count < 44 {
                    print("❌ Файл слишком мал для WAV формата")
                    completionHandler(.failure(NSError(domain: "AudioKit", code: -2, userInfo: [NSLocalizedDescriptionKey: "Файл слишком мал для WAV формата"])))
                    return
                }
                
                // Проверка WAV заголовка
                let header = data.prefix(4)
                if let headerString = String(data: header, encoding: .ascii) {
                    print("🔍 WAV заголовок: \(headerString)")
                    if headerString != "RIFF" {
                        print("⚠️ Неожиданный WAV заголовок: \(headerString)")
                    }
                }
                
                // Пропускаем WAV заголовок (44 байта) и конвертируем в Float
                let floats = stride(from: 44, to: data.count, by: 2).map {
                    return data[$0..<$0 + 2].withUnsafeBytes {
                        let short = Int16(littleEndian: $0.load(as: Int16.self))
                        return max(-1.0, min(Float(short) / 32767.0, 1.0))
                    }
                }
                
                print("✅ Конвертировано в \(floats.count) PCM float значений")
                
                // Анализ конвертированных данных
                if !floats.isEmpty {
                    let samplesToPrint = min(5, floats.count)
                    var samplesInfo = "Первые \(samplesToPrint) конвертированных сэмплов: "
                    for i in 0..<samplesToPrint {
                        samplesInfo += String(format: "%.4f ", floats[i])
                    }
                    print("🎵 \(samplesInfo)")
                    
                    let maxAmplitude = floats.map { abs($0) }.max() ?? 0
                    print("📊 Максимальная амплитуда после конвертации: \(maxAmplitude)")
                    
                    if maxAmplitude < 0.01 {
                        print("⚠️ Низкая амплитуда после конвертации - возможно проблема с конвертацией")
                    }
                    
                    // Нормализация амплитуды для улучшения распознавания
                    if maxAmplitude > 0.01 {
                        let normalizedFloats = floats.map { $0 / maxAmplitude * 0.8 }
                        print("✅ Данные нормализованы до 80% от максимума")
                        try? FileManager.default.removeItem(at: tempURL)
                        completionHandler(.success(normalizedFloats))
                        return
                    }
                }
                
                try? FileManager.default.removeItem(at: tempURL)
                completionHandler(.success(floats))
                
            } catch {
                print("❌ Не удалось прочитать конвертированный файл: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: tempURL)
                completionHandler(.failure(error))
            }
        }
    }
    
    /// Запасной метод конвертации в случае проблем с AudioKit
    /// Fallback conversion method in case of AudioKit issues
    private func convertBufferTo16kHzPCMFallback(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let inputFormat = buffer.format
        let targetSampleRate: Double = 16000
        
        print("⚠️ Using fallback conversion method")
        print("🔊 Converting audio from \(inputFormat.sampleRate)Hz to \(targetSampleRate)Hz")
        
        // Если уже 16kHz, просто возвращаем данные
        if inputFormat.sampleRate == targetSampleRate {
            print("🔊 Audio already at target sample rate, no conversion needed")
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }
        
        // Улучшенный ресэмплинг для изменения sample rate
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
                // Защита от выхода за границы массива
                continue
            }
            
            let lowerValue = channelData[lowerIndex]
            let upperValue = channelData[upperIndex]
            let interpolatedValue = lowerValue + Float(fraction) * (upperValue - lowerValue)
            
            outputFrames.append(interpolatedValue)
        }
        
        // Нормализация амплитуды для улучшения распознавания
        let maxAmplitude = outputFrames.map { abs($0) }.max() ?? 1.0
        if maxAmplitude > 0.01 { // Проверка на тишину
            let normalizedFrames = outputFrames.map { $0 / maxAmplitude * 0.8 } // Нормализуем до 80% от максимума
            print("🔊 Audio normalized with max amplitude: \(maxAmplitude)")
            return normalizedFrames
        }
        
        print("🔊 Audio conversion complete, frames: \(outputFrames.count)")
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
