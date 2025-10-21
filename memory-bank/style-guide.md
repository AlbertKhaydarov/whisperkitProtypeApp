# SwiftWhisper App Style Guide

## 🎨 Design Philosophy

**Minimalist Real-time Transcription Interface**
- Clean, distraction-free design for focused transcription work
- iOS-native appearance following Human Interface Guidelines
- High contrast for accessibility and clarity
- Smooth animations for state transitions

## 🎨 Color Palette

### Primary Colors
- **System Blue**: `#007AFF` - Primary actions, active states
- **System Green**: `#34C759` - Success states, ready indicators
- **System Red**: `#FF3B30` - Error states, stop actions
- **System Orange**: `#FF9500` - Warning states, loading indicators

### Neutral Colors
- **System Background**: `#FFFFFF` (Light) / `#000000` (Dark)
- **System Secondary Background**: `#F2F2F7` (Light) / `#1C1C1E` (Dark)
- **System Label**: `#000000` (Light) / `#FFFFFF` (Dark)
- **System Secondary Label**: `#3C3C43` (Light) / `#EBEBF5` (Dark)
- **System Tertiary Label**: `#3C3C43` (Light) / `#EBEBF5` (Dark)

### Status Colors
- **Recording**: `#FF3B30` (Red) - Active recording state
- **Ready**: `#34C759` (Green) - System ready state
- **Loading**: `#FF9500` (Orange) - Processing state
- **Error**: `#FF3B30` (Red) - Error states

## 📝 Typography

### Font Hierarchy
- **Large Title**: 34pt, Semibold - App title
- **Title 1**: 28pt, Regular - Section headers
- **Title 2**: 22pt, Regular - Subsection headers
- **Title 3**: 20pt, Regular - Component headers
- **Headline**: 17pt, Semibold - Button text, important labels
- **Body**: 17pt, Regular - Main content text
- **Callout**: 16pt, Regular - Secondary content
- **Subhead**: 15pt, Regular - Captions, metadata
- **Footnote**: 13pt, Regular - Small text, timestamps
- **Caption 1**: 12pt, Regular - Very small text
- **Caption 2**: 11pt, Regular - Smallest text

### Font Families
- **Primary**: San Francisco (SF Pro Display, SF Pro Text)
- **Monospace**: SF Mono (for technical content)

## 📏 Spacing System

### Base Unit: 8pt
- **XS**: 4pt (0.5x)
- **S**: 8pt (1x)
- **M**: 16pt (2x)
- **L**: 24pt (3x)
- **XL**: 32pt (4x)
- **XXL**: 40pt (5x)
- **XXXL**: 48pt (6x)

### Layout Spacing
- **Screen Margins**: 16pt (M)
- **Component Padding**: 16pt (M)
- **Element Spacing**: 8pt (S)
- **Section Spacing**: 24pt (L)

## 🎛️ Component Styles

### Buttons

#### Primary Button (Start/Stop)
```swift
// Start State
backgroundColor = .systemBlue
titleColor = .white
cornerRadius = 12
font = .systemFont(ofSize: 17, weight: .semibold)
contentEdgeInsets = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)

// Stop State
backgroundColor = .systemRed
titleColor = .white
cornerRadius = 12
font = .systemFont(ofSize: 17, weight: .semibold)
contentEdgeInsets = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)

// Disabled State
backgroundColor = .systemGray
titleColor = .systemGray2
isEnabled = false
```

#### Secondary Button
```swift
backgroundColor = .clear
titleColor = .systemBlue
borderWidth = 1
borderColor = .systemBlue
cornerRadius = 8
font = .systemFont(ofSize: 15, weight: .medium)
```

### Progress Indicators

#### Progress Bar
```swift
progressTintColor = .systemBlue
trackTintColor = .systemGray5
cornerRadius = 4
height = 8
```

#### Activity Indicator
```swift
color = .systemBlue
style = .large
hidesWhenStopped = true
```

### Text Views

#### Results Text View
```swift
backgroundColor = .systemBackground
textColor = .label
font = .systemFont(ofSize: 17)
cornerRadius = 8
borderWidth = 1
borderColor = .systemGray4
contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
```

#### Status Label
```swift
textColor = .secondaryLabel
font = .systemFont(ofSize: 15, weight: .medium)
textAlignment = .center
numberOfLines = 1
```

### Cards and Containers

#### Main Container
```swift
backgroundColor = .systemBackground
cornerRadius = 12
shadowColor = .black
shadowOffset = CGSize(width: 0, height: 2)
shadowRadius = 8
shadowOpacity = 0.1
```

#### Content Card
```swift
backgroundColor = .secondarySystemBackground
cornerRadius = 8
borderWidth = 1
borderColor = .systemGray5
```

## 🎭 Animation Guidelines

### Transition Durations
- **Fast**: 0.2s - Button presses, quick state changes
- **Medium**: 0.3s - UI transitions, modal presentations
- **Slow**: 0.5s - Complex animations, loading states

