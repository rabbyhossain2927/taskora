import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models.dart';
import 'api.dart';

/// Uploads files to your server (max 30 MB each, 2 GB per person).
class FileService {
  static const maxBytes = 30 * 1024 * 1024;

  /// Lets the user pick a file and uploads it. Returns null if they cancel.
  static Future<Attachment?> pickAndUpload({bool imagesOnly = false}) async {
    final r = await FilePicker.platform.pickFiles(type: imagesOnly ? FileType.image : FileType.any);
    if (r == null || r.files.isEmpty || r.files.single.path == null) return null;
    final f = r.files.single;
    if (f.size > maxBytes) throw 'Files can be up to 30 MB. This one is ${(f.size / 1048576).toStringAsFixed(1)} MB.';
    return upload(File(f.path!), f.name);
  }

  static Future<Attachment> upload(File file, String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Not signed in';
    final token = await user.getIdToken() ?? '';
    final req = http.MultipartRequest('POST', Uri.parse('${Config.apiBase}/files.php'))
      ..headers['X-Auth-Token'] = token
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: name));
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 5)));
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw res.statusCode == 404 ? 'File uploads aren’t on the server yet. Please try again later.' : 'Upload failed (${res.statusCode}).';
    }
    if (res.statusCode != 200) throw (j['error'] ?? 'Upload failed (${res.statusCode})').toString();
    return Attachment(
      id: j['id'].toString(),
      name: (j['name'] ?? name).toString(),
      mime: (j['mime'] ?? '').toString(),
      size: ((j['size'] ?? 0) as num).toInt(),
      url: (j['url'] ?? '${Config.apiBase}/files.php?id=${j['id']}').toString(),
    );
  }

  static Future<void> delete(Attachment a) async {
    try {
      await Api.post('files.php', {'action': 'delete', 'id': a.id});
    } catch (_) {}
  }

  /// (used bytes, limit bytes)
  static Future<(int, int)> usage() async {
    final j = await Api.post('files.php', {'action': 'usage'});
    return (((j['used'] ?? 0) as num).toInt(), ((j['limit'] ?? 0) as num).toInt());
  }

  static Future<void> open(Attachment a) => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication);

  static String sizeLabel(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }
}
