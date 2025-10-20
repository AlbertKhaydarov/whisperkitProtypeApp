//
//  ModelDownloadManager.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import Foundation

/// Менеджер для скачивания и кэширования моделей WhisperKit
/// Manager for downloading and caching WhisperKit models
class ModelDownloadManager {
    private let modelName = "openai_whisper-small.en" // Используем правильное имя модели
    private let fileManager = FileManager.default
    
    /// Скачать модель если её нет в кэше
    /// Download model if not cached
    func downloadModelIfNeeded() async throws {
        print("📥 WhisperKit will download model '\(modelName)' automatically...")
        
        // WhisperKit автоматически скачает модель при инициализации
        // с параметром download: true
        // WhisperKit will automatically download model during initialization
        // with download: true parameter
        
        // Здесь можно добавить дополнительную логику:
        // - Показать прогресс скачивания
        // - Валидация скачанной модели
        // - Fallback на другую модель если скачивание не удалось
        // Additional logic can be added here:
        // - Show download progress
        // - Validate downloaded model
        // - Fallback to another model if download fails
    }
    
    /// Проверить наличие кэшированной модели
    /// Check if model is cached
    func hasCachedModel() -> Bool {
        let cachePath = getCachePath()
        
        // Проверяем наличие папки с моделями WhisperKit
        // Check for WhisperKit models folder
        guard fileManager.fileExists(atPath: cachePath.path) else {
            return false
        }
        
        // Проверяем наличие хотя бы одной модели
        // Check for at least one model
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: cachePath.path)
            return !contents.isEmpty
        } catch {
            return false
        }
    }
    
    /// Получить путь к кэшу моделей
    /// Get cache path for models
    func getCachePath() -> URL {
        let documentsPath = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent("openai_whisper-small.en") // Добавляем имя модели
    }
    
    /// Очистить кэш моделей
    /// Clear model cache
    func clearCache() throws {
        let cachePath = getCachePath()
        
        if fileManager.fileExists(atPath: cachePath.path) {
            try fileManager.removeItem(at: cachePath)
            print("🗑️ Cache cleared")
        }
    }
    
    /// Получить размер кэша
    /// Get cache size
    func getCacheSize() -> Int64 {
        let cachePath = getCachePath()
        
        guard let enumerator = fileManager.enumerator(
            at: cachePath,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    /// Форматировать размер для отображения
    /// Format size for display
    func formattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
