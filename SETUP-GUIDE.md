# TaskOra — how to run the app, step by step

You don't need to install Flutter or Android Studio. GitHub builds the app for you in the cloud,
and every phone with TaskOra installed gets your fixes automatically.

**Where things live:**

- **Sign-in:** Google Firebase handles only Google and email login.
- **Your data:** the app saves everything on the phone first, then syncs it with your own server, a small PHP + MySQL API in the `server/taskora-api` folder that runs on your normal web hosting next to WordPress.

**Time needed:** about 45 minutes the first time. After that, shipping a fix takes about 2 minutes plus 10 minutes of build time.

**You need:** a Google account, a free GitHub account (github.com), and an Android phone.

You also have two private files that came with this code. **Never upload them to GitHub or share them:**

- `upload-keystore.jks` is the app's signing key. Every version must be signed with this same key, or phones won't install the update. Back it up somewhere safe, such as Google Drive.
- `TaskOra-signing-secrets.txt` holds the passwords, the key as text, and the SHA fingerprints you'll paste in below.

---

## Part 1 — Create the Firebase project (sign-in only)

1. Go to **console.firebase.google.com**, click **Create a project** and name it `TaskOra`. You can turn Google Analytics off. Click **Create**.
2. On the project home page, click the **Android** icon to add an app.
   - **Android package name:** `com.taskora.taskora` (it must be exactly this).
   - **App nickname:** TaskOra.
   - **Debug signing certificate SHA-1:** paste the **SHA-1** from `TaskOra-signing-secrets.txt`.
   - Click **Register app**. You can **skip** downloading `google-services.json` and skip the SDK steps.
3. Open **Project settings** (the gear icon), find **Your apps → TaskOra**, and click **Add fingerprint**. Paste the **SHA-256** from the secrets file and save.
4. In the left menu, open **Build → Authentication → Get started**.
   - Enable **Email/Password**.
   - Enable **Google** and choose a support email. After saving, open the Google provider again, expand **Web SDK configuration** and copy the **Web client ID** (it ends in `.apps.googleusercontent.com`). You'll need it in Part 3.
5. You do **not** need Firestore or Realtime Database. Your data goes to your own server (Part 2).
6. Back in **Project settings → General → Your apps → TaskOra**, write down these four values:
   - **App ID** (looks like `1:1234567890:android:abc...`)
   - **Project ID**
   - **Project number** (this is the "sender ID")
   - **Web API Key** (shown at the top of the General tab)

## Part 2 — Put the sync server on your hosting (cPanel)

This assumes the same hosting as your WordPress site. It needs PHP 7.4 or newer, MySQL, and HTTPS.

1. **Create the database.** In cPanel, open **MySQL Databases**.
   - Create a database, e.g. `taskora`. cPanel names it something like `youruser_taskora`.
   - Create a user with a strong password.
   - Under **Add user to database**, give that user **ALL PRIVILEGES** on the database.
2. **Upload the API.** In **File Manager**, open `public_html` and upload the folder `server/taskora-api` from this code, so it ends up at `public_html/taskora-api/`.
   - Zip it first, upload the zip, then use **Extract**.
   - Make sure the hidden `.htaccess` files came along. In File Manager, use **Settings → Show hidden files** to check.
3. **Fill in the settings.** In `taskora-api`, copy `config.sample.php` to `config.php` and edit it:
   - `db_name`, `db_user` and `db_pass`: from step 1
   - `firebase_project_id`: your Firebase **Project ID** from Part 1, step 6
4. **Create the table.** Open `https://rabbyhossain.com/taskora-api/install.php` in a browser. It should say `"ok":true`. Then **delete `install.php`** from the server.
   - Alternative: import `schema.sql` in phpMyAdmin.
5. **Check it.** Open `https://rabbyhossain.com/taskora-api/health.php`. Every check should be `true`, and the last line should read `"all_good":true`.
   - If `google_keys` is false, your host blocks outgoing connections. Ask support to allow outgoing HTTPS to `www.googleapis.com`.
   - If `cache_writable` is false, set the `cache` folder's permissions to 755.
