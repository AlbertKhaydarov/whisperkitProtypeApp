//
//  ErrorHandler.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import UIKit

/// Глобальный обработчик ошибок для WhisperKit
/// Global error handler for WhisperKit
class ErrorHandler {
    weak var viewController: UIViewController?
    
    /// Обработать ошибку
    /// Handle error
    func handle(_ error: Error) {
        // Конвертировать в WhisperKitError
        // Convert to WhisperKitError
        let whisperError: WhisperKitError
        
        if let wkError = error as? WhisperKitError {
            whisperError = wkError
        } else {
            whisperError = .unknown(underlying: error)
        }
        
        // Логирование
        // Logging
        logError(whisperError)
        
        // Показать алерт пользователю
        // Show alert to user
        showErrorAlert(whisperError)
    }
    
    /// Логировать ошибку
    /// Log error
    private func logError(_ error: WhisperKitError) {
        print("❌ Error: \(error)")
        print("   Message: \(error.userFriendlyMessage)")
        
        // В production используйте профессиональную систему логирования
        // например: OSLog, CocoaLumberjack, или отправку в сервис аналитики
        // In production use professional logging system
        // e.g.: OSLog, CocoaLumberjack, or send to analytics service
    }
    
    /// Показать алерт с ошибкой
    /// Show error alert
    private func showErrorAlert(_ error: WhisperKitError) {
        Task { @MainActor [weak self] in
            guard let viewController = self?.viewController else { return }
            
            let alert = UIAlertController(
                title: "Ошибка",
                message: error.userFriendlyMessage,
                preferredStyle: .alert
            )
            
            // Основное действие
            // Primary action
            let primaryAction = UIAlertAction(
                title: error.recoveryAction,
                style: .default
            ) { _ in
                self?.handleRecoveryAction(for: error)
            }
            alert.addAction(primaryAction)
            
            // Отмена
            // Cancel
            if error.recoveryAction != "OK" {
                alert.addAction(UIAlertAction(
                    title: "Отмена",
                    style: .cancel
                ))
            }
            
            viewController.present(alert, animated: true)
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    /// Обработать действие восстановления
    /// Handle recovery action
    private func handleRecoveryAction(for error: WhisperKitError) {
        switch error {
        case .microphonePermissionDenied:
            openAppSettings()
            
        case .modelDownloadFailed, .networkError:
            // Повторить последнюю операцию
            // Retry last operation
            break
            
        default:
            break
        }
    }
    
    /// Открыть настройки приложения
    /// Open app settings
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
