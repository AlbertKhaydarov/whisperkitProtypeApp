# 📱 Техническое задание: Интеграция WhisperKit для real-time распознавания речи

**Версия:** 1.0  
**Дата:** 18 октября 2025  
**Платформа:** iOS (Swift UIKit)  
**Целевая версия iOS:** 16.0+  

---

## 📋 Оглавление

1. [Обзор проекта](#1-обзор-проекта)
2. [Технические требования](#2-технические-требования)
3. [Архитектура решения](#3-архитектура-решения)
4. [Детальная спецификация компонентов](#4-детальная-спецификация-компонентов)
5. [Конфигурация WhisperKit](#5-конфигурация-whisperkit)
6. [Real-time транскрипция](#6-real-time-транскрипция)
7. [Обработка результатов](#7-обработка-результатов)
8. [Определение языка и валидация](#8-определение-языка-и-валидация)
9. [Retry механизм](#9-retry-механизм)
10. [Обработка ошибок](#10-обработка-ошибок)
11. [Best Practices](#11-best-practices)
12. [Примеры кода](#12-примеры-кода)
13. [Чек-лист и критерии приемки](#13-чек-лист-и-критерии-приемки)

---

## 1. Обзор проекта

### 1.1. Цель

Разработать iOS-модуль для распознавания речи в реальном времени (speech-to-text) с использованием библиотеки **WhisperKit**, работающей полностью offline через CoreML.

### 1.2. Ключевые возможности

- ✅ **Real-time транскрипция** с микрофона с отображением промежуточных результатов
- ✅ **Offline работа** — все модели работают на устройстве без интернета
- ✅ **Оптимизация под Neural Engine** — максимальная производительность на iPhone
- ✅ **Определение языка** — распознавание только английской речи с уведомлениями
- ✅ **Retry механизм** — автоматические повторные попытки при ошибках
- ✅ **Профессиональная обработка ошибок** — понятные сообщения для пользователя

### 1.3. Ограничения

- **Только английский язык** — модель `tiny-en` оптимизирована для английского
- **UIKit** — использовать UIKit, НЕ SwiftUI
- **Без Combine** — использовать delegates
- **iOS 16.0+** — минимальная версия для CoreML оптимизаций

---

## 2. Технические требования

### 2.1. Системные требования

| Параметр | Значение |
|----------|----------|
| **Минимальная версия iOS** | 16.0 |
| **Xcode** | 15.0+ |
| **Swift** | 6.0+ |
| **Поддерживаемые устройства** | iPhone 8+ (A12+ рекомендуется для Neural Engine) |
| **Архитектура** | UIKit (без SwiftUI) |
| **Паттерны** | Singleton, Delegate, Async/await, Actors |

### 2.2. Зависимости

```swift
// Package.swift или SPM в Xcode
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.14.0")
]
```

### 2.3. Разрешения (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Микрофон используется для распознавания вашей речи в реальном времени</string>

<key>NSAllowsArbitraryLoads</key>
<false/>
```

---

## 3. Архитектура решения

### 3.1. Структура компонентов

```
┌─────────────────────────────────────────────────────┐
│        TranscriptionViewController (UIKit)          │
│  - UI элементы (UILabel, UIButton, UITextView)     │
│  - Отображение промежуточных/финальных результатов  │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│         WhisperKitManager (Singleton)               │
│  - Инициализация WhisperKit                         │
│  - Управление моделями                               │
│  - Координация транскрипции                          │
└──────────┬───────────────────────┬──────────────────┘
           │                       │
           ▼                       ▼
┌──────────────────────┐   ┌──────────────────────────┐
│ AudioRecordingManager│   │ ModelDownloadManager     │
│ - AVAudioEngine      │   │ - Скачивание модели      │
│ - Buffer processing  │   │ - Кэширование            │
│ - Real-time capture  │   │ - Проверка наличия       │
└──────────────────────┘   └──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────┐
│        AudioStreamTranscriber (WhisperKit)          │
│  - Непрерывная транскрипция аудио потока            │
│  - Колбэки для промежуточных результатов            │
└─────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────┐
│           ErrorHandler + RetryManager               │
│  - Обработка всех типов ошибок                      │
│  - Retry с экспоненциальной задержкой               │
│  - Логирование                                       │
└─────────────────────────────────────────────────────┘
```

### 3.2. Диаграмма классов

```
┌────────────────────────────────────────┐
│   WhisperKitManager (Singleton)        │
├────────────────────────────────────────┤
│ - whisperKit: WhisperKit?              │
│ - modelDownloadManager                 │
│ - retryManager                         │
├────────────────────────────────────────┤
│ + shared: WhisperKitManager            │
│ + initialize() async throws            │
│ + startRealtimeTranscription(delegate) │
│ + stopTranscription()                  │
│ + retryWithBackoff(operation)          │
└────────────────────────────────────────┘
                │
                │ has-a
                ▼
┌────────────────────────────────────────┐
│   ModelDownloadManager                 │
├────────────────────────────────────────┤
│ - cachedModelPath: URL?                │
├────────────────────────────────────────┤
│ + downloadIfNeeded() async throws      │
│ + checkCachedModel() -> Bool           │
│ + getCachePath() -> URL                │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│   AudioRecordingManager                │
├────────────────────────────────────────┤
│ - audioEngine: AVAudioEngine           │
│ - streamTranscriber                    │
│ - delegate                             │
├────────────────────────────────────────┤
│ + startRecording() throws              │
│ + stopRecording()                      │
│ + processAudioBuffer(buffer)           │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│   TranscriptionViewController          │
├────────────────────────────────────────┤
│ - intermediateLabel: UILabel           │
│ - finalTextView: UITextView            │
│ - recordButton: UIButton               │
│ - statusLabel: UILabel                 │
│ - whisperManager                       │
├────────────────────────────────────────┤
│ + viewDidLoad()                        │
│ + setupUI()                            │
│ + handleRecordButtonTap()              │
│ + updateIntermediateResult(text)       │
│ + updateFinalResult(text)              │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│   TranscriptionDelegate (Protocol)     │
├────────────────────────────────────────┤
│ + didReceiveIntermediateResult(String) │
│ + didReceiveFinalResult(String)        │
│ + didEncounterError(Error)             │
│ + didDetectNonEnglishSpeech()          │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│   RetryManager                         │
├────────────────────────────────────────┤
│ - maxRetries: Int = 3                  │
│ - baseDelay: TimeInterval = 1.0        │
├────────────────────────────────────────┤
│ + retry(operation) async throws -> T   │
│ + exponentialBackoff(attempt) -> Time  │
└────────────────────────────────────────┘
```

---

## 4. Детальная спецификация компонентов

### 4.1. WhisperKitManager

**Назначение:** Singleton для управления жизненным циклом WhisperKit и координации всех операций распознавания.

**Ответственности:**
- Инициализация WhisperKit с правильной конфигурацией
- Управление моделью `tiny-en`
- Координация real-time транскрипции
- Обеспечение thread-safety

**Ключевые методы:**

```swift
class WhisperKitManager {
    static let shared = WhisperKitManager()
    
    private var whisperKit: WhisperKit?
    private let modelDownloadManager: ModelDownloadManager
    private let retryManager: RetryManager
    private var audioRecordingManager: AudioRecordingManager?
    
    // Инициализация с полной конфигурацией
    func initialize() async throws
    
    // Запуск real-time транскрипции
    func startRealtimeTranscription(delegate: TranscriptionDelegate) throws
    
    // Остановка транскрипции
    func stopTranscription()
    
    // Проверка готовности
    func isReady() -> Bool
}
```

### 4.2. ModelDownloadManager

**Назначение:** Управление скачиванием и кэшированием моделей WhisperKit.

**Ответственности:**
- Проверка наличия кэшированной модели
- Скачивание модели при первом запуске
- Управление кэшем в Documents/whisperkit_models/
- Очистка старых моделей

**Ключевые методы:**

```swift
class ModelDownloadManager {
    private let modelName = "tiny-en"
    
    // Скачать модель если её нет
    func downloadModelIfNeeded() async throws -> URL
    
    // Проверить наличие кэшированной модели
    func hasCachedModel() -> Bool
    
    // Получить путь к кэшу
    func getCachePath() -> URL
    
    // Очистить кэш
    func clearCache() throws
}
```

### 4.3. AudioRecordingManager

**Назначение:** Управление захватом аудио с микрофона и передача в WhisperKit для real-time транскрипции.

**Ответственности:**
- Конфигурация AVAudioEngine
- Захват аудио буферов в реальном времени
- Обработка audio session
- Передача данных в AudioStreamTranscriber

**Ключевые методы:**

```swift
class AudioRecordingManager {
    private let audioEngine = AVAudioEngine()
    private var streamTranscriber: AudioStreamTranscriber?
    weak var delegate: TranscriptionDelegate?
    
    // Настроить audio session
    func setupAudioSession() throws
    
    // Начать запись
    func startRecording() throws
    
    // Остановить запись
    func stopRecording()
    
    // Обработать audio buffer
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
}
```

### 4.4. TranscriptionViewController

**Назначение:** UIKit view controller для отображения интерфейса транскрипции. - используй уже существующий mainviewcontroller и его компоненты

<!--**UI компоненты:** -->

<!--```swift-->
<!--class TranscriptionViewController: UIViewController {-->
<!--    // UI элементы-->
<!--    private let intermediateLabel: UILabel       // Промежуточные результаты-->
<!--    private let finalTextView: UITextView        // Финальный текст-->
<!--    private let recordButton: UIButton           // Кнопка записи-->
<!--    private let statusLabel: UILabel             // Статус (готов/запись/ошибка)-->
<!--    private let languageWarningView: UIView      // Предупреждение о языке-->
<!--    -->
<!--    // Менеджеры-->
<!--    private let whisperManager = WhisperKitManager.shared-->
<!--    -->
<!--    override func viewDidLoad()-->
<!--    func setupUI()-->
<!--    func setupConstraints()-->
<!--    func handleRecordButtonTap()-->
<!--}-->
<!--```-->

### 4.5. RetryManager

**Назначение:** Реализация retry механизма с экспоненциальной задержкой.

**Конфигурация:**
- Максимум попыток: 3
- Базовая задержка: 1.0 секунда
- Экспоненциальный рост: delay = baseDelay * 2^(attempt - 1)

```swift
class RetryManager {
    let maxRetries = 3
    let baseDelay: TimeInterval = 1.0
    
    func retry<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T
    
    private func calculateBackoff(attempt: Int) -> TimeInterval
}
```

---

## 5. Конфигурация WhisperKit

### 5.1. WhisperKitConfig - Настройки инициализации

**Требования:**
- Модель: `tiny-en` (размер ~40MB, только английский)
- Автоматическое скачивание при первом запуске
- Предзагрузка модели (prewarm) для быстрого старта
- Кэширование в локальной файловой системе

**Код конфигурации:**

```swift
let config = WhisperKitConfig(
    model: "tiny-en",                    // Модель для английского языка
    verbose: false,                      // Логи только в debug режиме
    download: true,                      // Автоматическое скачивание
    prewarm: true,                      // Предзагрузка для ускорения
    load: true,                         // Загрузить модель сразу
    modelRepo: nil,                     // Использовать дефолтный репозиторий
    modelFolder: getCachedModelPath()   // Кэш в Documents
)

let whisperKit = try await WhisperKit(config)
```

**Путь к кэшу модели:**

```swift
func getCachedModelPath() -> URL {
    let documentsPath = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsPath
        .appendingPathComponent("whisperkit_models")
        .appendingPathComponent("tiny-en")
}
```

### 5.2. ModelComputeOptions - Оптимизация под Neural Engine

**Требования:**
- Использовать Neural Engine для iPhone с A12+
- Fallback на CPU для старых устройств
- Оптимизация энергопотребления

**Код конфигурации:**

```swift
var computeOptions = ModelComputeOptions()

// Использовать Neural Engine + GPU для максимальной производительности
computeOptions.audioEncoderCompute = .neuralEngine
computeOptions.textDecoderCompute = .neuralEngine

// Если Neural Engine недоступен, fallback на CPU
if !isNeuralEngineAvailable() {
    computeOptions.audioEncoderCompute = .cpuAndGPU
    computeOptions.textDecoderCompute = .cpuAndGPU
}

// Применить конфигурацию
let whisperKit = try await WhisperKit(
    WhisperKitConfig(
        model: "tiny-en",
        computeOptions: computeOptions
    )
)
```

**Проверка доступности Neural Engine:**

```swift
func isNeuralEngineAvailable() -> Bool {
    // Neural Engine доступен на A12+ (iPhone XS и новее)
    // Проверяем через device identifier
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(validatingUTF8: $0)
        }
    }
    
    // iPhone11,2 = iPhone XS (A12) и выше
    // Для production используйте более надежную проверку
    return true  // Для упрощения, так как минимум iOS 16
}
```

### 5.3. DecodingOptions - Настройки декодирования

**Требования:**
- Язык: английский (`en`)
- Задача: транскрипция (`transcribe`)
- Температура: 0.0 (детерминированные результаты)
- Колбэки для прогресса и сегментов
- Временные метки на уровне слов

**Код конфигурации:**

```swift
var decodingOptions = DecodingOptions()

// Базовые настройки
decodingOptions.language = "en"              // Только английский
decodingOptions.task = .transcribe           // Транскрипция (не перевод)
decodingOptions.temperature = 0.0            // Детерминированный результат
decodingOptions.temperatureFallbackCount = 0 // Без fallback
decodingOptions.sampleLength = 224           // Длина аудио сегмента

// Временные метки
decodingOptions.wordTimestamps = true        // Метки на уровне слов
decodingOptions.clipTimestamps = [0]         // Начало с 0 секунды

// Колбэки для real-time обновлений
decodingOptions.progressCallback = { progress in
    DispatchQueue.main.async {
        // Обновить UI с прогрессом (0.0 - 1.0)
        self.updateProgress(progress.fractionCompleted)
    }
}

decodingOptions.segmentCallback = { segments in
    DispatchQueue.main.async {
        // Промежуточные результаты для отображения
        let intermediateText = segments.map { $0.text }.joined()
        self.updateIntermediateResult(intermediateText)
    }
}

// Детекция других языков (для предупреждения)
decodingOptions.detectLanguage = true        // Включить детекцию
```

### 5.4. Стратегия чанкинга (Chunking)

**Требования:**
- Автоматическая детекция чанков на основе VAD (Voice Activity Detection)
- Размер чанка: ~30 секунд (дефолт WhisperKit)
- Overlap для контекста между чанками

**Настройка:**

```swift
// WhisperKit использует автоматический чанкинг по умолчанию
// Настройка через AudioStreamTranscriber

let streamTranscriber = AudioStreamTranscriber(
    audioProcessor: whisperKit.audioProcessor,
    transcriber: whisperKit,
    decodingOptions: decodingOptions
)

// Конфигурация потока
streamTranscriber.transcribeChunk = { audioBuffer in
    // WhisperKit автоматически определяет границы чанков
    // на основе детекции голоса (VAD)
    return try await whisperKit.transcribe(
        audioArray: audioBuffer,
        decodeOptions: decodingOptions
    )
}
```

---

## 6. Real-time транскрипция

### 6.1. Архитектура AudioStreamTranscriber

**Поток данных:**

```
Микрофон → AVAudioEngine → Audio Buffer → 
AudioStreamTranscriber → WhisperKit → Результат → 
Колбэки → UI Update
```

### 6.2. Настройка AVAudioEngine

**Требования:**
- Формат: 16000 Hz, моно, Float32
- Размер буфера: оптимальный для real-time
- Audio session category: `.record`

**Код настройки:**

```swift
class AudioRecordingManager {
    private let audioEngine = AVAudioEngine()
    private var streamTranscriber: AudioStreamTranscriber?
    private let targetSampleRate: Double = 16000  // WhisperKit требует 16kHz
    
    func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: []
        )
        try audioSession.setActive(true)
    }
    
    func startRecording(
        whisperKit: WhisperKit,
        decodingOptions: DecodingOptions,
        delegate: TranscriptionDelegate
    ) throws {
        // Настроить audio session
        try setupAudioSession()
        
        // Создать AudioStreamTranscriber
        self.streamTranscriber = AudioStreamTranscriber(
            audioProcessor: whisperKit.audioProcessor,
            transcriber: whisperKit,
            decodingOptions: decodingOptions
        )
        
        // Настроить колбэки
        setupCallbacks(delegate: delegate)
        
        // Начать захват аудио
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Установить tap для захвата буферов
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        // Запустить audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        streamTranscriber?.stopTranscription()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Конвертировать в Float array
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(
            UnsafeBufferPointer(
                start: channelData[0],
                count: frameLength
            )
        )
        
        // Ресемплировать до 16kHz если нужно
        let resampledSamples = resampleIfNeeded(
            samples,
            from: buffer.format.sampleRate,
            to: targetSampleRate
        )
        
        // Передать в AudioStreamTranscriber
        Task {
            await streamTranscriber?.processAudioSamples(resampledSamples)
        }
    }
    
    private func resampleIfNeeded(
        _ samples: [Float],
        from sourceRate: Double,
        to targetRate: Double
    ) -> [Float] {
        guard sourceRate != targetRate else { return samples }
        
        // Простой linear resampling
        // Для production используйте vDSP или Accelerate framework
        let ratio = sourceRate / targetRate
        let newLength = Int(Double(samples.count) / ratio)
        var resampled: [Float] = []
        
        for i in 0..<newLength {
            let sourceIndex = Int(Double(i) * ratio)
            if sourceIndex < samples.count {
                resampled.append(samples[sourceIndex])
            }
        }
        
        return resampled
    }
}
```

### 6.3. Конфигурация колбэков

**Требования:**
- Прогресс колбэк: обновление UI индикатора прогресса
- Сегмент колбэк: отображение промежуточных результатов
- Все UI обновления на main thread

**Код колбэков:**

```swift
extension AudioRecordingManager {
    private func setupCallbacks(delegate: TranscriptionDelegate) {
        // Колбэк для прогресса транскрипции
        streamTranscriber?.onProgress = { progress in
            DispatchQueue.main.async {
                // progress.fractionCompleted: 0.0 - 1.0
                delegate.didUpdateProgress(progress.fractionCompleted)
            }
        }
        
        // Колбэк для промежуточных сегментов
        streamTranscriber?.onSegmentReceived = { segments in
            DispatchQueue.main.async {
                let intermediateText = segments
                    .map { $0.text }
                    .joined(separator: " ")
                delegate.didReceiveIntermediateResult(intermediateText)
            }
        }
        
        // Колбэк для финального результата
        streamTranscriber?.onTranscriptionComplete = { result in
            DispatchQueue.main.async {
                if let finalText = result?.text {
                    delegate.didReceiveFinalResult(finalText)
                }
            }
        }
        
        // Колбэк для ошибок
        streamTranscriber?.onError = { error in
            DispatchQueue.main.async {
                delegate.didEncounterError(error)
            }
        }
    }
}
```

---

## 7. Обработка результатов

### 7.1. Типы результатов

**WhisperKit возвращает:**

```swift
struct TranscriptionResult {
    let text: String                    // Весь транскрибированный текст
    let segments: [TranscriptionSegment] // Сегменты с временными метками
    let language: String                // Определенный язык
    let languageLogProbs: [String: Float] // Вероятности языков
}

struct TranscriptionSegment {
    let id: Int
    let text: String
    let start: Double                   // Время начала (секунды)
    let end: Double                     // Время окончания (секунды)
    let tokens: [Int]
    let temperature: Float
    let avgLogprob: Float
    let compressionRatio: Float
    let noSpeechProb: Float
    let words: [WordTiming]?            // Если включен wordTimestamps
}

struct WordTiming {
    let word: String
    let start: Double
    let end: Double
    let probability: Float
}
```

### 7.2. Отображение промежуточных результатов

**UI компонент:**

```swift
class TranscriptionViewController: UIViewController {
    // Промежуточные результаты (по мере говорения)
    private let intermediateLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "Начните говорить..."
        return label
    }()
    
    // Финальный текст (завершённые сегменты)
    private let finalTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 18, weight: .medium)
        textView.textColor = .label
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        return textView
    }()
    
    // Индикатор прогресса
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = 0.0
        return progress
    }()
}

// MARK: - TranscriptionDelegate
extension TranscriptionViewController: TranscriptionDelegate {
    func didReceiveIntermediateResult(_ text: String) {
        // Промежуточные результаты (серым цветом)
        intermediateLabel.text = text
        intermediateLabel.alpha = 0.7
    }
    
    func didReceiveFinalResult(_ text: String) {
        // Финальный результат добавляем в историю
        let currentText = finalTextView.text ?? ""
        let newText = currentText.isEmpty ? text : "\(currentText)\n\n\(text)"
        finalTextView.text = newText
        
        // Очистить промежуточные результаты
        intermediateLabel.text = ""
        
        // Автоскролл вниз
        let bottom = NSRange(location: finalTextView.text.count - 1, length: 1)
        finalTextView.scrollRangeToVisible(bottom)
    }
    
    func didUpdateProgress(_ progress: Float) {
        progressView.progress = progress
    }
    
    func didEncounterError(_ error: Error) {
        showErrorAlert(error)
    }
    
    func didDetectNonEnglishSpeech() {
        showLanguageWarning()
    }
}
```

### 7.3. Форматирование результатов с временными метками

**Опциональное форматирование:**

```swift
func formatResultWithTimestamps(_ result: TranscriptionResult) -> String {
    var formatted = ""
    
    for segment in result.segments {
        let startTime = formatTime(segment.start)
        let endTime = formatTime(segment.end)
        formatted += "[\(startTime) - \(endTime)] \(segment.text)\n"
    }
    
    return formatted
}

func formatTime(_ seconds: Double) -> String {
    let minutes = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", minutes, secs)
}

// Пример вывода:
// [00:00 - 00:03] Hello world
// [00:03 - 00:06] This is a test
```

---

## 8. Определение языка и валидация

### 8.1. Требования

- ✅ Модель настроена только на английский (`tiny-en`)
- ✅ При детекции другого языка показывать предупреждение
- ✅ Не блокировать транскрипцию, но уведомить пользователя
- ✅ Использовать `languageLogProbs` для детекции

### 8.2. Детекция неанглийской речи

**Алгоритм:**

```swift
class LanguageDetector {
    // Порог уверенности для английского языка
    private let englishConfidenceThreshold: Float = 0.7
    
    func isEnglishSpeech(result: TranscriptionResult) -> Bool {
        guard let englishProb = result.languageLogProbs["en"] else {
            return false
        }
        
        // Log probability конвертируем в вероятность
        let probability = exp(englishProb)
        
        return probability >= englishConfidenceThreshold
    }
    
    func getMostLikelyLanguage(result: TranscriptionResult) -> String {
        let sorted = result.languageLogProbs.sorted { $0.value > $1.value }
        return sorted.first?.key ?? "unknown"
    }
}
```

### 8.3. UI предупреждения

**Алерт при детекции неанглийской речи:**

```swift
extension TranscriptionViewController {
    func showLanguageWarning() {
        let alert = UIAlertController(
            title: "English Only",
            message: "Please speak English. This model is optimized for English language only.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "OK",
            style: .default
        ))
        
        // Добавить haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        
        present(alert, animated: true)
    }
    
    // Альтернатива: баннер вместо алерта
    func showLanguageWarningBanner() {
        let warningView = UIView()
        warningView.backgroundColor = .systemOrange
        warningView.layer.cornerRadius = 8
        
        let label = UILabel()
        label.text = "⚠️ Please speak English"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        
        // Анимация появления и исчезновения
        UIView.animate(withDuration: 0.3, animations: {
            warningView.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                warningView.alpha = 0.0
            })
        })
    }
}
```

### 8.4. Интеграция в поток транскрипции

```swift
extension AudioRecordingManager {
    private func setupCallbacks(delegate: TranscriptionDelegate) {
        streamTranscriber?.onTranscriptionComplete = { result in
            DispatchQueue.main.async {
                guard let result = result else { return }
                
                // Проверить язык
                let detector = LanguageDetector()
                if !detector.isEnglishSpeech(result: result) {
                    delegate.didDetectNonEnglishSpeech()
                }
                
                // Всё равно показать результат
                delegate.didReceiveFinalResult(result.text)
            }
        }
    }
}
```

---

## 9. Retry механизм

### 9.1. Типы ошибок требующих retry

1. **Network errors** - скачивание модели
2. **Model loading failures** - временные проблемы с памятью
3. **Transcription errors** - кратковременные сбои CoreML
4. **Audio processing errors** - проблемы с микрофоном

### 9.2. Стратегия retry

**Параметры:**
- Максимум попыток: **3**
- Базовая задержка: **1.0 секунда**
- Экспоненциальный backoff: `delay = baseDelay * 2^(attempt - 1)`
  - Попытка 1: немедленно
  - Попытка 2: через 1 секунду
  - Попытка 3: через 2 секунды
  - Попытка 4: через 4 секунды (не выполняется, так как maxRetries = 3)

### 9.3. Реализация RetryManager

```swift
class RetryManager {
    let maxRetries: Int
    let baseDelay: TimeInterval
    
    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }
    
    /// Выполнить операцию с автоматическими повторами
    func retry<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                // Попытка выполнить операцию
                return try await operation()
            } catch {
                lastError = error
                
                // Логирование
                print("⚠️ Attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Если это последняя попытка, прокинуть ошибку
                if attempt == maxRetries - 1 {
                    throw error
                }
                
                // Вычислить задержку
                let delay = calculateBackoff(attempt: attempt + 1)
                print("⏳ Retrying in \(delay) seconds...")
                
                // Подождать перед следующей попыткой
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Не должно сюда попадать, но для безопасности
        throw lastError ?? NSError(
            domain: "RetryManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All retries failed"]
        )
    }
    
    /// Вычислить экспоненциальную задержку
    private func calculateBackoff(attempt: Int) -> TimeInterval {
        return baseDelay * pow(2.0, Double(attempt - 1))
    }
}
```

### 9.4. Применение retry

**Пример: Инициализация с retry**

```swift
class WhisperKitManager {
    private let retryManager = RetryManager(maxRetries: 3, baseDelay: 1.0)
    
