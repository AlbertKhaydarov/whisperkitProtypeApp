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
    private var isRecording = false
    private var confirmedText: String = "" // Хранит финальный подтвержденный текст
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Voice Transcription"
        view.backgroundColor = .systemBackground
        
        setupUI()
        setupConstraints()
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
        
    }
}
