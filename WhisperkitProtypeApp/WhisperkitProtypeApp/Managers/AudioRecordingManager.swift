//
//  AudioRecordingManager.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation
import AVFoundation
import WhisperKit

/// Менеджер для записи аудио и передачи в WhisperKit (Thread-Safe версия)
/// Manager for audio recording and passing to WhisperKit (Thread-Safe version)
actor AudioRecordingManager {
    private var streamTranscriber: AudioStreamTranscriber?
    private weak var delegate: TranscriptionDelegate?
    
    // Удаляем NotificationCenter observers - заменяем на async/await
    // Remove NotificationCenter observers - replace with async/await
    private var isRecording = false
    private var audioSessionTask: Task<Void, Never>?

    // Защита от concurrent доступа к audio session
    // Protection against concurrent access to audio session
    private var isConfiguringAudioSession = false
    

    // Отслеживание состояния audio route для логирования только изменений
    // Track audio route state to log only changes
    private var lastAudioRoute: String?
    private var lastAudioSessionState: Bool = true

    // Кэшированные regex для оптимизации
    // Cached regex for optimization
    private static let timestampRegex = try? NSRegularExpression(
        pattern: "<\\|\\d+\\.\\d+\\|>|\\[\\s*\\]|\\[\\s*end\\s*\\]|\\|\\s*",
        options: []
    )

    private static let serviceTokensRegex = try? NSRegularExpression(
        pattern: "<\\|startoftranscript\\|>|<\\|endoftext\\|>|Waiting for speech\\.\\.\\.?|\\[end\\]",
        options: []
    )

    // MARK: - Audio Configuration Constants
    // Константы конфигурации аудио
    // Audio configuration constants

    /// Количество подтвержденных сегментов для получения более длинных фраз
    /// Number of confirmed segments required for longer phrases
    private static let requiredSegmentsForConfirmation = 3

    /// Порог тишины для определения конца фразы (0.0 - 1.0)
    /// Silence threshold for detecting end of phrase (0.0 - 1.0)
    private static let silenceThreshold: Float = 0.3

    /// Окно для проверки компрессии аудио (количество буферов)
    /// Window for audio compression check (number of buffers)
    private static let compressionCheckWindow = 20

    /// Размер IO буфера в секундах (100ms для баланса latency/quality)
    /// IO buffer size in seconds (100ms for latency/quality balance)
    private static let preferredIOBufferDuration: TimeInterval = 0.1

    /// Частота дискретизации для WhisperKit (16kHz требуется моделью)
    /// Sample rate for WhisperKit (16kHz required by model)
    private static let preferredSampleRate: Double = 16000

    /// Интервал мониторинга audio session в наносекундах (100ms)
    /// Audio session monitoring interval in nanoseconds (100ms)
    private static let monitoringInterval: UInt64 = 100_000_000

    init() {
        // Больше не нужны NotificationCenter observers
        // No longer need NotificationCenter observers
    }

    deinit {
        // Останавливаем все задачи при деинициализации
        // Stop all tasks on deinitialization
        audioSessionTask?.cancel()

        // Пытаемся деактивировать audio session синхронно
        // Try to deactivate audio session synchronously
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        print("🗑️ AudioRecordingManager деинициализирован")
    }

    /// Запустить мониторинг audio session с помощью async/await
    /// Start audio session monitoring using async/await
    private func startAudioSessionMonitoring() {
        audioSessionTask = Task { [weak self] in
            await self?.monitorAudioSession()
        }
    }
    
    /// Остановить мониторинг audio session
    /// Stop audio session monitoring
    private func stopAudioSessionMonitoring() {
        audioSessionTask?.cancel()
        audioSessionTask = nil
    }
    
    /// Мониторинг audio session с помощью async/await
    /// Monitor audio session using async/await
    private func monitorAudioSession() async {
        while !Task.isCancelled {
            do {
                // Проверяем состояние audio session каждые 100ms
                // Check audio session state every 100ms
                try await Task.sleep(nanoseconds: Self.monitoringInterval)
                
                // Используем централизованную проверку состояния
                // Use centralized state checking
                await checkAudioSessionState()
                
            } catch {
                // Task был отменен
                // Task was cancelled
                break
            }
        }
    }

    /// Проверить разрешение на микрофон
    /// Check microphone permission
    private func checkMicrophonePermission() async -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission

        switch status {
        case .granted:
            print("✅ Разрешение на микрофон получено")
            return true

        case .denied:
            print("❌ Разрешение на микрофон отклонено")
            return false

        case .undetermined:
            print("❓ Запрашиваем разрешение на микрофон...")
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print(granted ? "✅ Разрешение получено" : "❌ Разрешение отклонено")
                    continuation.resume(returning: granted)
                }
            }

        @unknown default:
            return false
        }
    }

    /// Настроить audio session для записи речи
    /// Setup audio session for speech recording
    nonisolated private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        // Настраиваем категорию для записи речи
        // Setup category for speech recording
        try audioSession.setCategory(
            .record,
            mode: .voiceChat, // Оптимизирован для голоса, включает шумоподавление
            options: [
                .allowBluetooth,
                .allowBluetoothA2DP
            ]
        )

        // Настраиваем предпочитаемые параметры
        // Setup preferred parameters
        try audioSession.setPreferredSampleRate(Self.preferredSampleRate)
        try audioSession.setPreferredIOBufferDuration(Self.preferredIOBufferDuration)

        // Активируем сессию
        // Activate session
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("🎤 Audio session настроен для распознавания речи")
    }

    /// Начать запись
    /// Start recording
    func startRecording(
        whisperKit: WhisperKit,
        decodingOptions: DecodingOptions,
        delegate: TranscriptionDelegate
    ) async throws {
        print("🎤 AudioRecordingManager.startRecording вызван")

        // Проверяем разрешение на микрофон
        // Check microphone permission
        let permission = await checkMicrophonePermission()
        guard permission else {
            let error = NSError(
                domain: "AudioRecordingManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]
            )
            print("❌ Нет разрешения на использование микрофона")
            await notifyDelegateError(error)
            throw error
        }

        // Проверяем, не запущена ли уже запись
        // Check if recording is already running
        if streamTranscriber != nil {
            print("⚠️ Запись уже запущена, останавливаем предыдущую...")
            await stopRecording()
            print("⚠️ Предыдущая запись остановлена")
        }

        // Проверяем и устанавливаем флаг конфигурации атомарно
        // Check and set configuration flag atomically
        guard !isConfiguringAudioSession else {
            let error = NSError(
                domain: "AudioRecordingManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Audio session is already being configured"]
            )
            print("❌ Audio session уже настраивается")
            await notifyDelegateError(error)
            throw error
        }
        
        isConfiguringAudioSession = true
        defer { isConfiguringAudioSession = false }

        // Сохраняем делегата
        // Store delegate
        self.delegate = delegate
        print("🎤 Делегат сохранен")

        // Настроить audio session
        // Setup audio session
        print("🎤 Настраиваем audio session...")

        do {
            try setupAudioSession()
        } catch {
            print("❌ Ошибка при настройке audio session: \(error)")
            await notifyDelegateError(error)
            throw error
        }
        
        // Запускаем мониторинг audio session
        // Start audio session monitoring
        startAudioSessionMonitoring()
        print("🎤 Мониторинг audio session запущен")

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
            requiredSegmentsForConfirmation: Self.requiredSegmentsForConfirmation,
            silenceThreshold: Self.silenceThreshold,
            compressionCheckWindow: Self.compressionCheckWindow,
            useVAD: true,
            stateChangeCallback: { [weak self] oldState, newState in
                Task { [weak self] in
                    await self?.handleStateChangeAsync(oldState, newState)
                }
            }
        )

        // Запускаем потоковую транскрипцию
        // Start streaming transcription
        print("🎤 Запускаем потоковую транскрипцию...")
        try await streamTranscriber?.startStreamTranscription()
        print("🎤 Потоковая транскрипция запущена успешно")
        
        // Устанавливаем флаг записи
        // Set recording flag
        isRecording = true

        // Уведомляем о начале записи
        // Notify about recording start
        await notifyDelegateProgress(0.0)
    }

    /// Остановить запись
    /// Stop recording
    func stopRecording() async {
        print("🛑 AudioRecordingManager.stopRecording вызван")

        // 1. Сбрасываем флаги состояния
        // Reset state flags
        isConfiguringAudioSession = false
        isRecording = false

        // 2. Останавливаем мониторинг
        // Stop monitoring
        stopAudioSessionMonitoring()
        print("🛑 Мониторинг audio session остановлен")

        // 3. Останавливаем транскрипцию
        // Stop transcription
        await streamTranscriber?.stopStreamTranscription()
        print("🛑 Потоковая транскрипция остановлена")

        // 4. Деактивируем audio session
        // Deactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🛑 Audio session деактивирован")
        } catch {
            print("❌ Ошибка при деактивации audio session: \(error)")
            await notifyDelegateError(error)
        }

        // 5. Очищаем ссылки
        // Clear references
        streamTranscriber = nil

        // Уведомляем о завершении записи
        // Notify about recording completion
        await notifyDelegateProgress(1.0)

        delegate = nil
        print("🛑 Ресурсы очищены")
    }

    /// Обработать изменения состояния транскрипции (thread-safe версия)
    /// Handle transcription state changes (thread-safe version)
    private func handleStateChangeAsync(_ oldState: AudioStreamTranscriber.State, _ newState: AudioStreamTranscriber.State) async {
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

        // Отправляем промежуточные результаты только при изменении
        // Send intermediate results only when changed
        if !newState.currentText.isEmpty && textChanged {
            let filteredText = filterServiceTokens(newState.currentText)
            if !filteredText.isEmpty {
                print("📝 Отправляем промежуточный результат: '\(filteredText)'")
                await notifyDelegateIntermediateResult(filteredText)
            }
        }

        // Отправляем только НОВЫЕ подтвержденные сегменты
        // Send only NEW confirmed segments
        if !newState.confirmedSegments.isEmpty && confirmedChanged {
            let newConfirmedCount = newState.confirmedSegments.count
            let oldConfirmedCount = oldState.confirmedSegments.count

            if newConfirmedCount > oldConfirmedCount {
                let newSegments = Array(newState.confirmedSegments.suffix(newConfirmedCount - oldConfirmedCount))
                for segment in newSegments {
                    let filteredText = filterServiceTokens(segment.text)
                    if !filteredText.isEmpty {
                        print("✅ Отправляем новый подтвержденный сегмент: '\(filteredText)'")
                        await notifyDelegateFinalResult(filteredText)
                    }
                }
            }
        }
    }

    /// Проверить состояние audio session (заменяет NotificationCenter)
    /// Check audio session state (replaces NotificationCenter)
    private func checkAudioSessionState() async {
        let audioSession = AVAudioSession.sharedInstance()

        // Проверяем прерывание записи напрямую
        // Check recording interruption directly
        if isRecording && streamTranscriber == nil {
            print("⚠️ Обнаружено прерывание записи (streamTranscriber == nil), останавливаем...")
            await stopRecording()
            return
        }

        // Проверяем, прервано ли аудио другим приложением
        // Check if audio is interrupted by another app
        if audioSession.isOtherAudioPlaying && isRecording {
            print("⚠️ Другое приложение воспроизводит аудио, останавливаем запись...")
            await stopRecording()
            return
        }

        // Проверяем доступность аудио маршрута - логируем только изменения
        // Check audio route availability - log only changes
        let currentRoute = audioSession.currentRoute
        let currentRouteDescription = currentRoute.outputs.first?.portName ?? "Unknown"
        let hasOutput = !currentRoute.outputs.isEmpty

        // Логируем только при изменении состояния
        // Log only on state change
        if hasOutput != lastAudioSessionState || currentRouteDescription != lastAudioRoute {
            if hasOutput {
                print("✅ Аудио устройство подключено: \(currentRouteDescription)")
            } else {
                print("⚠️ Аудио устройство отключено")
                if isRecording {
                    print("⚠️ Останавливаем запись из-за отключения устройства")
                    await stopRecording()
                }
            }
            lastAudioSessionState = hasOutput
            lastAudioRoute = currentRouteDescription
        } else if !hasOutput && isRecording {
            // Устройство уже было отключено, но запись все еще идет - останавливаем
            // Device was already disconnected, but recording is still active - stop it
            await stopRecording()
        }
    }

    /// Уведомить делегата об ошибке (async/await версия)
    /// Notify delegate about error (async/await version)
    private func notifyDelegateError(_ error: Error) async {
        await MainActor.run { [weak delegate] in
            delegate?.didEncounterError(error)
        }
    }
    
    /// Уведомить делегата о прогрессе (async/await версия)
    /// Notify delegate about progress (async/await version)
    private func notifyDelegateProgress(_ progress: Float) async {
        await MainActor.run { [weak delegate] in
            delegate?.didUpdateProgress(progress)
        }
    }
    
    /// Уведомить делегата о промежуточном результате (async/await версия)
    /// Notify delegate about intermediate result (async/await version)
    private func notifyDelegateIntermediateResult(_ text: String) async {
        await MainActor.run { [weak delegate] in
            delegate?.didReceiveIntermediateResult(text)
        }
    }
    
    /// Уведомить делегата о финальном результате (async/await версия)
    /// Notify delegate about final result (async/await version)
    private func notifyDelegateFinalResult(_ text: String) async {
        await MainActor.run { [weak delegate] in
            delegate?.didReceiveFinalResult(text)
        }
    }

    /// Фильтровать служебные токены WhisperKit (оптимизированная версия)
    /// Filter WhisperKit service tokens (optimized version)
    private func filterServiceTokens(_ text: String) -> String {
        guard !text.isEmpty, text.count > 5 else { return text }

        var filteredText = text

        // Удаляем служебные токены одной regex операцией для эффективности
        // Remove service tokens with one regex operation for efficiency
        if let serviceRegex = Self.serviceTokensRegex {
            let range = NSRange(filteredText.startIndex..<filteredText.endIndex, in: filteredText)
            filteredText = serviceRegex.stringByReplacingMatches(
                in: filteredText,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Удаляем временные метки и служебные символы одним regex
        // Remove timestamps and service characters with one regex
        if let regex = Self.timestampRegex {
            let range = NSRange(filteredText.startIndex..<filteredText.endIndex, in: filteredText)
            filteredText = regex.stringByReplacingMatches(
                in: filteredText,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Удаляем множественные пробелы более эффективно
        // Remove multiple spaces more efficiently
        filteredText = filteredText.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return filteredText
    }
}
