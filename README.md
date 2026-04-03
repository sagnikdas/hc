# Hanuman Chalisa Mobile App

A beautiful, offline-first devotional mobile app for chanting the Hanuman Chalisa (a beloved Hindu prayer). Built with Flutter for iOS and Android.

**Download**: [Google Play Store](https://play.google.com/store) | [Apple App Store](https://apps.apple.com)

---

## Features

### 🙏 **Core Prayer Experience** (Completely Offline)
- **High-quality audio** of the full Hanuman Chalisa chant (preloaded)
- **Synchronized lyrics** with timestamps (scroll or auto-scroll)
- **Language toggle**: Switch between Sanskrit, Hindi, English, and transliteration
- **No internet required** — pray anytime, anywhere
- **Offline-first architecture** ensures the core experience never depends on a network connection

### 📊 **Progress Tracking** (Optional Cloud Sync)
- Track daily streaks and all-time completion counts
- Heatmap visualization of your prayer history
- Weekly and daily statistics
- Syncs across devices when you sign in (optional)

### 🎵 **Customization**
- Adjust playback speed
- Change audio quality settings
- Dark mode optimized for night prayer
- Responsive UI that scales beautifully from phones to tablets
- Font scaling for accessibility

### 🔐 **Privacy-First**
- All core prayer data is stored **locally** on your device
- Optional Google Sign-In for cloud sync
- Your chanting data is never shared with third parties
- See [PRIVACY.md](PRIVACY.md) for full details

### 📱 **Global Leaderboard** (Optional)
- Anonymous weekly and all-time leaderboards (if you opt in)
- Connect with other devotees around the world
- Celebrate milestones together

---

## Getting Started

### Prerequisites
- Flutter SDK 3.0 or later
- Dart 3.0 or later
- Android Studio / Xcode for building
- An Android or iOS device/emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sagnikdas/hc.git
   cd hc
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run on a device/emulator**
   ```bash
   # List available devices
   flutter devices
   
   # Run on a specific device
   flutter run -d <device_id>
   
   # Run in hot-reload mode
   flutter run
   ```

### Build for Production

**Android (APK)**
```bash
flutter build apk --debug    # Debug build
flutter build apk --release  # Release build (optimized)
```

**iOS**
```bash
flutter build ios --release
```

---

## Project Structure

```
lib/
├── core/                       # Shared utilities & services
│   ├── audio_handler/          # Audio playback (just_audio wrapper)
│   ├── lyrics_service/         # Lyrics data loading & caching
│   ├── supabase_service/       # Cloud sync & authentication
│   ├── notification_service/   # Push notifications
│   ├── theme.dart              # Material 3 dark theme
│   ├── responsive.dart         # Responsive scaling utilities
│   ├── transitions.dart        # Page transition animations
│   └── app_secrets.dart        # API keys (git-ignored)
│
├── features/
│   ├── auth/                   # Sign in, profile setup
│   ├── home/                   # Hero card landing screen
│   ├── onboarding/             # First-time user flow
│   ├── play/                   # Main player UI (core feature)
│   ├── progress/               # Streak & heatmap dashboard
│   ├── profile/                # Settings & account management
│   ├── leaderboard/            # Global leaderboards
│   └── recitation/             # Scrollable lyrics with language toggle
│
├── data/
│   ├── local/                  # SQLite database helper
│   ├── models/                 # Data classes (PlaySession, UserSettings)
│   └── repositories/           # Single source of truth (AppRepository)
│
├── assets/
│   ├── audio/                  # Hanuman Chalisa MP3 files (preloaded)
│   ├── lyrics/                 # Timestamped lyrics JSON (multiple languages)
│   └── images/                 # Idol illustrations, backgrounds
│
└── main.dart                   # App entry point & global singletons
```

### Key Architectural Patterns

**Offline-First Design**
- SQLite stores all session data locally (`lib/data/local/database_helper.dart`)
- Cloud sync is fire-and-forget (app never blocks waiting for Supabase)
- Users can sign out anytime; local data is preserved

**Single Repository Pattern**
- `AppRepository` in `lib/data/repositories/` is the single source of truth
- All feature layers read/write through the repository
- Clean separation between UI and data layers

**Global Singletons** (Initialized in `main.dart`)
- `audioHandlerNotifier` — Audio playback manager
- `isPlayScreenOpen` — Signals when user is actively praying (triggers progress refresh)
- `lyricsService` — Preloaded lyrics for all languages

**Responsive Scaling**
- All sizes use `context.sp(value)` from `lib/core/responsive.dart`
- Automatically scales between 0.85× and 1.28× of baseline (375px width)
- No hardcoded pixel values in the UI

---

## Data & Privacy

### Local Storage
- **SQLite Database** (`play_sessions`, `user_settings`)
- Stored locally on your device only
- Survives app updates; cleared only when you uninstall or manually delete app data

### Optional Cloud Sync (When Signed In)
- Managed by **Supabase** (open-source Firebase alternative)
- Stores: completion records, streaks, heatmap data, user settings
- Syncs on sign-in and after each session completion
- Deleted from cloud within 30 days of account deletion

### Authentication
- **Google Sign-In** (optional)
- Session tokens stored securely; never in plain text
- Sign out anytime to go offline-only

**For full privacy details, see [PRIVACY.md](PRIVACY.md).**

---

## Testing

### Run All Tests
```bash
flutter test
```

### Run a Specific Test File
```bash
flutter test test/repository_test.dart
```

### Lint & Analyze
```bash
flutter analyze
```

### Test Patterns
- **Unit tests** use `sqflite_common_ffi` (in-memory SQLite)
- **Widget tests** override singletons to bypass real Supabase/SQLite
- Use `AppRepository.overrideProgressForTest()` to stub progress data
- See `test/` directory for examples

---

## Development Workflow

1. **Pick a task** from `todos/BACKLOG.md` (highest priority first)
2. **Implement** the feature or bug fix
3. **Run tests**: `flutter test` (must pass)
4. **Analyze**: `flutter analyze` (must pass)
5. **Build APK**: `flutter build apk --debug` (must succeed)
6. **Commit** with a clear message
7. **Create a PR** and request review

---

## Performance & Constraints

### Target Metrics
- **App launch**: < 2.5 seconds on mid-range devices
- **Audio startup**: < 500ms from play tap to sound
- **Database queries**: < 100ms (SQLite is local, so very fast)

### Critical Product Rules
- ✅ Never interrupt active chanting with dialogs or paywalls
- ✅ Core prayer experience is always free (no paywall before first play)
- ✅ Session counts only if ≥95% of audio played
- ✅ Max 1 paywall impression per day

### Database Migrations
- All migrations are versioned in `lib/data/local/database_helper.dart`
- Migrations are reversible (important for app rollbacks)
- SQLite version control via `database_version` field

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.0+ |
| **Language** | Dart 3.0+ |
| **Local Storage** | SQLite (sqflite) |
| **Audio** | just_audio + audio_session |
| **Auth & Cloud** | Supabase + Google Sign-In |
| **State Management** | ValueNotifier + Provider pattern |
| **Notifications** | flutter_local_notifications |
| **Fonts** | Google Fonts (Noto Serif, Manrope) |
| **Testing** | flutter_test, mocktail, sqflite_common_ffi |

---

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Follow the [Development Workflow](#development-workflow)
4. Submit a pull request with a clear description

For major changes, please open an issue first to discuss.

---

## License

This project is licensed under the [MIT License](LICENSE).

### Audio & Content Attribution

The Hanuman Chalisa prayer text is in the public domain. However, the audio recordings and translations have specific attributions and licenses:

- **Traditional Devotional Recording (9+ min)**: Performed by Hari Haran (classical Indian devotional musician)
- **Other Recitations**: See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for artist credits
- **Translations & Transliterations**: See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for complete credits
- **Imagery**: See [ATTRIBUTIONS.md](ATTRIBUTIONS.md)

**Please review [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for full attribution details, license terms, and all contributor information.**

---

## Support

- **Issues & Bug Reports**: [GitHub Issues](https://github.com/sagnikdas/hc/issues)
- **Privacy Questions**: See [PRIVACY.md](PRIVACY.md)
- **Contact**: sagnikd91@gmail.com

---

## Acknowledgments

- The Hanuman Chalisa devotional community for inspiration
- Flutter & Dart teams for excellent developer experience
- Supabase for open-source backend infrastructure
- All contributors who help improve this app

---

**Jai Hanuman! 🙏**
