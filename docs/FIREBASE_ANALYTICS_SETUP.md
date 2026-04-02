# Firebase Analytics Setup Guide

**Status**: ✅ Code changes completed  
**Next Step**: Configure Firebase project and add credentials

---

## ✅ What Has Been Done (Code Changes)

Firebase Analytics has been integrated into your app. Here's what was added:

### 1. Dependencies Added (`pubspec.yaml`)
```yaml
firebase_core: ^2.24.0
firebase_analytics: ^10.7.0
firebase_crashlytics: ^3.4.0
```

### 2. Firebase Initialization (`lib/main.dart`)
```dart
// Global analytics instance
late final FirebaseAnalytics analytics;

// In main():
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
analytics = FirebaseAnalytics.instance;

// Crash reporting enabled
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
```

### 3. Analytics Events Added

**Onboarding Screen** (`lib/features/onboarding/onboarding_screen.dart`):
- `onboarding_skipped` — When user taps "Skip for now"
- `user_signed_in` — When user signs in with Google

**Play Screen** (`lib/features/play/play_screen.dart`):
- `audio_completed` — When user completes listening to audio
  - Parameters: duration, completed_count, target_count, timestamp

**Profile Screen** (`lib/features/profile/profile_screen.dart`):
- `reminders_toggled` — When user enables/disables reminders
  - Parameters: enabled (true/false), timestamp

### 4. Firebase Options Template (`lib/firebase_options.dart`)
A placeholder file created that will be filled with your Firebase credentials.

---

## 📋 Complete Setup Steps (You Do This)

### Step 1: Create Firebase Project

**Time**: 5 minutes

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Create a new project**
3. Name: `Hanuman Chalisa`
4. Enable Google Analytics: ✅ YES
5. Select or create a Google Analytics property
6. Click **Create project**
7. Wait for initialization to complete

### Step 2: Add Android App

**Time**: 10 minutes

1. In Firebase Console, click **+ Add app**
2. Select **Android**
3. **Package name**: `com.yourcompany.hanumanchalisa`
   - Match exactly what's in `android/app/build.gradle`
4. **App nickname**: `Hanuman Chalisa Android` (optional)
5. Click **Register app**
6. **Download google-services.json** file
7. Place the file in: `android/app/` directory
8. Click **Next** through the remaining steps
9. Click **Continue to console**

### Step 3: Add iOS App

**Time**: 10 minutes

1. In Firebase Console, click **+ Add app**
2. Select **iOS**
3. **Bundle ID**: `com.yourcompany.hanumanchalisa`
   - Match exactly what's in Xcode
4. **App nickname**: `Hanuman Chalisa iOS` (optional)
5. Click **Register app**
6. **Download GoogleService-Info.plist** file
7. Open Xcode: `open ios/Runner.xcworkspace/`
8. Drag the `GoogleService-Info.plist` into Xcode
   - Select **Copy items if needed** ✅
   - Select **Add to targets**: Runner ✅
9. Click **Next** through the remaining steps
10. Click **Continue to console**

### Step 4: Generate Firebase Config File

**Time**: 5 minutes (automatic)

Run the FlutterFire CLI to auto-generate the `firebase_options.dart` file:

```bash
# Install FlutterFire CLI (one-time)
dart pub global activate flutterfire_cli

# Generate firebase_options.dart
flutterfire configure \
  --project=hanuman-chalisa \
  --platforms=android,ios,web
```

This will:
1. Ask you which Firebase project to use (select `Hanuman Chalisa`)
2. Ask which platforms to configure (select Android, iOS, Web)
3. Auto-generate `lib/firebase_options.dart` with your credentials
4. Replace the placeholder file

**Alternative (Manual)**: If you can't use FlutterFire CLI, manually copy credentials from Firebase Console to `lib/firebase_options.dart`:

In Firebase Console → Project Settings → Your Apps:
- **Android**: Copy API key from google-services.json
- **iOS**: Copy API key from GoogleService-Info.plist
- Fill in `lib/firebase_options.dart` with these values

### Step 5: Enable Analytics in Firebase Console

**Time**: 2 minutes

1. Go to **Analytics** in left sidebar
2. Click **Enable analytics** (if not already enabled)
3. You should now see an "Analytics Dashboard" option

### Step 6: Build and Test

**Time**: 10 minutes

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Build for Android
flutter build apk --release

