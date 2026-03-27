# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter devotional mobile app for the Hanuman Chalisa (a Hindu prayer). The app is **offline-first** — the core prayer experience must work without any backend. **All four phases are complete** (see git log). Active work is tracked in `todos/BACKLOG.md`.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint
flutter test             # Run all tests
flutter test <file>      # Run a single test file
flutter build apk --debug
flutter run -d <device>
```

Test dependencies: `mocktail` (mocking), `sqflite_common_ffi` (in-memory SQLite for unit tests).

## Active Work

All four phases are shipped. Ongoing bugs and features are tracked in **`todos/BACKLOG.md`** (ranked P1–P4). Work from that file — one item at a time.

**Protocol**: Implement one backlog item → run `flutter analyze` + `flutter test` + `flutter build apk --debug` → commit.

## Architecture

```
lib/
  core/                  # theme, audio_handler, lyrics_service,
                         # supabase_service, notification_service,
                         # font_scale_notifier, responsive, transitions,
                         # main_shell, app_secrets
  features/
    auth/                # AuthGate, SignInScreen, ProfileFormScreen
    home/                # HomeScreen — landing/hero card
    onboarding/          # OnboardingScreen
    play/                # PlayScreen — main player UI
    progress/            # ProgressScreen — streak, heatmap, daily stats
    profile/             # ProfileScreen — settings, account
    leaderboard/         # LeaderboardScreen
  data/
    local/               # database_helper.dart (SQLite via sqflite)
    models/              # PlaySession, UserSettings
    repositories/        # app_repository.dart (single repo)
assets/
  audio/                 # Preloaded Hanuman Chalisa audio
  lyrics/                # Timestamped lyrics JSON
  images/                # Idol illustrations
```

**Global singletons in `main.dart`**: `audioHandlerNotifier` (`ValueNotifier<HanumanAudioHandler?>`) and `lyricsService`. Both are initialized asynchronously *after* `runApp` to keep launch fast.

**Audio**: `HanumanAudioHandler` wraps `just_audio` directly with `audio_session` for OS focus management. `audio_service` is in `pubspec.yaml` for lock-screen controls.

**Key tech**: `just_audio` + `audio_session`, `sqflite` (local DB), `supabase_flutter` (auth + cloud sync), `google_sign_in`, `flutter_local_notifications`, `share_plus`, `google_fonts`.

## Critical Product Constraints

- **Never interrupt active chanting** — no paywall or dialogs during playback.
- **Never block core prayer flow** with a paywall — free tier must always work.
- Completion counts only when ≥95% of audio has played.
- Max 1 paywall impression per day; never before the first successful play completion.
- App must launch in <2.5 sec on mid-range devices.
- DB migrations must be versioned and reversible.

## Token-Efficiency Rules

- Implement **one checklist task at a time** from the relevant `todos/phase-*.md` file.
- Request patch-style edits, not broad rewrites.
- Do not touch unrelated files when implementing a task.
- Pick items from `todos/BACKLOG.md` by priority (P1 first).
