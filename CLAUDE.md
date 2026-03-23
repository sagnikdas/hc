# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter devotional mobile app for the Hanuman Chalisa (a Hindu prayer). The app is **offline-first** — the core prayer experience must work without any backend. **Phases 0 and 1 are complete** (see git log). Currently working toward Phase 2.

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

## Phased Implementation

Work is organized into four phases defined in `IMPLEMENTATION_PLAN.md`, with per-phase checklists in `todos/`:

- **Phase 0** (`todos/phase-0-foundation.md`): App shell, 3-tab nav (Play/Progress/Profile), SQLite DB + data models, CI
- **Phase 1** (`todos/phase-1-v1-core.md`): Audio playback, completion counter (≥95% played), streaks, heatmap, recording
- **Phase 2** (`todos/phase-2-monetization-growth.md`): Paywall infrastructure, referral unlocks, event instrumentation
- **Phase 3** (`todos/phase-3-v2-social.md`): Supabase auth, leaderboard, cloud sync

**Mandatory stage protocol**: Implement checklist items one at a time → run `flutter analyze` + `flutter test` + `flutter build apk --debug` → smoke run on device → commit only after all checks pass. Do not start the next phase until the current phase is passing.

Commit format: `feat(phase-X): complete <phase-name> shippable milestone`

## Architecture

```
lib/
  core/                  # theme, audio_handler, completion_detector,
                         # streak_calculator, lyrics_service, recording_service,
                         # analytics
  features/
    play/                # PlayScreen — main player UI
    progress/            # ProgressScreen — streak, heatmap, daily stats
    profile/             # ProfileScreen — settings, account
  data/
    local/               # database_helper.dart (SQLite via sqflite)
    models/              # PlaySession, DailyStat, UserSettings, Recording
    repositories/        # Repository interfaces + implementations
assets/
  audio/                 # Preloaded Hanuman Chalisa audio
  lyrics/                # Timestamped lyrics JSON
  images/                # Idol illustrations
```

**Global singletons in `main.dart`**: `audioHandlerNotifier` (`ValueNotifier<HanumanAudioHandler?>`) and `lyricsService`. Both are initialized asynchronously *after* `runApp` to keep launch fast.

**Audio**: `HanumanAudioHandler` wraps `just_audio` directly with `audio_session` for OS focus management. The `audio_service` package is in `pubspec.yaml` but the background/lock-screen layer is **not yet wired** — it is a Phase 1 remaining task.

**Key tech**: `just_audio` + `audio_session`, `sqflite` (local DB), `record` (user recording), Supabase (Phase 3 only), RevenueCat (Phase 2 IAP), PostHog or Firebase Analytics.

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
- Use the prompt template from `IMPLEMENTATION_PLAN.md § 7` when generating code.