    func initialize() async throws {
        try await retryManager.retry {
            // Скачать модель (может упасть из-за сети)
            try await modelDownloadManager.downloadModelIfNeeded()
            
            // Инициализировать WhisperKit (может упасть из-за памяти)
            let config = WhisperKitConfig(model: "tiny-en")
            self.whisperKit = try await WhisperKit(config)
            
            print("✅ WhisperKit initialized successfully")
        }
    }
}
```

**Пример: Транскрипция с retry**

```swift
func transcribeWithRetry(audioPath: String) async throws -> TranscriptionResult? {
    return try await retryManager.retry {
        guard let whisperKit = self.whisperKit else {
            throw WhisperKitError.notInitialized
        }
        
        return try await whisperKit.transcribe(audioPath: audioPath)
    }
}
```

### 9.5. UI индикация retry

```swift
extension TranscriptionViewController {
    func showRetryIndicator(attempt: Int, maxAttempts: Int) {
        statusLabel.text = "Retry \(attempt)/\(maxAttempts)..."
        statusLabel.textColor = .systemOrange
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
```

---

## 10. Обработка ошибок

### 10.1. Типы ошибок WhisperKit

```swift
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
```

### 10.2. Маппинг ошибок на UI сообщения

```swift
extension WhisperKitError {
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
```

### 10.3. Глобальный обработчик ошибок

```swift
class ErrorHandler {
    weak var viewController: UIViewController?
    
    func handle(_ error: Error) {
        // Конвертировать в WhisperKitError
        let whisperError: WhisperKitError
        
        if let wkError = error as? WhisperKitError {
            whisperError = wkError
        } else {
            whisperError = .unknown(underlying: error)
        }
        
        // Логирование
        logError(whisperError)
        
        // Показать алерт пользователю
        showErrorAlert(whisperError)
        
        // Аналитика (опционально)
        trackError(whisperError)
    }
    
    private func logError(_ error: WhisperKitError) {
        print("❌ Error: \(error)")
        print("   Message: \(error.userFriendlyMessage)")
        
        // В production используйте профессиональную систему логирования
        // например: OSLog, CocoaLumberjack, или отправку в сервис аналитики
    }
    
    private func showErrorAlert(_ error: WhisperKitError) {
        DispatchQueue.main.async { [weak self] in
            guard let viewController = self?.viewController else { return }
            
            let alert = UIAlertController(
                title: "Ошибка",
                message: error.userFriendlyMessage,
                preferredStyle: .alert
            )
            
            // Основное действие
            let primaryAction = UIAlertAction(
                title: error.recoveryAction,
                style: .default
            ) { _ in
                self?.handleRecoveryAction(for: error)
            }
            alert.addAction(primaryAction)
            
            // Отмена
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
    
    private func handleRecoveryAction(for error: WhisperKitError) {
        switch error {
        case .microphonePermissionDenied:
            openAppSettings()
            
        case .modelDownloadFailed, .networkError:
            retryOperation()
            
        default:
            break
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func retryOperation() {
        // Повторить последнюю операцию
        // Реализация зависит от контекста
    }
    
    private func trackError(_ error: WhisperKitError) {
        // Отправить в аналитику (Firebase, Amplitude, etc.)
        // Analytics.logEvent("whisperkit_error", parameters: [...])
    }
}
```

### 10.4. Обработка специфичных ошибок

**Проверка разрешения на микрофон:**

```swift
func checkMicrophonePermission() async throws {
    let status = AVAudioSession.sharedInstance().recordPermission
    
    switch status {
    case .granted:
        return
        
    case .denied:
        throw WhisperKitError.microphonePermissionDenied
        
    case .undetermined:
        // Запросить разрешение
        let granted = await AVAudioSession.sharedInstance().requestRecordPermission()
        if !granted {
            throw WhisperKitError.microphonePermissionDenied
        }
        
    @unknown default:
        throw WhisperKitError.unknown(underlying: NSError(
            domain: "AVAudioSession",
            code: -1
        ))
    }
}
```

**Мониторинг памяти:**

```swift
class MemoryMonitor {
    func checkAvailableMemory() throws {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            throw WhisperKitError.unknown(underlying: NSError(
                domain: "MemoryMonitor",
                code: Int(kerr)
            ))
        }
        
        let usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
        let totalMemoryGB = ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024
        
        // Если используется >80% памяти, предупредить
        let memoryThreshold = Double(totalMemoryGB) * 0.8 * 1024  // в MB
        
        if usedMemoryMB > memoryThreshold {
            throw WhisperKitError.insufficientMemory
        }
    }
}
```

---

## 11. Best Practices

### 11.1. Управление памятью

**Правила:**

1. **Освобождать WhisperKit при уходе в background**

```swift
class WhisperKitManager {
    func applicationDidEnterBackground() {
        // Остановить транскрипцию
        stopTranscription()
        
        // Выгрузить модель из памяти
        whisperKit?.unloadModels()
        
        print("♻️ Models unloaded to free memory")
    }
    
    func applicationWillEnterForeground() async throws {
        // Перезагрузить модель
        try await initialize()
    }
}
```

2. **Использовать weak references для избежания retain cycles**

```swift
class AudioRecordingManager {
    weak var delegate: TranscriptionDelegate?  // ⬅️ weak
    
    private func setupCallbacks() {
        streamTranscriber?.onProgress = { [weak self] progress in
            self?.delegate?.didUpdateProgress(progress)
        }
    }
}
```

3. **Очищать аудио буферы**

```swift
func stopRecording() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    
    // Очистить буферы
    recordedSamples.removeAll()
    streamTranscriber = nil
}
```

### 11.2. Многопоточность

**Правила:**

1. **Все UI обновления на main thread**

```swift
DispatchQueue.main.async {
    self.intermediateLabel.text = text
    self.progressView.progress = progress
}
```

2. **Heavy операции на background**

```swift
Task.detached(priority: .userInitiated) {
    let result = try await whisperKit.transcribe(audioPath: path)
    
    await MainActor.run {
        self.displayResult(result)
    }
}
```

3. **Использовать actors для thread-safety (опционально)**

```swift
actor TranscriptionQueue {
    private var queue: [TranscriptionResult] = []
    
    func enqueue(_ result: TranscriptionResult) {
        queue.append(result)
    }
    
    func dequeue() -> TranscriptionResult? {
        queue.isEmpty ? nil : queue.removeFirst()
    }
}
```

### 11.3. Battery optimization

**Стратегии:**

1. **Останавливать транскрипцию при неактивности**

```swift
class TranscriptionViewController {
    private var inactivityTimer: Timer?
    
    func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: 30.0,  // 30 секунд
            repeats: false
        ) { [weak self] _ in
            self?.handleInactivity()
        }
    }
    
    private func handleInactivity() {
        // Остановить запись если нет активности
        stopRecording()
        showInactivityMessage()
    }
}
```

2. **Использовать энергоэффективные настройки аудио**

```swift
func setupAudioSession() throws {
    let audioSession = AVAudioSession.sharedInstance()
    
    try audioSession.setCategory(
        .record,
        mode: .measurement,  // ⬅️ Энергоэффективный режим
        options: []
    )
    
    // Отключить bluetooth если не нужен
    try audioSession.setPreferredInput(
        audioSession.availableInputs?.first(where: { $0.portType == .builtInMic })
    )
}
```

### 11.4. Permission handling

**Best practice:**

```swift
class PermissionManager {
    func requestMicrophonePermission() async -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            return true
            
        case .denied:
            // Показать инструкцию как включить
            await showPermissionDeniedInstructions()
            return false
            
        case .undetermined:
            // Показать объяснение ПЕРЕД запросом
            await showPermissionRationale()
            
            // Запросить разрешение
            return await AVAudioSession.sharedInstance().requestRecordPermission()
            
        @unknown default:
            return false
        }
    }
    
    @MainActor
    private func showPermissionRationale() async {
        // Показать экран объясняющий зачем нужен микрофон
        // Пользователь будет более склонен дать разрешение
    }
    
    @MainActor
    private func showPermissionDeniedInstructions() async {
        // Показать инструкцию: Settings → Privacy → Microphone → Your App
    }
}
```

### 11.5. UI responsiveness

**Правила:**

1. **Не блокировать main thread**

```swift
// ❌ ПЛОХО - блокирует UI
let result = try await whisperKit.transcribe(audioPath: path)
updateUI(result)

// ✅ ХОРОШО - UI остаётся responsive
Task {
    let result = try await whisperKit.transcribe(audioPath: path)
    await MainActor.run {
        updateUI(result)
    }
}
```

2. **Показывать loading индикаторы**

```swift
func startTranscription() async {
    showLoadingIndicator()
    
    do {
        try await whisperManager.startRealtimeTranscription(delegate: self)
        hideLoadingIndicator()
    } catch {
        hideLoadingIndicator()
        handleError(error)
    }
}
```

3. **Debounce UI updates для production**

```swift
class DebouncedUpdater {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }
    
