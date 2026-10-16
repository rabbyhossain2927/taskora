import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import 'api.dart';
import 'notify_service.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// All of the user's data.
///
/// * Saved on the phone first (a JSON file), so the app works offline.
/// * Every change also goes into an "outbox" and is sent to YOUR server
///   (taskora-api on your hosting) a moment later.
/// * Each sync also pulls what changed on other phones.
class Store extends ChangeNotifier {
  final String uid;

  List<Project> projects = [];
  List<Todo> todos = [];
  List<Note> notes = [];
  List<NoteSection> sections = [];
  List<AppNotice> notices = [];
  List<String> tags = const ['client', 'idea', 'urgent', 'personal'];
  List<Tag> statuses = List.of(defaultStatuses);
  List<Tag> projectCats = List.of(defaultProjectCats);
  List<Tag> todoCats = List.of(defaultTodoCats);
  bool loaded = false;

  // Sync state (shown on Backup & sync and the profile badge)
  bool syncing = false;
  String? syncError;
  DateTime? lastSyncedAt;
  bool get hasPendingWrites => _outbox.isNotEmpty;
  int get pendingCount => _outbox.length;

  static const collections = ['projects', 'todos', 'notes', 'sections', 'notices'];
  static const _metaCol = 'meta', _userDoc = 'user';

