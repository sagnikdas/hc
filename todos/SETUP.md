# Complete Setup Guide — Hanuman Chalisa App
> Follow every step in order. Do not skip any step.
> Your specific project values are already filled in wherever possible.

---

# PART 1 — Google Cloud Console

---

## STEP 1 — Open Google Cloud and Create a Project

1. Open your browser (Chrome preferred) and go to:
   ```
   https://console.cloud.google.com
   ```

2. Sign in with your Google account if prompted.

3. Once the page loads, look at the **top-left area** of the screen.
   Next to the Google Cloud logo there is a button that shows your current
   project name (might say "My First Project" or "Select a project").
   **Click that button.**

4. A popup window opens showing your existing projects.
   In the **top-right corner of the popup**, click **"NEW PROJECT"**.

5. Fill in the form:
   - **Project name**: type exactly →
     ```
     Hanuman Chalisa
     ```
   - **Organization / Location**: leave as default ("No organization").

6. Click the blue **"CREATE"** button.

7. Wait about 15–20 seconds. A notification bell at the top-right will
   show "Creating project: Hanuman Chalisa…" and then "Created".

8. Click the **project dropdown** at the top-left again.
   You will now see "Hanuman Chalisa" in the list. Click it.
   The dropdown now shows **"Hanuman Chalisa"** — this is your active project.

---

## STEP 2 — Enable the Google People API

1. In the **left sidebar**, click **"APIs & Services"**.
   (If the sidebar is hidden, click the ☰ hamburger icon at the very top-left first.)

2. In the submenu that appears, click **"Library"**.

3. You will see a search bar. Click it and type:
   ```
   Google People API
   ```

4. In the search results, click **"Google People API"** (by Google LLC).

5. Click the blue **"ENABLE"** button.

6. Wait 10–15 seconds until the page reloads and shows "API enabled". ✅

---

## STEP 3 — Set Up the OAuth Consent Screen

> This is the screen your users see when they tap "Continue with Google".
> You must complete this before creating any credentials — Google requires it.

1. In the left sidebar, click **"APIs & Services"**, then click **"OAuth consent screen"**.

2. On the right side of the page, you will see two radio buttons:
   - **Internal** (only for Google Workspace users in your org)
   - **External** (for everyone, which is what you want)

   Select **"External"**, then click **"CREATE"**.

3. You are now on the "Edit app registration" page — **App information** section.
   Fill in every field exactly as follows:

   - **App name**: type →
     ```
     Hanuman Chalisa
     ```
   - **User support email**: click the dropdown → select your email address.
   - **App logo**: skip this (leave blank).
   - **App domain** section: skip all three fields (leave blank).
   - **Developer contact information** → **Email addresses** (at the very bottom):
     type your email address.

4. Click **"SAVE AND CONTINUE"** (blue button at the bottom).

5. You are now on the **Scopes** page.
   Click the **"ADD OR REMOVE SCOPES"** button.
   A panel slides in from the right side of the screen.

6. Inside that panel there is a **filter/search box**. Type:
   ```
   userinfo.email
   ```
   One row appears. **Check the checkbox** on the left of that row.

7. Clear the search box. Type:
   ```
   userinfo.profile
   ```
   One row appears. **Check the checkbox** on the left of that row.

8. Clear the search box. Type:
   ```
   openid
   ```
   One row appears. **Check the checkbox** on the left of that row.

9. Scroll down inside the panel to find the **"UPDATE"** button. Click it.

10. You are back on the Scopes page. Click **"SAVE AND CONTINUE"**.

11. You are on the **Test users** page. Click **"SAVE AND CONTINUE"** (skip this page).

12. You are on the **Summary** page. Click **"BACK TO DASHBOARD"** at the bottom.

---

## STEP 4 — Create the Web OAuth Client ID
### ⚠️ Most important step — do this carefully.

> The Web client ID is what both Supabase and your Flutter app use to verify
> Google logins. If this is wrong, sign-in will not work.

1. In the left sidebar, click **"APIs & Services"** → **"Credentials"**.

2. Near the top of the page, click the **"+ CREATE CREDENTIALS"** button.
   A small dropdown appears. Click **"OAuth client ID"**.

3. You are now on the "Create OAuth client ID" page.
   - **Application type**: click the dropdown → select **"Web application"**.
   - **Name**: type →
     ```
     Hanuman Chalisa Web
     ```

4. Scroll down to find the section **"Authorized redirect URIs"**.
   Click **"+ ADD URI"**.

5. In the text box that appears, paste this **exact URL** (already has your project ref):
   ```
   https://ymcmpmigmuvpofkdywgd.supabase.co/auth/v1/callback
   ```

6. Click the blue **"CREATE"** button.