### Easing Curves
- **Ease In Out**: Standard UI transitions
- **Ease Out**: Button press feedback
- **Ease In**: Loading animations
- **Linear**: Progress bars, continuous animations

### Animation Examples
```swift
// Button Press Animation
UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
    self.startButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
} completion: { _ in
    UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseIn]) {
        self.startButton.transform = .identity
    }
}

// Progress Animation
UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
    self.progressView.setProgress(progress, animated: true)
}

// Text Update Animation
UIView.transition(with: self.resultsTextView, duration: 0.3, options: [.transitionCrossDissolve]) {
    self.resultsTextView.text = newText
}
```

## ♿ Accessibility Guidelines

### VoiceOver Support
- **Labels**: Descriptive labels for all interactive elements
- **Hints**: Clear instructions for complex interactions
- **Traits**: Proper accessibility traits (button, static text, etc.)
- **Values**: Dynamic values for progress indicators

### Dynamic Type Support
- **Scalable Text**: All text scales with user preferences
- **Layout Adaptation**: UI adapts to larger text sizes
- **Minimum Sizes**: Maintain readability at all sizes

### High Contrast Support
- **Color Adaptation**: Colors adapt to high contrast mode
- **Border Enhancement**: Enhanced borders for better visibility
- **Icon Clarity**: Clear, high-contrast icons

### Accessibility Examples
```swift
// VoiceOver Labels
startButton.accessibilityLabel = "Start transcription"
startButton.accessibilityHint = "Double tap to begin recording"
progressView.accessibilityLabel = "Download progress"
resultsTextView.accessibilityLabel = "Transcription results"

// Dynamic Type
resultsTextView.font = UIFont.preferredFont(forTextStyle: .body)
statusLabel.font = UIFont.preferredFont(forTextStyle: .caption1)

// High Contrast Adaptation
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColorsForAccessibility()
}
```

## 📱 Responsive Design

### iPhone Layout
- **Portrait**: Single column layout with vertical stacking
- **Landscape**: Optimized for horizontal viewing
- **Safe Areas**: Respect safe area insets
- **Notch Support**: Proper handling of notch and home indicator

### iPad Layout
- **Portrait**: Centered content with side margins
- **Landscape**: Wider content area with better spacing
- **Split View**: Adapts to split view and slide over
- **Multitasking**: Supports all multitasking modes

### Layout Examples
```swift
// iPhone Portrait
let margins: CGFloat = 16
let buttonHeight: CGFloat = 60
let progressHeight: CGFloat = 8

// iPad Layout
let margins: CGFloat = 32
let maxWidth: CGFloat = 600
let buttonHeight: CGFloat = 60
```

## 🎨 Iconography

### System Icons (SF Symbols)
- **Microphone**: `mic.fill` - Recording state
- **Stop**: `stop.fill` - Stop recording
- **Play**: `play.fill` - Start recording
- **Download**: `arrow.down.circle` - Download progress
- **Checkmark**: `checkmark.circle.fill` - Success state
- **Exclamation**: `exclamationmark.triangle.fill` - Warning state
- **X Mark**: `xmark.circle.fill` - Error state

### Custom Icons
- **App Icon**: Whisper-themed microphone icon
- **Status Icons**: Custom status indicators
- **Progress Icons**: Custom progress indicators

## 🔄 State Management

### Visual States
- **Loading**: Orange progress indicator with "Loading..." text
- **Ready**: Green checkmark with "Ready to start" text
- **Recording**: Red indicator with "Recording..." text
- **Processing**: Orange spinner with "Processing..." text
- **Error**: Red X with error message

### State Transitions
- **Smooth**: All state changes use smooth animations
- **Clear**: Each state has distinct visual indicators
- **Consistent**: Same transition patterns throughout app
- **Accessible**: State changes announced to VoiceOver

## 📊 Performance Guidelines

### Animation Performance
- **60fps**: All animations target 60fps
- **Efficient**: Use transform animations over frame changes
- **Smooth**: Avoid janky or stuttering animations
- **Responsive**: Immediate feedback for user interactions

### Memory Management
- **Efficient**: Minimize memory usage for animations
- **Cleanup**: Proper cleanup of animation resources
- **Optimization**: Use efficient animation techniques
- **Monitoring**: Monitor memory usage during animations

## ✅ Style Guide Compliance

### Design Review Checklist
- [ ] Colors match defined palette
- [ ] Typography follows hierarchy
- [ ] Spacing uses base unit system
- [ ] Components follow defined styles
- [ ] Animations use specified durations
- [ ] Accessibility guidelines followed
- [ ] Responsive design implemented
- [ ] Performance targets met

### Implementation Checklist
- [ ] All colors defined as system colors
- [ ] Typography uses preferred fonts
- [ ] Spacing uses consistent values
- [ ] Components implement defined styles
- [ ] Animations follow guidelines
- [ ] Accessibility features implemented
- [ ] Responsive layouts created
- [ ] Performance optimized