    func debounce(_ action: @escaping () -> Void) {
        workItem?.cancel()
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
}

// Использование
let updater = DebouncedUpdater(delay: 0.3)

func didReceiveIntermediateResult(_ text: String) {
    updater.debounce {
        self.intermediateLabel.text = text
    }
}
```

---

## 12. Примеры кода

### 12.1. WhisperKitManager (полная реализация)

```swift
import Foundation
import WhisperKit
import AVFoundation

class WhisperKitManager {
    // MARK: - Singleton
    static let shared = WhisperKitManager()
    
    // MARK: - Properties
    private var whisperKit: WhisperKit?
    private let modelDownloadManager: ModelDownloadManager
    private let retryManager: RetryManager
    private var audioRecordingManager: AudioRecordingManager?
    private let errorHandler: ErrorHandler
    
    private var isInitialized = false
    
    // MARK: - Initialization
    private init() {
        self.modelDownloadManager = ModelDownloadManager()
        self.retryManager = RetryManager(maxRetries: 3, baseDelay: 1.0)
        self.errorHandler = ErrorHandler()
    }
    
    // MARK: - Public Methods
    
    /// Инициализация WhisperKit с моделью tiny-en
    func initialize() async throws {
        guard !isInitialized else {
            print("✅ WhisperKit already initialized")
            return
        }
        
        try await retryManager.retry {
            // 1. Скачать модель если нужно
            print("📥 Downloading model if needed...")
            try await modelDownloadManager.downloadModelIfNeeded()
            
            // 2. Настроить конфигурацию
            let config = createConfig()
            
            // 3. Инициализировать WhisperKit
            print("🚀 Initializing WhisperKit...")
            self.whisperKit = try await WhisperKit(config)
            
            self.isInitialized = true
            print("✅ WhisperKit initialized successfully")
        }
    }
    