# Or build for iOS
flutter build ios --release
```

### Step 7: Test on Real Device

**Time**: 5 minutes

1. Install on Android device or iOS device
2. Open app
3. Tap "Skip for now" or sign in with Google
4. Play audio until it completes
5. Toggle reminders on/off

### Step 8: View Analytics Data

**Time**: 2-5 minutes (data takes time to appear)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **Hanuman Chalisa** project
3. Go to **Analytics** → **Dashboard**
4. Wait 1-5 minutes for events to appear
5. You should see:
   - **Realtime** tab: Live events as they happen
   - **Dashboard**: User overview and events

---

## 📊 What You'll See in Firebase

### Real-time Events (appears immediately)

Once data starts flowing, you'll see in the **Realtime** tab:
- User count
- Events happening right now
- User properties

### Dashboard (updates within 24 hours)

- **Active Users**: Daily/Weekly/Monthly
- **Sessions**: How long users spend in the app
- **Events**: Track completions, sign-ins, settings changes
- **Crashes**: Automatic crash reporting
- **Performance**: App startup time, frame rates

### Custom Reports

Create custom dashboards to track:
- How many users complete audio daily
- How many enable reminders
- User retention (do they come back?)
- Conversion funnel (download → sign-in → leaderboard)

---

## 🔍 Viewing Specific Events

### View Audio Completions

1. Go to **Analytics** → **Events**
2. Search for `audio_completed`
3. See:
   - How many times audio was completed
   - Average duration
   - Completion count breakdown

### View Sign-ins

1. Go to **Analytics** → **Events**
2. Search for `user_signed_in`
3. See:
   - How many users signed in
   - When they signed in
   - Conversion rate (% of users who sign in)

### View Reminder Toggles

1. Go to **Analytics** → **Events**
2. Search for `reminders_toggled`
3. See:
   - How many users enabled reminders
   - How many disabled them
   - User preferences

---

## 📲 Crash Reporting (Automatic)

Firebase Crashlytics will automatically capture:
- App crashes
- Stack traces
- Device info (OS version, model)
- User data (if logged in)

**View Crashes**:
1. Go to **Crashlytics** in left sidebar
2. See all crashes reported by users
3. Click on a crash to see stack trace
4. Use this to find bugs before users report them

---

## 🎯 What Events Are Being Tracked

| Event | Triggered When | Parameters |
|-------|---|---|
| `onboarding_skipped` | User taps "Skip for now" | timestamp |
| `user_signed_in` | User signs in with Google | method (google), timestamp |
| `audio_completed` | Audio playback finishes | duration_seconds, completed_count, target_count, timestamp |
| `reminders_toggled` | User enables/disables reminders | enabled (true/false), timestamp |

### Auto-Tracked Events (No Code Needed)
- `first_open` — App opens for first time
- `app_open` — App opens (any time)
- `session_start` — User session starts
- `session_end` — User session ends
- `screen_view` — User navigates to new screen (if enabled)

---

## 🆘 Troubleshooting

### Events Not Showing Up

**Problem**: Set up Firebase but events not appearing in dashboard

**Solutions** (in order):
1. **Wait**: Events take 5-30 minutes to appear (not instant)
2. **Check console**: Run `flutter logs` and look for Firebase logs
3. **Verify config**: Ensure `firebase_options.dart` has correct API keys
4. **Test on device**: Firebase may not work well on emulator
5. **Check Privacy**: Android may have restricted analytics permission

### Firebase Won't Initialize

**Problem**: App crashes with "Firebase initialization failed"

**Solutions**:
1. **Check API key**: Verify keys in `firebase_options.dart`
2. **Check bundle ID**: Must match Firebase console exactly
3. **Check permissions**: AndroidManifest.xml needs INTERNET permission
4. **Rebuild**: `flutter clean && flutter pub get`

### Can't Generate firebase_options.dart

**Problem**: `flutterfire configure` command not found

**Solutions**:
1. Install CLI: `dart pub global activate flutterfire_cli`
2. Add to PATH: `export PATH="$PATH":"$HOME/.pub-cache/bin"`
3. Or manually fill in `lib/firebase_options.dart` with values from Firebase Console

### No Google-Services.json

**Problem**: Downloaded but Android app can't find it

**Solution**: Ensure file is in `android/app/` (not `android/`)

### No GoogleService-Info.plist in Xcode

**Problem**: Downloaded but Xcode can't find it

**Solution**: 
1. Reopen Xcode: `open ios/Runner.xcworkspace/`
2. Drag file into sidebar (under Runner folder)
3. Check "Copy items if needed" ✅

---

## 📈 Best Practices

### 1. Don't Track Too Much

❌ Bad: Track every tiny action (every button tap, every scroll)
✅ Good: Track key milestones (audio completed, settings changed)

**Reason**: Too many events = noise in data + slower app

### 2. Use Meaningful Names

❌ Bad: `event_1`, `user_action`, `button_click`
✅ Good: `audio_completed`, `reminders_enabled`, `sign_in_success`

### 3. Add Useful Parameters

❌ Bad: Just log that something happened
✅ Good: Log context (which audio, what setting, when, user info)

### 4. Review Data Regularly

- Check weekly what users are doing
- Spot trends (e.g., "many users enable reminders but few use them")
- Use data to improve the app

---

## 💰 Pricing (You're Safe)

| Feature | Free Tier | Cost |
|---------|-----------|------|
| **Analytics Events** | Unlimited | FREE |
| **User Count** | Unlimited | FREE |
| **Crash Reports** | Unlimited | FREE |
| **Performance Monitoring** | Unlimited | FREE |
| **Custom Dashboards** | Unlimited | FREE |
| **Data Retention** | 1 year | FREE |

**You only pay if**:
- You store >100GB of data (unlikely unless millions of users)
- You use BigQuery export (optional advanced feature)

**For your app**: Completely FREE forever ✅

---

## 🚀 Next Steps

1. ✅ Code changes done (you already have everything)
2. Create Firebase project (5 min)
3. Add Android app to Firebase (10 min)
4. Add iOS app to Firebase (10 min)
5. Run `flutterfire configure` (5 min)
6. Build & test (10 min)
7. View analytics in Firebase Console (2 min)

**Total time**: ~45 minutes

---

## 📚 Resources

- **Firebase Console**: https://console.firebase.google.com
- **FlutterFire Docs**: https://firebase.flutter.dev/
- **Analytics Guide**: https://firebase.flutter.dev/docs/analytics/usage/
- **Crashlytics**: https://firebase.flutter.dev/docs/crashlytics/overview/
- **Firebase Blog**: https://firebase.blog/

---

## ✨ Summary

Your app now tracks:
- ✅ When users skip onboarding
- ✅ When users sign in
- ✅ When users complete audio
- ✅ When users toggle reminders
- ✅ App crashes (automatic)

All **completely free** and **completely private** (data stays in your Firebase project).

Just follow the 7 setup steps above and you'll have full analytics visibility into how users are using your app! 🎉
