//
//  AudioRecordingManager.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation
import AVFoundation
import WhisperKit

/// Менеджер для записи аудио и передачи в WhisperKit
/// Manager for audio recording and passing to WhisperKit
class AudioRecordingManager {
    private var streamTranscriber: AudioStreamTranscriber?
    weak var delegate: TranscriptionDelegate?
    
    /// Настроить audio session
    /// Setup audio session
    func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Сначала деактивируем, если активен
        // First deactivate if active
        if audioSession.isOtherAudioPlaying {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🎤 Деактивировали другой аудио контент")
        }
        
        // Настраиваем категорию
        // Setup category
        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: [.allowBluetooth, .defaultToSpeaker]
        )
        
        // Активируем сессию
        // Activate session
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("🎤 Audio session настроен и активирован")
    }
    
    /// Начать запись
    /// Start recording
    func startRecording(
        whisperKit: WhisperKit,
        decodingOptions: DecodingOptions,
        delegate: TranscriptionDelegate
    ) async throws {
        print("🎤 AudioRecordingManager.startRecording вызван")
        
        // Проверяем, не запущена ли уже запись
        // Check if recording is already running
        if streamTranscriber != nil {
            print("⚠️ Запись уже запущена, останавливаем предыдущую...")
            await stopRecordingAsync()
            print("⚠️ Предыдущая запись остановлена")
        }
        
        // Сохраняем делегата
        // Store delegate
        self.delegate = delegate
        print("🎤 Делегат сохранен: \(delegate)")
        
        // Настроить audio session
        // Setup audio session
        print("🎤 Настраиваем audio session...")
        try setupAudioSession()
        
        // Создать AudioStreamTranscriber с правильными параметрами
        // Create AudioStreamTranscriber with correct parameters
        print("🎤 Создаем AudioStreamTranscriber...")
        self.streamTranscriber = AudioStreamTranscriber(
            audioEncoder: whisperKit.audioEncoder,
            featureExtractor: whisperKit.featureExtractor,
            segmentSeeker: whisperKit.segmentSeeker,
            textDecoder: whisperKit.textDecoder,
            tokenizer: whisperKit.tokenizer!,
            audioProcessor: whisperKit.audioProcessor,
            decodingOptions: decodingOptions,
            requiredSegmentsForConfirmation: 3,
            silenceThreshold: 0.3,
            compressionCheckWindow: 20,
            useVAD: true,
            stateChangeCallback: { [weak self] oldState, newState in
                self?.handleStateChange(oldState, newState)
            }
        )
        
        // Запускаем потоковую транскрипцию через правильный метод
        // Start streaming transcription through correct method
        print("🎤 Запускаем потоковую транскрипцию...")
        try await streamTranscriber?.startStreamTranscription()
        print("🎤 Потоковая транскрипция запущена успешно")
    }
    
    /// Остановить запись (синхронная версия)
    /// Stop recording (synchronous version)
    func stopRecording() {
        print("🛑 AudioRecordingManager.stopRecording вызван")
        
        // Останавливаем транскрипцию через правильный метод
        // Stop transcription through correct method
        Task {
            await streamTranscriber?.stopStreamTranscription()
            print("🛑 Потоковая транскрипция остановлена")
        }
        
        // Деактивируем audio session
        // Deactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🛑 Audio session деактивирован")
        } catch {
            print("❌ Ошибка при деактивации audio session: \(error)")
        }
        
        // Очищаем ссылки
        // Clear references
        streamTranscriber = nil
        delegate = nil
        print("🛑 Ресурсы очищены")
    }
    
    /// Остановить запись (асинхронная версия)
    /// Stop recording (asynchronous version)
    func stopRecordingAsync() async {
        print("🛑 AudioRecordingManager.stopRecordingAsync вызван")
        
        // Останавливаем транскрипцию через правильный метод
        // Stop transcription through correct method
        await streamTranscriber?.stopStreamTranscription()
        print("🛑 Потоковая транскрипция остановлена")
        
        // Деактивируем audio session
        // Deactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🛑 Audio session деактивирован")
        } catch {
            print("❌ Ошибка при деактивации audio session: \(error)")
        }
        
        // Очищаем ссылки
        // Clear references
        streamTranscriber = nil
        delegate = nil
        print("🛑 Ресурсы очищены")
    }
    
    
    /// Обработать изменения состояния транскрипции
    /// Handle transcription state changes
    private func handleStateChange(_ oldState: AudioStreamTranscriber.State, _ newState: AudioStreamTranscriber.State) {
        // Проверяем, действительно ли состояние изменилось
        // Check if state actually changed
        let stateChanged = oldState.isRecording != newState.isRecording
        let textChanged = oldState.currentText != newState.currentText
        let confirmedChanged = oldState.confirmedSegments.count != newState.confirmedSegments.count
        let unconfirmedChanged = oldState.unconfirmedSegments.count != newState.unconfirmedSegments.count
        
        // Логируем только при реальных изменениях
        // Log only on actual changes
        if stateChanged || textChanged || confirmedChanged || unconfirmedChanged {
            print("🎤 Состояние изменилось: \(oldState.isRecording) -> \(newState.isRecording)")
            print("🎤 Текущий текст: '\(newState.currentText)'")
            print("🎤 Подтвержденные сегменты: \(newState.confirmedSegments.count)")
            print("🎤 Неподтвержденные сегменты: \(newState.unconfirmedSegments.count)")
        }
        
        // Отправляем промежуточные результаты (текущий текст) только при изменении
        // Send intermediate results (current text) only when changed
        if !newState.currentText.isEmpty && textChanged {
            let filteredText = filterServiceTokens(newState.currentText)
            if !filteredText.isEmpty {
                print("📝 Отправляем промежуточный результат: '\(filteredText)'")
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.didReceiveIntermediateResult(filteredText)
                }
            }
        }
        
        // Отправляем подтвержденные сегменты как финальные результаты
        // Send confirmed segments as final results
        if !newState.confirmedSegments.isEmpty {
            let confirmedText = newState.confirmedSegments.map { $0.text }.joined(separator: " ")
            let filteredText = filterServiceTokens(confirmedText)
            if !filteredText.isEmpty {
                print("✅ Отправляем подтвержденный результат: '\(filteredText)'")
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.didReceiveFinalResult(filteredText)
                }
            }
        }
        
        // Отправляем неподтвержденные сегменты как промежуточные только при изменении
        // Send unconfirmed segments as intermediate only when changed
        if !newState.unconfirmedSegments.isEmpty && unconfirmedChanged {
            let unconfirmedText = newState.unconfirmedSegments.map { $0.text }.joined(separator: " ")
            let filteredText = filterServiceTokens(unconfirmedText)
            if !filteredText.isEmpty {
                print("⏳ Отправляем неподтвержденный результат: '\(filteredText)'")
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.didReceiveIntermediateResult(filteredText)
                }
            }
        }
    }
    
    /// Фильтровать служебные токены WhisperKit
    /// Filter WhisperKit service tokens
    private func filterServiceTokens(_ text: String) -> String {
        var filteredText = text
        
        // Удаляем служебные токены
        // Remove service tokens
        filteredText = filteredText.replacingOccurrences(of: "<|startoftranscript|>", with: "")
        filteredText = filteredText.replacingOccurrences(of: "<|endoftext|>", with: "")
        filteredText = filteredText.replacingOccurrences(of: "Waiting for speech...", with: "")
        filteredText = filteredText.replacingOccurrences(of: "Waiting for speech", with: "")
        
        // Удаляем временные метки в формате <|число.число|>
        // Remove timestamps in format <|number.number|>
        filteredText = filteredText.replacingOccurrences(of: "<|\\d+\\.\\d+\\|>", with: "", options: .regularExpression)
        
        // Удаляем пустые скобки и лишние пробелы
        // Remove empty brackets and extra spaces
        filteredText = filteredText.replacingOccurrences(of: "\\[\\s*\\]", with: "", options: .regularExpression)
        
        // Удаляем одиночные символы | и лишние пробелы
        // Remove single | characters and extra spaces
        filteredText = filteredText.replacingOccurrences(of: "\\|\\s*", with: "", options: .regularExpression)
        filteredText = filteredText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Удаляем служебные токены [end] и подобные
        // Remove service tokens like [end]
        filteredText = filteredText.replacingOccurrences(of: "\\[end\\]", with: "", options: .regularExpression)
        filteredText = filteredText.replacingOccurrences(of: "\\[\\s*end\\s*\\]", with: "", options: .regularExpression)
        
        // Удаляем лишние пробелы в начале и конце
        // Remove leading and trailing whitespace
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return filteredText
    }
}
