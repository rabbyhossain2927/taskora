# TaskOra — Web & Desktop Version: Build Brief

> **For the AI building this:** Read this whole brief before you change anything. It describes an app that already exists and works on Android, and exactly how to add a web version of it.
> The goal is **one codebase**. Don't rewrite the app in another framework, and don't start a new project.

---

## 1. What TaskOra is

TaskOra is a productivity app for freelancers. It has **Projects**, **To-dos** (with sub-tasks) and **Notes**, and they link to each other. It is already live as an Android app.

| Item | Value |
|---|---|
| Source code | https://github.com/rabbyhossain2927/taskora (public, branch `main`) |
| Framework | **Flutter 3.27.1** (Dart ≥ 3.4), Material 3 |
| Sign-in | Firebase Auth (Google + email/password). Firebase is used **only** for sign-in. |
| Data | Saved on the device first (local JSON + an outbox), then synced to the owner's own PHP/MySQL server: `https://rabbyhossain.com/taskora-api` |
| Owner | Rabby Hossain — rabbyhossain.com — contact@rabbyhossain.com |

**The task:** add a **Flutter Web** build of this same app. It must:
1. look **exactly** like the phone app (same colours, font, cards, animations, themes, dark mode);
2. use a **desktop-style layout** on wide screens (details in section 5);
3. sync with the **same server and account**, so the phone and the web show the same data.

---

## 2. Rules you must follow

1. **Don't break the Android app.** Every change has to compile and behave the same on Android. Use `kIsWeb` checks and conditional imports, not deletions.
2. **Keep the UI identical.** Reuse the existing widgets in `lib/widgets/common.dart` and the theme in `lib/theme.dart`. Don't introduce a new design system, colours or fonts.
3. **Never commit secrets.** `.gitignore` already excludes `*.jks`, `android/key.properties` and `server/taskora-api/config.php`. Don't add a keystore, passwords or database credentials anywhere.
4. **Don't change the sync data format.** The phone and the web share the same server records (section 6).
5. **Plain, friendly wording** in the UI. The owner isn't a developer, so explain any manual steps in very simple language.
6. Work in small commits. CI must stay green: `.github/workflows/check.yml` runs `flutter analyze` and fails on errors.

---

## 3. Project map (what exists today)

```
lib/
  main.dart                 App start, AuthState, MaterialApp (built once), AuthGate (splash → welcome → Shell)
  config.dart               apiBase, GitHub owner/repo, googleWebClientId
  firebase_options.dart     Android Firebase options only → needs a WEB entry
  models.dart               Project, Todo, SubTask, Note, NoteTab, NoteBlock, Attachment, NoteSection, AppNotice, Tag
  theme.dart                Colours (C), pastels, noteColors, 37 appThemes, softPalette(), bgStyles, buildTheme(), AppBackground
  icons.dart                icon name → IconData map
  services/
    store.dart              ChangeNotifier with all data; local JSON file + outbox; sync(); archive/trash; flush()
    api.dart                POST JSON to the server with the Firebase ID token
    auth_service.dart       Google (google_sign_in) + email sign-in
    file_service.dart       Upload/delete files on the server (uses dart:io File)
    import_service.dart     .docx/.odt/.txt/.md → notes (uses dart:io File)
    notify_service.dart     flutter_local_notifications (Android only)
    focus_service.dart      Focus timer, state in SharedPreferences + notification controls (Android)
    backup_service.dart     Local backup files + Google Drive appdata backup (uses dart:io)
    update_service.dart     Downloads the APK from GitHub Releases and installs it (Android only)
    prefs.dart              SharedPreferences settings
  widgets/
    common.dart             Box, RoundButton, Header, MainHeader, Label, RowTile, TagChip, FadeIn, Pressable, pickers, toast…
    note_text.dart          NoteTextController: per-line styles (# heading, ## subheading, -# small, • bullets, **bold**)
  screens/
    shell.dart              4 tabs (Home, Projects, To-do, Notes) + floating white nav pill + round + button
    home_screen.dart, projects_screen.dart, project_detail.dart, project_editor.dart,
    todos_screen.dart, todo_editor.dart, notes_screen.dart, note_editor.dart,
    stats_screen.dart, focus_screen.dart, calendar_screen.dart, search_screen.dart,
    profile_screen.dart, bin_screen.dart (Archive/Trash), notifications_screen.dart,
    notification_settings.dart, backup_screen.dart, update_screen.dart, auth_screens.dart,
    splash_screen.dart, feedback_screen.dart, howto_screen.dart, about_screens.dart,
    badges_screen.dart, taxonomy_screen.dart
server/taskora-api/          PHP API (sync.php, files.php, feedback.php, account.php, health.php, lib.php)
.github/workflows/           check.yml (analyze on push), build.yml (APK + GitHub Release)
```

