# VT-Polyglot

A multilingual learning app built with Flutter for web and mobile platforms.

## Features

- Interactive lessons
- Progress tracking
- Offline mode
- Gamification
- Speech recognition
- Multimedia content
- AI-powered recommendations

## Setup

1. **Install Flutter**: Download and install Flutter SDK from [flutter.dev](https://flutter.dev/docs/get-started/install/windows).

2. **Enable Web Support** (optional for web builds):
   ```
   flutter config --enable-web
   ```

3. **Install Dependencies**:
   ```
   flutter pub get
   ```

4. **Run the App**:
   - For web: `flutter run -d chrome`
   - For Android: `flutter run -d android` (requires Android Studio and emulator)
   - For iOS: `flutter run -d ios` (requires macOS and Xcode)

## Building

- Web: `flutter build web`
- APK: `flutter build apk`
- iOS: `flutter build ios`

## Project Structure

- `lib/`: Dart source code
- `pubspec.yaml`: Project dependencies
- `android/`: Android-specific files (generated)
- `ios/`: iOS-specific files (generated)
- `web/`: Web-specific files (generated)

## Contributing

Add features for lessons, progress, etc., in the `lib/` directory.