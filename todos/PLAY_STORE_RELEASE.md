# Google Play Store Release Checklist

---

## Phase 1 — Fix Critical Bugs (Pre-release blockers)

These are already in the backlog — **must fix before publishing**:

- [ ] **#2** — Remove debug banner: add `debugShowCheckedModeBanner: false` in `main.dart`
- [ ] **#3** — Fix "Start Now" not auto-playing audio
- [ ] **#1** — Fix heatmap not updating after completion
- [ ] **#4** — Fix bottom CTA hiding the Continuous Play toggle (safe-area padding)

---

## Phase 2 — App Identity & Assets

- [ ] **App name**: Change `android:label` from `"hanuman_chalisa"` → `"Hanuman Chalisa"` in `android/app/src/main/AndroidManifest.xml:11`
- [ ] **App icon**: Backlog item #14 — run `flutter pub run flutter_launcher_icons` (config already in `pubspec.yaml`, need icon images at the paths specified)
- [ ] **App version**: Confirm `version: 1.0.0+1` in `pubspec.yaml` is intentional; ensure `versionCode` increments with each upload
- [ ] **Package ID**: `com.sagnikdas.hanuman_chalisa` — confirm this is final (cannot change after first publish)

---

## Phase 3 — Android Signing (Critical)

`android/app/build.gradle.kts:38` currently uses `signingConfigs.getByName("debug")` — **must be replaced for release**.

- [ ] Generate a release keystore:
  ```bash
  keytool -genkey -v -keystore ~/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias upload
  ```
- [ ] Store keystore credentials in `android/key.properties` (never commit this file)
- [ ] Update `android/app/build.gradle.kts` to use the release signing config
- [ ] Add `android/key.properties` to `.gitignore`
- [ ] **Back up your keystore securely** — losing it means you can never update the app

---

## Phase 4 — Build & Test Release AAB

- [ ] `flutter analyze` — zero warnings
- [ ] `flutter test` — all tests green
- [ ] Build release AAB (Play Store requires AAB, not APK):
  ```bash
  flutter build appbundle --release
  ```
- [ ] Install and manually test on a physical Android device:
  - Audio plays and completes correctly
  - Notifications fire
  - Google Sign-In works
  - Supabase sync works
  - App doesn't crash on cold start

---

## Phase 5 — Google Play Console Setup

- [ ] Create a [Google Play Developer account](https://play.google.com/console) — one-time $25 USD fee
- [ ] Create a new app in Play Console
- [ ] Fill in **App details**:
  - App name, short description (80 chars), full description (4000 chars)
  - Category: `Music & Audio` or `Lifestyle`
  - Tags: devotional, prayer, Hindu, Hanuman Chalisa
- [ ] Upload **store listing assets**:
  - App icon: 512×512 PNG
  - Feature graphic: 1024×500 PNG
  - Screenshots: at least 2 phone screenshots (1080×1920 recommended)
  - Optional: 10-second promo video
- [ ] Set **Content rating** — complete the questionnaire (should be "Everyone")
- [ ] Set **Target audience** — All ages (no ads, no data collection from minors)
- [ ] **Privacy Policy URL** — required; must be hosted publicly (covers Supabase/Google Sign-In data)
- [ ] Fill in **Data safety section**:
  - Google account info (name, email, photo) via Google Sign-In
  - Usage data (recitation count, streaks) synced to Supabase
  - No financial data, no precise location

---

## Phase 6 — Permissions Audit

- [ ] **`RECORD_AUDIO`** — audit whether the app actually records audio. If not, remove it. This permission triggers Play Store scrutiny and may cause rejection without justification.
- [ ] **`SCHEDULE_EXACT_ALARM`** — required justification since Android 12+. Ensure the notification UX handles graceful denial by the user.

---

## Phase 7 — Supabase / Backend Readiness

- [ ] Confirm Supabase project is on a plan whose limits won't block real users
- [ ] Confirm API keys in `app_secrets.dart` are not committed in plaintext
- [ ] Enable Row Level Security on all Supabase tables
- [ ] Register the **release** SHA-1 fingerprint in Google Cloud Console for OAuth — it differs from the debug SHA-1 and Google Sign-In will silently fail without it

---

## Phase 8 — Play Store Release Track

- [ ] Upload AAB to **Internal Testing** track → test with 5–10 real users
- [ ] Promote to **Closed Testing (Alpha)** → broader group
- [ ] Fix any issues found → promote to **Open Testing (Beta)** (optional)
- [ ] Submit for **Production** — Google review typically takes 1–7 days for first submission

---

## Quick Summary of Blockers

| Priority | Item |
|----------|------|
| P0 | Release signing config (currently uses debug keys) |
| P0 | `RECORD_AUDIO` permission — remove or justify |
| P0 | Privacy policy URL |
| P0 | Fix 4 P1 bugs from backlog |
| P1 | App icon (backlog #14) |
| P1 | Proper app label ("Hanuman Chalisa") |
| P1 | Google Sign-In SHA-1 for release keystore |
| P2 | Store listing copy + screenshots |
| P2 | Data safety section in Play Console |