Files that import `dart:io` and so **won't compile for web as they are**: `store.dart`, `file_service.dart`, `import_service.dart`, `backup_service.dart`, `update_service.dart`, `screens/update_screen.dart`, `screens/backup_screen.dart`.

---

## 4. Design system: keep it exactly the same

All of this already lives in `lib/theme.dart` and `lib/widgets/common.dart`. **Reuse it; don't redefine it.**

- **Font:** Archivo via `google_fonts`. Text is scaled to 0.94× in `MaterialApp.builder`; keep that.
- **Text sizes (`T`):** display 24, title 20, heading 16, body 14, small 12.5, tiny 11.
- **Base colours (`C`):** ink `#16161D`, muted `#6E6E7C`, light background `#F6F6FA`, line `#ECECF2`, green `#1E8A5A`, red `#D64545`.
- **Dark mode:** surface `#1B1B23`, page `#111117`, ink `#EDEDF3`.
- **Accent:** the theme the user picks (37 options in `appThemes`, default Indigo Night `#5B5FEF`). The tint is the accent mixed 88% toward white.
- **Backgrounds:** `AppBackground` paints a soft accent glow plus a chosen style (glow, aurora, mesh, silk, waves, grain, paper, grid, dots, plain) behind every page. Scaffolds are transparent.
- **Shapes:** white cards (`Box`) with radius 22, round 44 px buttons (`RoundButton`), stadium chips, 16 px input radius, 28 px bottom-sheet radius.
- **Pastels:** 20 bg/fg pairs (`pastels`) for categories and statuses, and 32 note colours.
- **Motion:** `FadeIn` staggered list entrance, `Pressable` scale on press, a 380 ms custom page transition (`BackgroundPageTransitionsBuilder`), and the animated rings and bars.
- **Nav (phone):** a floating white pill with 4 tabs. The selected tab is an accent-gradient pill with its icon and label, and it slides between tabs. Next to it is a 66 px accent-gradient round **+** button: tap it for Project/To-do/Note, hold it for Focus.

---

## 5. Desktop / wide-screen layout (the new part)

Use breakpoints on the window width:

| Width | Layout |
|---|---|
| < 700 px | **Phone layout, unchanged** (bottom nav pill + **+** button) |
| 700–1100 px | **Compact desktop:** icon-only sidebar (72 px) + content |
| ≥ 1100 px | **Full desktop:** labelled sidebar (240 px) + list pane + detail pane |

### 5.1 Sidebar (replaces the bottom nav on wide screens)
- Same visual language as the nav pill: white (dark: `#1E1E27`) rounded panel, 24 px radius, soft shadow, 12 px margin from the window edges.
- Top: the TaskOra logo and name.
- A big accent-gradient **"+ New"** button. Clicking it opens the same Project / To-do / Note menu. Ctrl+Shift+F (or holding the button) opens Focus.
- Tabs: Home, Projects, To-do, Notes. The selected tab is the accent-gradient pill with a white icon and label. The rest use a grey icon and label, with a subtle tint on hover.
- Lower section: Stats, Calendar, Focus, Notifications (with unread badge), Archive, Trash.
- Bottom: avatar, name and sync status dot. Clicking it opens Profile/Settings.

