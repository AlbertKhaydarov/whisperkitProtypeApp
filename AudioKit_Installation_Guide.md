# Инструкция по добавлению AudioKit в проект

## Шаг 1: Добавление AudioKit через Swift Package Manager

1. Откройте проект в Xcode
2. Выберите в меню: File > Swift Packages > Add Package Dependency...
3. Вставьте URL репозитория AudioKit: `https://github.com/AudioKit/AudioKit.git`
4. Выберите последнюю версию (рекомендуется 5.6.0 или новее)
5. Выберите "AudioKit" в списке продуктов для добавления
6. Нажмите "Finish"

## Шаг 2: Настройка проекта для работы с AudioKit

1. Выберите целевой проект (target) в навигаторе проектов
2. Перейдите на вкладку "Build Phases"
3. Убедитесь, что "AudioKit" добавлен в секцию "Link Binary With Libraries"
4. Перейдите на вкладку "Build Settings"
5. Найдите "Other Linker Flags" и добавьте `-lc++` если его там нет

## Шаг 3: Импорт AudioKit в коде

В файлах, где используется AudioKit, добавьте импорт:

```swift
import AudioKit
```

## Шаг 4: Обновление Info.plist для доступа к микрофону

Добавьте следующие ключи в Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Приложение использует микрофон для записи и распознавания речи</string>
```

## Возможные проблемы и их решения

### Ошибка "No such module 'AudioKit'"

1. Закройте Xcode
2. Удалите папку DerivedData: `~/Library/Developer/Xcode/DerivedData`
3. Откройте проект заново
4. Выполните Clean (Cmd+Shift+K) и Build (Cmd+B)

### Ошибки линковки

Если возникают ошибки линковки, убедитесь что:
- В "Other Linker Flags" добавлен флаг `-lc++`
- В "Framework Search Paths" добавлен путь к AudioKit
- В "Header Search Paths" добавлен путь к заголовочным файлам AudioKit

### Проблемы с совместимостью

AudioKit требует iOS 13.0 или новее. Убедитесь, что в настройках проекта установлен соответствующий минимальный iOS Target.
