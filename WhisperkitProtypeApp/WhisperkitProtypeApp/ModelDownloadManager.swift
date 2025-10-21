//
//  ModelDownloadManager.swift
//  WhisperkitProtypeApp
//
//  Created by AI Assistant on 21.10.2025.
//

import Foundation

// MARK: - ModelDownloadManager Delegate
protocol ModelDownloadManagerDelegate: AnyObject {
    func modelDownloadManager(_ manager: ModelDownloadManager, didUpdateProgress progress: Double)
    func modelDownloadManager(_ manager: ModelDownloadManager, didCompleteDownloadFor modelName: String, at localURL: URL)
    func modelDownloadManager(_ manager: ModelDownloadManager, didFailDownloadFor modelName: String, with error: Error)
}

/// Менеджер для загрузки и управления моделями Whisper
/// Manager for downloading and managing Whisper models
class ModelDownloadManager: NSObject {
    
    // MARK: - Properties
    private let urlSession: URLSession
    private let fileManager: FileManager
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    
    // MARK: - Delegate
    weak var delegate: ModelDownloadManagerDelegate?
    
    // MARK: - Initialization
    override init() {
        let config = URLSessionConfiguration.default
        self.fileManager = FileManager.default
        self.urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        super.init()
        // Note: URLSession delegate cannot be set after initialization
        // We'll need to handle download completion differently
    }
    
    // MARK: - Public Methods
    
    /// Загрузка модели
    /// Download model
    func downloadModel(_ modelName: String) async throws -> URL {
        guard let modelConfig = getModelConfiguration(modelName) else {
            throw ModelDownloadError.modelNotFound
        }
        
        // Проверяем, есть ли уже локальная копия
        if let localURL = getLocalModelURL(modelName) {
            print("📁 Model already exists locally: \(localURL.path)")
            return localURL
        }
        
        print("📥 Starting download for model: \(modelName)")
        
        guard let url = URL(string: modelConfig.downloadURL) else {
            throw ModelDownloadError.invalidURL
        }
        
        // Используем async/await для загрузки
        let (localURL, _) = try await urlSession.download(from: url)
        
        // Перемещаем файл в нужную директорию
        let documentsDir = getDocumentsDirectory()
        let modelsDir = documentsDir.appendingPathComponent("Models")
        
        // Создаем директорию Models если не существует
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        let destinationURL = modelsDir.appendingPathComponent("\(modelName).zip")
        
        // Удаляем существующий файл если есть
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Перемещаем загруженный файл
        try fileManager.moveItem(at: localURL, to: destinationURL)
        
        // Распаковываем ZIP файл
        let extractedURL = try await extractModel(from: destinationURL, modelName: modelName)
        
        print("✅ Model downloaded and extracted successfully: \(extractedURL.path)")
        
        // Уведомляем делегата о завершении загрузки
        delegate?.modelDownloadManager(self, didCompleteDownloadFor: modelName, at: extractedURL)
        
        return extractedURL
    }
    
    /// Получение локального URL модели
    /// Get local model URL
    func getLocalModelURL(_ modelName: String) -> URL? {
        let modelsDir = getDocumentsDirectory().appendingPathComponent("Models")
        let modelFile = modelsDir.appendingPathComponent("ggml-\(modelName).bin")
        
        // Проверяем существование файла модели
        guard fileManager.fileExists(atPath: modelFile.path) else { 
            print("📁 Model file not found: \(modelFile.path)")
            return nil 
        }
        
        print("📁 Found local model: \(modelFile.path)")
        return modelFile
    }
    
    /// Валидация модели
    /// Validate model
    func validateModel(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int else { return false }
            
            // Минимальный размер файла модели (10MB)
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
        // Возвращаем только английские модели с расширением .en
        return ["tiny.en", "base.en", "small.en"]
    }
    
    // MARK: - Private Methods
    
    private func getModelConfiguration(_ modelName: String) -> ModelConfiguration? {
        // Поддерживаем только английские модели с расширением .en
        let models: [String: ModelConfiguration] = [
            "tiny.en": ModelConfiguration(
                name: "tiny.en",
                size: 77 * 1024 * 1024, // 77.7 MB
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin",
                checksum: "tiny_en_checksum",
                localPath: "Models/ggml-tiny.en.bin"
            ),
            "base.en": ModelConfiguration(
                name: "base.en",
                size: 148 * 1024 * 1024, // 148 MB
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin",
                checksum: "base_en_checksum",
                localPath: "Models/ggml-base.en.bin"
            ),
            "small.en": ModelConfiguration(
                name: "small.en",
                size: 488 * 1024 * 1024, // 488 MB
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin",
                checksum: "small_en_checksum",
                localPath: "Models/ggml-small.en.bin"
            ),
            "medium.en": ModelConfiguration(
                name: "medium.en",
                size: 1530 * 1024 * 1024, // 1.53 GB
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin",
                checksum: "medium_en_checksum",
                localPath: "Models/ggml-medium.en.bin"
            )
        ]
        
        return models[modelName]
    }
    
    private func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Перемещение скачанного файла модели в правильное место
    /// Move downloaded model file to correct location
    private func extractModel(from downloadedURL: URL, modelName: String) async throws -> URL {
        let documentsDir = getDocumentsDirectory()
        let modelsDir = documentsDir.appendingPathComponent("Models")
        let modelFile = modelsDir.appendingPathComponent("ggml-\(modelName).bin")
        
        // Создаем директорию Models если не существует
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        // Удаляем старый файл модели если существует
        if fileManager.fileExists(atPath: modelFile.path) {
            try fileManager.removeItem(at: modelFile)
        }
        
        // Перемещаем скачанный файл в правильное место
        print("📦 Moving model file: \(downloadedURL.lastPathComponent) -> \(modelFile.lastPathComponent)")
        
        do {
            try fileManager.moveItem(at: downloadedURL, to: modelFile)
            print("✅ Model file moved successfully")
        } catch {
            print("❌ Failed to move model file: \(error.localizedDescription)")
            throw ModelDownloadError.validationFailed
        }
        
        // Проверяем размер файла модели
        do {
            let fileAttributes = try fileManager.attributesOfItem(atPath: modelFile.path)
            if let fileSize = fileAttributes[.size] as? NSNumber {
                let sizeInMB = fileSize.doubleValue / (1024 * 1024)
                print("📊 Model file size: \(String(format: "%.2f", sizeInMB)) MB")
                
                // Проверяем минимальный размер файла
                if sizeInMB < 10 {
                    print("⚠️ Warning: Model file seems too small (\(String(format: "%.2f", sizeInMB)) MB)")
                }
            }
        } catch {
            print("⚠️ Could not get model file attributes: \(error.localizedDescription)")
        }
        
        print("📦 Model ready at: \(modelFile.path)")
        return modelFile
    }
}

// MARK: - URLSessionDownloadDelegate (Removed - using async/await instead)

// MARK: - Model Configuration
struct ModelConfiguration {
    let name: String
    let size: Int
    let downloadURL: String
    let checksum: String
    let localPath: String
}

// MARK: - Model Download Errors
enum ModelDownloadError: Error, LocalizedError {
    case modelNotFound
    case invalidURL
    case downloadFailed
    case validationFailed
    
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
        }
    }
}
