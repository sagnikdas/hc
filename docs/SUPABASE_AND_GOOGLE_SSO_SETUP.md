# Supabase + Google SSO + Leaderboard — Setup Guide

This document matches the current Hanuman Chalisa Flutter app: Supabase is initialized in `lib/main.dart`, Google Sign-In uses `google_sign_in` with a **Web OAuth client ID** as `serverClientId`, then exchanges tokens via `signInWithIdToken` in `lib/core/supabase_service.dart`. The leaderboard and sync layer expect the SQL in `supabase/migrations/20260325_phase3_social.sql`.

**Identifiers in this repo**

| Platform | Value |
|----------|--------|
| Android `applicationId` | `com.sagnikdas.hanuman_chalisa` (`android/app/build.gradle.kts`) |
| iOS bundle ID | `com.sagnikdas.hanumanChalisa` (`ios/Runner.xcodeproj/project.pbxproj`) |

---

## 1. Prerequisites

- [Supabase](https://supabase.com) account and a new (or existing) project  
- [Google Cloud](https://console.cloud.google.com) project  
- Flutter SDK; run `flutter pub get` from the repo root  
- For Android debug builds: Java `keytool` (for SHA-1)  
- For iOS: Xcode, Apple Developer Program as needed for devices  

**Secrets:** Create `lib/core/app_secrets.dart` locally. It is listed in `.gitignore` and must not be committed. Use `lib/core/app_secrets.dart` as the single place for `kSupabaseUrl`, `kSupabaseAnonKey`, and `kGoogleWebClientId`.

---

## 2. Supabase project

1. In the [Supabase Dashboard](https://supabase.com/dashboard), create or open a project.  
2. Note **Project URL** and **anon public** key: **Settings → API**.  
3. Put them in `app_secrets.dart`:

```dart
// lib/core/app_secrets.dart — do not commit
const kSupabaseUrl = 'https://<project-ref>.supabase.co';
const kSupabaseAnonKey = '<anon-public-key>';

// Google Web Client ID (Step 5); required for GoogleSignIn.serverClientId
const kGoogleWebClientId =
    '<numbers>-<client-id-suffix>.apps.googleusercontent.com';
```

**Important:** `kGoogleWebClientId` must be the real **Web application** client ID from Google Cloud. If you leave a placeholder like `YOUR_WEB_CLIENT_ID.apps.googleusercontent.com`, sign-in will fail (often with no `id_token`).

Never put the **service_role** key in the app. It is server-only.

---

## 3. Database schema (profiles, completions, leaderboard)

Run the full migration once in **SQL Editor → New query**:

- **Canonical file:** [`supabase/migrations/20260325_phase3_social.sql`](../supabase/migrations/20260325_phase3_social.sql)

It creates:

- `public.profiles` — display name and optional `referral_code`, RLS (users manage own row; anyone can `SELECT` for leaderboard names)  
- `public.completions` — synced play completions; users insert own rows; anyone can `SELECT` for aggregation  
- `get_leaderboard(p_weekly boolean)` — RPC returning top 10 by total `count` (all-time or last 7 days); granted to `anon` and `authenticated` so the leaderboard UI can load without forcing login  

If SQL errors mention existing objects, adjust manually (for example you may have an older `profiles` table from `docs/supabase_migration.sql` without `referral_code`). In that case add missing columns with `ALTER TABLE` or reconcile policies so they match the migration intent.

**Verify**

- Table Editor shows `profiles` and `completions`.  
- In SQL Editor: `select * from get_leaderboard(false) limit 1;` should run without error (may return no rows until data exists).

---

## 4. Google Cloud — APIs and OAuth consent

1. Open [Google Cloud Console](https://console.cloud.google.com) and select/create a project.  
2. **APIs & Services → Library**: enable **Google People API** (helps with profile fields some sign-in flows use).  
3. **APIs & Services → OAuth consent screen**  
   - User type: **External** (or Internal for Workspace-only).  
   - Fill app name, support email, developer contact.  
   - Complete scopes/scopes summary as prompted.  
   - For broad testing outside your Google account, publish the app when appropriate.

---

## 5. Google Cloud — OAuth clients

You need **three** client types: **Web**, **Android**, and **iOS**. The **Web** client ID and secret pair are what Supabase’s Google provider uses; the **same Web client ID** is what the Flutter app passes as `GoogleSignIn(serverClientId: kGoogleWebClientId)` so Google returns a valid **ID token** for Supabase.

### 5.1 Web client (Supabase + `kGoogleWebClientId`)

1. **Credentials → Create credentials → OAuth client ID**.  
2. Application type: **Web application**.  
3. **Authorized redirect URIs** — add exactly:

   `https://<project-ref>.supabase.co/auth/v1/callback`

   Replace `<project-ref>` with the subdomain from your Supabase URL (e.g. `abcdxyzcompany` from `https://abcdxyzcompany.supabase.co`).

4. Create and copy:  
   - **Client ID** → used in Supabase *and* in `kGoogleWebClientId`  
   - **Client secret** → **Supabase dashboard only**, never in Flutter  

### 5.2 Android client

1. **OAuth client ID → Android**.  
2. Package name: `com.sagnikdas.hanuman_chalisa`  
3. SHA-1 (debug example):

   ```bash
   keytool -keystore ~/.android/debug.keystore -list -v \
     -alias androiddebugkey -storepass android -keypass android
   ```

   Paste the **SHA1** fingerprint. Add a separate OAuth client for your **release** keystore SHA-1 before shipping.

### 5.3 iOS client

1. **OAuth client ID → iOS**.  
2. Bundle ID: `com.sagnikdas.hanumanChalisa`  
3. Download **GoogleService-Info.plist** if you use Firebase-style tooling; for `google_sign_in` you still need the **REVERSED_CLIENT_ID** for URL schemes (below).

---

## 6. Supabase — Enable Google provider

1. **Authentication → Providers → Google**.  
2. Enable and paste the **Web** **Client ID** and **Client secret** from section 5.1.  
3. Confirm the **callback URL** shown in the UI matches the redirect URI you added in Google Cloud.  

The mobile app does not embed the client secret; it signs in natively and sends the ID token to Supabase, which verifies it using this provider configuration.

---

## 7. iOS — URL scheme (required)

`Info.plist` in this repo does not yet include a Google URL scheme; add it so the OAuth callback can return to the app.

1. Open `ios/Runner/Info.plist`.  
2. Add `CFBundleURLTypes` with the **REVERSED_CLIENT_ID** from Google’s iOS OAuth client (also present as `REVERSED_CLIENT_ID` in `GoogleService-Info.plist` if you downloaded it). It looks like `com.googleusercontent.apps.<numbers>-<suffix>`.

Example structure:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_SUFFIX</string>
    </array>
  </dict>
</array>
```

If you add `GoogleService-Info.plist` to the Runner target in Xcode, ensure it is the plist for the same bundle ID.

---

## 8. Android notes

- Default template already includes `INTERNET`; no change required for sign-in alone.  
- Wrong **package name** or **SHA-1** causes `sign_in_failed` / `DEVELOPER_ERROR`.

---

## 9. End-to-end checks

| Check | How |
|--------|-----|
| App boots | `flutter run`; no crash on `Supabase.initialize` |
| Google sign-in | Profile (or sign-in UI) → sign in; session appears under **Authentication → Users** |
| Profile row | Complete profile form; **Table Editor → profiles** shows a row for your `auth.users` id |
| Completions | Complete a listen locally while signed in; `completions` gains rows (see `AppRepository` → `syncCompletion`) |
| Leaderboard | Open leaderboard tab; `get_leaderboard` returns rows (empty until completions exist) |

---

## 10. Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `Google id_token is null` in Dart | `kGoogleWebClientId` missing/wrong; use the **Web** client ID used in Supabase, not the Android/iOS client ID alone |
| Android `sign_in_failed` / `DEVELOPER_ERROR` | SHA-1 or package name mismatch in Google Cloud Android OAuth client |
| iOS sign-in hangs or fails | `CFBundleURLTypes` / REVERSED_CLIENT_ID missing or incorrect |
| Supabase rejects token | Google provider disabled, wrong Web client/secret, or redirect URI mismatch |
| Leaderboard RPC error | Migration not applied; or function name/argument typo (`p_weekly`) |
| Profile insert denied | RLS or not signed in; ensure policies from phase 3 migration are present |

---

## 11. Related files in the repo

| File | Role |
|------|------|
| `lib/main.dart` | `Supabase.initialize(url, anonKey)` |
| `lib/core/supabase_service.dart` | Google sign-in, profile CRUD, `syncCompletion`, `fetchLeaderboard` |
| `lib/data/repositories/app_repository.dart` | Calls `SupabaseService.syncCompletion` after local completion |
| `lib/features/leaderboard/leaderboard_screen.dart` | Calls `fetchLeaderboard` |
| `supabase/migrations/20260325_phase3_social.sql` | Schema + RPC |

Older snippets: `docs/google_sso_setup.md` and `docs/supabase_migration.sql` are partial/legacy; use this guide and the phase 3 migration file as the source of truth for the current app.
