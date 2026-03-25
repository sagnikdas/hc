# Google SSO + Supabase Setup Guide

## What you'll set up
- A Google Cloud project with OAuth 2.0 credentials (Web, Android, iOS)
- Supabase Google authentication provider
- A `profiles` table in Supabase with RLS policies
- App secrets wired into the Flutter codebase
- iOS URL scheme for Google Sign-In redirect

## Prerequisites
- Google account
- Supabase project (already created — URL: kxliplazsbwoizdekiwy.supabase.co)
- Flutter app with package name: com.sagnikdas.hanuman_chalisa
- Xcode installed (for iOS bundle ID)

## Step 1 — Create a Google Cloud Project
1. Go to https://console.cloud.google.com
2. Click "Select a project" dropdown at the top → "New Project"
3. Project name: HanumanChalisa (or anything)
4. Click "Create"
5. Make sure the new project is selected in the top dropdown

## Step 2 — Enable the Google People API
1. In left sidebar → "APIs & Services" → "Library"
2. Search for "Google People API"
3. Click it → "Enable"
(needed to fetch profile name/email)

## Step 3 — Create OAuth Consent Screen
1. APIs & Services → "OAuth consent screen"
2. User Type: External → "Create"
3. App name: Hanuman Chalisa
4. User support email: your email
5. Developer contact email: your email
6. Click "Save and Continue" through all screens
7. Back to dashboard → click "Publish App" → "Confirm"
   (keeps you out of 100-user test limit)

## Step 4 — Create OAuth Credentials (Web — for Supabase)
1. APIs & Services → "Credentials" → "+ Create Credentials" → "OAuth client ID"
2. Application type: **Web application**
3. Name: HanumanChalisa-Supabase
4. Authorized redirect URIs → "+ Add URI":
   ```
   https://kxliplazsbwoizdekiwy.supabase.co/auth/v1/callback
   ```
5. Click "Create"
6. **Copy and save:**
   - Client ID  (you will paste this into Supabase AND into `app_secrets.dart` as `kGoogleWebClientId`)
   - Client Secret (you will paste this into Supabase only — never put in app code)

## Step 5 — Create OAuth Credentials (Android)
1. "Credentials" → "+ Create Credentials" → "OAuth client ID"
2. Application type: **Android**
3. Package name:
   ```
   com.sagnikdas.hanuman_chalisa
   ```
4. SHA-1 certificate fingerprint — get it by running:
   ```bash
   # Debug keystore (for development):
   keytool -keystore ~/.android/debug.keystore -list -v -alias androiddebugkey -storepass android -keypass android
   # Copy the SHA1 value shown
   ```
   Paste the SHA-1 into the form.
5. Click "Create" (no secret needed for Android native)
6. For release builds, repeat with your release keystore SHA-1

## Step 6 — Create OAuth Credentials (iOS)
1. "Credentials" → "+ Create Credentials" → "OAuth client ID"
2. Application type: **iOS**
3. Bundle ID: Find yours in Xcode → open `ios/Runner.xcworkspace` → click Runner target → General tab → Bundle Identifier (e.g., `com.sagnikdas.hanumanChalisa`)
4. Click "Create"
5. **Copy the iOS Client ID** — you will need the **REVERSED_CLIENT_ID** (reverse it manually: e.g., `com.googleusercontent.apps.1234567890-abc` becomes `com.googleusercontent.apps.1234567890-abc` reversed = `abc-1234567890.apps.googleusercontent.com` → actually the reversed client id is given directly in the downloaded plist — see Step 8)
6. Download the `GoogleService-Info.plist` — **you'll use this for iOS config**

## Step 7 — Configure Supabase Google Provider
1. Go to https://supabase.com/dashboard/project/kxliplazsbwoizdekiwy
2. Left sidebar → "Authentication" → "Providers"
3. Find "Google" → toggle Enable
4. Paste **Web Client ID** (from Step 4) into "Client ID"
5. Paste **Web Client Secret** (from Step 4) into "Client Secret"
6. Callback URL shown in the panel should match what you put in Step 4
7. Click "Save"

## Step 8 — Configure Supabase SQL (profiles table)
1. Supabase dashboard → "SQL Editor" → "New query"
2. Paste and run the SQL from `docs/supabase_migration.sql`

## Step 9 — Add kGoogleWebClientId to app_secrets.dart
Open `lib/core/app_secrets.dart` and set:
```dart
const kGoogleWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
```
(The Client ID from Step 4)

## Step 10 — iOS: Add URL scheme for Google Sign-In
1. Open `ios/Runner/Info.plist` in a text editor
2. Locate the `<key>CFBundleURLTypes</key>` array (or create it)
3. Add the following entry using the **REVERSED_CLIENT_ID** from your iOS OAuth credential:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```
   The REVERSED_CLIENT_ID looks like: `com.googleusercontent.apps.1234567890-xxxxxxxxx`
   It is in the downloaded `GoogleService-Info.plist` under the key `REVERSED_CLIENT_ID`

## Step 11 — iOS: Add GoogleService-Info.plist
1. In Xcode, drag the `GoogleService-Info.plist` (from Step 6) into the Runner folder
2. Make sure "Copy items if needed" is checked and "Runner" target is checked

## Step 12 — Android: Internet permission
Already present in AndroidManifest.xml. No changes needed.

## Step 13 — Run pub get
```bash
flutter pub get
```

## Step 14 — Test sign-in
```bash
flutter run -d <your_device>
```
Tap "Continue with Google" on startup. Complete profile. Verify data appears in Supabase → Table Editor → profiles.

## Troubleshooting
- **PlatformException(sign_in_failed)**: SHA-1 mismatch. Re-run keytool and verify exact SHA-1 in Google Cloud Console.
- **DEVELOPER_ERROR on Android**: Wrong package name or SHA-1. Double-check both.
- **iOS sign-in hangs**: REVERSED_CLIENT_ID URL scheme missing from Info.plist.
- **Supabase "invalid JWT"**: Web Client ID in app_secrets.dart doesn't match what's in Supabase dashboard.
- **Profile not saving**: Check Supabase RLS policies — run the SQL migration exactly.