7. A popup appears: **"OAuth client created"**.
   It shows two values. **You must save both right now.**

   Open your Mac's Notes app (or any text file) and paste them like this:
   ```
   === Google Web Client ===
   Client ID:     [paste here — ends in .apps.googleusercontent.com]
   Client Secret: [paste here — starts with GOCSPX-]
   ```

   You will use the **Client ID** in Step 13 (code) and Step 10 (Supabase).
   You will use the **Client Secret** in Step 10 (Supabase only).

8. Click **"OK"** to close the popup.

---

## STEP 5 — Get Your Android SHA-1 Fingerprint

> Google needs this to confirm requests are really coming from your Android app.

1. Open **Terminal** on your Mac.
   Press **Cmd + Space**, type `Terminal`, press **Enter**.

2. Copy the entire command below and paste it into Terminal, then press **Enter**:
   ```bash
   keytool -list -v \
     -keystore ~/.android/debug.keystore \
     -alias androiddebugkey \
     -storepass android \
     -keypass android
   ```

3. Terminal prints several lines. Find the line that starts with `SHA1:`.
   It looks like:
   ```
   SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
   ```

4. Copy everything **after** `SHA1: ` (the colon-separated hex string).
   Save it in your Notes:
   ```
   === Android SHA-1 ===
   SHA1: [paste here]
   ```

---

## STEP 6 — Create the Android OAuth Client ID

1. Go back to Google Cloud Console browser tab.
   You should still be on **"APIs & Services → Credentials"**.

2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**.

3. Fill in the form:
   - **Application type**: select **"Android"**.
   - **Name**: type →
     ```
     Hanuman Chalisa Android
     ```
   - **Package name**: type exactly →
     ```
     com.sagnikdas.hanuman_chalisa
     ```
   - **SHA-1 certificate fingerprint**: paste the SHA1 value you saved in Step 5.

4. Click **"CREATE"**.

5. A popup shows the new credential. Click **"OK"**.
   (You do not need to copy anything here.)

---

## STEP 7 — Create the iOS OAuth Client ID

1. Still on **"APIs & Services → Credentials"**.

2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**.

3. Fill in the form:
   - **Application type**: select **"iOS"**.
   - **Name**: type →
     ```
     Hanuman Chalisa iOS
     ```
   - **Bundle ID**: type exactly →
     ```
     com.sagnikdas.hanumanChalisa
     ```
   - **App Store ID**: leave blank.
   - **Team ID**: leave blank.

4. Click **"CREATE"**.

5. A popup appears showing **"Your Client ID"** — a long string ending in
   `.apps.googleusercontent.com`.

   **Copy it and save it in your Notes:**
   ```
   === iOS Client ID ===
   Client ID: [paste here]
   ```

6. Click **"OK"**.

---

# PART 2 — Supabase Dashboard

---

## STEP 8 — Verify Your Supabase URL and Anon Key

1. Open this URL (your Supabase project settings):
   ```
   https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/settings/api
   ```

2. On this page you will see:
   - **Project URL**: `https://ymcmpmigmuvpofkdywgd.supabase.co`
   - **anon public** key: a long JWT string starting with `eyJ...`

3. These are already in your `lib/core/app_secrets.dart` file. No action needed here — just confirming they match.

---

## STEP 9 — Enable Google Sign-In in Supabase

1. Open this URL directly (your Google auth provider page):
   ```
   https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/auth/providers
   ```

2. The page shows a list of authentication providers.
   Scroll down until you see **"Google"** in the list.

3. Click on **"Google"** to expand it.

4. At the top of the expanded section there is a toggle switch.
   Click it so it turns **ON** (blue/green color).

5. Two input fields appear:
   - **Client ID (for iOS)**: paste your **Web Client ID** from Step 4.
     (The long string ending in `.apps.googleusercontent.com`)
   - **Client Secret**: paste your **Web Client Secret** from Step 4.
     (The string starting with `GOCSPX-`)

6. Click **"Save"**.

7. A green success message appears at the top. ✅

---

## STEP 10 — Run the Database Migration

> This creates the tables the app needs: profiles, completions, and the leaderboard function.

1. Open VS Code. In your project, find and open this file:
   ```
   supabase/migrations/20260325_phase3_social.sql
   ```
   It is in the root of your project folder, inside the `supabase/migrations/` folder.

2. Press **Cmd + A** to select all the text in the file.

3. Press **Cmd + C** to copy it.

4. Now open this URL in your browser:
   ```
   https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/sql/new
   ```

5. You will see a large dark text area — this is the SQL editor.

6. Click anywhere inside the dark text area.

7. Press **Cmd + A** to select any existing placeholder text, then press **Delete** to clear it.