    /// Начать real-time транскрипцию
    func startRealtimeTranscription(delegate: TranscriptionDelegate) throws {
        guard isInitialized, let whisperKit = whisperKit else {
            throw WhisperKitError.notInitialized
        }
        
        // Создать audio recording manager если нет
        if audioRecordingManager == nil {
            audioRecordingManager = AudioRecordingManager()
        }
        
        // Настроить decoding options
        let decodingOptions = createDecodingOptions(delegate: delegate)
        
        // Начать запись
        try audioRecordingManager?.startRecording(
            whisperKit: whisperKit,
            decodingOptions: decodingOptions,
            delegate: delegate
        )
    }
    
    /// Остановить транскрипцию
    func stopTranscription() {
        audioRecordingManager?.stopRecording()
    }
    
    /// Проверить готовность
    func isReady() -> Bool {
        return isInitialized && whisperKit != nil
    }
    
    /// Выгрузить модель (для экономии памяти)
    func unloadModels() {
        whisperKit?.unloadModels()
        isInitialized = false
        print("♻️ Models unloaded")
    }
    
    // MARK: - Private Methods
    
    private func createConfig() -> WhisperKitConfig {
        var config = WhisperKitConfig(
            model: "tiny-en",
            verbose: false,
            download: true,
            prewarm: true,
            load: true,
            modelFolder: modelDownloadManager.getCachePath()
        )
        
        // Настроить compute options для Neural Engine
        var computeOptions = ModelComputeOptions()
        computeOptions.audioEncoderCompute = .neuralEngine
        computeOptions.textDecoderCompute = .neuralEngine
        config.computeOptions = computeOptions
        
        return config
    }
    
