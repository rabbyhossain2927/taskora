import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class UpdateInfo {
  final String version; // e.g. 1.0.3
  final String apkUrl;
  final String pageUrl;
  final List<String> added;
  final List<String> fixed;
  final String summary;
  final DateTime? published;
  final int sizeBytes;
  UpdateInfo(this.version, this.apkUrl, this.pageUrl, this.added, this.fixed, this.summary, this.published, this.sizeBytes);

  String get sizeLabel => sizeBytes <= 0 ? '' : '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
}

class AppVersion {
  final String version;
  final String build;
  AppVersion(this.version, this.build);
}

/// Reads the latest GitHub Release of your repo. When you fix a bug, you push a
/// new tag (v1.0.3); GitHub Actions builds the APK and publishes the Release;
/// every installed app sees it here and offers the update.
class UpdateService {
  static Future<AppVersion> current() async {
    final i = await PackageInfo.fromPlatform();
    return AppVersion(i.version, i.buildNumber);
  }

  static Future<List<UpdateInfo>> releases({int count = 10}) async {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/${Config.githubOwner}/${Config.githubRepo}/releases?per_page=$count'),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw 'Couldn’t reach the update server (${r.statusCode}).';
    final list = jsonDecode(r.body) as List;
    return list.where((j) => j['draft'] != true && j['prerelease'] != true).map((j) => _parse(j as Map<String, dynamic>)).toList();
  }

  static Future<UpdateInfo?> latest() async {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/${Config.githubOwner}/${Config.githubRepo}/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 404) return null; // no releases yet
    if (r.statusCode != 200) throw 'Couldn’t reach the update server (${r.statusCode}).';
    return _parse(jsonDecode(r.body) as Map<String, dynamic>);
  }

  static UpdateInfo _parse(Map<String, dynamic> j) {
    final tag = (j['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), '');
    final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final apk = assets.where((a) => a['name'].toString().endsWith('.apk')).firstOrNull;
    final body = (j['body'] ?? '').toString();
    final added = <String>[], fixed = <String>[], other = <String>[];
    // Release notes format (see RELEASE_NOTES.md):
    //   New: something new
    //   Fixed: something fixed
    var section = '';
    for (var line in const LineSplitter().convert(body)) {
      line = line.trim().replaceFirst(RegExp(r'^[-*•]\s*'), '');
      if (line.isEmpty) continue;
      final low = line.toLowerCase();
      if (low.startsWith('## new') || low == 'new features' || low == 'new:') { section = 'new'; continue; }
      if (low.startsWith('## fix') || low == 'fixed' || low == 'fixed:') { section = 'fix'; continue; }
      if (low.startsWith('new:')) { added.add(line.substring(4).trim()); continue; }
      if (low.startsWith('fixed:')) { fixed.add(line.substring(6).trim()); continue; }
      if (line.startsWith('#')) continue;
      if (section == 'new') {
        added.add(line);
      } else if (section == 'fix') {
        fixed.add(line);
      } else {
        other.add(line);
      }
    }
    final parts = <String>[];
    if (fixed.isNotEmpty) parts.add('${fixed.length} fix${fixed.length == 1 ? '' : 'es'}');
    if (added.isNotEmpty) parts.add('${added.length} new feature${added.length == 1 ? '' : 's'}');
    final summary = parts.isEmpty ? (other.isEmpty ? '' : other.first) : 'Includes ${parts.join(' and ')}.';
    return UpdateInfo(
      tag,
      apk?['browser_download_url'] ?? j['html_url'] ?? '',
      j['html_url'] ?? '',
      added,
      fixed,
      summary,
      DateTime.tryParse((j['published_at'] ?? '').toString()),
      (apk?['size'] ?? 0) as int,
    );
  }

  /// true when [a] is a higher version than [b] (1.0.10 > 1.0.9).
  static bool isNewer(String a, String b) {
    List<int> p(String s) => s.split(RegExp(r'[.+-]')).map((x) => int.tryParse(x) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0, yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi > yi;
    }
    return false;
  }

  /// Returns the update if one is available, else null.
  static Future<UpdateInfo?> check() async {
    final cur = await current();
    final l = await latest();
    if (l == null || !isNewer(l.version, cur.version)) return null;
    return l;
  }

  static Future<UpdateInfo?>? _cached;

  /// Same as [check] but asks GitHub at most once per app session.
  static Future<UpdateInfo?> cachedCheck() => _cached ??= check().catchError((_) {
        _cached = null;
        return null;
      });

  /// Opens the APK download. Android then asks the user to install it
  /// (the first time it asks to allow installs from the browser).
  /// Opens the release page in the browser (fallback if in-app install fails).
  static Future<bool> openInBrowser(UpdateInfo u) =>
      launchUrl(Uri.parse(u.apkUrl), mode: LaunchMode.externalApplication);

  /// Downloads the new APK inside the app. [onProgress] gets (received, total) bytes.
  /// Returns the downloaded file.
  static Future<File> downloadApk(UpdateInfo u, void Function(int received, int total) onProgress, {bool Function()? cancelled}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/TaskOra-${u.version}.apk');
    if (await file.exists() && u.sizeBytes > 0 && await file.length() == u.sizeBytes) {
      onProgress(u.sizeBytes, u.sizeBytes);
      return file; // already downloaded
    }
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(u.apkUrl))).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw 'Download failed (${res.statusCode}).';
      final total = res.contentLength ?? u.sizeBytes;
      final sink = file.openWrite();
      var got = 0;
      try {
        await for (final chunk in res.stream) {
          if (cancelled?.call() == true) throw 'cancelled';
          sink.add(chunk);
          got += chunk.length;
          onProgress(got, total);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got < total) throw 'Download was interrupted. Please try again.';
      return file;
    } catch (e) {
      try {
        await file.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Opens Android's installer for the downloaded APK.
  /// The first time, Android asks to allow installs from TaskOra.
  static Future<String?> install(File apk) async {
    final r = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    return r.type == ResultType.done ? null : r.message;
  }

  static String mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
