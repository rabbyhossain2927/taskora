import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => message;
}

/// Talks to your own server (the taskora-api folder on your hosting).
/// Every request carries the Firebase sign-in token; the server checks it
/// and only ever touches that person's data.
class Api {
  static Future<Map<String, dynamic>> post(String file, Map<String, dynamic> body, {bool retried = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiError(401, 'Not signed in');
    final token = await user.getIdToken(retried);
    final r = await http
        .post(
          Uri.parse('${Config.apiBase}/$file'),
          headers: {
            'Content-Type': 'application/json',
            'X-Auth-Token': token ?? '',
            'Authorization': 'Bearer ${token ?? ''}',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError(r.statusCode, r.statusCode == 404 ? 'This feature isn’t on the server yet. Please try again later.' : 'The server sent an unexpected reply (${r.statusCode}).');
    }
    // Token just expired: get a fresh one and try once more.
    if (r.statusCode == 401 && !retried) return post(file, body, retried: true);
    if (r.statusCode != 200) throw ApiError(r.statusCode, (j['error'] ?? 'Server error ${r.statusCode}').toString());
    return j;
  }
}