  // Local database: collection -> id -> data
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};
  // Changes not yet on the server: "col/id" -> {col, id, data, deleted}
  final Map<String, Map<String, dynamic>> _outbox = {};
  String _cursor = '0';

  File? _file;
  Timer? _saveTimer, _syncTimer, _periodic;
  Future<void>? _running;

  Store(this.uid) {
    _init();
  }

  Future<void> _init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/taskora_${uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        (j['data'] as Map? ?? {}).forEach((col, docs) {
          _data[col as String] = {for (final e in (docs as Map).entries) e.key as String: Map<String, dynamic>.from(e.value as Map)};
        });
        (j['outbox'] as Map? ?? {}).forEach((k, v) => _outbox[k as String] = Map<String, dynamic>.from(v as Map));
        _cursor = (j['cursor'] ?? '0').toString();
        final ls = j['lastSyncedAt'];
        if (ls is int) lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(ls);
      }
    } catch (e) {
      debugPrint('Local data could not be read: $e');
    }
    loaded = true;
    _rebuild();
    // First sync now, then every 60 seconds while the app is open.
    unawaited(syncQuietly());
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) => syncQuietly());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _syncTimer?.cancel();
    _periodic?.cancel();
    _writeFile();
    super.dispose();
  }

  // ---------------- local storage ----------------
  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _writeFile);
  }

  Future<void> _writeFile() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'data': _data,
        'outbox': _outbox,
        'cursor': _cursor,
        'lastSyncedAt': lastSyncedAt?.millisecondsSinceEpoch,
      }));
      await tmp.rename(f.path); // atomic: never leaves a half-written file
    } catch (e) {
      debugPrint('Local save failed: $e');
    }
  }

  void _rebuild() {
    List<T> all<T>(String col, T Function(String, Map<String, dynamic>) f) =>
        (_data[col] ?? {}).entries.map((e) => f(e.key, e.value)).toList();
    projects = all('projects', Project.fromMap)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    todos = all('todos', Todo.fromMap)..sort(_todoSort);
    notes = all('notes', Note.fromMap)
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    sections = all('sections', NoteSection.fromMap)..sort((a, b) => a.order.compareTo(b.order));
    notices = all('notices', AppNotice.fromMap)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final m = _data[_metaCol]?[_userDoc] ?? const {};
    tags = List<String>.from(m['tags'] ?? const ['client', 'idea', 'urgent', 'personal']);
    List<Tag> read(String k, List<Tag> def) => m[k] == null ? List.of(def) : (m[k] as List).map((e) => Tag.fromMap(e as Map)).toList();
    statuses = read('statuses', defaultStatuses);
    projectCats = read('projectCats', defaultProjectCats);
    todoCats = read('todoCats', defaultTodoCats);
    notifyListeners();
  }

  static int _todoSort(Todo a, Todo b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final ad = a.deadline, bd = b.deadline;
    if (ad != null && bd != null) return ad.compareTo(bd);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return a.priority.compareTo(b.priority);
  }

  /// Every local change goes through here. `data == null` deletes.
  void _put(String col, String id, Map<String, dynamic>? data, {bool rebuild = true}) {
    if (data == null) {
      _data[col]?.remove(id);
    } else {
      (_data[col] ??= {})[id] = jsonDecode(jsonEncode(data)) as Map<String, dynamic>; // deep copy, JSON-safe
    }
    _outbox['$col/$id'] = {'col': col, 'id': id, 'data': data == null ? null : _data[col]![id], 'deleted': data == null};
    if (rebuild) _rebuild();
    _persist();
    _scheduleSync();
  }

  Map<String, dynamic>? _get(String col, String id) => _data[col]?[id];

  // ---------------- lookups ----------------
  Project? project(String? id) => id == null ? null : projects.where((p) => p.id == id).firstOrNull;
  Tag status(String key) => statuses.firstWhere((t) => t.key == key, orElse: () => statuses.first);
  Tag projectCat(String key) => projectCats.firstWhere((t) => t.key == key, orElse: () => projectCats.first);
  Tag todoCat(String key) => todoCats.firstWhere((t) => t.key == key, orElse: () => todoCats.first);
  List<Todo> todosOf(String projectId) => todos.where((t) => t.projectId == projectId).toList();
  double progressOf(String projectId) {
    final t = todosOf(projectId);
    if (t.isEmpty) return project(projectId)?.done == true ? 1 : 0;
    return t.where((x) => x.done).length / t.length;
  }

  int get unreadCount => notices.where((n) => !n.read).length;

  // ---------------- writes ----------------
  Future<void> saveProject(Project p) async {
    _put('projects', p.id, p.toMap());
    await NotifyService.scheduleFor(p.id, p.title, 'Project reminder', p.reminder);
  }

  Future<void> saveTodo(Todo t) async {
    if (t.done && t.completedAt == null) t.completedAt = DateTime.now();
    if (!t.done) t.completedAt = null;
    _put('todos', t.id, t.toMap());
    await NotifyService.scheduleFor(t.id, t.title, 'To-do reminder', t.done ? null : t.reminder);
  }

  Future<void> toggleTodo(Todo t) {
    t.done = !t.done;
    return saveTodo(t);
  }

  Future<void> saveNote(Note n) async {
    n.updatedAt = DateTime.now();
    _put('notes', n.id, n.toMap());
  }

  Future<void> saveSection(NoteSection s) async => _put('sections', s.id, s.toMap());
  Future<void> saveNotice(AppNotice n) async => _put('notices', n.id, n.toMap());

  /// Adds to Notifications in the app and shows it in the phone's notification panel.
  Future<void> addNotice(String title, String body, String kind) async {
    await saveNotice(AppNotice(id: newId(), title: title, body: body, kind: kind));
    if (kind != 'update') await NotifyService.showNotice(title, body); // updates have their own alert
  }

  Future<void> markRead(Iterable<String> ids, [bool read = true]) async {
    for (final id in ids.toList()) {
      final m = _get('notices', id);
      if (m == null) continue;
      _put('notices', id, {...m, 'read': read}, rebuild: false);
    }
    _rebuild();
  }

  Future<void> _saveMeta(Map<String, dynamic> fields) async {
    final m = Map<String, dynamic>.from(_get(_metaCol, _userDoc) ?? {});
    m.addAll(fields);
    _put(_metaCol, _userDoc, m);
  }

  Future<void> saveTags(List<String> t) => _saveMeta({'tags': t});
  Future<void> saveTaxonomy(String field, List<Tag> list) => _saveMeta({field: list.map((e) => e.toMap()).toList()});

  /// Deletes items and returns a function that puts them back (for Undo).
  Future<Future<void> Function()> deleteDocs(String collection, Iterable<String> ids) async {
    final saved = <String, Map<String, dynamic>>{};
    final extra = <String, Map<String, dynamic>>{};
    for (final id in ids.toList()) {
      final m = _get(collection, id);
      if (m != null) saved[id] = Map<String, dynamic>.from(m);
      _put(collection, id, null, rebuild: false);
      if (collection == 'todos' || collection == 'projects') await NotifyService.cancelFor(id);
    }
    // Deleting a project also removes its to-dos.
    if (collection == 'projects') {
      for (final t in todos.where((t) => saved.containsKey(t.projectId)).toList()) {
        extra[t.id] = t.toMap();
        _put('todos', t.id, null, rebuild: false);
        await NotifyService.cancelFor(t.id);
      }
    }
    _rebuild();
    return () async {
      saved.forEach((id, m) => _put(collection, id, m, rebuild: false));
      extra.forEach((id, m) => _put('todos', id, m, rebuild: false));
      _rebuild();
    };
  }

  // ---------------- sync with your server ----------------
  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), syncQuietly);
  }

  /// Background sync: never shows errors as pop-ups (they appear on Backup & sync).
  Future<void> syncQuietly() async {
    try {
      await sync();
    } catch (_) {}
  }

  /// Pull-to-sync. Throws when the server can't be reached.
  Future<void> sync() => _running ??= _doSync().whenComplete(() => _running = null);

  Future<void> _doSync() async {
    syncing = true;
    notifyListeners();
    var gotChanges = false;
    try {
      var more = true;
      var rounds = 0;
      while (more && rounds++ < 50) {
        final sending = Map<String, Map<String, dynamic>>.of(_outbox);
        final batch = sending.entries.take(400).toList();
        final res = await Api.post('sync.php', {
          'since': _cursor,
          'changes': [for (final e in batch) e.value],
        });
        // Remove what the server saved — unless it was changed again meanwhile.
        for (final e in batch) {
          if (identical(_outbox[e.key], e.value)) _outbox.remove(e.key);
        }
        for (final c in (res['changes'] as List? ?? const [])) {
          final m = c as Map<String, dynamic>;
          final col = m['col'] as String, id = m['id'] as String;
          if (_outbox.containsKey('$col/$id')) continue; // our newer local edit wins; it is sent next
          if (m['deleted'] == true || m['data'] == null) {
            _data[col]?.remove(id);
          } else {
            (_data[col] ??= {})[id] = Map<String, dynamic>.from(m['data'] as Map);
          }
          gotChanges = true;
        }
        _cursor = (res['cursor'] ?? _cursor).toString();
        more = res['more'] == true || (_outbox.isNotEmpty && batch.length == 400);
      }
      lastSyncedAt = DateTime.now();
      syncError = null;
    } catch (e) {
      syncError = e is SocketException || e is TimeoutException ? 'You’re offline. Changes are saved on this phone.' : e.toString();
      rethrow;
    } finally {
      syncing = false;
      _persist();
      if (gotChanges) {
        _rebuild();
      } else {
        notifyListeners();
      }
    }
  }

  // ---------------- backup ----------------
  Future<Map<String, dynamic>> exportAll() async => {
        'app': 'TaskOra',
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'user': _get(_metaCol, _userDoc) ?? {},
        for (final c in collections) c: _data[c] ?? {},
      };

  /// Restores a backup. Items in the backup replace items with the same id;
  /// everything else is kept. Restored items are synced to the server.
  Future<int> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'TaskOra') throw 'This file is not a TaskOra backup.';
    var count = 0;
    if (data['user'] is Map && (data['user'] as Map).isNotEmpty) {
      await _saveMeta(Map<String, dynamic>.from(fromJsonSafe(data['user']) as Map));
    }
    for (final c in collections) {
      final m = (data[c] as Map?) ?? {};
      for (final e in m.entries) {
        _put(c, e.key.toString(), Map<String, dynamic>.from(fromJsonSafe(e.value) as Map), rebuild: false);
        count++;
      }
    }
    _rebuild();
    return count;
  }

  /// Removes everything from your server and this phone (Edit profile > Delete account).
  Future<void> deleteEverything() async {
    await Api.post('account.php', {'action': 'delete'});
    _periodic?.cancel();
    _data.clear();
    _outbox.clear();
    _cursor = '0';
    try {
      await _file?.delete();
    } catch (_) {}
    _file = null;
    _rebuild();
  }
}