    private func createDecodingOptions(delegate: TranscriptionDelegate) -> DecodingOptions {
        var options = DecodingOptions()
        
        // Базовые настройки
        options.language = "en"
        options.task = .transcribe
        options.temperature = 0.0
        options.wordTimestamps = true
        options.detectLanguage = true
        
        // Колбэки
        options.progressCallback = { progress in
            DispatchQueue.main.async {
                delegate.didUpdateProgress(Float(progress.fractionCompleted))
            }
        }
        
        options.segmentCallback = { segments in
            DispatchQueue.main.async {
                let text = segments.map { $0.text }.joined()
                delegate.didReceiveIntermediateResult(text)
            }
        }
        
        return options
    }
}

// MARK: - Errors
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
```

### 12.2. TranscriptionViewController (UIKit)

```swift
import UIKit

class TranscriptionViewController: UIViewController {
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
        if isRecording {
            stopRecording()
        } else {
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
        Task {
            do {
                // Проверить разрешение на микрофон
                try await checkMicrophonePermission()
                
                // Начать транскрипцию
                try whisperManager.startRealtimeTranscription(delegate: self)
                
                await MainActor.run {
                    isRecording = true
                    recordButton.isSelected = true
                    recordButton.backgroundColor = .systemRed
                    statusLabel.text = "Recording..."
                    statusLabel.textColor = .systemRed
                }
            } catch {
                await MainActor.run {
                    errorHandler.handle(error)
                }
            }
        }
    }
    