8. Press **Cmd + V** to paste the SQL you copied.

9. Look at the bottom of the page. Click the green **"Run"** button.
   (Shortcut: **Cmd + Enter**)

10. Below the editor, you will see a result area.
    It should show: **"Success. No rows returned"**
    This is correct. It means all tables and functions were created. ✅

11. **If you see a red error:** Read the error message.
    - If it says "already exists" — that's fine, the table was already there.
      Click the run button again — Supabase handles duplicates with `IF NOT EXISTS`.
    - If it says something else — copy the error and search it or let me know.

---

## STEP 11 — Verify the Tables Were Created

1. Open this URL to view your database tables:
   ```
   https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/editor
   ```

2. In the left panel, under **"public"** schema, you should see:
   - `completions`
   - `profiles`

3. If both appear, the migration worked. ✅

4. Optional — verify the leaderboard function works:
   Go back to the SQL editor:
   ```
   https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/sql/new
   ```
   Paste and run:
   ```sql
   select * from get_leaderboard(false) limit 1;
   ```
   It should say "Success. No rows returned" (empty because no data yet). ✅

---

# PART 3 — Code Changes (2 files to edit)

---

## STEP 12 — Update app_secrets.dart with Your Web Client ID

1. In VS Code, open:
   ```
   lib/core/app_secrets.dart
   ```

2. You will see this line near the bottom:
   ```dart
   const kGoogleWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
   ```

3. Replace that **entire line** with your real Web Client ID from Step 4.

   **Example of what it should look like after editing:**
   ```dart
   const kGoogleWebClientId = '123456789-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com';
   ```
   Use your **actual Client ID** — not this example.

4. Press **Cmd + S** to save.

---

## STEP 13 — Add the iOS URL Scheme to Info.plist

> This is required so the iPhone can return to your app after Google Sign-In.
> Without it the app will hang on iOS.

1. In VS Code, open:
   ```
   ios/Runner/Info.plist
   ```

2. Scroll to the **very bottom** of the file.
   The last two lines look like this:
   ```xml
   </dict>
   </plist>
   ```

3. Click at the end of the **second-to-last line** (the `</dict>` line).
   Press **Enter** to create a new line just above `</dict>`.

   Actually the easiest way: click just **before** `</dict>` on that line,
   then add a new line above it. The block you need to insert is:

   ```xml
   	<key>CFBundleURLTypes</key>
   	<array>
   		<dict>
   			<key>CFBundleTypeRole</key>
   			<string>Editor</string>
   			<key>CFBundleURLSchemes</key>
   			<array>
   				<string>REPLACE_THIS_WITH_REVERSED_IOS_CLIENT_ID</string>
   			</array>
   		</dict>
   	</array>
   ```

4. **What to put instead of `REPLACE_THIS_WITH_REVERSED_IOS_CLIENT_ID`:**

   Take your iOS Client ID from Step 7. It looks like:
   ```
   123456789-xxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
   ```

   The reversed version is just this pattern:
   ```
   com.googleusercontent.apps.123456789-xxxxxxxxxxxxxxxxxxxx
   ```
   (You remove `.apps.googleusercontent.com` from the end and put
   `com.googleusercontent.apps.` at the front, then paste your number part.)

   **Concrete example:**
   ```
   iOS Client ID:  98765432-abcdef123456.apps.googleusercontent.com
   Reversed value: com.googleusercontent.apps.98765432-abcdef123456
   ```

5. After your edit, the **bottom of Info.plist** should look exactly like this
   (indentation uses tabs, matching the rest of the file):
   ```xml
   	<key>CFBundleURLTypes</key>
   	<array>
   		<dict>
   			<key>CFBundleTypeRole</key>
   			<string>Editor</string>
   			<key>CFBundleURLSchemes</key>
   			<array>
   				<string>com.googleusercontent.apps.YOUR_ACTUAL_NUMBER_HERE</string>
   			</array>
   		</dict>
   	</array>
   </dict>
   </plist>
   ```

6. Press **Cmd + S** to save.

---

# PART 4 — Run and Test

---

## STEP 14 — Run the App

1. Connect your phone via USB, or open a simulator.

2. Open Terminal and go to your project folder:
   ```bash
   cd ~/hc
   ```

3. Run:
   ```bash
   flutter run
   ```

4. The first build takes 2–3 minutes. Subsequent runs are faster.

---

## STEP 15 — Test Every Feature in Order

Work through this list top to bottom after the app installs:

**Onboarding (first launch only):**
- [ ] App opens and shows the Onboarding screen.
      You should see: the ॐ symbol, "Hanuman Chalisa" title, three feature bullet points.