6. If you used a different folder or domain, change `apiBase` in `lib/config.dart` to match. It must start with `https://`.

**How it stays private:** every request carries the person's Firebase sign-in token, and the server checks Google's signature on it. Each person can only read and write their own rows, and `config.php` can't be opened from a browser.

## Part 2b — Turn on Google Drive backup

1. Go to **console.cloud.google.com** and select the same `TaskOra` project from the top bar. Firebase created it for you.
2. Open **APIs & Services → Library**, search for **Google Drive API** and click **Enable**.
3. Open **APIs & Services → OAuth consent screen** (it may be called **Google Auth Platform → Branding / Audience**).
   - App name: TaskOra. Use your email for both support and contact.
   - Under **Data access / Scopes**, click **Add scope** and add `.../auth/drive.appdata`. This lets the app see only its own hidden backup folder, not your other files.
   - Under **Audience**, click **Publish app**. While it stays in "Testing", only the test users you add can sign in.

## Part 3 — Put your settings into the code

Open these two files in any text editor (or edit them on GitHub later with the pencil icon).

**`lib/firebase_options.dart`** — replace each `YOUR_...` with the values from Part 1, step 6:

```dart
apiKey: 'AIza...',                       // Web API Key
appId: '1:1234567890:android:abc123',    // App ID
messagingSenderId: '1234567890',         // Project number
projectId: 'taskora-xxxxx',              // Project ID
storageBucket: 'taskora-xxxxx.appspot.com',
```

**`lib/config.dart`**:

```dart
static const apiBase = 'https://rabbyhossain.com/taskora-api';  // Part 2
static const githubOwner = 'your-github-username';
static const githubRepo = 'taskora';
static const googleWebClientId = '....apps.googleusercontent.com'; // from Part 1, step 4
```

## Part 4 — Put the code on GitHub

1. On github.com, click **New repository**. Name it `taskora` and choose **Public**.
   It has to be public so phones can download updates without logging in. Your data never lives here; only the app code does.
   Leave "Add a README" unticked, then click **Create repository**.
2. Upload the code. The easiest way is **GitHub Desktop** (desktop.github.com):
   - Use **File → Clone repository** to get your empty `taskora` repo.
   - Copy everything from this folder into it, including the hidden `.github` folder.
   - Write a summary such as "First version" and click **Commit to main**, then **Push origin**.

   *Web-only alternative:* on the repo page, use **Add file → Upload files** and drag in all the folders. If your file browser hides `.github`, create `.github/workflows/build.yml` by hand with **Add file → Create new file** and paste the file's contents.
3. Make sure **no `.jks` file** was uploaded. The `.gitignore` file blocks it, but check anyway.

## Part 5 — Add your signing key to GitHub (one time only)

In your repo, go to **Settings → Secrets and variables → Actions → New repository secret** and add these four secrets. Copy each value from `TaskOra-signing-secrets.txt`.

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | the long block of text |
| `KEYSTORE_PASSWORD` | the password |
| `KEY_ALIAS` | `taskora` |
| `KEY_PASSWORD` | the same password |

## Part 6 — Build and install the first version

1. In your repo, open the **Actions** tab. If GitHub asks, click **I understand… enable workflows**.
2. Click **Build & release TaskOra → Run workflow**. Type `1.0.0` as the version, leave **Publish** ticked, and click **Run workflow**.
3. Wait about 8–12 minutes for the green tick. If you get a red ✗ instead, see Troubleshooting below.
4. On your phone, open `github.com/<you>/taskora/releases`, then tap **TaskOra-v1.0.0.apk** to download it.
5. Open the download. Android will ask you to **allow installs from this source**: tap **Settings → Allow**, go back, and tap **Install**.
6. Open TaskOra and tap **Continue with Google**. 🎉

## Part 7 — Fix a bug and send the update to every phone

This is the update system. You fix the code, publish a new version, and every installed app shows a notification plus an **"Update ready"** popup.