    private func stopRecording() {
        whisperManager.stopTranscription()
        
        isRecording = false
        recordButton.isSelected = false
        recordButton.backgroundColor = .systemBlue
        statusLabel.text = "Ready"
        statusLabel.textColor = .secondaryLabel
        intermediateLabel.text = ""
    }
    
    private func checkMicrophonePermission() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            return
        case .denied:
            throw WhisperKitError.microphonePermissionDenied
        case .undetermined:
            let granted = await AVAudioSession.sharedInstance().requestRecordPermission()
            if !granted {
                throw WhisperKitError.microphonePermissionDenied
            }
        @unknown default:
            throw WhisperKitError.unknown(underlying: NSError(domain: "Permission", code: -1))
        }
    }
}

// MARK: - TranscriptionDelegate
extension TranscriptionViewController: TranscriptionDelegate {
    func didReceiveIntermediateResult(_ text: String) {
        intermediateLabel.text = text
        intermediateLabel.alpha = 0.7
    }
    
    func didReceiveFinalResult(_ text: String) {
        let currentText = finalTextView.text ?? ""
        let timestamp = Date().formatted(date: .omitted, time: .shortened)
        let newText = currentText.isEmpty 
            ? "[\(timestamp)] \(text)" 
            : "\(currentText)\n\n[\(timestamp)] \(text)"
        
        finalTextView.text = newText
        intermediateLabel.text = ""
        
        // Scroll to bottom
        let bottom = NSRange(location: finalTextView.text.count - 1, length: 1)
        finalTextView.scrollRangeToVisible(bottom)
    }
    
