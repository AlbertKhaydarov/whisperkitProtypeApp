//
//  WhisperKitError.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation

/// Типы ошибок WhisperKit с понятными сообщениями для пользователя
/// WhisperKit error types with user-friendly messages
enum WhisperKitError: Error {
    case notInitialized
    case modelNotFound
    case modelDownloadFailed(underlying: Error)
    case modelLoadingFailed(underlying: Error)
    case audioProcessingFailed(underlying: Error)
    case transcriptionFailed(underlying: Error)
    case microphonePermissionDenied
    case audioSessionFailed(underlying: Error)
    case insufficientMemory
    case unsupportedDevice
    case networkError(underlying: Error)
    case unknown(underlying: Error)
}

// MARK: - User-Friendly Messages
extension WhisperKitError {
    /// Понятное сообщение об ошибке для пользователя
    /// User-friendly error message
    var userFriendlyMessage: String {
        switch self {
        case .notInitialized:
            return "WhisperKit не инициализирован. Пожалуйста, перезапустите приложение."
            
        case .modelNotFound:
            return "Модель распознавания речи не найдена. Проверьте подключение к интернету."
            
        case .modelDownloadFailed:
            return "Не удалось скачать модель. Проверьте подключение к интернету и попробуйте снова."
            
        case .modelLoadingFailed:
            return "Не удалось загрузить модель. Попробуйте перезапустить приложение."
            
        case .audioProcessingFailed:
            return "Ошибка обработки аудио. Проверьте настройки микрофона."
            
        case .transcriptionFailed:
            return "Не удалось распознать речь. Говорите чётче и попробуйте снова."
            
        case .microphonePermissionDenied:
            return "Доступ к микрофону запрещен. Разрешите доступ в настройках iOS."
            
        case .audioSessionFailed:
            return "Не удалось настроить аудио. Закройте другие приложения использующие микрофон."
            
        case .insufficientMemory:
            return "Недостаточно памяти. Закройте другие приложения и попробуйте снова."
            
        case .unsupportedDevice:
            return "Ваше устройство не поддерживается. Требуется iOS 16.0 или выше."
            
        case .networkError:
            return "Ошибка сети. Проверьте подключение к интернету."
            
        case .unknown:
            return "Произошла неизвестная ошибка. Попробуйте перезапустить приложение."
        }
    }
    
    /// Действие для восстановления после ошибки
    /// Recovery action for the error
    var recoveryAction: String {
        switch self {
        case .microphonePermissionDenied:
            return "Открыть настройки"
        case .modelDownloadFailed, .networkError:
            return "Повторить"
        case .insufficientMemory:
            return "Закрыть приложения"
        default:
            return "OK"
        }
    }
}