### 5.2 Panes
- **Projects:** the grid of square cards becomes 3–5 columns. Clicking a card opens `ProjectDetail` in a **right-hand detail pane** (about 42% width, min 420 px) instead of a new page. Board view uses the full width.
- **To-do:** list on the left; clicking a row opens `TodoEditor` in the right pane. Auto-save on close is already built in.
- **Notes:** folders and notes grid on the left (3–4 columns). Opening a note shows `NoteEditor` in a wide right pane, max 820 px readable width, centred when there's room.
- **Home:** two columns. Left: greeting, today card, due today, next 7 days. Right: active projects, Stats + Focus tiles, note folders.
- **Editors and pickers:** on desktop, bottom sheets (`showModalBottomSheet`) should show as centred dialogs, max width 520, same radius and styling. Make a helper, e.g. `showAdaptiveSheet`, and use it everywhere.
- Close the detail pane with **Esc** or an × button. Keep the selected item highlighted in the list.

### 5.3 Desktop interactions
- **Hover:** every `Box` with `onTap`, plus every card and row, gets a hover state (slight lift or tint, and a pointer cursor).
- **Right-click** opens the same menu as long-press (`showProjectActions`, `showTodoActions`, `showNoteActions`).
- **Keyboard shortcuts:**
  - Ctrl/Cmd+N new to-do, Ctrl/Cmd+Shift+P new project, Ctrl/Cmd+Shift+N new note
  - Ctrl/Cmd+K search, Ctrl/Cmd+1–4 switch tabs, Esc close the pane or dialog
  - In the note editor: Ctrl+B bold, Ctrl+Alt+1 heading, Ctrl+Alt+2 subheading, Ctrl+Alt+0 normal, Ctrl+Shift+8 bullets
- **Swipe actions** (flutter_slidable) still work with the mouse, but always offer the right-click menu too.
- **Scroll:** smooth mouse-wheel scrolling, visible thin scrollbars on desktop, and no overscroll glow.
- **Notes:** drag-and-drop a .docx/.odt/.txt/.md file onto the Notes page to import it (optional, nice to have).

---

## 6. Server API (don't change the data format)

Base URL: `https://rabbyhossain.com/taskora-api`

Every request needs the Firebase ID token. Send both headers:
```
Authorization: Bearer <firebase id token>
X-Auth-Token: <firebase id token>
```

### `POST sync.php`
Request:
```json
{ "since": "<cursor string, '0' first time>",
  "changes": [ { "col": "projects|todos|notes|sections|notices|meta", "id": "<id>", "data": { ... } , "deleted": false } ] }
```
Response:
```json
{ "saved": 3, "changes": [ { "col": "...", "id": "...", "deleted": false, "data": { ... } } ],
  "cursor": "<next cursor>", "more": false, "serverTime": 1790000000000 }
```
- Loop while `more` is true. Local unsent edits win over incoming ones for the same `col/id`.
- `meta/user` holds tags, statuses, projectCats and todoCats.
- Dates are **milliseconds since 1970** (numbers).
- Archive and Trash are stored **inside** the item's data: `archived: true` + `archivedAt`, and `deletedAt` (+ `trashedWith` for to-dos trashed together with their project). Items in Trash for more than 30 days are deleted for good.

### `files.php`
- Upload: `POST multipart/form-data`, field `file` (max 30 MB, 2 GB per user). Returns `{id, name, mime, size, url, used, limit}`.
- `POST {"action":"usage"}` returns `{used, limit}`. `POST {"action":"delete","id":"..."}` deletes a file.
- `GET files.php?id=<id>` returns the file, publicly readable by its random ID.

### Others
- `feedback.php`: POST `{name, message, kind, appVersion}`.
- `account.php`: POST `{"action":"delete"}`.
- `health.php`: GET, returns a status JSON.

### Required server change for web: CORS
Browsers block these calls unless the server allows the web app's address. Add this to `server/taskora-api/lib.php`, near the top, before any output, and keep it tight:
```php
$allowed = ['https://app.rabbyhossain.com', 'https://rabbyhossain.com', 'http://localhost:8080'];
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, $allowed, true)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
    header('Access-Control-Allow-Headers: Authorization, X-Auth-Token, Content-Type');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Max-Age: 86400');
}
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }
```
- `files.php` serves files with its own headers. Make sure the CORS headers above run for it too.
- Bump `SERVER_VERSION` in `lib.php`. The server updates itself from GitHub every 6 hours. It never overwrites `config.php` or `install.php`.

