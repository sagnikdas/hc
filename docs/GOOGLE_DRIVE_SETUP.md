# Upload APK to Google Drive — Quick Guide

## Step 1: Find Your APK File

The APK file is ready at:
```
/Users/sagnikdas/hc/build/app/outputs/flutter-apk/Hanuman_Chalisa_v1.0.0_beta.apk
```

**File size**: 72 MB  
**File name**: `Hanuman_Chalisa_v1.0.0_beta.apk`

---

## Step 2: Upload to Google Drive

### Option A: Via Web Browser (Easiest)

1. Open [Google Drive](https://drive.google.com)
2. Click **New** (left side) → **File upload**
3. Find and select: `Hanuman_Chalisa_v1.0.0_beta.apk`
4. Wait for upload to complete (2–3 minutes)
5. You'll see a checkmark when done ✓

### Option B: Drag & Drop

1. Open [Google Drive](https://drive.google.com)
2. Open a **new folder** for beta testing (optional):
   - Click **New** → **Folder** → Name it "Hanuman Chalisa Beta"
3. Drag the APK file from your computer into Google Drive
4. Release to upload

---

## Step 3: Share the Link

### Recommended: Anyone with Link (No Sign-in Needed)

1. Right-click the APK file in Google Drive
2. Click **Share**
3. In the popup, click **Change** (next to "Restricted")
4. Select **Anyone with the link**
5. Permission: Make sure **Viewer** is selected
6. Click **Copy link** → Link is now copied
7. Click **Done**

### Share the Link with Your 10 Testers

Paste the link into:
- **WhatsApp group** (fastest)
- **Email** (attach the link in the message)
- **Telegram** (in a message or group)

**Example message to send:**

```
Hi everyone! 🙏

I've prepared the Hanuman Chalisa app for beta testing. 
You can download it from this link:

[PASTE GOOGLE DRIVE LINK HERE]

Instructions:
1. Download the APK file
2. Open Settings → Security → Enable "Unknown sources"
3. Open Downloads → Tap the APK → Install

Full instructions are here:
[PASTE THIS LINK: https://raw.githubusercontent.com/YOUR_REPO/TESTING_INSTRUCTIONS.md]

Please test and send feedback via WhatsApp. Thanks! 🙏
```

---

## Step 4: Share Testing Instructions

Option 1: **Copy-paste from TESTING_INSTRUCTIONS.md**
- Open `TESTING_INSTRUCTIONS.md` in this repo
- Share the content in a message or document

Option 2: **Create a Google Doc**
1. In Google Drive, click **New** → **Google Docs**
2. Copy-paste content from `TESTING_INSTRUCTIONS.md`
3. Share the doc with testers (everyone can view)
4. Send them the link

Option 3: **Send as file**
- Attach `TESTING_INSTRUCTIONS.md` to your email

---

## Verify the Upload

After uploading, test the link yourself:

1. **Incognito window** (⇧ + Ctrl + N in Chrome)
2. Paste the Google Drive link you shared
3. Click **Download** → File should download
4. ✓ If it works for you, it will work for everyone

---

## Troubleshooting

### Link doesn't work
- Check permission is set to **"Anyone with the link"**
- Make sure you copied the full link

### Download is slow
- Normal for 72 MB file on mobile data (3–5 min)
- Recommend testers use WiFi

### Testers can't download
- Ask them to check: Do they have WiFi or mobile data?
- Ask them to try again in a few minutes
- Check if their browser is blocking the download

---

## After Testing

1. **Collect feedback** from your 10 testers (via WhatsApp, email, etc.)
2. **Fix any critical bugs** before Play Store launch
3. **Update version** in `pubspec.yaml` if you rebuild
4. **Upload new APK** to Google Drive
5. **Notify testers** of the updated version

---

## Ready?

1. ✓ APK is ready: `Hanuman_Chalisa_v1.0.0_beta.apk`
2. ✓ Upload to Google Drive
3. ✓ Share link with your 10 testers
4. ✓ Send them `TESTING_INSTRUCTIONS.md`
5. ✓ Collect feedback
6. ✓ Launch on Play Store!

Good luck! 🙏
