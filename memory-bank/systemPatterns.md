# System Patterns - SwiftWhisper Integration

## 🏗️ Architectural Patterns

### MVP (Model-View-Presenter) Pattern
- **View**: TranscriptionViewController (UIKit)
- **Presenter**: RecognitionPresenter (бизнес-логика)
- **Model**: WhisperKitManager + сервисы

### Singleton Pattern
- **WhisperKitManager** - единая точка координации
- **ErrorHandler** - централизованная обработка ошибок

### Delegate Pattern
- **TranscriptionDelegate** - коммуникация между компонентами
- **AudioCaptureDelegate** - события аудио захвата
- **ModelDownloadDelegate** - прогресс загрузки моделей

### Actor Pattern (Swift 6)
- **WhisperKitManager** - потокобезопасная работа с моделью
- **AudioRecordingManager** - безопасная обработка аудио

## 🔄 Data Flow Patterns

### Audio Processing Pipeline
```
Microphone → AVAudioEngine → AVAudioConverter → 16kHz PCM → SwiftWhisper → Text Segments
```

### Model Management Flow
```
App Launch → Check Cache → Download (if needed) → Warmup → Ready State
```

### Error Handling Flow
```
Error Occurred → RetryManager → Exponential Backoff → Retry → Success/Failure
```

## 🎯 Design Patterns

### State Machine Pattern
- **App States**: Loading, Ready, Recording, Error
- **Recording States**: Idle, Starting, Active, Stopping
- **Model States**: NotLoaded, Downloading, Warming, Ready

### Observer Pattern (via Delegates)
- UI обновления через делегаты
- Прогресс загрузки через делегаты
- Результаты транскрипции через делегаты

### Factory Pattern
- **ModelFactory** - создание экземпляров моделей
- **AudioConverterFactory** - создание конвертеров аудио

## 🔧 Technical Patterns

### Async/Await Pattern
```swift
// Загрузка модели
func loadModel() async throws -> URL {
    let modelURL = try await downloadManager.downloadModel()
    try await whisperManager.loadModel(from: modelURL)
    return modelURL
}

// Прогрев модели
func warmupModel() async throws {
    try await whisperManager.warmup()
}
```

### Error Handling Pattern
```swift
// Централизованная обработка ошибок
func handleError(_ error: Error) {
    let userMessage = errorHandler.userFriendlyMessage(for: error)
    retryManager.scheduleRetry(for: error)
    delegate?.didEncounterError(userMessage)
}
```

### Resource Management Pattern
```swift
// Управление ресурсами
class WhisperKitManager {
    private var whisper: Whisper?
    
    deinit {
        whisper = nil // Освобождение ресурсов
    }
}
```

## 📱 UI Patterns

### State-Based UI Updates
```swift
// Обновление UI на основе состояния
func updateUI(for state: AppState) {
    switch state {
    case .loading:
        showProgressView()
        disableStartButton()
    case .ready:
        hideProgressView()
        enableStartButton()
    case .recording:
        updateButtonToStop()
        showRecordingIndicator()
    }
}
```

### Progress Indication Pattern
```swift
// Универсальный прогресс
protocol ProgressDelegate: AnyObject {
    func didUpdateProgress(_ progress: Double)
    func didCompleteProgress()
    func didFailProgress(with error: Error)
}
```

## 🔒 Security Patterns

### Permission Management
```swift
// Запрос разрешений
func requestMicrophonePermission() async -> Bool {
    return await audioSession.requestRecordPermission()
}
```

### Data Validation
```swift
// Валидация аудио данных
func validateAudioData(_ data: [Float]) -> Bool {
    return !data.isEmpty && data.count >= minimumFrameSize
}
```

## 📊 Performance Patterns

### Lazy Loading
```swift
// Ленивая загрузка модели
lazy private var whisper: Whisper = {
    return Whisper(fromFileURL: modelURL)
}()
```

### Caching Pattern
```swift
// Кэширование моделей
class ModelCache {
    private let cacheDirectory: URL
    private var cachedModels: [String: URL] = [:]
}
```

### Memory Management
```swift
// Управление памятью
func releaseResources() {
    whisper = nil
    audioEngine.stop()
    audioEngine.reset()
}
```

## 🧪 Testing Patterns

### Mock Pattern
```swift
// Моки для тестирования
protocol WhisperKitManagerProtocol {
    func loadModel(from url: URL) async throws
    func transcribe(audioFrames: [Float]) -> [Segment]
}

class MockWhisperKitManager: WhisperKitManagerProtocol {
    // Mock implementation
}
```

### Dependency Injection
```swift
// Внедрение зависимостей
class RecognitionPresenter {
    private let whisperManager: WhisperKitManagerProtocol
    private let audioManager: AudioRecordingManagerProtocol
    
    init(whisperManager: WhisperKitManagerProtocol, 
         audioManager: AudioRecordingManagerProtocol) {
        self.whisperManager = whisperManager
        self.audioManager = audioManager
    }
}
```

## 🔄 Integration Patterns

### Service Layer Pattern
```swift
// Слой сервисов
protocol ServiceProtocol {
    func start() async throws
    func stop() async throws
    func reset() async throws
}
```

### Event-Driven Pattern
```swift
// Событийно-ориентированная архитектура
protocol EventDelegate: AnyObject {
    func didReceiveEvent(_ event: SystemEvent)
}
```

## 📋 Pattern Compliance Checklist

```
✓ ARCHITECTURAL PATTERNS
- MVP Pattern implemented? [YES/NO]
- Singleton Pattern used appropriately? [YES/NO]
- Delegate Pattern for communication? [YES/NO]
- Actor Pattern for thread safety? [YES/NO]

✓ DESIGN PATTERNS
- State Machine Pattern for app states? [YES/NO]
- Observer Pattern via delegates? [YES/NO]
- Factory Pattern for object creation? [YES/NO]

✓ TECHNICAL PATTERNS
- Async/Await for async operations? [YES/NO]
- Centralized error handling? [YES/NO]
- Proper resource management? [YES/NO]

✓ UI PATTERNS
- State-based UI updates? [YES/NO]
- Progress indication pattern? [YES/NO]
- Responsive UI design? [YES/NO]

✓ SECURITY PATTERNS
- Permission management? [YES/NO]
- Data validation? [YES/NO]
- Secure data storage? [YES/NO]

✓ PERFORMANCE PATTERNS
- Lazy loading implemented? [YES/NO]
- Caching strategy? [YES/NO]
- Memory management? [YES/NO]

✓ TESTING PATTERNS
- Mock pattern for testing? [YES/NO]
- Dependency injection? [YES/NO]
- Testable architecture? [YES/NO]
```
