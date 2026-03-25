# Backlog — Android-First Feature & Bug List

Ranked by criticality. Fix bugs first, then high-impact features, then enhancements.

---

## Answers to your embedded questions

**Q: When offline — does the completion count still get saved and sync later?**
No. Currently `insertSession` in `AppRepository` fires `SupabaseService.syncCompletion` fire-and-forget at the moment of completion. If the device is offline, the call silently fails and the completion is **never retried**. The local SQLite count is saved correctly, but the cloud record is lost. Item #7 below fixes this.

**Q: How is the referral code generated?**
`AppRepository._generateCode()` uses `Random.secure()` with a 32-character alphabet (no ambiguous chars like I/O/0/1), picks 6 characters. Generated once on first use, stored in SQLite `user_settings.referral_code`, and synced to Supabase `profiles.referral_code` when signed in.

**Q: What's the end logic with referral code sharing? How do we reward referrals?**
Not yet designed. The current code only generates and shares the code — there is no detection of "someone used my code" and no reward logic. Needs product decision before implementation (see item #16).

---

## P1 — Bugs (Broken functionality, fix immediately)

| # | Issue | Root Cause | File |
|---|-------|-----------|------|
| 1 | **Heatmap doesn't update after completing a listen** | `_loadStats()` is called via `.then((_) => _loadStats())` after PlayScreen *pops*. If user switches tabs while playing (PlayScreen stays on the stack), the `.then` never fires. | `lib/features/home/home_screen.dart:46` |
| 2 | **Debug banner visible on screen** | `MaterialApp` has no `debugShowCheckedModeBanner: false` | `lib/main.dart` |
| 3 | **"Start Now" tap opens player but audio doesn't play** | `_openPlay()` pushes `PlayScreen` but `PlayScreen._initAudio()` only loads the audio file — it never calls `play()`. User must tap the play button manually. | `lib/features/home/home_screen.dart:43`, `lib/features/play/play_screen.dart:82` |
| 4 | **"Begin Recitation" button hides the Continuous Play toggle** | Bottom CTA uses `Positioned(bottom: 0)` with no safe-area padding. On phones with a home indicator (34px safe zone), the 80px spacer isn't enough and the last toggle is partially obscured. | `lib/features/profile/profile_screen.dart:202` |

---

## P2 — High-impact features (Core product gaps)

| # | Feature | What's missing | Notes |
|---|---------|---------------|-------|
| 5 | **Hamburger menu → Drawer with user profile** | `Icons.menu_rounded` is a plain `Icon` with no tap handler — clicking does nothing. Needs a `Drawer` showing: signed-in user photo + name, today's recitation count, "Sync Your Path" Google SSO CTA, and link to Profile settings. | `lib/features/home/home_screen.dart:95` |
| 6 | **Seamless return to playing screen** | Switching tabs while playing abandons the PlayScreen. User has no way to get back without the home screen refreshing/losing state. Needs a persistent mini-player bar or a sticky "now playing" FAB that taps back to PlayScreen. | `lib/core/main_shell.dart` |
| 7 | **Offline completion sync queue** | Completions are lost if offline. Needs: store failed syncs in a local `pending_syncs` table → retry on next app launch or when connectivity is restored. | `lib/data/repositories/app_repository.dart`, `lib/core/supabase_service.dart` |
| 8 | **English lyrics toggle** | Lyrics file (`assets/lyrics/hanuman_chalisa.json`) is Hindi only. Add an English transliteration/translation and a toggle in `_LyricsPanel` to switch between Hindi and English seamlessly without restarting playback. | `assets/lyrics/hanuman_chalisa.json`, `lib/features/play/play_screen.dart:650` |

---

## P3 — Medium-priority features (Meaningful improvements)

| # | Feature | What's missing | Notes |
|---|---------|---------------|-------|
| 9 | **Playback speed / tempo control** | No speed control exists. Add a speed chip row (0.75×, 1×, 1.25×, 1.5×) in PlayScreen, using `just_audio`'s `setSpeed()`. Save chosen speed to `UserSettings`. | `lib/features/play/play_screen.dart` |
| 10 | **Shareable milestone cards via WhatsApp** | The share button in PlayScreen top bar sends a generic message. After reaching 11/21/108 completions, show a celebratory bottom sheet with a "Share on WhatsApp" button that includes the milestone count and a referral code. | `lib/features/play/play_screen.dart:259` |
| 11 | **ॐ symbol repositioned to lower-right** | Currently `Center` in `_BackgroundLayer`. Per original Stitch design: enlarged (≈220px), positioned lower-right of screen. | `lib/features/play/play_screen.dart:593` |
| 12 | **Global font size slider** | No font scaling exists. Add a slider (0.8× – 1.4×) in Sankalp Settings that applies a `textScaleFactor`-style multiplier across the app. Important for elderly users. | `lib/features/profile/profile_screen.dart` |
| 13 | **Random Hanuman Ji background photos** | Hero card on HomeScreen shows a single static `hanuman_hero.png` (falls back to ॐ symbol if missing). Add 15–20 photos to `assets/images/` and pick one at random per app session. | `lib/features/home/home_screen.dart:121` |

---

## P4 — Lower-priority enhancements

| # | Feature | What's missing | Notes |
|---|---------|---------------|-------|
| 14 | **App icon** | Default Flutter launcher icon. Replace with a proper Hanuman Chalisa icon using `flutter_launcher_icons`. | `android/app/src/main/res/`, `pubspec.yaml` |
| 15 | **Lock screen lyrics display** | Lock screen shows play/pause controls (audio_service) but no lyrics. Would require a custom notification layout with `MediaSession` extras. Complex on Android, skip unless requested. | `lib/core/audio_handler.dart` |
| 16 | **Referral reward design + implementation** | Sharing sends the code but nothing happens when someone else enters it. Needs product decision first: options include (a) badge on leaderboard, (b) unlock a voice/track, (c) streak-protection day. Once decided, implement a `referrals` table in Supabase + claim flow. | `lib/data/repositories/app_repository.dart`, `supabase/migrations/` |
| 17 | **Voice recitation audio file** | `assets/audio/voice_1.mp3` already exists and is wired as "Voice Recitation" in Sacred Melodies. Verify audio quality and replace with a better recording if needed. No code changes required unless file is silent/corrupt. | `assets/audio/voice_1.mp3` |
