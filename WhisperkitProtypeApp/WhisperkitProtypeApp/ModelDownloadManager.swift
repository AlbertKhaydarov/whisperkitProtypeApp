//
//  ModelDownloadManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation

#if canImport(WhisperKit)
import WhisperKit
#endif

// MARK: - ModelDownloadManager Delegate
protocol ModelDownloadManagerDelegate: AnyObject {
    func modelDownloadManager(_ manager: ModelDownloadManager, didUpdateProgress progress: Double)
    func modelDownloadManager(_ manager: ModelDownloadManager, didCompleteDownloadFor modelName: String)
    func modelDownloadManager(_ manager: ModelDownloadManager, didFailDownloadFor modelName: String, with error: Error)
}

/// Менеджер для управления моделями WhisperKit
/// Manager for managing WhisperKit models
class ModelDownloadManager: NSObject {
    
    // MARK: - Properties
    private let fileManager: FileManager
    
    // MARK: - Delegate
    weak var delegate: ModelDownloadManagerDelegate?
    
    // MARK: - Initialization
    override init() {
        self.fileManager = FileManager.default
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Проверка доступности модели
    /// Check model availability
    func isModelAvailable(_ modelName: String) -> Bool {
        // WhisperKit автоматически управляет моделями
        // Проверяем, есть ли модель в кэше WhisperKit
        let modelsDir = getWhisperKitModelsDirectory()
        let modelPath = modelsDir.appendingPathComponent("openai_whisper-\(modelName)")
        
        return fileManager.fileExists(atPath: modelPath.path)
    }
    
    /// Получение локального URL модели
    /// Get local model URL
    func getLocalModelURL(_ modelName: String) -> URL? {
        let modelsDir = getWhisperKitModelsDirectory()
        let modelPath = modelsDir.appendingPathComponent("openai_whisper-\(modelName)")
        
        // Проверяем существование директории модели
        guard fileManager.fileExists(atPath: modelPath.path) else { 
            print("📁 Model directory not found: \(modelPath.path)")
            return nil 
        }
        
        print("📁 Found local model: \(modelPath.path)")
        return modelPath
    }
    
    /// Валидация модели
    /// Validate model
    func validateModel(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int else { return false }
            
            // Минимальный размер директории модели (10MB)
            return fileSize > 10 * 1024 * 1024
        } catch {
            return false
        }
    }
    
    /// Удаление модели
    /// Remove model
    func removeModel(_ modelName: String) async throws {
        guard let url = getLocalModelURL(modelName) else {
            throw ModelDownloadError.modelNotFound
        }
        
        try fileManager.removeItem(at: url)
        print("🗑️ Model removed: \(modelName)")
    }
    
    /// Получение доступных моделей
    /// Get available models
    func getAvailableModels() -> [String] {
        // Возвращаем модели, поддерживаемые WhisperKit с расширением .en
        return ["tiny.en", "base.en", "small.en", "medium.en", "large-v3"]
    }
    
    /// Получение рекомендуемой модели для устройства
    /// Get recommended model for device
    func getRecommendedModel() -> String {
        // WhisperKit автоматически выбирает оптимальную модель
        // Возвращаем базовую модель как fallback
        return "base.en"
    }
    
    /// Получение размера модели
    /// Get model size
    func getModelSize(_ modelName: String) -> Int64 {
        let modelSizes: [String: Int64] = [
            "tiny.en": 39 * 1024 * 1024,      // 39 MB
            "base.en": 74 * 1024 * 1024,      // 74 MB
            "small.en": 244 * 1024 * 1024,    // 244 MB
            "medium.en": 769 * 1024 * 1024,   // 769 MB
            "large-v3": 1550 * 1024 * 1024    // 1.55 GB
        ]
        
        return modelSizes[modelName] ?? 0
    }
    
    /// Получение информации о модели
    /// Get model information
    func getModelInfo(_ modelName: String) -> ModelInfo? {
        guard isModelAvailable(modelName) else { return nil }
        
        return ModelInfo(
            name: modelName,
            size: getModelSize(modelName),
            isDownloaded: true,
            localPath: getLocalModelURL(modelName)?.path
        )
    }
    
    /// Очистка кэша моделей
    /// Clear models cache
    func clearModelsCache() async throws {
        let modelsDir = getWhisperKitModelsDirectory()
        
        if fileManager.fileExists(atPath: modelsDir.path) {
            try fileManager.removeItem(at: modelsDir)
            print("🗑️ Models cache cleared")
        }
    }
    
    // MARK: - Private Methods
    
    private func getWhisperKitModelsDirectory() -> URL {
        // WhisperKit сохраняет модели в Application Support
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("WhisperKit")
    }
    
    private func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// MARK: - Model Information
struct ModelInfo {
    let name: String
    let size: Int64
    let isDownloaded: Bool
    let localPath: String?
    
    var sizeInMB: Double {
        return Double(size) / (1024 * 1024)
    }
    
    var sizeFormatted: String {
        if sizeInMB < 1024 {
            return String(format: "%.1f MB", sizeInMB)
        } else {
            return String(format: "%.1f GB", sizeInMB / 1024)
        }
    }
}

// MARK: - Model Download Errors
enum ModelDownloadError: Error, LocalizedError {
    case modelNotFound
    case invalidURL
    case downloadFailed
    case validationFailed
    case modelNotSupported
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Модель не найдена"
        case .invalidURL:
            return "Неверный URL для загрузки"
        case .downloadFailed:
            return "Ошибка загрузки модели"
        case .validationFailed:
            return "Ошибка валидации модели"
        case .modelNotSupported:
            return "Модель не поддерживается"
        }
    }
}