- [ ] Tap **"Invite devotees via WhatsApp"** → share sheet opens → close it.
- [ ] Tap **"Begin Your Journey"** → app goes to the main screen with 4 tabs at the bottom.
- [ ] iOS: A popup says "Allow Hanuman Chalisa to send notifications?" → tap **"Allow"**.

**Audio and lock-screen controls:**
- [ ] Tap the **Home tab** (house icon, bottom-left).
- [ ] Tap the **play button** → audio starts.
- [ ] Press the Home button on your phone → audio keeps playing in the background.
- [ ] Swipe down from the top of the screen (notification shade on Android /
      Control Centre on iPhone) → you see playback controls with play/pause button.
- [ ] Tap pause from the notification — audio pauses.
- [ ] Come back to the app.

**Google Sign-In:**
- [ ] Tap the **Settings tab** (gear icon, bottom-right).
- [ ] Near the top you see a card: "Sign in to sync your paath".
- [ ] Tap the **"Sign in"** button.
- [ ] A Google account picker appears. Tap your Google account.
- [ ] A profile form opens (name, email, phone, date of birth).
      Fill in all fields, then tap **"Continue"**.
- [ ] You return to the Settings tab.
      Your **name** and **Google profile picture** now show at the top. ✅

**Referral code:**
- [ ] In Settings tab, below your profile, you see "Invite Devotees"
      with a 6-character code (e.g. `XK4P7M`).
- [ ] Tap the share button → share sheet opens with your referral code message.

**Leaderboard:**
- [ ] Tap the **Trophy tab** (3rd icon, bottom nav).
- [ ] The Leaderboard screen loads.
      It will say "No completions yet" — this is correct since you haven't finished a full paath yet.
- [ ] Go back to Home, play the audio to the end (or long-press seek near the end).
- [ ] When it completes, you should feel a haptic vibration and the counter increments.
- [ ] Go back to the Trophy tab, pull down to refresh → your name appears on the board. ✅

**Verify data in Supabase (optional but recommended):**
- [ ] Open:
      ```
      https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/auth/users
      ```
      You should see your Google account listed as a user. ✅
- [ ] Open:
      ```
      https://supabase.com/dashboard/project/ymcmpmigmuvpofkdywgd/editor
      ```
      Click the `profiles` table → your row should be there with your name. ✅
      Click the `completions` table → a row should be there from your test completion. ✅

---

# Troubleshooting

| Problem | What to check |
|---------|---------------|
| "Sign-in failed" error on tap | `kGoogleWebClientId` in `app_secrets.dart` is wrong or still the placeholder. Re-do Step 12. |
| "Google id_token is null" | You used the Android or iOS client ID instead of the **Web** client ID. The Web client ID must be used in `app_secrets.dart` and in Supabase. |
| Android sign-in shows `DEVELOPER_ERROR` | SHA-1 fingerprint is wrong or package name is wrong. Re-check Step 6. |
| iPhone hangs after selecting Google account | `CFBundleURLTypes` in `Info.plist` is missing or the reversed client ID is wrong. Re-do Step 13. |
| Supabase rejects the token | Google provider not enabled, or wrong Client ID/Secret in Supabase. Re-do Step 9. |
| Tables don't exist in Supabase | SQL migration didn't run. Re-do Step 10. |
| Leaderboard shows network error | SQL migration not run, or the `get_leaderboard` function not created. Re-do Steps 10–11. |
| Notifications never appear | On iOS: Settings → Hanuman Chalisa → Notifications → enable. On Android: Settings → Apps → Hanuman Chalisa → Notifications → enable. |

---

# Final Checklist

- [ ] **Step 1** — Created Google Cloud project "Hanuman Chalisa"
- [ ] **Step 2** — Enabled Google People API
- [ ] **Step 3** — Configured OAuth consent screen
- [ ] **Step 4** — Created Web OAuth client → saved Client ID + Secret
- [ ] **Step 5** — Got SHA-1 fingerprint from Terminal
- [ ] **Step 6** — Created Android OAuth client (package name + SHA-1)
- [ ] **Step 7** — Created iOS OAuth client → saved iOS Client ID
- [ ] **Step 8** — Confirmed Supabase URL and anon key are already set
- [ ] **Step 9** — Enabled Google provider in Supabase (pasted Web Client ID + Secret)
- [ ] **Step 10** — Ran SQL migration in Supabase SQL editor
- [ ] **Step 11** — Verified `profiles` and `completions` tables exist
- [ ] **Step 12** — Updated `app_secrets.dart` with real Web Client ID
- [ ] **Step 13** — Added reversed iOS Client ID to `ios/Runner/Info.plist`
- [ ] **Step 14** — Ran `flutter run` successfully with no errors
- [ ] **Step 15** — Tested all features end-to-end
