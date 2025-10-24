//
//  QualityControlView.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 24.01.2025.
//

import UIKit

// MARK: - Quality Control View Delegate

protocol QualityControlViewDelegate: AnyObject {
    func qualityControlView(_ view: QualityControlView, didSelectQualityLevel level: QualityLevel)
    func qualityControlView(_ view: QualityControlView, didToggleQualityManager enabled: Bool)
}

/// UI компонент для управления качеством распознавания
/// UI component for managing recognition quality
class QualityControlView: UIView {
    
    // MARK: - UI Components
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "🎯 Управление качеством"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let qualitySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: QualityLevel.allCases.map { $0.displayName })
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.backgroundColor = .systemGray6
        control.selectedSegmentTintColor = .systemBlue
        return control
    }()
    
    private let qualityDescriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private let metricsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }()
    
    private let performanceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGreen
        label.text = "Производительность: --"
        return label
    }()
    
    private let memoryLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.text = "Память: --"
        return label
    }()
    
    private let speedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemOrange
        label.text = "Скорость: --"
        return label
    }()
    
    private let qualityToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("🎯 Включить Quality Manager", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.tag = 0 // 0 = выключен, 1 = включен
        return button
    }()
    
    private let deviceCompatibilityLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .systemGreen
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Properties
    
    weak var delegate: QualityControlViewDelegate?
    private var currentQualityLevel: QualityLevel = .adaptive
    private var isQualityManagerEnabled = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
        updateUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupActions()
        updateUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
        
        // Добавляем компоненты
        addSubview(titleLabel)
        addSubview(qualitySegmentedControl)
        addSubview(qualityDescriptionLabel)
        addSubview(metricsStackView)
        addSubview(qualityToggleButton)
        addSubview(deviceCompatibilityLabel)
        
        // Настраиваем stack view для метрик
        metricsStackView.addArrangedSubview(performanceLabel)
        metricsStackView.addArrangedSubview(memoryLabel)
        metricsStackView.addArrangedSubview(speedLabel)
        
        // Настраиваем constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Quality Control
            qualitySegmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            qualitySegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            qualitySegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            qualitySegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // Description
            qualityDescriptionLabel.topAnchor.constraint(equalTo: qualitySegmentedControl.bottomAnchor, constant: 8),
            qualityDescriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            qualityDescriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Metrics
            metricsStackView.topAnchor.constraint(equalTo: qualityDescriptionLabel.bottomAnchor, constant: 12),
            metricsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            metricsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Toggle Button
            qualityToggleButton.topAnchor.constraint(equalTo: metricsStackView.bottomAnchor, constant: 16),
            qualityToggleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            qualityToggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            qualityToggleButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Device Compatibility
            deviceCompatibilityLabel.topAnchor.constraint(equalTo: qualityToggleButton.bottomAnchor, constant: 8),
            deviceCompatibilityLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            deviceCompatibilityLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            deviceCompatibilityLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    private func setupActions() {
        qualitySegmentedControl.addTarget(self, action: #selector(qualityLevelChanged), for: .valueChanged)
        qualityToggleButton.addTarget(self, action: #selector(qualityToggleTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func qualityLevelChanged() {
        let selectedIndex = qualitySegmentedControl.selectedSegmentIndex
        guard selectedIndex < QualityLevel.allCases.count else { return }
        
        let selectedLevel = QualityLevel.allCases[selectedIndex]
        currentQualityLevel = selectedLevel
        
        updateUI()
        delegate?.qualityControlView(self, didSelectQualityLevel: selectedLevel)
    }
    
    @objc private func qualityToggleTapped() {
        isQualityManagerEnabled.toggle()
        updateToggleButton()
        delegate?.qualityControlView(self, didToggleQualityManager: isQualityManagerEnabled)
    }
    
    // MARK: - Public Methods
    
    /// Обновление метрик качества
    /// Update quality metrics
    func updateMetrics(_ metrics: QualityMetrics) {
        DispatchQueue.main.async {
            self.performanceLabel.text = "Производительность: \(String(format: "%.1f", metrics.performanceScore))/100"
            self.memoryLabel.text = "Память: \(String(format: "%.1f", Double(metrics.memoryPeak) / 1_000_000_000)) GB"
            self.speedLabel.text = "Скорость: \(String(format: "%.2f", metrics.realtimeFactor))x RTF"
            
            // Обновляем цвета на основе производительности
            self.updateMetricsColors(metrics)
        }
    }
    
    /// Установка уровня качества
    /// Set quality level
    func setQualityLevel(_ level: QualityLevel) {
        currentQualityLevel = level
        if let index = QualityLevel.allCases.firstIndex(of: level) {
            qualitySegmentedControl.selectedSegmentIndex = index
        }
        updateUI()
    }
    
    /// Включение/выключение Quality Manager
    /// Enable/disable Quality Manager
    func setQualityManagerEnabled(_ enabled: Bool) {
        isQualityManagerEnabled = enabled
        updateToggleButton()
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        // Обновляем описание
        qualityDescriptionLabel.text = currentQualityLevel.description
        
        // Обновляем совместимость с устройством
        updateDeviceCompatibility()
        
        // Обновляем доступность сегментов
        updateSegmentAvailability()
    }
    
    private func updateToggleButton() {
        if isQualityManagerEnabled {
            qualityToggleButton.setTitle("✅ Quality Manager включен", for: .normal)
            qualityToggleButton.backgroundColor = .systemGreen
        } else {
            qualityToggleButton.setTitle("🎯 Включить Quality Manager", for: .normal)
            qualityToggleButton.backgroundColor = .systemBlue
        }
    }
    
    private func updateDeviceCompatibility() {
        let isCompatible = currentQualityLevel.isCompatibleWithDevice()
        let deviceModel = UIDevice.current.model
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        if isCompatible {
            deviceCompatibilityLabel.text = "✅ Совместимо с \(deviceModel)\nПамять: \(String(format: "%.1f", Double(totalMemory) / 1_000_000_000)) GB"
            deviceCompatibilityLabel.textColor = .systemGreen
        } else {
            deviceCompatibilityLabel.text = "⚠️ Может работать медленно на \(deviceModel)\nРекомендуется: \(QualityLevel.recommendedForDevice().displayName)"
            deviceCompatibilityLabel.textColor = .systemOrange
        }
    }
    
    private func updateSegmentAvailability() {
        for (index, level) in QualityLevel.allCases.enumerated() {
            let isCompatible = level.isCompatibleWithDevice()
            qualitySegmentedControl.setEnabled(isCompatible, forSegmentAt: index)
            
            if !isCompatible {
                // Добавляем индикатор несовместимости
                qualitySegmentedControl.setTitle("\(level.displayName) ⚠️", forSegmentAt: index)
            } else {
                qualitySegmentedControl.setTitle(level.displayName, forSegmentAt: index)
            }
        }
    }
    
    private func updateMetricsColors(_ metrics: QualityMetrics) {
        // Производительность
        if metrics.performanceScore >= 80 {
            performanceLabel.textColor = .systemGreen
        } else if metrics.performanceScore >= 60 {
            performanceLabel.textColor = .systemOrange
        } else {
            performanceLabel.textColor = .systemRed
        }
        
        // Память
        let memoryGB = Double(metrics.memoryPeak) / 1_000_000_000
        if memoryGB <= 1.0 {
            memoryLabel.textColor = .systemGreen
        } else if memoryGB <= 2.0 {
            memoryLabel.textColor = .systemOrange
        } else {
            memoryLabel.textColor = .systemRed
        }
        
        // Скорость
        if metrics.realtimeFactor <= 0.1 {
            speedLabel.textColor = .systemGreen
        } else if metrics.realtimeFactor <= 0.5 {
            speedLabel.textColor = .systemOrange
        } else {
            speedLabel.textColor = .systemRed
        }
    }
}

// MARK: - Quality Control View Extensions

extension QualityControlView {
    /// Получение текущего выбранного уровня качества
    /// Get currently selected quality level
    var selectedQualityLevel: QualityLevel {
        return currentQualityLevel
    }
    
    /// Проверка включен ли Quality Manager
    /// Check if Quality Manager is enabled
    var isQualityManagerActive: Bool {
        return isQualityManagerEnabled
    }
}
