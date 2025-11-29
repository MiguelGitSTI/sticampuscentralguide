# STI Campus Central Guide

A comprehensive Flutter mobile application designed to help STI students and staff navigate campus life. The app provides essential campus information, class schedules, event updates, FAQs, and interactive campus maps.

## Features

- **User Authentication** - Secure login and registration via Firebase Auth
- **Home Dashboard** - Quick access to announcements, alerts, and campus updates
- **Class Schedule** - View and manage your class timetable with reminder notifications
- **Campus Map** - Interactive map for navigating the campus
- **Events Hub** - Stay updated with campus events and activities
- **FAQ Section** - Quick answers to frequently asked questions
- **Push Notifications** - Receive important alerts and reminders
- **Dark/Light Theme** - Customizable app appearance
- **Admin Panel** - Administrative features for content management

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

| Software | Version | Download Link |
|----------|---------|---------------|
| Flutter SDK | ^3.9.2 or higher | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Dart SDK | ^3.9.2 or higher | Included with Flutter |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) |
| VS Code (optional) | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |
| Git | Latest | [git-scm.com](https://git-scm.com/) |
| JDK | 17 or higher | [adoptium.net](https://adoptium.net/) |

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/)
2. Enable the following Firebase services:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Firebase Messaging
3. Download and add `google-services.json` to `android/app/`
4. Download and add `GoogleService-Info.plist` to `ios/Runner/`

### Environment Verification

Run the following command to verify your Flutter installation:

```bash
flutter doctor
```

Ensure all checkmarks are green before proceeding.

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/MiguelGitSTI/sticampuscentralguide.git
   cd sticampuscentralguide
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Testing Devices

The application has been tested on the following devices and platforms:

### Android Devices

| Device | Android Version | Screen Size | Status |
|--------|-----------------|-------------|--------|
| Xiaomi Redmi Note 11 | Android 12 | 6.43" | ✅ Tested |

### Android Emulators

| Emulator | API Level | Resolution | Status |
|----------|-----------|------------|--------|
| Pixel 7 Pro | API 34 | 1440x3120 | ✅ Tested |
| Pixel 4 | API 30 | 1080x2280 | ✅ Tested |
| Medium Phone | API 33 | 1080x2400 | ✅ Tested |

### Minimum Requirements

- **Android**: API Level 21 (Android 5.0 Lollipop) or higher
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 100MB free space

## Project Structure

```
lib/
├── main.dart              # App entry point
├── firebase_options.dart  # Firebase configuration
├── Items/                 # Data models and item classes
├── Screens/               # App screens
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── map_screen.dart
│   ├── hub_screen.dart
│   ├── faq_screen.dart
│   ├── settings_screen.dart
│   ├── notification_screen.dart
│   └── admin_screen.dart
├── Widgets/               # Reusable UI components
├── theme/                 # Theme configuration
└── utils/                 # Utility classes and services
```

## Dependencies

Key packages used in this project:

- `firebase_core` - Firebase initialization
- `firebase_auth` - User authentication
- `cloud_firestore` - Database storage
- `firebase_messaging` - Push notifications
- `firebase_ai` - AI-powered features
- `provider` - State management
- `flutter_local_notifications` - Local notification scheduling
- `google_fonts` - Custom typography
- `flutter_animate` - UI animations
- `shared_preferences` - Local storage
- `image_picker` - Image selection
- `workmanager` - Background tasks

## Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS (requires macOS)
```bash
flutter build ios --release
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dart Language Tour](https://dart.dev/language)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)

## License

This project is for educational purposes as part of STI College coursework.

## Contact

For questions or support, please contact the development team.