### New, optional: `preview.php` (link previews)
Browsers can't fetch other websites directly, so the web app can't read their og: tags. Add a small, signed-in-only endpoint:
- `POST {url}` returns `{title, description, image}`.
- Fetch with a 6 s timeout and a 512 KB limit, `http/https` only.
- Block private and loopback IPs (to prevent server-side request forgery).
- Cache the result.

`LinkPreview` in `note_editor.dart` should use it when `kIsWeb`.

---

## 7. Code changes needed for web (Flutter side)

1. **Enable web:** run `flutter create --platforms=web .`. Then edit `web/index.html` and `web/manifest.json`:
   - title "TaskOra", theme colour `#5B5FEF`, background `#F6F6FA`;
   - the app icons;
   - a simple CSS loading screen (logo + thin progress bar) that matches the Android splash.
2. **Firebase for web:**
   - Add a `web` entry to `DefaultFirebaseOptions` and pick it with `kIsWeb`. The values come from the owner (section 9).
   - `projectId: taskora-4f3f0`, `messagingSenderId: 305454392450`, `authDomain: taskora-4f3f0.firebaseapp.com`, plus the web `appId` and `apiKey` from the console.
3. **Google sign-in on web:** use `FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())`; keep `google_sign_in` for Android. Email sign-in, sign-up and password reset work as they are.
4. **Remove `dart:io` from shared code** using conditional imports (`import 'x_io.dart' if (dart.library.html) 'x_web.dart';`):
   - **`store.dart`** local storage:
     - Android keeps the JSON file.
     - Web stores the same JSON (data, outbox, cursor, lastSyncedAt) in IndexedDB, or in SharedPreferences for small data. Use one key per user ID.
     - Call `flush()` on `visibilitychange` / `beforeunload` as well.
   - **`file_service.dart`:** on web, upload from `PlatformFile.bytes` (`pickFiles(withData: true)`) with `http.MultipartFile.fromBytes`. Open files with `url_launcher` in a new tab.
   - **`import_service.dart`:** read `bytes` from the picker (already supported); only the `File(path)` fallback is native.
   - **`backup_service.dart` / `backup_screen.dart`:**
     - Web "Export backup" downloads a `.json` file.
     - "Restore" uses the file picker bytes.
     - Hide automatic local backups on web.
     - Google Drive backup is optional on web; hide it for now.
   - **`update_service.dart` / `update_screen.dart`:** not used on web (the site is always the latest). Hide "Check for update" and the update popup when `kIsWeb`.
5. **Notifications on web:**
   - `flutter_local_notifications` doesn't support web. Wrap `NotifyService` so every call is a no-op on web.
   - Optional: reminders while the tab is open, using the browser Notification API (ask permission from Notification settings, check every minute, de-duplicate).
   - Show a small note on the web Notification settings page: "Reminders on the web only show while TaskOra is open. Your phone still reminds you when it's closed."
6. **Focus timer on web:**
   - Same `FocusService` timing logic, stored in SharedPreferences (works on web), so it survives a reload.
   - No notification-panel buttons.
   - Show the remaining time in the browser tab title, e.g. `12:34 · Focus — TaskOra`.
