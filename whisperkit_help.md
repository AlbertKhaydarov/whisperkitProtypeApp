# 🎙️ Полная инструкция по интеграции WhisperKit в iOS приложение

> **WhisperKit** — это Swift-библиотека для распознавания речи (speech-to-text) на устройствах Apple с полностью оффлайн работой через CoreML.

---

## 📋 Содержание

1. [Установка](#-1-установка)
2. [Быстрый старт](#-2-быстрый-старт)
3. [Основные API функции](#-3-основные-api-функции)
4. [Продвинутая конфигурация](#-4-продвинутая-конфигурация)
5. [Работа с результатами](#-5-работа-с-результатами)
6. [Полные примеры реализации](#-6-полные-примеры-реализации)
7. [Оптимизация и производительность](#-7-оптимизация-и-производительность)
8. [Работа с языками](#-8-работа-с-языками)
9. [Обработка ошибок](#-9-обработка-ошибок)
10. [Best Practices](#-10-best-practices)

---

## 🚀 1. Установка

### Требования

- **iOS 16.0+** / macOS 13.0+ / watchOS 10.0+ / visionOS 1.0+
- **Xcode 15.0+**
- **Swift 5.9+**

### Установка через Swift Package Manager

#### Вариант 1: Через Xcode (рекомендуется)

1. Откройте ваш проект в Xcode
2. Перейдите в **File → Add Package Dependencies...**
3. Вставьте URL репозитория:
   ```
   https://github.com/argmaxinc/whisperkit
   ```
4. Выберите версию: **0.14.0** или **Up to Next Major Version**
5. Нажмите **Add Package**

#### Вариант 2: Через Package.swift

Добавьте в файл `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.14.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["WhisperKit"]
    )
]
```

### Импорт в код

```swift
import WhisperKit
```

---

## ⚡ 2. Быстрый старт

### Минимальный пример (3 строки кода)

```swift
import WhisperKit

Task {
    let whisperKit = try await WhisperKit()
    let result = try await whisperKit.transcribe(audioPath: "path/to/audio.mp3")
    print(result?.text ?? "Нет результата")
}
```

### Что происходит под капотом:

1. ✅ Автоматически определяется оптимальная модель для вашего устройства
2. ✅ Модель скачивается (если еще не скачана)
3. ✅ Модель загружается в память
4. ✅ Аудио файл обрабатывается и распознается

---

## 🔧 3. Основные API функции

### 3.1. Инициализация WhisperKit

#### Базовая инициализация

```swift
let whisperKit = try await WhisperKit()
```

#### С выбором конкретной модели

```swift
let whisperKit = try await WhisperKit(
    WhisperKitConfig(model: "small-en")
)
```

#### С полной конфигурацией

```swift
let config = WhisperKitConfig(
    model: "small-en",
    verbose: true,              // Подробные логи
    download: true,             // Автоскачивание модели
    prewarm: true,             // Предзагрузка для ускорения
    load: true                 // Загрузить модель сразу
)

let whisperKit = try await WhisperKit(config)
```

### 3.2. Доступные модели

| Модель | Размер | Языки | Скорость | Точность | Использование |
|--------|--------|-------|----------|----------|---------------|
| `tiny-en` | ~30 MB | Английский | ⚡⚡⚡⚡⚡ | ⭐⭐ | Real-time, быстрые ответы |
| `base-en` | ~70 MB | Английский | ⚡⚡⚡⚡ | ⭐⭐⭐ | Баланс скорости и качества |
| `small-en` | ~250 MB | Английский | ⚡⚡⚡ | ⭐⭐⭐⭐ | Хорошая точность |
| `medium-en` | ~750 MB | Английский | ⚡⚡ | ⭐⭐⭐⭐⭐ | Высокая точность |
| `large-v3` | ~1.5 GB | 100+ языков | ⚡ | ⭐⭐⭐⭐⭐ | Максимальная точность |
| `distil-large-v3` | ~800 MB | 100+ языков | ⚡⚡ | ⭐⭐⭐⭐ | Дистиллированная версия |

**Примечание:** Модели с суффиксом `-en` работают только с английским языком, но быстрее и требуют меньше памяти.

### 3.3. Распознавание речи из файла

#### Базовое распознавание

```swift
let result = try await whisperKit.transcribe(audioPath: "path/to/audio.mp3")
print(result?.text ?? "")
```

**Поддерживаемые форматы:** `.wav`, `.mp3`, `.m4a`, `.flac`

#### С настройками декодирования

```swift
var options = DecodingOptions()
options.language = "ru"           // Русский язык
options.task = .transcribe        // Или .translate для перевода в английский
options.temperature = 0.0         // Детерминированный результат

let result = try await whisperKit.transcribe(
    audioPath: audioPath,
    decodeOptions: options
)
print(result?.text ?? "")
```

### 3.4. Распознавание с временными метками

```swift
var options = DecodingOptions()
options.wordTimestamps = true     // Метки для каждого слова

let result = try await whisperKit.transcribe(
    audioPath: audioPath,
    decodeOptions: options
)

// Обработка результатов с метками
if let segments = result?.segments {
    for segment in segments {
        print("[\(segment.start)s - \(segment.end)s]: \(segment.text)")
        
        // Метки на уровне слов
        if options.wordTimestamps {
            for token in segment.tokens {
                print("  '\(token.text)' at \(token.timestamp)s")
            }
        }
    }
}
```

### 3.5. Распознавание с колбэками прогресса и сегментов

```swift
let result = try await whisperKit.transcribe(
    audioArray: audioSamples,  // или используйте audioPath для файла
    decodeOptions: options,
    callback: { progress in
        // TranscriptionCallback - отслеживание прогресса транскрипции
        DispatchQueue.main.async {
            print("Текущий текст: \(progress.text)")
            print("Прогресс: \(progress.timings)")
        }
        return nil  // Вернуть nil для продолжения или false для отмены
    },
    segmentCallback: { segments in
        // SegmentDiscoveryCallback - получение сегментов по мере их распознавания
        DispatchQueue.main.async {
            for segment in segments {
                print("Новый сегмент [\(segment.start)s - \(segment.end)s]: \(segment.text)")
            }
        }
    }
)
```

### 3.6. Распознавание массива аудио-данных

Для обработки предзаписанного аудио из массива:

```swift
// audioSamples - массив Float с частотой 16000 Hz
let audioSamples: [Float] = // ... получено с микрофона или файла

var options = DecodingOptions()
options.language = "ru"

let result = try await whisperKit.transcribe(
    audioArray: audioSamples,
    decodeOptions: options
)

print(result?.text ?? "")
```

### 3.7. Real-time транскрипция с микрофона (AudioStreamTranscriber)

Для непрерывной транскрипции в реальном времени используйте `AudioStreamTranscriber`:

```swift
import WhisperKit

class RealtimeTranscriptionManager {
    private var streamTranscriber: AudioStreamTranscriber?
    private var whisperKit: WhisperKit?
    
    func initialize() async throws {
        // Инициализируем WhisperKit
        whisperKit = try await WhisperKit(
            WhisperKitConfig(model: "tiny-en")  // Используйте быструю модель для real-time
        )
        
        guard let kit = whisperKit,
              let audioEncoder = kit.audioEncoder as? AudioEncoder,
              let featureExtractor = kit.featureExtractor as? FeatureExtractor,
              let textDecoder = kit.textDecoder as? TextDecoder,
              let tokenizer = kit.tokenizer else {
            throw NSError(domain: "WhisperKit components not initialized", code: -1)
        }
        
        // Создаем AudioStreamTranscriber
        streamTranscriber = AudioStreamTranscriber(
            audioEncoder: audioEncoder,
            featureExtractor: featureExtractor,
            segmentSeeker: kit.segmentSeeker,
            textDecoder: textDecoder,
            tokenizer: tokenizer,
            audioProcessor: kit.audioProcessor,
            decodingOptions: DecodingOptions(language: "ru"),
            requiredSegmentsForConfirmation: 2,  // Количество сегментов для подтверждения
            silenceThreshold: 0.3,                // Порог тишины для VAD
            useVAD: true,                         // Использовать Voice Activity Detection
            stateChangeCallback: { oldState, newState in
                // Обработка изменений состояния
                DispatchQueue.main.async {
                    print("✅ Подтвержденный текст: \(newState.confirmedSegments.map { $0.text }.joined())")
                    print("⏳ Неподтвержденный текст: \(newState.unconfirmedSegments.map { $0.text }.joined())")
                    print("🎤 Текущий текст: \(newState.currentText)")
                }
            }
        )
    }
    
    // Начать real-time транскрипцию
    func startTranscription() async throws {
        try await streamTranscriber?.startStreamTranscription()
    }
    
    // Остановить транскрипцию
    func stopTranscription() async {
        await streamTranscriber?.stopStreamTranscription()
    }
}

// Использование
let manager = RealtimeTranscriptionManager()
try await manager.initialize()
try await manager.startTranscription()  // Начинает слушать микрофон
// ... пользователь говорит ...
await manager.stopTranscription()      // Останавливает транскрипцию
```

#### Состояние AudioStreamTranscriber

```swift
public struct State {
    public var isRecording: Bool                          // Идет ли запись
    public var currentText: String                        // Текущий распознаваемый текст
    public var confirmedSegments: [TranscriptionSegment]  // Подтвержденные сегменты
    public var unconfirmedSegments: [TranscriptionSegment] // Неподтвержденные сегменты
    public var bufferEnergy: [Float]                      // Энергия аудио буфера (для визуализации)
    public var lastConfirmedSegmentEndSeconds: Float      // Время окончания последнего подтвержденного сегмента
}
```

### 3.8. Определение языка

```swift
let (language, probabilities) = try await whisperKit.detectLanguage(
    audioPath: audioPath
)

print("Обнаружен язык: \(language)")
print("Вероятности:")
for (lang, prob) in probabilities.sorted(by: { $0.value > $1.value }).prefix(5) {
    print("  \(lang): \(String(format: "%.2f%%", prob * 100))")
}
```

### 3.9. Пакетная обработка файлов

```swift
let audioPaths = [
    "recording1.m4a",
    "recording2.m4a",
    "recording3.m4a"
]

let results = await whisperKit.transcribeWithResults(
    audioPaths: audioPaths,
    decodeOptions: DecodingOptions(language: "ru")
)

for (index, result) in results.enumerated() {
    switch result {
    case .success(let transcriptions):
        print("Файл \(index + 1): \(transcriptions.first?.text ?? "")")
    case .failure(let error):
        print("Ошибка в файле \(index + 1): \(error.localizedDescription)")
    }
}
```

---

## ⚙️ 4. Продвинутая конфигурация

### 4.1. WhisperKitConfig - Настройки инициализации

```swift
let config = WhisperKitConfig(
    // Модель
    model: "small-en",                    // Название модели
    modelRepo: "argmaxinc/whisperkit-coreml",  // HuggingFace репозиторий
    modelFolder: nil,                     // Локальная папка с моделью
    
    // Загрузка
    download: true,                       // Скачивать если нет
    load: true,                          // Загружать в память сразу
    prewarm: true,                       // Предзагрузка для ускорения
    
    // Вычисления
    computeOptions: ModelComputeOptions(
        audioEncoderCompute: .cpuAndNeuralEngine,
        textDecoderCompute: .cpuAndGPU,
        melCompute: .cpuAndGPU
    ),
    
    // Логирование
    verbose: true,                        // Подробные логи
    logLevel: .info                      // Уровень логирования
)

let whisperKit = try await WhisperKit(config)
```

### 4.2. ModelComputeOptions - Выбор процессора

```swift
let computeOptions = ModelComputeOptions(
    audioEncoderCompute: .cpuAndNeuralEngine,  // Encoder на Neural Engine
    textDecoderCompute: .cpuAndGPU,            // Decoder на GPU
    melCompute: .cpuAndGPU,                    // Mel Spectrogram на GPU
    prefillCompute: .cpuOnly                   // Prefill на CPU
)
```

**Доступные варианты:**
- `.cpuOnly` - только CPU (медленно)
- `.cpuAndGPU` - CPU + GPU (рекомендуется)
- `.cpuAndNeuralEngine` - CPU + Neural Engine (быстро на Apple Silicon)
- `.all` - все доступные процессоры

### 4.3. DecodingOptions - Настройки декодирования

```swift
var options = DecodingOptions(
    // Основные настройки
    verbose: false,                      // Подробные логи декодирования
    task: .transcribe,                  // .transcribe или .translate
    language: "ru",                     // Код языка или nil для автоопределения
    
    // Временные метки
    wordTimestamps: true,               // Метки для каждого слова
    withoutTimestamps: false,           // Без временных меток (быстрее)
    
    // Температура (случайность)
    temperature: 0.0,                   // 0.0 = детерминированно
    temperatureIncrementOnFallback: 0.2,
    temperatureFallbackCount: 5,
    
    // Пороги качества
    compressionRatioThreshold: 2.4,     // Порог сжатия текста
    logProbThreshold: -1.0,             // Порог вероятности логита
    noSpeechThreshold: 0.6,             // Порог определения тишины
    
    // Чанкинг (разбивка длинных аудио)
    chunkingStrategy: .vad,             // Разбивка по Voice Activity Detection
    
    // Промпт и префикс
    promptTokens: nil,                  // Токены промпта для контекста
    prefixTokens: nil                   // Токены префикса
)

let result = try await whisperKit.transcribe(
    audioPath: audioPath,
    decodeOptions: options
)
```

### 4.4. Стратегии чанкинга

Для длинных аудио файлов (>30 секунд):

```swift
var options = DecodingOptions()

// Автоматическая разбивка по детекции голоса (рекомендуется)
options.chunkingStrategy = .vad

// Разбивка по фиксированным временным меткам
options.clipTimestamps = [0.0, 30.0, 60.0, 90.0]  // секунды

let result = try await whisperKit.transcribe(
    audioPath: longAudioPath,
    decodeOptions: options
)
```

---

## 📊 5. Работа с результатами

### 5.1. Структура TranscriptionResult

```swift
struct TranscriptionResult {
    let text: String                           // Полный текст транскрипции
    let segments: [TranscriptionSegment]       // Сегменты с метками
    let language: String                       // Определённый язык
    let timings: TranscriptionTimings          // Время обработки
}
```

### 5.2. Структура TranscriptionSegment

```swift
struct TranscriptionSegment {
    let id: Int                    // ID сегмента
    let seek: Int                  // Позиция поиска
    let start: Float               // Начало (секунды)
    let end: Float                 // Конец (секунды)
    let text: String               // Текст сегмента
    let tokens: [Int]              // Токены
    let temperature: Float         // Температура декодирования
    let avgLogprob: Float         // Средняя лог-вероятность
    let compressionRatio: Float   // Коэффициент сжатия
    let noSpeechProb: Float       // Вероятность отсутствия речи
}
```

### 5.3. Примеры обработки результатов

#### Получение полного текста

```swift
let result = try await whisperKit.transcribe(audioPath: audioPath)
let fullText = result?.text ?? ""
print(fullText)
```

#### Обработка сегментов

```swift
if let segments = result?.segments {
    for (index, segment) in segments.enumerated() {
        print("Сегмент \(index + 1):")
        print("  Время: \(segment.start)s - \(segment.end)s")
        print("  Текст: \(segment.text)")
        print("  Вероятность речи: \(String(format: "%.2f%%", (1 - segment.noSpeechProb) * 100))")
    }
}
```

#### Создание субтитров (SRT формат)

```swift
func generateSRT(from result: TranscriptionResult?) -> String {
    guard let segments = result?.segments else { return "" }
    
    var srtContent = ""
    for (index, segment) in segments.enumerated() {
        let startTime = formatSRTTime(segment.start)
        let endTime = formatSRTTime(segment.end)
        
        srtContent += "\(index + 1)\n"
        srtContent += "\(startTime) --> \(endTime)\n"
        srtContent += "\(segment.text.trimmingCharacters(in: .whitespaces))\n\n"
    }
    
    return srtContent
}

func formatSRTTime(_ seconds: Float) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    let millis = Int((seconds - Float(Int(seconds))) * 1000)
    
    return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
}
```

---

## 💼 6. Полные примеры реализации

### 6.1. Менеджер транскрипции (класс)

```swift
import WhisperKit
import AVFoundation
import Combine

class TranscriptionManager: ObservableObject {
    @Published var isLoading = false
    @Published var transcriptionText = ""
    @Published var progress: Double = 0.0
    @Published var error: Error?
    
    private var whisperKit: WhisperKit?
    
    // Инициализация WhisperKit
    func initialize(model: String = "small-en") async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let config = WhisperKitConfig(
                model: model,
                verbose: true,
                prewarm: true
            )
            whisperKit = try await WhisperKit(config)
        } catch {
            self.error = error
            print("Ошибка инициализации: \(error)")
        }
    }
    
    // Транскрипция файла
    func transcribe(audioPath: String, language: String = "ru") async {
        guard let kit = whisperKit else {
            self.error = NSError(domain: "WhisperKit не инициализирован", code: -1)
            return
        }
        
        isLoading = true
        transcriptionText = ""
        progress = 0.0
        defer { isLoading = false }
        
        do {
            var options = DecodingOptions()
            options.language = language
            options.wordTimestamps = true
            
            let result = try await kit.transcribe(
                audioPath: audioPath,
                decodeOptions: options,
                callback: { [weak self] progressUpdate in
                    DispatchQueue.main.async {
                        self?.progress = progressUpdate.fractionCompleted
                    }
                },
                segmentCallback: { [weak self] segments in
                    DispatchQueue.main.async {
                        let newText = segments.map { $0.text }.joined()
                        self?.transcriptionText += newText
                    }
                }
            )
            
            DispatchQueue.main.async {
                self.transcriptionText = result?.text ?? ""
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            print("Ошибка транскрипции: \(error)")
        }
    }
    
    // Определение языка
    func detectLanguage(audioPath: String) async -> String? {
        guard let kit = whisperKit else { return nil }
        
        do {
            let (language, _) = try await kit.detectLanguage(audioPath: audioPath)
            return language
        } catch {
            self.error = error
            return nil
        }
    }
}
```

### 6.2. SwiftUI View с транскрипцией

```swift
import SwiftUI

struct TranscriptionView: View {
    @StateObject private var manager = TranscriptionManager()
    @State private var selectedAudioURL: URL?
    @State private var showFilePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Кнопка выбора файла
                Button(action: { showFilePicker = true }) {
                    Label("Выбрать аудио файл", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                
                // Прогресс
                if manager.isLoading {
                    VStack {
                        ProgressView(value: manager.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("Обработка: \(Int(manager.progress * 100))%")
                            .font(.caption)
                    }
                    .padding()
                }
                
                // Результат
                ScrollView {
                    Text(manager.transcriptionText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Транскрипция речи")
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio],
                onCompletion: handleFileSelection
            )
            .task {
                await manager.initialize()
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            selectedAudioURL = url
            Task {
                await manager.transcribe(audioPath: url.path)
            }
        case .failure(let error):
            print("Ошибка выбора файла: \(error)")
        }
    }
}
```

### 6.3. Запись с микрофона и транскрипция

```swift
import AVFoundation
import WhisperKit

class MicrophoneRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""
    
    private var audioEngine: AVAudioEngine?
    private var recordedSamples: [Float] = []
    private var whisperKit: WhisperKit?
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    func initialize() async {
        do {
            whisperKit = try await WhisperKit(
                WhisperKitConfig(model: "tiny-en")  // Быстрая модель для real-time
            )
        } catch {
            print("Ошибка инициализации: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }
    
    func startRecording() {
        recordedSamples.removeAll()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine?.start()
            isRecording = true
        } catch {
            print("Ошибка начала записи: \(error)")
        }
    }
    
    func stopRecording() async {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        isRecording = false
        
        // Транскрипция записанного аудио
        await transcribeRecordedAudio()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        recordedSamples.append(contentsOf: samples)
    }
    
    private func transcribeRecordedAudio() async {
        guard let kit = whisperKit, !recordedSamples.isEmpty else { return }
        
        // Ресемплинг до 16000 Hz (если нужно)
        let resampledSamples = resample(recordedSamples, to: 16000)
        
        do {
            let result = try await kit.transcribe(
                audioArray: resampledSamples,
                decodeOptions: DecodingOptions(language: "ru")
            )
            
            DispatchQueue.main.async {
                self.transcriptionText = result?.text ?? ""
            }
        } catch {
            print("Ошибка транскрипции: \(error)")
        }
    }
    
    private func resample(_ samples: [Float], to targetRate: Int) -> [Float] {
        // Упрощённый ресемплинг (для production используйте vDSP)
        return samples
    }
}
```

### 6.4. Транскрипция видео файла

```swift
import AVFoundation
import WhisperKit

class VideoTranscriber {
    private var whisperKit: WhisperKit?
    
    func initialize() async throws {
        whisperKit = try await WhisperKit(
            WhisperKitConfig(model: "small-en")
        )
    }
    
    func transcribeVideo(url: URL) async throws -> TranscriptionResult? {
        // Извлечение аудио из видео
        let audioURL = try await extractAudio(from: url)
        
        // Транскрипция аудио
        guard let kit = whisperKit else {
            throw NSError(domain: "WhisperKit не инициализирован", code: -1)
        }
        
        return try await kit.transcribe(audioPath: audioURL.path)
    }
    
    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(domain: "Не удалось создать export session", code: -1)
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            return outputURL
        } else {
            throw exportSession.error ?? NSError(domain: "Ошибка экспорта", code: -1)
        }
    }
}
```

---

## ⚡ 7. Оптимизация и производительность

### 7.1. Выбор модели в зависимости от устройства

```swift
func selectOptimalModel(for device: String) -> String {
    let deviceName = device.lowercased()
    
    if deviceName.contains("iphone 15 pro") || deviceName.contains("iphone 16") {
        return "medium-en"  // Мощные устройства
    } else if deviceName.contains("iphone 13") || deviceName.contains("iphone 14") {
        return "small-en"   // Средние устройства
    } else {
        return "tiny-en"    // Старые устройства
    }
}

// Использование
let deviceModel = UIDevice.current.model
let optimalModel = selectOptimalModel(for: deviceModel)
let whisperKit = try await WhisperKit(WhisperKitConfig(model: optimalModel))
```

### 7.2. Предзагрузка модели при запуске приложения

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    var whisperKit: WhisperKit?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Асинхронная загрузка модели в фоне
        Task {
            do {
                let config = WhisperKitConfig(
                    model: "small-en",
                    prewarm: true,  // Важно!
                    load: true
                )
                whisperKit = try await WhisperKit(config)
                print("✅ WhisperKit готов к использованию")
            } catch {
                print("❌ Ошибка загрузки WhisperKit: \(error)")
            }
        }
        
        return true
    }
}
```

### 7.3. Кэширование моделей

```swift
// Проверка наличия модели локально
func isModelDownloaded(modelName: String) -> Bool {
    let modelPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("huggingface")
        .appendingPathComponent("models")
        .appendingPathComponent("argmaxinc--whisperkit-coreml")
        .appendingPathComponent("openai_whisper-\(modelName)")
    
    return FileManager.default.fileExists(atPath: modelPath.path)
}

// Использование локальной модели
if isModelDownloaded(modelName: "small-en") {
    print("Модель уже загружена, используем локальную версию")
}
```

### 7.4. Оптимизация для длинных аудио

```swift
// Для файлов > 10 минут используйте чанкинг
var options = DecodingOptions()
options.chunkingStrategy = .vad  // Разбивка по детекции голоса

// Отключите метки слов для ускорения
options.wordTimestamps = false

// Увеличьте concurrentWorkerCount
options.concurrentWorkerCount = 4

let result = try await whisperKit.transcribe(
    audioPath: longAudioPath,
    decodeOptions: options
)
```

### 7.5. Мониторинг использования памяти

```swift
func printMemoryUsage() {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        print("Использовано памяти: \(String(format: "%.2f", usedMB)) MB")
    }
}

// Вызов после загрузки модели
printMemoryUsage()
```

---

## 🌍 8. Работа с языками

### 8.1. Поддерживаемые языки

WhisperKit поддерживает **100+ языков** при использовании multilingual моделей (`large-v3`, `distil-large-v3`).

**Основные языки:**
- Русский: `ru`
- Английский: `en`
- Испанский: `es`
- Французский: `fr`
- Немецкий: `de`
- Китайский: `zh`
- Японский: `ja`
- Корейский: `ko`
- Арабский: `ar`
- Хинди: `hi`

[Полный список языков](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py)

### 8.2. Автоопределение языка

```swift
var options = DecodingOptions()
options.language = nil          // Не указываем язык
options.detectLanguage = true   // Включаем автоопределение

let result = try await whisperKit.transcribe(
    audioPath: audioPath,
    decodeOptions: options
)

print("Определён язык: \(result?.language ?? "unknown")")
```

### 8.3. Перевод на английский

```swift
var options = DecodingOptions()
options.task = .translate  // Переводить в английский
options.language = "ru"    // Исходный язык

let result = try await whisperKit.transcribe(
    audioPath: russianAudioPath,
    decodeOptions: options
)

print("Перевод: \(result?.text ?? "")")
```

### 8.4. Мультиязычная транскрипция

```swift
func transcribeMultilingual(audioPaths: [String]) async {
    let whisperKit = try! await WhisperKit(
        WhisperKitConfig(model: "large-v3")  // Multilingual модель
    )
    
    for path in audioPaths {
        // Сначала определяем язык
        let (language, _) = try! await whisperKit.detectLanguage(audioPath: path)
        print("Обнаружен язык: \(language)")
        
        // Транскрибируем с определённым языком
        var options = DecodingOptions()
        options.language = language
        
        let result = try! await whisperKit.transcribe(
            audioPath: path,
            decodeOptions: options
        )
        
        print("Транскрипция [\(language)]: \(result?.text ?? "")")
    }
}
```

---

## 🚨 9. Обработка ошибок

### 9.1. Типы ошибок WhisperKit

```swift
enum WhisperError: Error {
    case modelsUnavailable(String)
    case tokenizerUnavailable()
    case transcriptionFailed(String)
    case audioProcessingFailed(String)
    case decodingFailed(String)
}
```

### 9.2. Правильная обработка ошибок

```swift
func safeTranscribe(audioPath: String) async -> String {
    do {
        let whisperKit = try await WhisperKit()
        let result = try await whisperKit.transcribe(audioPath: audioPath)
        return result?.text ?? "Нет результата"
        
    } catch let error as WhisperError {
        switch error {
        case .modelsUnavailable(let message):
            print("Модель недоступна: \(message)")
            return "Ошибка: Не удалось загрузить модель"
            
        case .tokenizerUnavailable:
            print("Токенайзер недоступен")
            return "Ошибка: Проблема с токенайзером"
            
        case .transcriptionFailed(let message):
            print("Транскрипция не удалась: \(message)")
            return "Ошибка транскрипции"
            
        case .audioProcessingFailed(let message):
            print("Ошибка обработки аудио: \(message)")
            return "Ошибка: Некорректный аудио файл"
            
        case .decodingFailed(let message):
            print("Ошибка декодирования: \(message)")
            return "Ошибка декодирования"
        }
        
    } catch {
        print("Неожиданная ошибка: \(error.localizedDescription)")
        return "Неизвестная ошибка"
    }
}
```

### 9.3. Retry механизм

```swift
func transcribeWithRetry(
    audioPath: String,
    maxAttempts: Int = 3
) async -> TranscriptionResult? {
    var attempt = 0
    var lastError: Error?
    
    while attempt < maxAttempts {
        do {
            let whisperKit = try await WhisperKit()
            let result = try await whisperKit.transcribe(audioPath: audioPath)
            return result
            
        } catch {
            lastError = error
            attempt += 1
            print("Попытка \(attempt) не удалась: \(error)")
            
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 секунды
            }
        }
    }
    
    print("Все попытки исчерпаны. Последняя ошибка: \(lastError?.localizedDescription ?? "unknown")")
    return nil
}
```

---

## ✅ 10. Best Practices

### 10.1. Выбор модели

```swift
// ✅ ПРАВИЛЬНО: Выбор в зависимости от задачи
let realtimeKit = try await WhisperKit(WhisperKitConfig(model: "tiny-en"))  // Real-time
let accurateKit = try await WhisperKit(WhisperKitConfig(model: "small-en")) // Баланс
let preciseKit = try await WhisperKit(WhisperKitConfig(model: "large-v3"))  // Точность

// ❌ НЕПРАВИЛЬНО: Использование large-v3 для real-time
let slowKit = try await WhisperKit(WhisperKitConfig(model: "large-v3"))  // Слишком медленно!
```

### 10.2. Управление жизненным циклом

```swift
class TranscriptionService {
    private var whisperKit: WhisperKit?
    
    // ✅ Инициализация один раз при старте
    func initialize() async {
        guard whisperKit == nil else { return }  // Не инициализируем повторно
        
        whisperKit = try? await WhisperKit(
            WhisperKitConfig(model: "small-en", prewarm: true)
        )
    }
    
    // ✅ Переиспользование экземпляра
    func transcribe(audioPath: String) async -> String? {
        guard let kit = whisperKit else {
            await initialize()
            guard let kit = whisperKit else { return nil }
            return try? await kit.transcribe(audioPath: audioPath)?.text
        }
        
        return try? await kit.transcribe(audioPath: audioPath)?.text
    }
    
    // ✅ Очистка при необходимости
    func cleanup() async {
        await whisperKit?.unloadModels()
        whisperKit = nil
    }
}
```

### 10.3. Оптимизация настроек

```swift
// ✅ ПРАВИЛЬНО: Настройки для конкретной задачи
func getOptionsForUseCase(_ useCase: UseCase) -> DecodingOptions {
    var options = DecodingOptions()
    
    switch useCase {
    case .realtime:
        options.temperature = 0.0
        options.wordTimestamps = false
        options.withoutTimestamps = true
        
    case .subtitles:
        options.wordTimestamps = true
        options.temperature = 0.0
        
    case .meeting:
        options.chunkingStrategy = .vad
        options.wordTimestamps = true
        
    case .voiceNote:
        options.temperature = 0.0
        options.compressionRatioThreshold = 2.4
    }
    
    return options
}

enum UseCase {
    case realtime, subtitles, meeting, voiceNote
}
```

### 10.4. Работа с большими файлами

```swift
// ✅ ПРАВИЛЬНО: Обработка больших файлов
func transcribeLargeFile(audioPath: String) async -> TranscriptionResult? {
    var options = DecodingOptions()
    options.chunkingStrategy = .vad       // Разбивка по VAD
    options.wordTimestamps = false        // Отключить для скорости
    options.concurrentWorkerCount = 4     // Параллельная обработка
    
    return try? await whisperKit.transcribe(
        audioPath: audioPath,
        decodeOptions: options
    )
}

// ❌ НЕПРАВИЛЬНО: Без оптимизации
func transcribeLargeFileSlow(audioPath: String) async -> TranscriptionResult? {
    return try? await whisperKit.transcribe(audioPath: audioPath)
}
```

### 10.5. Обработка прерываний

```swift
class SafeTranscriber {
    private var currentTask: Task<Void, Never>?
    
    func transcribe(audioPath: String) {
        // Отменяем предыдущую задачу
        currentTask?.cancel()
        
        currentTask = Task {
            do {
                let result = try await whisperKit.transcribe(audioPath: audioPath)
                
                // Проверяем, не была ли отменена задача
                guard !Task.isCancelled else { return }
                
                // Обрабатываем результат
                print(result?.text ?? "")
                
            } catch {
                guard !Task.isCancelled else { return }
                print("Ошибка: \(error)")
            }
        }
    }
    
    func cancelTranscription() {
        currentTask?.cancel()
    }
}
```

### 10.6. Логирование и отладка

```swift
// ✅ Включайте verbose во время разработки
let debugConfig = WhisperKitConfig(
    model: "small-en",
    verbose: true,
    logLevel: .debug
)

// ✅ Отключайте в production
let productionConfig = WhisperKitConfig(
    model: "small-en",
    verbose: false,
    logLevel: .error
)

// Кастомный логгер
whisperKit.loggingCallback { message in
    // Отправка в аналитику или файл
    print("[WhisperKit] \(message)")
}
```

---

## 📚 Дополнительные ресурсы

### Официальная документация
- [GitHub репозиторий](https://github.com/argmaxinc/WhisperKit)
- [Swift Package Index](https://swiftpackageindex.com/argmaxinc/WhisperKit)
- [Примеры приложений](https://github.com/argmaxinc/WhisperKit/tree/main/Examples)

### Модели
- [HuggingFace модели](https://huggingface.co/argmaxinc/whisperkit-coreml)
- [Бенчмарки производительности](https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks)

### Сообщество
- [Discord канал](https://discord.gg/G5F5GZGecC)
- [Twitter @argmaxinc](https://twitter.com/argmaxinc)

---

## 🎯 Краткая шпаргалка

```swift
// Базовая инициализация
let kit = try await WhisperKit()

// Транскрипция файла
let result = try await kit.transcribe(audioPath: "audio.mp3")
print(result?.text ?? "")

// С настройками
var options = DecodingOptions()
options.language = "ru"
options.wordTimestamps = true

let result = try await kit.transcribe(
    audioPath: "audio.mp3",
    decodeOptions: options
)

// Обработка сегментов
for segment in result?.segments ?? [] {
    print("[\(segment.start)s - \(segment.end)s]: \(segment.text)")
}

// Определение языка
let (language, _) = try await kit.detectLanguage(audioPath: "audio.mp3")
print("Язык: \(language)")

// Перевод на английский
options.task = .translate
let translation = try await kit.transcribe(audioPath: "audio.mp3", decodeOptions: options)
```

---

**Версия документа:** 1.0  
**Дата создания:** 18 октября 2025  
**Версия WhisperKit:** 0.14.0+

**Лицензия:** MIT License

---

*Эта инструкция создана на основе официальной документации WhisperKit и актуальна на момент создания. Для получения последних обновлений проверяйте официальный репозиторий на GitHub.*
