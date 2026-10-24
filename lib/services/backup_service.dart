import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'auth_service.dart';
import 'prefs.dart';
import 'store.dart';

class BackupEntry {
  final String id; // Drive file id or local path
  final String name;
  final DateTime time;
  final int size;
  final bool onDrive;
  BackupEntry(this.id, this.name, this.time, this.size, this.onDrive);
}

/// Automatic backups to Google Drive (hidden app folder) and to phone storage.
class BackupService {
  static final _fmt = DateFormat('yyyyMMdd-HHmm');

  static Duration _every(String f) => switch (f) {
        'Weekly' => const Duration(days: 7),
        'Monthly' => const Duration(days: 30),
        _ => const Duration(days: 1),
      };

  /// Called when the app opens. Runs whichever backups are due, silently.
  static Future<void> runAutoBackups(Store store) async {
    if (kIsWeb) return;
    final p = Prefs.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      if (p.localAuto && now - p.lastLocal > _every(p.localFreq).inMilliseconds) await backupLocal(store);
    } catch (_) {}
    try {
      if (p.driveAuto && now - p.lastDrive > _every(p.driveFreq).inMilliseconds) await backupDrive(store, interactive: false);
    } catch (_) {}
  }

  static Future<String> _json(Store store) async => const JsonEncoder.withIndent(' ').convert(await store.exportAll());

  // ---------------- phone storage ----------------
  static Future<Directory> _localDir() async {
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/backups');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> backupLocal(Store store) async {
    final d = await _localDir();
    final f = File('${d.path}/taskora-${_fmt.format(DateTime.now())}.json');
    await f.writeAsString(await _json(store));
    Prefs.instance.lastLocal = DateTime.now().millisecondsSinceEpoch;
    // keep only the newest N
    final all = await listLocal();
    for (final old in all.skip(Prefs.instance.keepBackups)) {
      try {
        await File(old.id).delete();
      } catch (_) {}
    }
    return f;
  }

  static Future<List<BackupEntry>> listLocal() async {
    final d = await _localDir();
    final files = d.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    final out = files.map((f) => BackupEntry(f.path, f.uri.pathSegments.last, f.lastModifiedSync(), f.lengthSync(), false)).toList();
    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  static Future<void> deleteLocal(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  static Future<void> shareLocal(String path) => Share.shareXFiles([XFile(path, mimeType: 'application/json')], subject: 'TaskOra backup');

  /// Turns Google's long error text into something short and useful.
  static String friendlyDriveError(Object e) {
    final t = e.toString();
    if (t.contains('popup-closed') || t.contains('cancelled-popup') || t.contains('popup-blocked')) return 'The Google window was closed or blocked. Allow pop-ups for this site and try again.';
    if (t.contains('credential-already-in-use') || t.contains('user-mismatch')) return 'Please choose the same Google account you use for TaskOra.';
    if (t.contains('has not been used') || t.contains('is disabled') || t.contains('accessNotConfigured')) {
      return 'Google Drive is switched off for this app. The owner needs to enable the Google Drive API in Google Cloud.';
    }
    if (t.contains('insufficient') || t.contains('403')) return 'Google Drive permission was not given. Try again and allow access.';
    if (t.contains('SocketException') || t.contains('Failed host lookup')) return 'You’re offline.';
    return 'Drive backup failed. Please try again later.';
  }

  static Future<int> restoreLocal(Store store, String path) async =>
      store.importAll(jsonDecode(await File(path).readAsString()) as Map<String, dynamic>);

  /// Saves a backup and opens the share sheet (save to Files, send to yourself, ...).
  static Future<void> exportAndShare(Store store) async {
    final f = await backupLocal(store);
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')], subject: 'TaskOra backup');
  }

  static Future<int> importFromText(Store store, String text) async =>
      store.importAll(jsonDecode(text) as Map<String, dynamic>);

  // ---------------- Google Drive ----------------
  // On the website Google sign-in goes through a popup, which gives a Drive
  // access token for about an hour.
  static String? _webToken;
  static DateTime? _webExpiry;

  static Future<drive.DriveApi?> _webDrive({required bool interactive}) async {
    const scope = drive.DriveApi.driveAppdataScope;
    if (_webToken == null || DateTime.now().isAfter(_webExpiry!)) {
      if (!interactive) return null;
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return null;
      final provider = GoogleAuthProvider()..addScope(scope);
      final hasGoogle = u.providerData.any((p) => p.providerId == 'google.com');
      final cred = hasGoogle ? await u.reauthenticateWithPopup(provider) : await u.linkWithPopup(provider);
      final t = cred.credential?.accessToken;
      if (t == null) return null;
      _webToken = t;
      _webExpiry = DateTime.now().add(const Duration(minutes: 55));
    }
    final client = gauth.authenticatedClient(
      http.Client(),
      gauth.AccessCredentials(gauth.AccessToken('Bearer', _webToken!, _webExpiry!.toUtc()), null, const [scope]),
    );
    return drive.DriveApi(client);
  }

  /// True on the website once Drive was connected in this visit.
  static bool get webDriveReady => _webToken != null && _webExpiry != null && DateTime.now().isBefore(_webExpiry!);

  static Future<drive.DriveApi?> _drive({required bool interactive}) async {
    if (kIsWeb) return _webDrive(interactive: interactive);
    final g = AuthService.google;
    var acc = g.currentUser ?? await g.signInSilently();
    if (acc == null && interactive) acc = await g.signIn();
    if (acc == null) return null;
    const scope = drive.DriveApi.driveAppdataScope;
    final ok = await g.requestScopes([scope]);
    if (!ok) return null;
    final client = await g.authenticatedClient();
    return client == null ? null : drive.DriveApi(client);
  }

  static Future<bool> backupDrive(Store store, {bool interactive = true}) async {
    final api = await _drive(interactive: interactive);
    if (api == null) return false;
    final bytes = utf8.encode(await _json(store));
    final meta = drive.File()
      ..name = 'taskora-${_fmt.format(DateTime.now())}.json'
      ..parents = ['appDataFolder'];
    await api.files.create(meta, uploadMedia: drive.Media(Stream.value(bytes), bytes.length));
    Prefs.instance.lastDrive = DateTime.now().millisecondsSinceEpoch;
    final all = await listDrive(interactive: false);
    for (final old in all.skip(Prefs.instance.keepBackups)) {
      try {
        await api.files.delete(old.id);
      } catch (_) {}
    }
    return true;
  }

  static Future<List<BackupEntry>> listDrive({bool interactive = false}) async {
    final api = await _drive(interactive: interactive);
    if (api == null) return [];
    final r = await api.files.list(spaces: 'appDataFolder', orderBy: 'createdTime desc', $fields: 'files(id,name,createdTime,size)', pageSize: 50);
    return (r.files ?? [])
        .map((f) => BackupEntry(f.id!, f.name ?? '', f.createdTime ?? DateTime.now(), int.tryParse(f.size ?? '') ?? 0, true))
        .toList();
  }

  static Future<int> restoreDrive(Store store, String fileId) async {
    final api = await _drive(interactive: true);
    if (api == null) throw 'Google Drive is not connected.';
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final chunks = <int>[];
    await for (final c in media.stream) {
      chunks.addAll(c);
    }
    return store.importAll(jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>);
  }
}
