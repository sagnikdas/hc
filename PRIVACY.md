# Privacy Policy

**Last Updated: April 2026**

## Introduction

The Hanuman Chalisa app ("we," "us," "our," or "app") is committed to protecting your privacy. This Privacy Policy explains our data practices and your rights.

## 1. Data Collection & Use

### 1.1 Offline-First Core Experience
The app's core prayer experience (chanting, lyrics, playback) is **entirely offline**. We do not collect, transmit, or store any data about your prayer sessions unless you actively sign in.

### 1.2 Optional Cloud Sync (When Signed In)
If you create an account and sign in, we collect and store the following to sync your progress across devices:

- **Completion Records**: Date, duration, and number of times you complete the Hanuman Chalisa chant
- **User Settings**: Language preferences, audio quality settings, app theme preferences, and font scaling
- **Streak Data**: Your daily and weekly streak counts, heatmap data for historical progress visualization
- **Account Information**: Email address and profile name (via Google Sign-In or your chosen auth method)

This data is stored securely in our Supabase database and synced between your devices when you're signed in.

### 1.3 Local Storage
Your device stores a local copy of:
- Completion records and statistics
- User preferences and settings
- Prayer session history

This local data remains on your device and is never transmitted unless you sign in and enable sync.

## 2. Third-Party Services

### 2.1 Google Sign-In
If you choose to sign in via Google, we use Google's authentication service. We receive your email address and profile name. Google's Privacy Policy governs their data practices: https://policies.google.com/privacy

### 2.2 Supabase (Backend & Auth)
When you sign in, we store your data in Supabase (https://supabase.io/), a cloud database service. Supabase's Privacy Policy: https://supabase.io/privacy

We use Supabase for:
- Authentication and account management
- Storing and syncing completion data and user settings
- Leaderboard functionality (aggregated statistics)

### 2.3 Firebase Cloud Messaging
The app may send you push notifications for milestones and reminders. Push notification delivery is handled by your device's native notification system; we do not store notification preferences on our servers beyond your device settings.

## 3. Data Security

- All data transmitted between the app and our servers is encrypted in transit (HTTPS/TLS)
- Local device storage is protected by your device's security mechanisms
- We do not share your personal data with third parties except where necessary (Google, Supabase)
- We do not sell, trade, or rent your personal information

## 4. Data Retention

- **While Signed In**: Your account data is stored indefinitely until you delete your account
- **Offline**: Local data remains on your device until you uninstall the app or manually clear app data
- **After Account Deletion**: We delete your personal data from our servers within 30 days. Local device data remains until you clear it manually

To delete your account, contact us at [support email — add if applicable].

## 5. Your Rights & Control

You have the right to:
- **Access**: View what data we store about you
- **Rectify**: Update or correct inaccurate information
- **Erase**: Delete your account and associated data
- **Opt-Out**: Stop syncing by signing out (local data remains on your device)
- **Data Portability**: Request a copy of your data in a standard format

To exercise these rights, [contact support — add if applicable].

## 6. Children's Privacy

This app is not directed to children under 13. We do not knowingly collect personal information from children under 13. If we become aware that a child under 13 has provided us personal information, we will delete such information promptly.

## 7. Changes to This Policy

We may update this Privacy Policy periodically. We will notify you of significant changes by updating the "Last Updated" date and, where required, by requesting your consent.

## 8. Contact Us

If you have questions about this Privacy Policy or our privacy practices, please contact us at:

**Email**: sagnikd91@gmail.com  

---

## Appendix: Data Flows

### Prayer Session Recording (Offline)
User completes chant → App records locally → No transmission

### Prayer Session Recording (Signed In)
User completes chant → App records locally → Fire-and-forget sync to Supabase (if online) → Data appears on dashboard after sync

### Settings Sync (Signed In)
User changes language/theme → Saved locally → Synced to Supabase on next app launch

### Leaderboard (Signed In)
Your aggregated completion count may appear on the leaderboard if you opt in. Only your name and weekly/all-time completion count are visible to other users.