    func didUpdateProgress(_ progress: Float) {
        progressView.progress = progress
    }
    
    func didEncounterError(_ error: Error) {
        errorHandler.handle(error)
        stopRecording()
    }
    
    func didDetectNonEnglishSpeech() {
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

// MARK: - TranscriptionDelegate Protocol
protocol TranscriptionDelegate: AnyObject {
    func didReceiveIntermediateResult(_ text: String)
    func didReceiveFinalResult(_ text: String)
    func didUpdateProgress(_ progress: Float)
    func didEncounterError(_ error: Error)
    func didDetectNonEnglishSpeech()
}
```

### 12.3. ModelDownloadManager

```swift
import Foundation

class ModelDownloadManager {
    private let modelName = "tiny-en"
    private let fileManager = FileManager.default
    
    /// Скачать модель если её нет в кэше
    func downloadModelIfNeeded() async throws {
        if hasCachedModel() {
            print("✅ Model already cached")
            return
        }
        
        print("📥 Downloading model '\(modelName)'...")
        
        // WhisperKit автоматически скачает модель при инициализации
        // с параметром download: true
        
        // Здесь можно добавить дополнительную логику:
        // - Показать прогресс скачивания
        // - Валидация скачанной модели
        // - Fallback на другую модель если скачивание не удалось
    }
    
    /// Проверить наличие кэшированной модели
    func hasCachedModel() -> Bool {
        let cachePath = getCachePath()
        return fileManager.fileExists(atPath: cachePath.path)
    }
    
    /// Получить путь к кэшу моделей
    func getCachePath() -> URL {
        let documentsPath = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        return documentsPath
            .appendingPathComponent("whisperkit_models")
            .appendingPathComponent(modelName)
    }
    
    /// Очистить кэш моделей
    func clearCache() throws {
        let cachePath = getCachePath()
        
        if fileManager.fileExists(atPath: cachePath.path) {
            try fileManager.removeItem(at: cachePath)
            print("🗑️ Cache cleared")
        }
    }
    
    /// Получить размер кэша
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
    func formattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
```

---

## 13. Чек-лист и критерии приемки

### 13.1. Чек-лист разработки

#### Фаза 1: Настройка проекта
- [ ] Добавить WhisperKit через SPM (версия 0.14.0+)
- [ ] Настроить Info.plist (микрофон permission)
- [ ] Настроить минимальную версию iOS 16.0
- [ ] Создать файловую структуру проекта

#### Фаза 2: Базовая инициализация
- [ ] Реализовать WhisperKitManager (singleton)
- [ ] Реализовать ModelDownloadManager
- [ ] Настроить конфигурацию для tiny-en модели
- [ ] Настроить ModelComputeOptions для Neural Engine
- [ ] Протестировать инициализацию на устройстве

#### Фаза 3: Real-time транскрипция
- [ ] Реализовать AudioRecordingManager
- [ ] Настроить AVAudioEngine
- [ ] Реализовать audio buffer processing
- [ ] Настроить AudioStreamTranscriber
- [ ] Настроить колбэки (progress, segments)
- [ ] Реализовать resampling до 16kHz

#### Фаза 4: UI (UIKit)
- [ ] Создать TranscriptionViewController
- [ ] Реализовать layout (Auto Layout)
- [ ] Добавить промежуточные результаты (UILabel)
- [ ] Добавить финальные результаты (UITextView)
- [ ] Добавить кнопку записи (UIButton)
- [ ] Добавить индикатор прогресса (UIProgressView)
- [ ] Добавить индикатор загрузки (UIActivityIndicatorView)

#### Фаза 5: Определение языка
- [ ] Реализовать LanguageDetector
- [ ] Настроить detectLanguage в DecodingOptions
- [ ] Реализовать UI алерт для неанглийской речи
- [ ] Протестировать на разных языках

#### Фаза 6: Retry механизм
- [ ] Реализовать RetryManager
- [ ] Настроить экспоненциальную задержку
- [ ] Интегрировать retry в инициализацию
- [ ] Интегрировать retry в транскрипцию
- [ ] Добавить UI индикацию retry

#### Фаза 7: Обработка ошибок
- [ ] Определить enum WhisperKitError
- [ ] Реализовать ErrorHandler
- [ ] Маппинг ошибок на user-friendly сообщения
- [ ] Реализовать recovery actions
- [ ] Протестировать все сценарии ошибок

#### Фаза 8: Оптимизация
- [ ] Реализовать выгрузку моделей при background
- [ ] Добавить мониторинг памяти
- [ ] Оптимизировать audio session для батареи
- [ ] Реализовать debouncing для UI updates
- [ ] Добавить инструментацию для профилирования

#### Фаза 9: Best Practices
- [ ] Проверить все weak references
- [ ] Проверить все UI updates на main thread
- [ ] Добавить haptic feedback
- [ ] Реализовать permission flow
- [ ] Добавить логирование (debug/production)

#### Фаза 10: Тестирование
- [ ] Unit тесты для WhisperKitManager
- [ ] Unit тесты для RetryManager
- [ ] UI тесты для TranscriptionViewController
- [ ] Тесты на реальных устройствах (iPhone 11, 12, 13, 14, 15)
- [ ] Тесты производительности
- [ ] Тесты памяти (Memory Graph)

### 13.2. Критерии приемки

#### Функциональные требования

| № | Требование | Критерий |
|---|------------|----------|
| 1 | Инициализация WhisperKit | Модель `tiny-en` загружается за <5 секунд на iPhone 12+ |
| 2 | Real-time транскрипция | Промежуточные результаты обновляются каждые 1-2 секунды |
| 3 | Точность распознавания | >85% точности на чистой английской речи |
| 4 | Определение языка | Детекция неанглийской речи с точностью >90% |
| 5 | Retry механизм | Успешный retry при временных ошибках сети/памяти |
| 6 | Обработка ошибок | Все ошибки имеют понятные пользователю сообщения |
| 7 | UI responsiveness | UI не замерзает даже при активной транскрипции |
| 8 | Кэширование модели | Модель скачивается только один раз |
| 9 | Neural Engine | Используется Neural Engine на iPhone с A12+ |
| 10 | Offline работа | Транскрипция работает без интернета после первого скачивания |

#### Нефункциональные требования

| № | Требование | Критерий |
|---|------------|----------|
| 1 | Производительность | Транскрипция в real-time без задержек |
| 2 | Память | Использование <200MB RAM при активной транскрипции |
| 3 | Батарея | <10% батареи в час при непрерывной транскрипции |
| 4 | Стабильность | Нет крашей при 30-минутной непрерывной работе |
| 5 | Качество кода | SwiftLint warnings = 0, code coverage >70% |
| 6 | Документация | Все public методы имеют комментарии |
| 7 | Совместимость | Работа на iOS 16.0 - 18.x |
| 8 | Accessibility | Поддержка VoiceOver и Dynamic Type |

### 13.3. Тестовые сценарии

#### Сценарий 1: Первый запуск
1. Установить приложение
2. Запустить приложение
3. Дождаться скачивания модели
4. Проверить: модель скачалась, UI готов
5. Проверить: модель кэширована в Documents

#### Сценарий 2: Real-time транскрипция
1. Нажать кнопку "Start Recording"
2. Разрешить доступ к микрофону
3. Начать говорить по-английски
4. Проверить: промежуточные результаты появляются
5. Остановить запись
6. Проверить: финальный текст сохранён

#### Сценарий 3: Неанглийская речь
1. Начать запись
2. Говорить на русском/испанском/французском
3. Проверить: появляется алерт "Please speak English"
4. Проверить: транскрипция всё равно работает (показывает результат)

#### Сценарий 4: Ошибка сети (первый запуск без интернета)
1. Отключить интернет
2. Запустить приложение (первый раз)
3. Проверить: алерт "Проверьте подключение к интернету"
4. Включить интернет
5. Нажать "Повторить"
6. Проверить: модель скачивается успешно

#### Сценарий 5: Работа в background
1. Начать транскрипцию
2. Перевести приложение в background
3. Проверить: транскрипция остановилась
4. Вернуться в foreground
5. Проверить: модель перезагружена, можно продолжить

#### Сценарий 6: Нехватка памяти
1. Запустить много других приложений
2. Попытаться начать транскрипцию
3. Проверить: алерт "Недостаточно памяти"
4. Закрыть другие приложения
5. Повторить попытку
6. Проверить: транскрипция работает

### 13.4. Метрики производительности

#### Измерения на iPhone 12 Pro

| Метрика | Целевое значение | Метод измерения |
|---------|------------------|-----------------|
| Время инициализации (первый запуск) | <10 секунд | Замер от launch до "Ready" |
| Время инициализации (повторный) | <3 секунды | Замер от launch до "Ready" |
| Latency транскрипции | <500ms | Время от речи до отображения |
| Использование RAM | <200MB | Instruments Memory Graph |
| Использование CPU | <30% | Instruments CPU Profiler |
| Батарея (30 мин работы) | <5% | Instruments Energy Log |
| Размер кэша модели | ~40MB | File Manager |
| FPS UI во время работы | 60 FPS | Instruments Core Animation |

### 13.5. Критичные баги (блокируют релиз)

- ❌ Краш при инициализации
- ❌ Краш при транскрипции
- ❌ Утечки памяти (memory leaks)
- ❌ UI блокируется на >1 секунду
- ❌ Транскрипция не работает на поддерживаемых устройствах
- ❌ Модель не скачивается / не кэшируется
- ❌ Нет обработки отказа в доступе к микрофону

### 13.6. Некритичные баги (можно отложить)

- ⚠️ Задержка транскрипции >1 секунды
- ⚠️ Неточная транскрипция с сильным акцентом
- ⚠️ UI глюки на iOS 16.0 (если работает на 16.1+)
- ⚠️ Детекция языка ошибается в <10% случаев
- ⚠️ Retry срабатывает не всегда

---

## Приложения

### A. Полезные ссылки

- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)
- [WhisperKit Documentation](https://swiftpackageindex.com/argmaxinc/WhisperKit)
- [Модели на HuggingFace](https://huggingface.co/argmaxinc/whisperkit-coreml)
- [Apple CoreML Documentation](https://developer.apple.com/documentation/coreml)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)

### B. Контакты

- **Техническая поддержка:** [Ваш email]
- **Вопросы по ТЗ:** [Ваш email]
- **Срок реализации:** [Указать дедлайн]

---

**Конец технического задания**

*Версия 1.0 от 18 октября 2025*
