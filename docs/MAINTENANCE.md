# Hanuman Chalisa App — Maintenance Guide

This document covers long-term maintenance, common tasks, architecture decisions, and known gotchas for the Hanuman Chalisa Flutter app.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Key Files & Directories](#key-files--directories)
4. [Common Maintenance Tasks](#common-maintenance-tasks)
5. [Testing Strategy](#testing-strategy)
6. [Database & Migrations](#database--migrations)
7. [Notifications & Reminders](#notifications--reminders)
8. [Supabase Integration](#supabase-integration)
9. [Known Issues & Gotchas](#known-issues--gotchas)
10. [Performance Considerations](#performance-considerations)
11. [Release & Deployment](#release--deployment)

---

## Quick Start

### Essential Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Lint check
flutter test                 # Run all tests
flutter test <file>          # Run single test file
flutter build apk --debug    # Build debug APK
flutter run -d <device>      # Run on device
```

### Project Structure

```
lib/
  core/                 # Singletons, services, utilities
    audio_handler.dart           # just_audio + audio_session wrapper
    notification_service.dart    # Local notifications, reminder scheduling
    supabase_service.dart        # Auth, profile sync, leaderboard
    theme.dart                   # Material 3 theme (dark mode)
    responsive.dart              # sp() scaling (375px baseline)
    main_shell.dart              # Bottom nav, mini-player, layout
  
  features/
    auth/               # Google sign-in, profile form
    home/               # Hero card, onboarding upsell
    onboarding/         # Intro slides
    play/               # Main player UI, audio controls
    progress/           # Streak, heatmap, daily stats
    profile/            # Settings, reminders, invite
    recitation/         # Scrollable lyrics with timestamps
    leaderboard/        # Weekly/all-time rankings
  
  data/
    local/              # SQLite via sqflite
      database_helper.dart
    models/             # Data classes (UserSettings, PlaySession, etc.)
    repositories/       # app_repository.dart (single repo pattern)

test/                   # Unit + widget tests
assets/audio/           # Pre-bundled Hanuman Chalisa MP3s
assets/lyrics/          # Timestamped lyrics JSON
```

---

## Architecture Overview

### Core Principles

- **Offline-first**: Prayer experience works without backend. DB is SQLite; Supabase is async+optional.
- **Single repository pattern**: All data access via `AppRepository.instance`.
- **Global singletons**: `audioHandlerNotifier`, `isPlayScreenOpen`, `lyricsService` initialized in `main.dart` after `runApp()` to keep launch <2.5s.
- **Test seams**: Mock-friendly via `*ForTest` static fields (e.g., `AppRepository.instance.overrideSettingsForTest()`).
- **Responsive scaling**: All sizes use `context.sp(value)` (375px baseline, clamped to [0.85×, 1.28×]).

### Data Flow

#### Completion Recording (Critical Path)

1. **PlayScreen** detects `ProcessingState.completed` on audio stream
2. Calls `AppRepository.insertSession()` → writes to SQLite `play_sessions` table
3. If signed in, fire-and-forget `SupabaseService.syncCompletion()` (queues to `pending_syncs` for retry if offline)
4. **MainShell** watches `isPlayScreenOpen` flip `true → false` → increments `_progressRefreshSignal` → **ProgressScreen** reloads stats

#### Settings Flow

1. User changes a setting in **ProfileScreen**
2. `_saveSettings()` persists to SQLite `user_settings` (row id=1)
3. If reminder-related: `NotificationService.applyReminderSchedule()` reschedules notifications
4. Globals like `fontScaleNotifier` and `themeModeNotifier` update to trigger rebuilds

#### Notification Tap Flow

1. User taps a paath reminder in foreground or cold-starts from notification
2. `NotificationService._onNotificationResponse()` or `consumeNotificationLaunchNavigation()` fires
3. Calls `bumpReminderNotificationTap()` → increments `reminderNotificationTapVersion`
4. **MainShell** listens to `reminderNotificationTapVersion` → calls `_tryOpenPlayFromReminder()`
5. Opens **PlayScreen** with `beginPaathImmediately: true` → auto-starts playback

---

## Key Files & Directories

### Core Services

| File | Purpose | Key Exports |
|------|---------|-------------|
| `core/audio_handler.dart` | Wraps `just_audio` + `audio_session` for focus management | `HanumanAudioHandler` |
| `core/notification_service.dart` | Local notifications, 7-day reminder scheduling with timezone support | `applyReminderSchedule()`, `cancelReminders()`, `requestPermissions()` |
| `core/supabase_service.dart` | Google OAuth, profile CRUD, leaderboard fetch, completion sync | `signInWithGoogle()`, `fetchLeaderboard()`, `syncCompletion()` |
| `core/main_shell.dart` | Bottom nav, mini-player, reminder tap navigation | `MainShell` widget |
| `core/responsive.dart` | Responsive scaling utility | `context.sp(value)` extension |
| `core/theme.dart` | Material 3 dark theme (saffron primary, gold secondary, charcoal surface) | `darkTheme` |

### Data Layer

| File | Purpose | Key Methods |
|------|---------|-------------|
| `data/local/database_helper.dart` | SQLite schema, migrations, queries | `initDb()`, `insertSession()`, `getProgress()` |
| `data/models/user_settings.dart` | Settings model with serialization | `UserSettings`, `clampReminderMinutes()` |
| `data/repositories/app_repository.dart` | Unified data access (SQLite + Supabase) | `getSettings()`, `saveSettings()`, `insertSession()`, `flushPendingSyncs()` |

### Features

| File | Purpose | Key Widgets |
|------|---------|-------------|
| `features/profile/profile_screen.dart` | Settings (reminders, haptic, theme, font scale, playback, invite) | `ProfileScreen`, `_ToggleRow`, `_ReminderTimeRow` |
| `features/play/play_screen.dart` | Main player, lyrics sync, completion detection | `PlayScreen`, `_PlaybackControls` |
| `features/progress/progress_screen.dart` | Streak, heatmap, daily/weekly stats | `ProgressScreen`, `HeatmapView` |
| `features/leaderboard/leaderboard_screen.dart` | Weekly/all-time rankings, profile card | `LeaderboardScreen` |
| `features/home/home_screen.dart` | Hero card, onboarding upsell for signed-out users | `HomeScreen` |
| `features/recitation/recitation_screen.dart` | Scrollable lyrics with timestamps, language toggle | `RecitationScreen` |

---

## Common Maintenance Tasks

### Adding a New Setting

1. **Add to `UserSettings` model** (`data/models/user_settings.dart`):
   ```dart
   final bool myNewSetting;  // In constructor
   ```

2. **Add to `toMap()` / `fromMap()`** for serialization

3. **Add to `copyWith()`** for immutability

4. **Add to `ProfileScreen._loadSettings()` / `_saveSettings()`**:
   ```dart
   _myNewSetting = settings.myNewSetting;  // Load
   // In copyWith:
   myNewSetting: _myNewSetting,
   ```

5. **Add UI widget** in appropriate section of `ProfileScreen.build()`

6. **Write tests** in `test/profile_screen_test.dart`

### Adding a New Feature

1. **Create `features/<feature_name>/` directory** with `<feature>_screen.dart`

2. **Register in `MainShell`** if it needs a bottom-nav tab:
   ```dart
   final screens = [
     // ... existing
     FeatureScreen(),  // Add here
   ];
   ```

3. **Add navigation in routes** (usually `MainShell` manages tabs)

4. **Test with widget tests** — see [Testing Strategy](#testing-strategy)

5. **Update `MAINTENANCE.md`** with new file location and purpose

### Updating Dependencies

1. **Check for breaking changes**: `flutter pub outdated`
2. **Run tests before updating**: `flutter test`
3. **Update one package at a time** to isolate failures: `flutter pub upgrade <package>`
4. **Re-run tests after each update**
5. **Commit**: Document why the upgrade was needed

### Database Migration

Migrations are versioned in `data/local/database_helper.dart`. Example:

```dart
// In initDb():
if (currentVersion < 2) {
  await db.execute(
    'ALTER TABLE play_sessions ADD COLUMN language TEXT DEFAULT "hindi"',
  );
}
```

**Rules**:
- Always increment `currentVersion`
- Test on both fresh install and upgrade paths
- Never drop columns; use `DEFAULT` or nullable fields
- Add a test in `test/repository_extended_test.dart`

### Fixing a Notification Bug

Notifications are scheduled in `NotificationService.applyReminderSchedule()`. Common issues:

- **Notifications don't fire**: Check `_initialized` flag; call `NotificationService.init()` early
- **Wrong time zone**: Verify `flutter_timezone.getLocalTimezone()` succeeds; fallback is UTC
- **Permission denied**: Call `requestPermissions()` before scheduling; handle denial gracefully
- **Sacred day logic broken**: Check `DateTime.tuesday` (2) vs `DateTime.saturday` (6)

### Updating Lyrics

Lyrics are in `assets/lyrics/lyrics.json`. Format:

```json
[
  {"line": "Jai Hanuman Gyan Gun Sagar", "startMs": 0, "endMs": 2000},
  ...
]
```

1. Update `assets/lyrics/lyrics.json`
2. Force reload in `LyricsService.load()` if caching issues arise
3. Test in **RecitationScreen** that timestamps sync with audio

---

## Testing Strategy

### Unit Tests (Models, Repositories)

Run specific test file:
```bash
flutter test test/repository_test.dart
```

Use `sqflite_common_ffi` for SQLite testing:
```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());
  final db = await databaseFactoryFfi.openDatabase(':memory:');
}
```

**What to test**:
- Model serialization (toMap/fromMap)
- Repository CRUD operations
- Settings clamping (e.g., reminder times 0–1439)
- Database migrations

### Widget Tests (UI)

Run all widget tests:
```bash
flutter test --tags=widget_test
```

**Key patterns**:
1. **Set view size** before pumpWidget to test responsiveness:
   ```dart
   tester.view.physicalSize = Size(390, 844);
   tester.view.devicePixelRatio = 1.0;
   ```

2. **Use test seams to bypass async work**:
   ```dart
   AppRepository.instance.overrideSettingsForTest(const UserSettings());
   NotificationService.applyReminderScheduleForTest = (_) async {};
   SupabaseService.currentUserForTest = () => null;
   ```

3. **Pump to settle async operations**:
   ```dart
   await tester.pumpWidget(_wrap());
   await tester.pumpAndSettle();  // Waits for animations, futures
   ```

4. **Verify text/icon presence**:
   ```dart
   expect(find.text('Button Label'), findsOneWidget);
   expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
   ```

### Integration Tests (User Flows)

Located in `test/*_integration_test.dart`. These test sign-in, completion recording, stats reload, etc.

```bash
flutter test test/sso_user_flow_integration_test.dart
```

**Critical flows to test**:
- Google sign-in → profile form → leaderboard
- Play completion → heatmap update
- Reminder tap → auto-play
- Settings change → notification reschedule

### Test Isolation

Each test should:
1. **setUp()**: Reset singletons, override stubs
2. **Test logic**
3. **tearDown()**: Clear overrides, close streams

Example:
```dart
setUp(() {
  DatabaseHelper.resetForTest();
  AppRepository.resetForTest();
  SupabaseService.resetAuthForTest();
});

tearDown(() {
  AppRepository.instance.clearSettingsOverrideForTest();
});
```

---

## Database & Migrations

### Schema

**play_sessions** table:
```sql
CREATE TABLE play_sessions (
  id INTEGER PRIMARY KEY,
  session_date TEXT NOT NULL,
  count INTEGER NOT NULL,
  synced INTEGER DEFAULT 0
);
```

**user_settings** table (single row, id=1):
```sql
CREATE TABLE user_settings (
  id INTEGER PRIMARY KEY,
  target_count INTEGER,
  haptic_enabled INTEGER,
  reminder_notifications_enabled INTEGER,
  reminder_morning_minutes INTEGER,
  reminder_evening_minutes INTEGER,
  sacred_day_notifications_enabled INTEGER,
  font_scale REAL,
  theme_mode INTEGER,
  ...
);
```

**pending_syncs** table (retry queue for offline completions):
```sql
CREATE TABLE pending_syncs (
  id INTEGER PRIMARY KEY,
  session_id INTEGER UNIQUE,
  retries INTEGER DEFAULT 0
);
```

### Migration Example

When adding a new column:

```dart
// In DatabaseHelper.initDb():
const int currentVersion = 3;  // Bump from 2

Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 3) {
    await db.execute(
      'ALTER TABLE user_settings ADD COLUMN language TEXT DEFAULT "hindi"',
    );
  }
}
```

**Always test**:
```bash
flutter test test/repository_extended_test.dart -k "migration"
```

---

## Notifications & Reminders

### How Reminders Work

1. **Scheduling**: `applyReminderSchedule()` runs in `main.dart` on app start, and whenever reminder settings change
2. **7-day window**: Notifications scheduled from now + 7 days
3. **Time zones**: Uses device timezone; falls back to UTC
4. **Sacred days**: Tuesday (2) and Saturday (6) get special high-importance channel + custom titles
5. **Cancellation**: Reminder IDs 100–106 (morning), 200–206 (evening)

### Reminder Settings Fields

```dart
// In UserSettings
bool reminderNotificationsEnabled        // Master toggle
int reminderMorningMinutes               // 0–1439 (7*60 = 7am default)
int reminderEveningMinutes               // 0–1439 (20*60 = 8pm default)
bool sacredDayNotificationsEnabled       // Tue/Sat special alerts
```

### Common Reminder Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Notifications don't appear | Permissions not granted | Call `requestPermissions()` first; check OS settings |
| Wrong time of day | Timezone not initialized | Call `NotificationService.init()` early in `main()` |
| Reminders stop after 7 days | Schedule isn't refreshed on app launch | Call `applyReminderSchedule()` in `main.dart` on app start (already done) |
| Sacred day logic broken | Weekday enum confusion (1=Mon, 7=Sun) | Use `DateTime.tuesday` (2), `DateTime.saturday` (6) |
| Permissions UI flickers | Saving state before checking permission | Check permission first, revert state if denied |

### Testing Notifications

Use stubs in tests:
```dart
NotificationService.applyReminderScheduleForTest = (settings) async {
  // Mock implementation
};
NotificationService.cancelRemindersForTest = () async {
  // Mock implementation
};
```

---

## Supabase Integration

### Auth Flow

1. User taps "Sign in" → `SupabaseService.signInWithGoogle()`
2. Opens Google OAuth → returns User + metadata
3. On sign-in, `AppRepository.flushPendingSyncs()` runs → syncs any offline completions
4. Listen to auth changes:
   ```dart
   Supabase.instance.client.auth.onAuthStateChange.listen((data) {
     if (data.event == AuthChangeEvent.signedIn) {
       // Sync
     }
   });
   ```

### Tables

**profiles** (custom table, created in dashboard):
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users,
  name TEXT,
  email TEXT,
  referral_code TEXT UNIQUE,  -- For invite feature (legacy, removed from UI)
  created_at TIMESTAMP DEFAULT NOW()
);
```

**completions** (append-only):
```sql
CREATE TABLE completions (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users,
  count INTEGER NOT NULL,
  recorded_at TIMESTAMP DEFAULT NOW()
);
```

### Common Supabase Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Sign-in fails silently | Network error or invalid OAuth config | Check `CLAUDE.md` for `kSupabaseUrl`, `kSupabaseAnonKey` |
| Profile sync fails | Row doesn't exist | `upsertProfile()` handles INSERT OR UPDATE |
| Leaderboard is stale | No refresh on sign-in | Listen to auth changes; call `fetchLeaderboard()` |
| Completions not syncing | `flushPendingSyncs()` not called | Should run on app resume + after sign-in |

---

## Known Issues & Gotchas

### 1. Permission + Settings Desync (FIXED)
**Issue**: If user enables reminders but OS denies permission, the UI toggle and DB get out of sync.
**Fix**: When permission is denied, revert the state and re-save settings with `reminderNotificationsEnabled: false`.
**Location**: `profile_screen.dart:_saveSettings()`

### 2. 7-Day Reminder Window Expires Silently
**Issue**: Reminders are only scheduled for 7 days ahead. If user doesn't open the app for >7 days, reminders stop with no warning.
**Fix**: Already mitigated — `applyReminderSchedule()` is called on app start in `main.dart`. But monitor for edge cases.

### 3. Referral Code (Legacy Feature)
**Issue**: Referral codes are stored in `user_settings.referralCode` but the UI was simplified to just share a message (no code display).
**Status**: Code generation + DB storage still exist; just not displayed. Safe to leave as-is or remove if cleaning up.

### 4. Exact Alarm Permission Ignored on Android 12+
**Issue**: `requestExactAlarmsPermission()` is called but return value is ignored.
**Fix**: Should check return value and handle denial gracefully (not critical; falls back to inexact).
**Location**: `notification_service.dart:requestPermissions()`

### 5. Audio Handler State After Completion
**Issue**: After a track completes, `playing=true` may persist even though `processingState=completed`.
**Fix**: Treat `completed` as paused for UI purposes (done in `main_shell.dart` mini-player).

### 6. Font Scale Non-Responsive Until Relayout
**Issue**: Changing font scale doesn't immediately redraw all text; requires navigation back + forth.
**Fix**: `fontScaleNotifier` is a `ValueNotifier` — listen in widgets that need immediate updates. Most screens already do.

### 7. Emoji in Notification Titles (iOS)
**Issue**: iOS may not render emoji in notification titles cleanly.
**Fix**: Use emoji (🙏) but test on real iOS devices before release.
**Location**: `notification_service.dart:_morningTitle()`, `_eveningTitle()`

---

## Performance Considerations

### Launch Time
- **Target**: <2.5 sec on mid-range devices
- **How**: Pre-load theme + font scale in `main()` before `runApp()`, init services async in `_initServices()`
- **Don't**: Load full DB, fetch leaderboard, or fetch profile on launch (all async)

### Audio Playback
- **just_audio**: Direct playback (no transcoding); `audio_session` for OS focus
- **Continuous play**: Audio is pre-bundled; no streaming
- **Memory**: One 10–15 min MP3 ≈ 20–40 MB in memory

### Database
- **Schema**: Indexed by `session_date` (frequent queries)
- **Queries**: Use batch operations for bulk inserts (pending_syncs flush)
- **Migration**: Test on real device; FFI-based testing may hide slow migrations

### Widgets
- **Rebuild**: Use `ValueNotifier` for global state; prefer StreamBuilder for async
- **Layout**: All sizes use `sp()` scaling (single constant for all breakpoints)
- **Images**: Asset images (no network images except avatar URLs)

### Supabase
- **Network**: Fire-and-forget for sync; don't block UI
- **Retry**: Pending syncs persist in local DB; auto-retry on app resume
- **Leaderboard**: Lazy load in tab; fetch only when user navigates to tab

---

## Release & Deployment

### Build Checklist

- [ ] Run `flutter analyze` → 0 errors/warnings (pre-existing ok)
- [ ] Run `flutter test` → all tests pass
- [ ] Update version in `pubspec.yaml` (`version: X.Y.Z`)
- [ ] Update `CHANGELOG.md` with new features/fixes
- [ ] Test on real devices (Android + iOS)
- [ ] Check reminder notifications work (enable, set times, wait)
- [ ] Verify sign-in and leaderboard
- [ ] Test offline mode (disconnect network, complete a session)

### Building for Release

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release  # Then sign in Xcode

# Android App Bundle (for Play Store)
flutter build appbundle --release
```

### Version Numbering

Use semantic versioning: `major.minor.patch`
- **Major**: Significant features or breaking changes
- **Minor**: New features, backwards-compatible
- **Patch**: Bug fixes

### Monitoring Post-Release

- Monitor app crashes (via Firebase Crashlytics if enabled)
- Check notification delivery rates
- Monitor Supabase sync errors (check logs)
- Monitor playback completion rates (low rate = audio bug)

### Rollback Plan

If critical bug in release:
1. Revert commit in git
2. Decrement version number
3. Rebuild + redeploy
4. Notify users (in-app message if time-sensitive)

---

## Building APK & App Bundle for Release

### Understanding the Formats

| Format | File | Size | Use Case |
|--------|------|------|----------|
| **APK** | `app-release.apk` | ~72 MB | Universal APK for all devices; direct installation or distribution |
| **App Bundle** | `app-release.aab` | ~61 MB | **Recommended for Play Store**; automatically optimized per device |

**Key difference**: App Bundle is smaller because Google Play generates device-specific APKs (removes unnecessary resources for each device's screen density, CPU architecture, etc.).

---

### Build Commands

#### 1. Universal APK (Single File, All Devices)

```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk` (72 MB)

**Use case**: Direct sharing with testers, side-loading, or as a fallback

#### 2. App Bundle (Recommended for Play Store)

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

**Output**: `build/app/outputs/bundle/release/app-release.aab` (61 MB)

**Use case**: Upload to Google Play Console (required for new apps as of Aug 2021)

#### 3. Debug APK (For Development/Testing)

```bash
flutter build apk --debug
```

**Output**: `build/app/outputs/flutter-apk/app-debug.apk` (larger, includes debug symbols)

**Use case**: Testing on devices before release build

### Pre-Build Checklist

Before building for release:

```bash
# 1. Lint check
flutter analyze

# 2. Run all tests
flutter test

# 3. Verify version in pubspec.yaml
grep "version:" pubspec.yaml

# 4. Build and verify on a test device
flutter run -d <device_id> --release
```

### Version Numbering

Update `pubspec.yaml` before each build:

```yaml
version: 1.0.1+2
#        Major.Minor.Patch+Build
```

- **Major**: Significant features or breaking changes
- **Minor**: New features, backwards-compatible
- **Patch**: Bug fixes
- **Build**: Internal build number (increment for each Play Store submission)

### Signing Configuration

The app uses keystore signing (configured in `android/app/build.gradle`). Ensure:

1. Keystore file exists: `android/app/key.jks` (not in repo)
2. Passwords are secure and backed up
3. Same keystore is used for all releases (Play Store requirement)

If keystore is lost, you cannot update the app on Play Store — you must create a new listing.

---

## Google Play Console — Complete Testing Workflow

### Overview of Testing Tracks

Google Play offers multiple testing phases before production:

| Track | Users | Approval | Auto-Updates | Use Case |
|-------|-------|----------|--------------|----------|
| **Internal Testing** | Your team only (max 100) | Instant | Yes | Quick smoke tests |
| **Closed Testing** | Limited group (optional) | 1–2 hours | Yes | Beta feedback from real users |
| **Open Testing** | All users (opt-in) | 1–2 hours | Yes | Wider testing before full release |
| **Production** | Everyone on Play Store | 3–4 hours | Yes | Public release |

---

### Setup: Initial Configuration

#### 1. Create Google Play Console Account

- Go to [Google Play Console](https://play.google.com/console)
- Sign in with your Google account
- Pay one-time $25 registration fee
- Complete merchant profile

#### 2. Create App Listing

1. **Create new app**:
   - **App name**: Hanuman Chalisa
   - **Default language**: English
   - **App type**: Apps
   - **Category**: Lifestyle or Books & Reference

2. **Fill in required fields**:
   - App icon (192×192 px)
   - Short description (<80 chars)
   - Full description (4000 chars max)
   - Screenshots (min 2, max 8 per device type)
   - Feature graphic (1024×500 px)
   - Privacy policy URL

3. **Content rating questionnaire**:
   - Complete Google Play's content rating system
   - Answer about violence, sexual content, etc.

4. **App signing**:
   - Choose "Google Play App Signing" (recommended)
   - Google manages signing certificates for you

---

### Workflow: Test → Release

#### Phase 1: Internal Testing (Your Team)

1. **Open [Google Play Console](https://play.google.com/console)**
2. **Select your app** → **Testing** → **Internal Testing**
3. **Create a new release**:
   ```
   - Click "Create new release"
   - Upload app-release.aab (or APK)
   - Add release notes (e.g., "v1.0.1: Fixed onboarding bug")
   - Add test instructions (what to test)
   ```
4. **Add testers**:
   ```
   - Go to Testers tab
   - Click "Invite testers"
   - Paste email addresses (your team, up to 100 people)
   - Send invitations
   ```
5. **Testers receive email**:
   - Click link
   - See "Join testing" button
   - Install from Play Store (like normal)
   - Receive auto-updates when you upload new versions

**Timeline**: 
- Setup: ~5 min
- Build available to testers: Instant (~5 min)
- Crash reports: Real-time in Play Console

---

#### Phase 2: Closed Testing (Beta Users — Optional)

For wider pre-launch feedback:

1. **Go to Closed Testing**:
   ```
   - Testing → Closed testing → Create new release
   ```
2. **Upload same AAB/APK**
3. **Add testers**:
   ```
   - Can add Google Groups, email lists, or individual emails
   - Larger group than internal (10,000+)
   ```
4. **Google Play reviews**:
   ```
   - Takes 1–2 hours (less strict than production)
   - Will notify you of any issues
   ```
5. **Testers join**:
   ```
   - Same flow: email link → "Join testing" → Install
   ```

**When to use**: 
- Larger user base feedback (>10 people)
- Multi-week testing before release
- Gathering community feedback

---

#### Phase 3: Full Release to Production

Once satisfied with testing:

1. **Go to Production**:
   ```
   - Release → Production → Create new release
   ```
2. **Upload AAB/APK**:
   ```
   - Same build as closed testing, or updated version
   ```
3. **Add release notes**:
   ```
   - What's new in this version
   - Visible to all users
   ```
4. **Add store listing** (if first release):
   ```
   - Screenshots
   - Description
   - Content rating
   - Privacy policy
   ```
5. **Review rollout**:
   ```
   - Default: 100% immediate rollout
   - Option: Gradual rollout (10% → 50% → 100% over days)
   - Recommendation: Use gradual for major changes
   ```
6. **Submit for review**:
   ```
   - Click "Review and roll out"
   - Google reviews (3–4 hours, strict review)
   - May reject if content violates policies
   ```
7. **Wait for approval**:
   ```
   - You get email when approved
   - App goes live on Play Store
   - Users can search and install
   ```

---

### Step-by-Step: Upload to Internal Testing (Quick Path)

For quick testing with 10 friends/family:

```bash
# 1. Build release AAB
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# 2. Open Google Play Console
# https://play.google.com/console

# 3. Select your app → Testing → Internal Testing

# 4. Click "Create new release"

# 5. Click "Browse files"
# Select: build/app/outputs/bundle/release/app-release.aab

# 6. Add release notes (required)
# Example:
# "v1.0.1 Beta
# - Fixed: Onboarding skip button now works
# - Fixed: Reminders permission dialog
# - Improved: Settings UI simplified"

# 7. Add test instructions (optional but helpful)
# "Please test:
# 1. App launches and plays audio offline
# 2. Reminders can be set in Settings
# 3. Home → Play → Settings navigation"

# 8. Save draft or publish
# Click "Save" to save as draft
# Click "Publish release" to make live

# 9. Go to Testers tab

# 10. Click "Invite testers"

# 11. Enter email addresses (one per line):
# friend1@gmail.com
# friend2@gmail.com
# ...

# 12. Click "Invite"

# 13. Testers receive email within minutes
# They click link, tap "Join testing", install
```

**Timeline**: 
- Total setup: ~10 minutes
- App available to testers: Immediate (< 1 minute)

---

### Monitoring & Feedback

#### View Testing Stats

1. **Testing → Internal Testing**
2. **Testers tab**: See who joined, who hasn't responded
3. **Release tab**: See install stats, crash rates
4. **Ratings & reviews**: See testers' feedback

#### Common Issues

| Issue | Solution |
|-------|----------|
| Testers don't receive invite | Check email in Testers list; resend if needed |
| "Can't find in Play Store" | They need to: (1) Accept invite, (2) Wait 5 min, (3) Search for app |
| App crashes on device | Check **Crashes** tab in Play Console; view stack traces |
| Auto-update didn't work | Test again or ask testers to uninstall + reinstall |

---

### Before Moving to Production

**Mandatory checks**:

- [ ] App launches without crashes on multiple devices
- [ ] Core feature (audio playback) works offline
- [ ] Reminders work when enabled
- [ ] Notifications appear at correct time
- [ ] Settings persist after app close/reopen
- [ ] No sensitive data in logs (check `flutter logs`)
- [ ] Version number bumped in `pubspec.yaml`
- [ ] Release notes written and clear
- [ ] At least 2 people have tested
- [ ] No critical bugs reported

**Recommended checks**:

- [ ] Test on oldest Android version you support (check `android/app/build.gradle`)
- [ ] Test on different screen sizes (phone, tablet)
- [ ] Test with low storage/memory
- [ ] Test with unstable network (airplane mode + WiFi toggle)
- [ ] Test theme switching (light/dark/system)

---

### Production Release Process

#### Gradual Rollout (Recommended)

For significant changes, use gradual rollout:

1. **Create release** in Production track
2. **Set rollout percentage**:
   - Day 1: 10% (1 out of 10 users get update)
   - Day 2: 25% (if no major crashes)
   - Day 3: 50%
   - Day 4+: 100%
3. **Monitor crashes**:
   - Check Play Console daily
   - If crash spike: Halt rollout, investigate, fix, re-release
4. **Complete rollout**:
   - Once confident, increase to 100%

**Why?** Catches bugs in production before they reach everyone.

#### Full Rollout (For Minor Fixes)

If only fixing a small bug (no major feature changes):

1. **Create release**
2. **Set rollout**: 100% immediately
3. **Submit for review**
4. **Wait for approval** (~3–4 hours)

---

### After Release

#### Monitor These

1. **Crashes**: Play Console → Crashes tab
2. **Ratings**: Play Console → Ratings
3. **User reviews**: Look for common complaints
4. **Hang-ups**: If crashes spike, check Play Console logs

#### If Critical Bug Found

1. **Fix the bug locally**
2. **Bump version** (`1.0.1` → `1.0.2`)
3. **Rebuild APK/AAB**
4. **Create new Production release**
5. **Gradual rollout** (10% first)
6. **Monitor crash rates**
7. **Increase rollout** once stable

---

### Troubleshooting Common Play Store Issues

| Issue | Solution |
|-------|----------|
| "Invalid APK" during upload | Verify: signing config, target SDK version (check `build.gradle`) |
| "This app uses high-risk permissions" | Check permissions in `AndroidManifest.xml`; use only what's needed |
| "Rejected: Policy violation" | Read rejection reason carefully; common: ads, privacy policy, data handling |
| "Can't find app in search" | Give it 24 hours; app may be hidden due to content rating |
| "Crashing on some devices" | Check Play Console logs; test on that device type; may be OS version issue |

---

### Firebase Crashlytics (Optional)

To get detailed crash reports:

1. **Set up Firebase** in `pubspec.yaml`:
   ```yaml
   firebase_core: ^2.0.0
   firebase_crashlytics: ^3.0.0
   ```

2. **Initialize in `main.dart`**:
   ```dart
   await Firebase.initializeApp();
   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
   ```

3. **View crashes in Firebase Console**:
   - https://console.firebase.google.com
   - Your project → Crashlytics
   - See stack traces, affected users, trends

This helps identify bugs users encounter that internal testing missed.

---

## Useful Resources

- **Flutter docs**: https://flutter.dev/docs
- **Material 3 spec**: https://m3.material.io
- **Google Play Console**: https://play.google.com/console
- **Play Store Testing Guide**: https://support.google.com/googleplay/android-developer/answer/188841
- **just_audio**: https://pub.dev/packages/just_audio
- **sqflite**: https://pub.dev/packages/sqflite
- **Supabase Flutter**: https://supabase.com/docs/reference/flutter

### Enable Verbose Logging

```bash
flutter run -v
```

### Inspect Database

```dart
// In main.dart or via console
final db = await DatabaseHelper.instance.database;
final settings = await db.query('user_settings');
print(settings);
```

### Test Notifications Locally

```dart
// In profile_screen.dart or test
NotificationService.init().then((_) {
  NotificationService._schedule(
    id: 999,
    title: 'Test',
    body: 'Tap me',
    scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(seconds: 5)),
    highImportance: false,
  );
});
```

### Simulate Cold-Start from Notification

1. Tap "Begin Recitation" to start playback
2. Close app completely
3. Tap a paath reminder in system tray
4. Verify app opens with PlayScreen auto-playing

### Check Supabase Sync

```dart
// In app
final pending = await AppRepository.instance.getPendingSyncs();
print('Pending syncs: $pending');
```

---

## Useful Resources

- **Flutter docs**: https://flutter.dev/docs
- **Material 3 spec**: https://m3.material.io
- **just_audio**: https://pub.dev/packages/just_audio
- **sqflite**: https://pub.dev/packages/sqflite
- **Supabase Flutter**: https://supabase.com/docs/reference/flutter

---

## Contact & Support

For questions about this app:
- Check `CLAUDE.md` for architecture rules
- Check `todos/BACKLOG.md` for active work items
- Review recent commits for context on recent changes
