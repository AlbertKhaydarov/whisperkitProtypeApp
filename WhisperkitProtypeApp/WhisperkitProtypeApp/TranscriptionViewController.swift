//
//  TranscriptionViewController.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import UIKit

/// Главный экран приложения для транскрипции речи
/// Main screen for speech transcription
class TranscriptionViewController: UIViewController {
    
    // MARK: - UI Components
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Инициализация..."
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        progressView.isHidden = true
        return progressView
    }()
    
    private let startStopButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("🎤 СТАРТ", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.isEnabled = false
        return button
    }()
    
    private let modelSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Tiny", "Base", "Small"])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0 // Tiny по умолчанию (самая быстрая)
        control.backgroundColor = .systemGray6
        control.selectedSegmentTintColor = .systemBlue
        return control
    }()
    
    private let resultsTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.text = "Ваша транскрипция появится здесь..."
        textView.textAlignment = .center
        textView.isEditable = false
        return textView
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("🗑️ Очистить", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.setTitleColor(.systemRed, for: .normal)
        button.isHidden = true
        return button
    }()
    
    // MARK: - Properties
    private let presenter: RecognitionPresenter
    private var currentStatus: AppStatus = .loading
    
    // MARK: - Initialization
    init(presenter: RecognitionPresenter = RecognitionPresenter()) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        presenter.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        // Синхронизируем выбранную модель с презентером
        let selectedIndex = modelSegmentedControl.selectedSegmentIndex
        let modelNames = ["tiny.en", "base.en", "small.en"]
        if selectedIndex < modelNames.count {
            presenter.selectModel(modelNames[selectedIndex])
        }
        
        // Инициализируем систему транскрипции
        Task {
            await presenter.initializeTranscription()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "🎤 Whisper Transcription"
        
        // Добавляем компоненты на view
        view.addSubview(modelSegmentedControl)
        view.addSubview(statusLabel)
        view.addSubview(progressView)
        view.addSubview(startStopButton)
        view.addSubview(resultsTextView)
        view.addSubview(clearButton)
        
        // Настраиваем обработчики
        modelSegmentedControl.addTarget(self, action: #selector(modelSelectionChanged), for: .valueChanged)
        
        // Настраиваем constraints
        NSLayoutConstraint.activate([
            // Model Selection
            modelSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            modelSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            modelSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            modelSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: modelSegmentedControl.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            
            // Start/Stop Button
            startStopButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 30),
            startStopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startStopButton.widthAnchor.constraint(equalToConstant: 200),
            startStopButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Results Text View
            resultsTextView.topAnchor.constraint(equalTo: startStopButton.bottomAnchor, constant: 30),
            resultsTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultsTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultsTextView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -20),
            
            // Clear Button
            clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 120),
            clearButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupActions() {
        startStopButton.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func startStopButtonTapped() {
        Task {
            switch currentStatus {
            case .ready:
                await presenter.startTranscription()
            case .recording:
                await presenter.stopTranscription()
            default:
                break
            }
        }
    }
    
    @objc private func clearButtonTapped() {
        Task {
            await presenter.clearTranscription()
            resultsTextView.text = "Ваша транскрипция появится здесь..."
            clearButton.isHidden = true
        }
    }
    
    @objc private func modelSelectionChanged() {
        let selectedIndex = modelSegmentedControl.selectedSegmentIndex
        let modelNames = ["tiny.en", "base.en", "small.en"]
        
        guard selectedIndex < modelNames.count else { return }
        
        let selectedModel = modelNames[selectedIndex]
        presenter.selectModel(selectedModel)
        
        // Переинициализируем систему с новой моделью
        Task {
            await presenter.initializeTranscription()
        }
    }
    
    // MARK: - Helper Methods
    private func updateButtonForStatus(_ status: AppStatus) {
        print("🔘 Updating button for status: \(status)")
        
        switch status {
        case .loading, .downloadingModel, .warmingModel, .processing:
            startStopButton.isEnabled = false
            startStopButton.setTitle("⏳ Загрузка...", for: .normal)
            startStopButton.backgroundColor = .systemGray
            print("🔘 Button set to: Loading state")
            
        case .ready:
            startStopButton.isEnabled = true
            startStopButton.setTitle("🎤 СТАРТ", for: .normal)
            startStopButton.backgroundColor = .systemBlue
            print("🔘 Button set to: Ready state - ENABLED")
            
        case .recording:
            startStopButton.isEnabled = true
            startStopButton.setTitle("⏹️ СТОП", for: .normal)
            startStopButton.backgroundColor = .systemRed
            print("🔘 Button set to: Recording state")
            
        case .error:
            startStopButton.isEnabled = false
            startStopButton.setTitle("❌ Ошибка", for: .normal)
            startStopButton.backgroundColor = .systemRed
            print("🔘 Button set to: Error state")
        }
    }
    
    private func updateStatusLabel(_ status: AppStatus) {
        switch status {
        case .loading:
            statusLabel.text = "Инициализация системы..."
        case .downloadingModel(let progress):
            statusLabel.text = "Загрузка модели... \(Int(progress * 100))%"
        case .warmingModel(let progress):
            statusLabel.text = "Прогрев модели... \(Int(progress * 100))%"
        case .ready:
            statusLabel.text = "✅ Готов к работе"
        case .recording:
            statusLabel.text = "🔴 Запись..."
        case .processing:
            statusLabel.text = "⚙️ Обработка..."
        case .error:
            statusLabel.text = "❌ Ошибка"
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Ошибка",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - RecognitionPresenter Delegate
extension TranscriptionViewController: RecognitionPresenterDelegate {
    func recognitionPresenter(_ presenter: RecognitionPresenter, didUpdateStatus status: AppStatus) {
        currentStatus = status
        print("🔄 Status updated: \(status)")
        
        DispatchQueue.main.async {
            self.updateStatusLabel(status)
            self.updateButtonForStatus(status)
            
            // Показываем/скрываем progress view
            switch status {
            case .downloadingModel, .warmingModel:
                self.progressView.isHidden = false
            default:
                self.progressView.isHidden = true
            }
            
            print("🎯 UI updated for status: \(status)")
        }
    }
    
    func recognitionPresenter(_ presenter: RecognitionPresenter, didUpdateProgress progress: Double) {
        DispatchQueue.main.async {
            self.progressView.setProgress(Float(progress), animated: true)
        }
    }
    
    func recognitionPresenter(_ presenter: RecognitionPresenter, didUpdateTranscription text: String) {
        DispatchQueue.main.async {
            self.resultsTextView.text = text
            self.clearButton.isHidden = text.isEmpty
        }
    }
    
    func recognitionPresenter(_ presenter: RecognitionPresenter, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.showError(error)
        }
    }
}