7. **Platform-only plugins:** `open_filex`, `share_plus` file sharing and the APK installer must not run on web. Guard them with `kIsWeb` and use web alternatives (download link, `url_launcher`).
8. **Text input:** the note editor's per-line styles and the tap-outside-to-hide behaviour work on web. On desktop, don't hide anything on tap-outside (there's no keyboard to hide), but keep the selection behaviour.
9. **Images from the server:** they're served from `rabbyhossain.com`. If the web app is on another subdomain, the CORS headers above (also on `files.php`) are needed for `Image.network`. Build with the CanvasKit/skwasm default renderer.

---

## 8. Hosting & automatic deployment

- Target address: **`https://app.rabbyhossain.com`** (the owner creates this subdomain in cPanel). Alternative: `https://rabbyhossain.com/app/`, which needs `--base-href /app/`.
- Build: `flutter build web --release --pwa-strategy=offline-first` (add `--base-href` if it's in a sub-folder).
- Add an `.htaccess` in the web root:
  - SPA fallback to `index.html`;
  - long cache for hashed assets;
  - no cache for `index.html`, `flutter_service_worker.js`, `version.json` and `manifest.json`.
- **Auto-deploy without giving AI FTP passwords** (preferred):
  1. A new GitHub Actions workflow `web.yml` (on push to `main` and on manual run) builds the web app and publishes `taskora-web.zip` as an asset on a GitHub Release tagged `web-latest`, replacing the asset each time.
  2. Add `server/taskora-api/web_update.php`. It reuses the existing self-update approach in `lib.php` (`maybe_self_update`):
     - every 6 hours, or when called with a secret key from `config.php`, it downloads the latest `taskora-web.zip` from GitHub;
     - it checks the zip and extracts it into the web root configured in `config.php` (`web_root` path);
     - it keeps the previous version for rollback.
  - Alternative: FTP deploy from GitHub Actions using repository secrets that the **owner** adds (`FTP_HOST`, `FTP_USER`, `FTP_PASSWORD`). Never hard-code them.
- **PWA:** the app must be installable ("Install TaskOra" in Chrome/Edge) and open in its own window. Use the manifest `display: standalone`, icons 192/512 plus a maskable icon.

---

## 9. What the owner must do by hand (give simple steps)

1. **Firebase console** › Project settings › *Add app* › **Web**, named "TaskOra Web". Copy the `apiKey` and `appId` into `firebase_options.dart`.
2. **Firebase console** › Authentication › Settings › **Authorized domains** › add `app.rabbyhossain.com`.
3. **Google Cloud console** › APIs & Services › Credentials › the *Web client* OAuth client › add `https://app.rabbyhossain.com` to **Authorized JavaScript origins**.
4. **cPanel** › Domains › create the subdomain `app.rabbyhossain.com` with SSL (AutoSSL).
5. Set `web_root` (and the optional deploy key) in the server's `config.php`. Explain exactly which line to add.

---

## 10. Done when (acceptance checklist)

- [ ] `flutter build apk` still works and the Android app behaves exactly as before.
- [ ] `flutter build web` works; `flutter analyze` shows no errors.
- [ ] Google and email sign-in work on the web; the same account shows the same data as the phone.
- [ ] Creating, editing, archiving or trashing on the web appears on the phone within a minute, and the other way round.
- [ ] The UI matches the phone: font, colours, all 37 themes, all background styles, dark mode, cards, animations.
- [ ] Under 700 px it's the phone layout. At 700 px and wider it's the sidebar layout with detail panes, hover states, right-click menus and keyboard shortcuts.
- [ ] Note editor: headings, small text, bold and bullets per line, tabs, checklists, dropdowns, link previews, images and files work.
- [ ] File upload (30 MB max) and document import (.docx/.odt/.txt/.md) work in the browser.
- [ ] Stats with a From–To range, Focus timer (tab title countdown), Calendar, Search, Archive and Trash with select-all all work.
- [ ] The update popup and APK features are hidden on the web.
- [ ] It's installable as a PWA, and reloading keeps the user signed in and the data cached.
- [ ] Deploying to `app.rabbyhossain.com` is automatic after a push to `main`.
- [ ] No secrets are in the repository.

---

## 11. Suggested order of work

1. Conditional imports so web compiles (storage, files, import, backup, update, notifications) → `flutter build web` succeeds.
2. Firebase web options + popup Google sign-in + CORS on the server → sign in and sync work.
3. Responsive shell: the sidebar, then the detail panes, then hover, right-click and shortcuts.
4. Adaptive sheets/dialogs, plus polish on each screen at desktop widths.
5. PWA manifest/icons/loading screen, `.htaccess`, `web.yml` + `web_update.php` auto-deploy.
6. Link preview proxy, then web reminders and the focus tab title.
7. Run the full checklist on Chrome, Edge, Firefox and Safari, and on phone-width windows.
