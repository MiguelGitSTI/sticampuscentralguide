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

## Technologies Used

### Frontend (Mobile Application)

| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | 3.9.2+ | Cross-platform UI framework |
| **Dart** | 3.9.2+ | Programming language |
| **Material Design 3** | Latest | UI design system |
| **Provider** | 6.1.1 | State management |

### Backend & Cloud Services

| Service | Purpose |
|---------|---------|
| **Firebase Authentication** | User authentication (Email/Password) |
| **Cloud Firestore** | NoSQL real-time database |
| **Firebase Cloud Messaging (FCM)** | Push notifications |
| **Firebase AI** | AI-powered features |
| **Firebase Cloud Functions** | Serverless backend logic |

### Backend Runtime

| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 20.x | Cloud Functions runtime |
| **Firebase Admin SDK** | 12.6.0 | Server-side Firebase access |
| **Firebase Functions SDK** | 5.0.0 | Cloud Functions framework |

### Key Libraries & Packages

| Package | Version | Category | Purpose |
|---------|---------|----------|---------|
| `firebase_core` | 4.2.1 | Firebase | Firebase initialization |
| `firebase_auth` | 6.1.2 | Firebase | User authentication |
| `cloud_firestore` | 6.1.0 | Firebase | Database operations |
| `firebase_messaging` | 16.0.4 | Firebase | Push notifications |
| `firebase_ai` | 3.6.0 | Firebase | AI-powered features |
| `provider` | 6.1.1 | State | State management |
| `flutter_local_notifications` | 19.5.0 | Notifications | Local notification scheduling |
| `flutter_animate` | 4.5.0 | UI | Animations and transitions |
| `google_fonts` | 6.2.1 | UI | Custom typography |
| `shared_preferences` | 2.2.2 | Storage | Local key-value storage |
| `image_picker` | 1.0.4 | Media | Image selection from gallery/camera |
| `workmanager` | 0.9.0+3 | Background | Background task execution |
| `timezone` | 0.10.0 | Utilities | Timezone handling |
| `flutter_timezone` | 5.0.1 | Utilities | Device timezone detection |

### Development Tools

| Tool | Purpose |
|------|---------|
| `flutter_lints` | Code quality and linting |
| `flutter_test` | Unit and widget testing |
| `network_image_mock` | Mocking network images in tests |
| `flutter_launcher_icons` | App icon generation |

### Architecture & Patterns

- **State Management**: Provider pattern for reactive state management
- **Project Structure**: Feature-based folder organization (Screens, Widgets, Utils)
- **Data Layer**: Firebase Firestore with local caching support
- **Authentication**: Firebase Auth with email/password
- **Notifications**: Dual-layer (FCM for remote, flutter_local_notifications for local)
- **Background Processing**: WorkManager for scheduled background tasks
- **Theming**: Dynamic light/dark theme support with ThemeProvider

---

## System Requirements

### Development Environment

Before you begin, ensure you have the following installed:

#### Required Software

| Software | Minimum Version | Recommended | Download Link |
|----------|-----------------|-------------|---------------|
| Flutter SDK | 3.9.2 | Latest stable | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Dart SDK | 3.9.2 | Latest stable | Included with Flutter |
| Android Studio | 2023.1+ | Latest | [developer.android.com](https://developer.android.com/studio) |
| VS Code | 1.80+ | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |
| Git | 2.30+ | Latest | [git-scm.com](https://git-scm.com/) |
| JDK | 17 | 17 or 21 | [adoptium.net](https://adoptium.net/) |
| Node.js | 20.x | 20 LTS | [nodejs.org](https://nodejs.org/) |

#### Development Machine Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 8GB | 16GB |
| **Storage** | 10GB free | 20GB+ free |
| **OS (Windows)** | Windows 10 (64-bit) | Windows 11 |
| **OS (macOS)** | macOS 10.15 (Catalina) | macOS 14 (Sonoma) |
| **OS (Linux)** | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |

#### IDE Extensions (Recommended)

**VS Code:**
- Flutter
- Dart
- Firebase Explorer
- GitLens

**Android Studio:**
- Flutter Plugin
- Dart Plugin

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/)
2. Enable the following Firebase services:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Firebase Messaging
3. Download and add `google-services.json` to `android/app/`

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

## Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | ✅ Production Ready | Primary target platform |
| **iOS** | ✅ Supported | Requires macOS for building |
| **Web** | 🔧 Experimental | Basic support included |
| **Windows** | 🔧 Experimental | Desktop support available |
| **macOS** | 🔧 Experimental | Desktop support available |
| **Linux** | 🔧 Experimental | Desktop support available |

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

### End-User Device Requirements

#### Android

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **Android Version** | 5.0 (API 21) | 10.0+ (API 29+) |
| **RAM** | 2GB | 4GB+ |
| **Storage** | 100MB | 200MB+ |
| **Screen** | 4.5" | 5.5"+ |
| **Internet** | Required | Wi-Fi or Mobile Data |

#### iOS

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **iOS Version** | 12.0 | 15.0+ |
| **Device** | iPhone 6s | iPhone 11+ |
| **Storage** | 100MB | 200MB+ |
| **Internet** | Required | Wi-Fi or Mobile Data |

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