1. **Fix the code.** On GitHub, open the file, click the ✏️ pencil, make the change and click **Commit changes**. You can also commit from GitHub Desktop.
2. **Write the notes.** Edit `RELEASE_NOTES.md`. The app reads these two headings for the popup and the What's new page:

   ```markdown
   ## New
   - Repeat to-dos every week

   ## Fixed
   - Fiverr fee rounding on amounts with cents
   ```

3. **Publish it.** Go to **Actions → Build & release TaskOra → Run workflow** and type a **higher** version, such as `1.0.1`.
4. About 10 minutes later the new Release is live. Every phone running TaskOra then:
   - checks for updates when the app opens or comes back to the front (at most every 3 hours),
   - shows a phone notification saying **"TaskOra 1.0.1 is ready"** and adds it to the in-app Notifications,
   - shows the **Update ready** popup with your Fixed / New notes, and
   - after you tap **Update now**, downloads the APK and asks you to **Install**. Your data stays, because it lives in the cloud and on the phone, not inside the APK.

   You can also check by hand at **Profile → Check for update**.

Version numbers: use `1.0.1`, `1.0.2` … for fixes, `1.1.0` for bigger features, and `2.0.0` for big changes. A version always has to be higher than the last one.

---

## How it fits together

| Feature | How it works |
|---|---|
| Sync | Your server (`taskora-api`, PHP + MySQL). Changes upload about 2 seconds after you make them, and the app also checks every minute and whenever you reopen it. Pull down on any page to sync right away; a bar at the bottom confirms it. |
| Offline / local storage | Everything is saved on the phone first. With no internet, changes wait in a queue and upload when you're back online. |
| Sign-in | Firebase Auth (Google or email). That's the only thing Firebase does. |
| Phone backup | An automatic JSON backup (daily, weekly or monthly) is saved in the app's folder on the phone. Export shares it anywhere. |
| Google Drive backup | An automatic backup goes to a hidden app folder in your own Drive, which only TaskOra can see. The newest 10 are kept (change this in Preferences). |
| Undo | Every delete shows an **Undo** bar at the bottom for 5 seconds. |
| Reminders | Phone notifications at the reminder time, and they still work after a restart. |
| Updates | GitHub Releases plus the in-app checker (`lib/services/update_service.dart`). |

## Troubleshooting

- **Google sign-in fails ("error 10" or "DEVELOPER_ERROR"):** the SHA-1 in Firebase doesn't match the signing key. Re-check Part 1, steps 2–3, and make sure the four secrets are set. A build without them uses a random key.
- **Google sign-in fails with "Sign-in cancelled" right away:** check `googleWebClientId` in `lib/config.dart`.
- **The build has a red ✗:** click the failed run, open the red step and read the last 30 lines. Copy them to me and I'll fix it.
- **"Couldn't reach the update server (404)":** `githubOwner` or `githubRepo` in `config.dart` is wrong, or the repo is private.
- **The update didn't show:** the new version must be higher, the run must have **Publish** ticked, and the app checks at most every 3 hours. Use **Profile → Check for update** to check right away.
- **"Update" downloads but won't install ("App not installed"):** the new APK was signed with a different key. Always keep the same 4 secrets.
- **Backup & sync says "Can't reach your server":** open `health.php` (Part 2, step 5) and fix any check that is false. Make sure `apiBase` is correct and uses https.
- **"Token is for another Firebase project":** set `firebase_project_id` in `config.php` to your Firebase Project ID.
- **Server replies with HTML instead of data (Cloudflare, security page or "Imunify360"):** whitelist `/taskora-api/` in your hosting's firewall or bot protection.
- **Drive backup says not connected:** turn on the Google Drive API (Part 2, step 2), and if you signed in with email, tap **Back up now** once to connect Google.

## Run it on a computer (optional, for developers)

Install Flutter 3.27, then:

```bash
flutter create --org com.taskora --project-name taskora --platforms=android .
flutter pub get
flutter run
```

## What's not built yet

- **Assigned / teammates:** marked "Soon" everywhere.
- **Licence keys:** the License page is ready, but there is no payment backend yet, so everything stays unlocked.
- **Google Docs-style tabs inside a note:** the note editor has text, checklist and dropdown blocks. Tabs would be the next block type.
