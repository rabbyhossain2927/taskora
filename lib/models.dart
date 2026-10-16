DateTime? _d(dynamic v) {
  if (v == null) return null;
  if (v is Map && v['__ts'] is String) return DateTime.tryParse(v['__ts'] as String); // old backups
  if (v is String) return DateTime.tryParse(v);
  if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

/// Dates are stored as milliseconds since 1970 (plain JSON numbers).
int? _t(DateTime? d) => d?.millisecondsSinceEpoch;

/// A status or category: label + pastel colour index + icon name.
class Tag {
  final String key;
  final String label;
  final int color;
  final String icon;
  const Tag(this.key, this.label, this.color, this.icon);
  Map<String, dynamic> toMap() => {'key': key, 'label': label, 'color': color, 'icon': icon};
  factory Tag.fromMap(Map m) => Tag(m['key'] ?? '', m['label'] ?? '', ((m['color'] ?? 0) as num).toInt(), m['icon'] ?? 'label');
  Tag copyWith({String? label, int? color, String? icon}) => Tag(key, label ?? this.label, color ?? this.color, icon ?? this.icon);
}

const defaultStatuses = <Tag>[
  Tag('todo', 'To do', 19, 'circle'),
  Tag('progress', 'In progress', 12, 'pending'),
  Tag('review', 'In review', 6, 'review'),
  Tag('hold', 'On hold', 4, 'pause'),
  Tag('complete', 'Complete', 8, 'check'),
  Tag('cancelled', 'Cancelled', 2, 'cancel'),
];

const defaultProjectCats = <Tag>[
  Tag('client', 'Client', 0, 'handshake'),
  Tag('personal', 'Personal', 8, 'person'),
  Tag('design', 'Design', 2, 'palette'),
  Tag('dev', 'Development', 12, 'code'),
  Tag('marketing', 'Marketing', 4, 'campaign'),
  Tag('learning', 'Learning', 10, 'school'),
];

const defaultTodoCats = <Tag>[
  Tag('work', 'Work', 0, 'work'),
  Tag('home', 'Home', 8, 'home'),
  Tag('errands', 'Errands', 4, 'cart'),
  Tag('health', 'Health', 2, 'fitness'),
  Tag('study', 'Study', 12, 'school'),
  Tag('someday', 'Someday', 19, 'hourglass'),
];

enum FeePlatform { direct, fiverr, upwork, custom }

double feePercent(FeePlatform p, double custom) => switch (p) {
      FeePlatform.direct => 0,
      FeePlatform.fiverr => 20,
      FeePlatform.upwork => 10,
      FeePlatform.custom => custom,
    };

class Project {
  String id;
  String title;
  String description;
  int color;
  String icon;
  String status;
  int priority; // 1 (urgent) .. 4 (low)
  String category;
  DateTime? start;
  DateTime? deadline;
  DateTime? reminder;
  bool done;
  double? amount;
  String currency;
  FeePlatform platform;
  double customFee;
  DateTime createdAt;

  Project({
    required this.id,
    this.title = '',
    this.description = '',
    this.color = 0,
    this.icon = 'work',
    this.status = 'todo',
    this.priority = 3,
    this.category = 'client',
    this.start,
    this.deadline,
    this.reminder,
    this.done = false,
    this.amount,
    this.currency = 'USD',
    this.platform = FeePlatform.direct,
    this.customFee = 15,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get fee => (amount ?? 0) * feePercent(platform, customFee) / 100;
  double get net => (amount ?? 0) - fee;

  Map<String, dynamic> toMap() => {
        'title': title, 'description': description, 'color': color, 'icon': icon, 'status': status,
        'priority': priority, 'category': category, 'start': _t(start), 'deadline': _t(deadline),
        'reminder': _t(reminder), 'done': done, 'amount': amount, 'currency': currency,
        'platform': platform.name, 'customFee': customFee, 'createdAt': _t(createdAt),
      };

  factory Project.fromMap(String id, Map<String, dynamic> m) => Project(
        id: id,
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        color: ((m['color'] ?? 0) as num).toInt(),
        icon: m['icon'] ?? 'work',
        status: m['status'] ?? 'todo',
        priority: ((m['priority'] ?? 3) as num).toInt(),
        category: m['category'] ?? 'client',
        start: _d(m['start']),
        deadline: _d(m['deadline']),
        reminder: _d(m['reminder']),
        done: m['done'] ?? false,
        amount: (m['amount'] as num?)?.toDouble(),
        currency: m['currency'] ?? 'USD',
        platform: FeePlatform.values.firstWhere((p) => p.name == m['platform'], orElse: () => FeePlatform.direct),
        customFee: ((m['customFee'] ?? 15) as num).toDouble(),
        createdAt: _d(m['createdAt']),
      );
}

class SubTask {
  String title;
  bool done;
  SubTask(this.title, [this.done = false]);
  Map<String, dynamic> toMap() => {'title': title, 'done': done};
  factory SubTask.fromMap(Map m) => SubTask(m['title'] ?? '', m['done'] ?? false);
}

class Todo {
  String id;
  String title;
  String notes;
  String? projectId;
  DateTime? start;
  DateTime? deadline;
  DateTime? reminder;
  int priority;
  String category;
  bool done;
  List<SubTask> subtasks;
  DateTime createdAt;
  DateTime? completedAt;

  Todo({
    required this.id,
    this.title = '',
    this.notes = '',
    this.projectId,
    this.start,
    this.deadline,
    this.reminder,
    this.priority = 4,
    this.category = 'work',
    this.done = false,
    List<SubTask>? subtasks,
    DateTime? createdAt,
    this.completedAt,
  })  : subtasks = subtasks ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'title': title, 'notes': notes, 'projectId': projectId, 'start': _t(start), 'deadline': _t(deadline),
        'reminder': _t(reminder), 'priority': priority, 'category': category, 'done': done,
        'subtasks': subtasks.map((s) => s.toMap()).toList(), 'createdAt': _t(createdAt), 'completedAt': _t(completedAt),
      };

  factory Todo.fromMap(String id, Map<String, dynamic> m) => Todo(
        id: id,
        title: m['title'] ?? '',
        notes: m['notes'] ?? '',
        projectId: m['projectId'],
        start: _d(m['start']),
        deadline: _d(m['deadline']),
        reminder: _d(m['reminder']),
        priority: ((m['priority'] ?? 4) as num).toInt(),
        category: m['category'] ?? 'work',
        done: m['done'] ?? false,
        subtasks: ((m['subtasks'] ?? []) as List).map((e) => SubTask.fromMap(e as Map)).toList(),
        createdAt: _d(m['createdAt']),
        completedAt: _d(m['completedAt']),
      );
}

/// A note is made of blocks: plain text, a checklist, or a collapsible dropdown.
class NoteBlock {
  String type; // text | check | dropdown
  String text; // text body, or dropdown title
  String body; // dropdown content
  List<SubTask> items; // checklist items
  bool open;
  NoteBlock({this.type = 'text', this.text = '', this.body = '', List<SubTask>? items, this.open = true}) : items = items ?? [];
  Map<String, dynamic> toMap() => {'type': type, 'text': text, 'body': body, 'items': items.map((i) => i.toMap()).toList(), 'open': open};
  factory NoteBlock.fromMap(Map m) => NoteBlock(
        type: m['type'] ?? 'text',
        text: m['text'] ?? '',
        body: m['body'] ?? '',
        items: ((m['items'] ?? []) as List).map((e) => SubTask.fromMap(e as Map)).toList(),
        open: m['open'] ?? true,
      );
}

class Note {
  String id;
  String title;
  String? sectionId;
  int color;
  String icon;
  List<String> tags;
  List<NoteBlock> blocks;
  bool pinned;
  DateTime updatedAt;

  Note({required this.id, this.title = '', this.sectionId, this.color = 0, this.icon = 'note', List<String>? tags, List<NoteBlock>? blocks, this.pinned = false, DateTime? updatedAt})
      : tags = tags ?? [],
        blocks = blocks ?? [NoteBlock()],
        updatedAt = updatedAt ?? DateTime.now();

  String get preview => blocks.where((b) => b.type == 'text').map((b) => b.text).join(' ').trim();

  Map<String, dynamic> toMap() => {
        'title': title, 'sectionId': sectionId, 'color': color, 'icon': icon, 'tags': tags,
        'blocks': blocks.map((b) => b.toMap()).toList(), 'pinned': pinned, 'updatedAt': _t(updatedAt),
      };

  factory Note.fromMap(String id, Map<String, dynamic> m) => Note(
        id: id,
        title: m['title'] ?? '',
        sectionId: m['sectionId'],
        color: ((m['color'] ?? 0) as num).toInt(),
        icon: m['icon'] ?? 'note',
        tags: List<String>.from(m['tags'] ?? const []),
        blocks: ((m['blocks'] ?? []) as List).map((e) => NoteBlock.fromMap(e as Map)).toList(),
        pinned: m['pinned'] ?? false,
        updatedAt: _d(m['updatedAt']),
      );
}

class NoteSection {
  String id;
  String title;
  bool onHome;
  int order;
  NoteSection({required this.id, this.title = '', this.onHome = false, this.order = 0});
  Map<String, dynamic> toMap() => {'title': title, 'onHome': onHome, 'order': order};
  factory NoteSection.fromMap(String id, Map<String, dynamic> m) =>
      NoteSection(id: id, title: m['title'] ?? '', onHome: m['onHome'] ?? false, order: ((m['order'] ?? 0) as num).toInt());
}

class AppNotice {
  String id;
  String title;
  String body;
  String kind; // reminder | update | sync | badge
  bool read;
  DateTime createdAt;
  AppNotice({required this.id, this.title = '', this.body = '', this.kind = 'reminder', this.read = false, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
  Map<String, dynamic> toMap() => {'title': title, 'body': body, 'kind': kind, 'read': read, 'createdAt': _t(createdAt)};
  factory AppNotice.fromMap(String id, Map<String, dynamic> m) =>
      AppNotice(id: id, title: m['title'] ?? '', body: m['body'] ?? '', kind: m['kind'] ?? 'reminder', read: m['read'] ?? false, createdAt: _d(m['createdAt']));
}

/// Old (Firestore-era) backups stored dates as {"__ts": "..."}; turn those into numbers.
dynamic fromJsonSafe(dynamic v) {
  if (v is Map && v.length == 1 && v['__ts'] is String) return DateTime.tryParse(v['__ts'] as String)?.millisecondsSinceEpoch;
  if (v is Map) return v.map((k, e) => MapEntry(k.toString(), fromJsonSafe(e)));
  if (v is List) return v.map(fromJsonSafe).toList();
  return v;
}
