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
    
    private let qualityControlView: QualityControlView = {
        let view = QualityControlView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let qualityModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("🎯 Высокое качество", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.tag = 0 // 0 = стандартный режим, 1 = высокое качество
        return button
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
    
    private let analyzeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("📝 Анализ текста", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.isEnabled = false
        return button
    }()
    
    private let feedbackTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.text = "Результаты анализа появятся здесь..."
        textView.textAlignment = .left
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
    private var isInitialized = false
    private var currentStatus: AppStatus = .loading
    private var gptManager: YandexGPTManager?
    
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
        setupGPTManager()
        
        // Синхронизируем выбранную модель с презентером
        let selectedIndex = modelSegmentedControl.selectedSegmentIndex
        let modelNames = ["tiny.en", "base.en", "small.en"]
        if selectedIndex < modelNames.count {
            presenter.selectModel(modelNames[selectedIndex])
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Всегда инициализируем систему транскрипции при появлении экрана
        Task {
            print("🚀 Starting initialization from viewDidAppear...")
            await presenter.initializeTranscription()
            isInitialized = true
            
            // Автоматически включаем Quality Manager для тестирования
            do {
                try await presenter.enableQualityManager()
                print("🚀 [AUTO] Quality Manager auto-enabled for testing")
            } catch {
                print("⚠️ [AUTO] Failed to auto-enable Quality Manager: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "🎤 Whisper Transcription"
        
        // Добавляем компоненты на view
        view.addSubview(modelSegmentedControl)
        view.addSubview(qualityControlView)
        view.addSubview(qualityModeButton)
        view.addSubview(statusLabel)
        view.addSubview(progressView)
        view.addSubview(startStopButton)
        view.addSubview(resultsTextView)
        view.addSubview(analyzeButton)
        view.addSubview(feedbackTextView)
        view.addSubview(clearButton)
        
        // Настраиваем обработчики
        modelSegmentedControl.addTarget(self, action: #selector(modelSelectionChanged), for: .valueChanged)
        qualityModeButton.addTarget(self, action: #selector(qualityModeToggled), for: .touchUpInside)
        qualityControlView.delegate = self
        
        // Настраиваем constraints
        NSLayoutConstraint.activate([
            // Model Selection
            modelSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            modelSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            modelSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            modelSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // Quality Control View
            qualityControlView.topAnchor.constraint(equalTo: modelSegmentedControl.bottomAnchor, constant: 10),
            qualityControlView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            qualityControlView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Quality Mode Button
            qualityModeButton.topAnchor.constraint(equalTo: qualityControlView.bottomAnchor, constant: 10),
            qualityModeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            qualityModeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            qualityModeButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: qualityModeButton.bottomAnchor, constant: 20),
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
            resultsTextView.heightAnchor.constraint(equalToConstant: 120),
            
            // Analyze Button
            analyzeButton.topAnchor.constraint(equalTo: resultsTextView.bottomAnchor, constant: 12),
            analyzeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            analyzeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            analyzeButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Feedback Text View
            feedbackTextView.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 12),
            feedbackTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            feedbackTextView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -20),
            
            // Clear Button
            clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 120),
            clearButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupActions() {
        startStopButton.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        analyzeButton.addTarget(self, action: #selector(analyzeButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    }
    
    private func setupGPTManager() {
        // Инициализируем YandexGPTManager - он сам загрузит ключи из окружения или .env файла
        gptManager = YandexGPTManager()
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
    
    @objc private func analyzeButtonTapped() {
        let text = resultsTextView.text ?? ""
        guard !text.isEmpty, text != "Ваша транскрипция появится здесь..." else { return }
        
        statusLabel.text = "Анализ текста..."
        analyzeButton.isEnabled = false
        
        Task {
            do {
                guard let gptManager = gptManager else {
                    throw NSError(domain: "GPTManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "GPT Manager не инициализирован"])
                }
                
                let feedback = try await gptManager.analyzeEnglishText(text)
                await MainActor.run {
                    feedbackTextView.text = feedback.feedback
                    statusLabel.text = "Анализ завершен"
                    analyzeButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    showError(error)
                    statusLabel.text = "Ошибка анализа"
                    analyzeButton.isEnabled = true
                }
            }
        }
    }
    
    @objc private func clearButtonTapped() {
        Task {
            await presenter.clearTranscription()
            resultsTextView.text = "Ваша транскрипция появится здесь..."
            feedbackTextView.text = "Результаты анализа появятся здесь..."
            analyzeButton.isEnabled = false
            clearButton.isHidden = true
        }
    }
    
    @objc private func modelSelectionChanged() {
        let selectedIndex = modelSegmentedControl.selectedSegmentIndex
        let modelNames = ["tiny.en", "base.en", "small.en"]
        
        guard selectedIndex < modelNames.count else { return }
        
        // Обновляем UI для индикации загрузки
        updateButtonForStatus(.loading)
        statusLabel.text = "Смена модели..."
        progressView.isHidden = false
        progressView.setProgress(0.0, animated: false)
        
        let selectedModel = modelNames[selectedIndex]
        presenter.selectModel(selectedModel)
        
        // Переинициализируем систему с новой моделью
        Task {
            await presenter.initializeTranscription()
        }
    }
    
    @objc private func qualityModeToggled() {
        let isHighQuality = qualityModeButton.tag == 0
        
        if isHighQuality {
            // Переключаемся на высокое качество
            qualityModeButton.tag = 1
            qualityModeButton.setTitle("📱 Стандартный режим", for: .normal)
            qualityModeButton.backgroundColor = .systemBlue
            
            // Обновляем UI для индикации загрузки
            updateButtonForStatus(.loading)
            statusLabel.text = "Включение режима высокого качества..."
            progressView.isHidden = false
            progressView.setProgress(0.0, animated: false)
            
            // Переключаемся на высокое качество
            Task {
                do {
                    try await presenter.enableHighQualityMode()
                } catch {
                    await MainActor.run {
                        self.statusLabel.text = "Ошибка: \(error.localizedDescription)"
                        self.updateButtonForStatus(.ready)
                    }
                }
            }
        } else {
            // Переключаемся на стандартный режим
            qualityModeButton.tag = 0
            qualityModeButton.setTitle("🎯 Высокое качество", for: .normal)
            qualityModeButton.backgroundColor = .systemGreen
            
            // Обновляем UI для индикации загрузки
            updateButtonForStatus(.loading)
            statusLabel.text = "Включение стандартного режима..."
            progressView.isHidden = false
            progressView.setProgress(0.0, animated: false)
            
            // Переключаемся на стандартный режим
            Task {
                do {
                    try await presenter.enableStandardMode()
                } catch {
                    await MainActor.run {
                        self.statusLabel.text = "Ошибка: \(error.localizedDescription)"
                        self.updateButtonForStatus(.ready)
                    }
                }
            }
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
        case .error(let error):
            statusLabel.text = "❌ Ошибка: \(error.localizedDescription)"
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
            
            // Кнопка анализа всегда видна, но активируется только при наличии текста
            let hasText = !text.isEmpty && text != "Ваша транскрипция появится здесь..."
            self.analyzeButton.isEnabled = hasText && self.gptManager != nil
        }
    }
    
    func recognitionPresenter(_ presenter: RecognitionPresenter, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.showError(error)
        }
    }
}

// MARK: - Quality Control View Delegate
extension TranscriptionViewController: QualityControlViewDelegate {
    func qualityControlView(_ view: QualityControlView, didSelectQualityLevel level: QualityLevel) {
        Task {
            do {
                try await presenter.switchQualityLevel(to: level)
                print("✅ [UI] Quality level switched to: \(level.rawValue)")
            } catch {
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }
    
    func qualityControlView(_ view: QualityControlView, didToggleQualityManager enabled: Bool) {
        Task {
            if enabled {
                do {
                    try await presenter.enableQualityManager()
                    print("✅ [UI] Quality Manager enabled")
                } catch {
                    await MainActor.run {
                        self.showError(error)
                        // Сбрасываем состояние кнопки при ошибке
                        self.qualityControlView.setQualityManagerEnabled(false)
                    }
                }
            } else {
                await presenter.disableQualityManager()
                print("✅ [UI] Quality Manager disabled")
            }
        }
    }
}
