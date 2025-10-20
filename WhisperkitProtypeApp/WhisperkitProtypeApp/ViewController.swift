//
//  ViewController.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import UIKit
import AVFoundation

/// Main view controller for speech transcription
/// Основной контроллер для транскрипции речи
class ViewController: UIViewController {
    
    // MARK: - UI Components
    private let intermediateLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "Tap the button and start speaking..."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let finalTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 18, weight: .medium)
        textView.textColor = .label
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Recording", for: .normal)
        button.setTitle("Stop Recording", for: .selected)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "Ready"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = 0.0
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Properties
    private let whisperManager = WhisperKitManager.shared
    private let errorHandler = ErrorHandler()
    private let languageDetector = LanguageDetector()
    private var isRecording = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Voice Transcription"
        view.backgroundColor = .systemBackground
        
        setupUI()
        setupConstraints()
        
        // Инициализировать WhisperKit
        initializeWhisperKit()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.addSubview(statusLabel)
        view.addSubview(intermediateLabel)
        view.addSubview(finalTextView)
        view.addSubview(recordButton)
        view.addSubview(progressView)
        view.addSubview(activityIndicator)
        
        recordButton.addTarget(
            self,
            action: #selector(handleRecordButtonTap),
            for: .touchUpInside
        )
        
        errorHandler.viewController = self
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Status label
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Intermediate label
            intermediateLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 30),
            intermediateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            intermediateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            intermediateLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Final text view
            finalTextView.topAnchor.constraint(equalTo: intermediateLabel.bottomAnchor, constant: 20),
            finalTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            finalTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            finalTextView.bottomAnchor.constraint(equalTo: recordButton.topAnchor, constant: -20),
            
            // Record button
            recordButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            recordButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            recordButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func handleRecordButtonTap() {
        print("🎤 handleRecordButtonTap вызван, isRecording: \(isRecording)")
        
        if isRecording {
            print("🎤 Запись уже идет, останавливаем...")
            stopRecording()
        } else {
            print("🎤 Начинаем запись...")
            startRecording()
        }
    }
    
    private func initializeWhisperKit() {
        activityIndicator.startAnimating()
        statusLabel.text = "Initializing..."
        recordButton.isEnabled = false
        
        Task {
            do {
                try await whisperManager.initialize()
                
                await MainActor.run {
                    activityIndicator.stopAnimating()
                    statusLabel.text = "Ready"
                    recordButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    activityIndicator.stopAnimating()
                    statusLabel.text = "Initialization failed"
                    errorHandler.handle(error)
                }
            }
        }
    }
    
    private func startRecording() {
        print("🎤 startRecording вызван")
        
        // Сначала обновляем UI
        print("🎤 Обновляем UI для записи...")
        isRecording = true
        recordButton.isSelected = true
        recordButton.backgroundColor = .systemRed
        statusLabel.text = "Recording..."
        statusLabel.textColor = .systemRed
        
        // Очищаем промежуточный текст при новой записи
        intermediateLabel.text = ""
        intermediateLabel.alpha = 1.0
        
        // Принудительно обновляем кнопку
        recordButton.setNeedsLayout()
        recordButton.layoutIfNeeded()
        
        print("🎤 UI обновлен: isRecording=\(isRecording), buttonTitle=\(recordButton.title(for: .selected) ?? "nil")")
        print("🎤 Кнопка isSelected: \(recordButton.isSelected)")
        
        // Затем запускаем транскрипцию в фоне
        Task {
            do {
                print("🎤 Проверяем разрешение на микрофон...")
                // Проверить разрешение на микрофон
                try await checkMicrophonePermission()
                
                print("🎤 Начинаем транскрипцию...")
                // Начать транскрипцию
                try await whisperManager.startRealtimeTranscription(delegate: self)
                
                print("🎤 Запись начата успешно")
            } catch {
                print("🎤 Ошибка при начале записи: \(error)")
                await MainActor.run {
                    // Сбрасываем UI при ошибке
                    isRecording = false
                    recordButton.isSelected = false
                    recordButton.backgroundColor = .systemBlue
                    statusLabel.text = "Ready"
                    statusLabel.textColor = .secondaryLabel
                    errorHandler.handle(error)
                }
            }
        }
    }
    
    private func stopRecording() {
        print("🛑 stopRecording вызван")
        
        // Сначала обновляем UI
        print("🛑 Обновляем UI для остановки...")
        isRecording = false
        recordButton.isSelected = false
        recordButton.backgroundColor = .systemBlue
        statusLabel.text = "Ready"
        statusLabel.textColor = .secondaryLabel
        intermediateLabel.text = ""
        
        // Принудительно обновляем кнопку
        recordButton.setNeedsLayout()
        recordButton.layoutIfNeeded()
        
        print("🛑 UI обновлен: isRecording=\(isRecording), buttonTitle=\(recordButton.title(for: .normal) ?? "nil")")
        print("🛑 Кнопка isSelected: \(recordButton.isSelected)")
        
        // Затем останавливаем транскрипцию в фоне
        Task {
            print("🛑 Останавливаем транскрипцию...")
            await whisperManager.stopTranscription()
            print("🛑 Запись остановлена успешно")
        }
    }
    
    private func checkMicrophonePermission() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            return
        case .denied:
            throw WhisperKitError.microphonePermissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                throw WhisperKitError.microphonePermissionDenied
            }
        @unknown default:
            throw WhisperKitError.unknown(underlying: NSError(domain: "Permission", code: -1))
        }
    }
}

