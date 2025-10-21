# SwiftWhisper Integration Project Brief

## 🎯 Project Goal
Develop an iOS application for real-time speech recognition (speech-to-text) using SwiftWhisper library, working completely offline with local model processing.

## 📱 Application Purpose
**Real-time Voice Transcription App** - An iOS application that captures speech from microphone in real-time and converts it to text using SwiftWhisper models running locally on the device with minimal latency.

## 🎨 Key Features
- **Real-time transcription** with live intermediate results display
- **Offline operation** - all models work on-device without internet
- **Neural Engine optimization** - maximum performance on iPhone
- **English language detection** - recognizes only English speech with notifications
- **Retry mechanism** - automatic retry attempts for errors
- **Professional error handling** - user-friendly error messages

## 🛠️ Technical Stack
- **Platform:** iOS 15.0+
- **Framework:** UIKit (SwiftUI запрещен)
- **Language:** Swift 6.0+
- **AI Library:** SwiftWhisper 0.14.0+
- **Architecture:** MVP with delegates (no Combine/closures)
- **Audio:** AVAudioEngine for real-time capture
- **Models:** tiny.en, base.en, small.en (English-only)
- **Dependencies:** Минимальные - только SwiftWhisper + AVFoundation

## 🎯 Target Users
- Users who need real-time speech-to-text conversion
- Professionals requiring offline transcription
- English speakers who need accurate voice recognition
- Users with iPhone 8+ (A12+ recommended for Neural Engine)

## 📊 Success Criteria
- Real-time transcription with <500ms latency
- >85% accuracy on clean English speech
- Offline operation after initial model download
- Stable performance for 30+ minutes continuous use
- User-friendly error handling and recovery