// MARK: - TranscriptionDelegate
extension ViewController: TranscriptionDelegate {
    func didReceiveIntermediateResult(_ text: String) {
        print("📱 didReceiveIntermediateResult вызван с текстом: '\(text)'")
        
        // Обновляем промежуточный результат в finalTextView
        let currentText = finalTextView.text ?? ""
        
        if currentText.isEmpty {
            // Если текст пустой, создаем новую запись с временной меткой
            let timestamp = Date().formatted(date: .omitted, time: .shortened)
            finalTextView.text = "[\(timestamp)] \(text)..."
        } else {
            // Если текст уже есть, обновляем последнюю строку
            var lines = currentText.components(separatedBy: .newlines)
            let lastLineIndex = lines.count - 1
            
            if lastLineIndex >= 0 {
                // Проверяем, является ли последняя строка промежуточным результатом
                let lastLine = lines[lastLineIndex]
                if lastLine.contains("...") {
                    // Заменяем последнюю строку новым промежуточным результатом
                    let timestamp = lastLine.components(separatedBy: "] ").first ?? ""
                    lines[lastLineIndex] = "\(timestamp)] \(text)..."
                } else {
                    // Добавляем новую строку с промежуточным результатом
                    let timestamp = Date().formatted(date: .omitted, time: .shortened)
                    lines.append("[\(timestamp)] \(text)...")
                }
                finalTextView.text = lines.joined(separator: "\n")
            }
        }
        
        // Показываем статус в intermediateLabel
        intermediateLabel.text = "Распознавание..."
        intermediateLabel.alpha = 0.7
        
        // Scroll to bottom
        let bottom = NSRange(location: finalTextView.text.count - 1, length: 1)
        finalTextView.scrollRangeToVisible(bottom)
    }
    
    func didReceiveFinalResult(_ text: String) {
        print("📱 didReceiveFinalResult вызван с текстом: '\(text)'")
        
        // Заменяем последний промежуточный результат на финальный
        let currentText = finalTextView.text ?? ""
        
        if currentText.isEmpty {
            // Если текст пустой, создаем новую запись с временной меткой
            let timestamp = Date().formatted(date: .omitted, time: .shortened)
            finalTextView.text = "[\(timestamp)] \(text)"
        } else {
            // Заменяем последнюю строку с промежуточным результатом на финальный
            var lines = currentText.components(separatedBy: .newlines)
            let lastLineIndex = lines.count - 1
            
            if lastLineIndex >= 0 {
                let lastLine = lines[lastLineIndex]
                if lastLine.contains("...") {
                    // Заменяем промежуточный результат на финальный
                    let timestamp = lastLine.components(separatedBy: "] ").first ?? ""
                    lines[lastLineIndex] = "\(timestamp)] \(text)"
                } else {
                    // Добавляем новую строку с финальным результатом
                    let timestamp = Date().formatted(date: .omitted, time: .shortened)
                    lines.append("[\(timestamp)] \(text)")
                }
                finalTextView.text = lines.joined(separator: "\n")
            }
        }
        
        intermediateLabel.text = ""
        
        // Scroll to bottom
        let bottom = NSRange(location: finalTextView.text.count - 1, length: 1)
        finalTextView.scrollRangeToVisible(bottom)
    }
    
    func didUpdateProgress(_ progress: Float) {
        print("📱 didUpdateProgress вызван с прогрессом: \(progress)")
        progressView.progress = progress
    }
    
    func didEncounterError(_ error: Error) {
        print("📱 didEncounterError вызван с ошибкой: \(error)")
        errorHandler.handle(error)
        stopRecording()
    }
    
    func didDetectNonEnglishSpeech() {
        print("📱 didDetectNonEnglishSpeech вызван")
        showLanguageWarning()
    }
    
    private func showLanguageWarning() {
        let alert = UIAlertController(
            title: "English Only",
            message: "Please speak English. This model is optimized for English language only.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

