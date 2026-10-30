import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/import_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'note_editor.dart';

Future<void> deleteNotes(BuildContext context, List<String> ids) async {
  final s = context.read<Store>();
  final m = ScaffoldMessenger.of(context);
  final undo = await s.deleteDocs('notes', ids);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(ids.length == 1 ? 'Note moved to Trash' : '${ids.length} notes moved to Trash'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
}

Future<void> archiveNotes(BuildContext context, List<String> ids) async {
  final s = context.read<Store>();
  await s.archive('notes', ids);
  if (context.mounted) showUndo(context, ids.length == 1 ? 'Note archived' : '${ids.length} notes archived', () => s.archive('notes', ids, false));
}

/// Pick Word / Google Docs / text files and turn each into a note.
Future<void> importNotes(BuildContext context, {String? folderId}) async {
  final s = context.read<Store>();
  final m = ScaffoldMessenger.of(context);
  try {
    final n = await ImportService.pickAndImport(s, folderId: folderId);
    if (n > 0) m.showSnackBar(SnackBar(content: Text(n == 1 ? '1 document added as a note' : '$n documents added as notes')));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Ask which folder; returns '' for "No folder", null if cancelled.
Future<String?> askFolder(BuildContext context, [String? current]) async {
  final s = context.read<Store>();
  final v = await pickOne<String>(context,
      title: 'Move to folder',
      current: current ?? '',
      options: [('', 'No folder'), for (final f in s.sections) (f.id, f.title), ('__new', '+ New folder…')]);
  if (v != '__new' || !context.mounted) return v;
  final name = await askText(context, title: 'New folder', hint: 'e.g. Client briefs');
  if (name == null || name.isEmpty) return null;
  final f = NoteSection(id: newId(), title: name, order: s.sections.length);
  await s.saveSection(f);
  return f.id;
}

void showNoteActions(BuildContext context, Note n, {VoidCallback? onSelect}) {
  final s = context.read<Store>();
  HapticFeedback.mediumImpact();
  showActions(context, title: n.title.isEmpty ? 'Untitled note' : n.title, items: [
    ActionItem(Icons.open_in_new_rounded, 'Open', () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(id: n.id)))),
    ActionItem(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, n.pinned ? 'Unpin' : 'Pin to top', () {
      n.pinned = !n.pinned;
      s.saveNote(n);
    }),
    ActionItem(Icons.drive_file_move_outline, 'Move to folder', () async {
      final f = await askFolder(context, n.sectionId);
      if (f == null) return;
      n.sectionId = f.isEmpty ? null : f;
      s.saveNote(n);
    }),
    ActionItem(Icons.copy_rounded, 'Duplicate', () {
      final copy = Note.fromMap(newId(), n.toMap())..title = '${n.title} (copy)';
      s.saveNote(copy);
    }),
    if (onSelect != null) ActionItem(Icons.checklist_rounded, 'Select several', onSelect),
    ActionItem(Icons.archive_outlined, 'Archive', () => archiveNotes(context, [n.id])),
    ActionItem(Icons.delete_outline_rounded, 'Move to Trash', () => deleteNotes(context, [n.id]), danger: true),
  ]);
}

/// Two-column masonry of note cards with select support.
class NotesGrid extends StatelessWidget {
  final List<Note> notes;
  final bool selecting;
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onStartSelect;
  const NotesGrid({super.key, required this.notes, required this.selecting, required this.picked, required this.onToggle, required this.onStartSelect});
  @override
  Widget build(BuildContext context) {
    final grid = context.watch<Prefs>().notesGrid;
    Widget card(Note n, int i) => FadeIn(
          index: i,
          child: NoteCard(
            note: n,
            selecting: selecting,
            selected: picked.contains(n.id),
            onToggle: () => onToggle(n.id),
            onStartSelect: () => onStartSelect(n.id),
          ),
        );
    if (!grid) return Column(children: [for (var i = 0; i < notes.length; i++) card(notes[i], i)]);
    return LayoutBuilder(builder: (context, c) {
      // 2 columns on phones, more on wide screens
      final n = (c.maxWidth / 250).floor().clamp(2, 6);
      final w = (c.maxWidth - 10 * (n - 1)) / n;
      final cols = List.generate(n, (_) => <Widget>[]);
      for (var i = 0; i < notes.length; i++) {
        cols[i % n].add(card(notes[i], i));
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var k = 0; k < n; k++) ...[
          if (k > 0) const SizedBox(width: 10),
          SizedBox(width: w, child: Column(children: cols[k])),
        ],
      ]);
    });
  }
}

/// Bottom bar shown while selecting notes.
class NotesSelectBar extends StatelessWidget {
  final Set<String> picked;
  final VoidCallback onDone;
  const NotesSelectBar({super.key, required this.picked, required this.onDone});
  @override
  Widget build(BuildContext context) {
    final s = context.read<Store>();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))]),
        child: Row(children: [
          const SizedBox(width: 8),
          Text('${picked.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            tooltip: 'Pin',
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: picked.isEmpty
                ? null
                : () {
                    for (final n in s.notes.where((n) => picked.contains(n.id))) {
                      n.pinned = true;
                      s.saveNote(n);
                    }
                    onDone();
                  },
          ),
          IconButton(
            tooltip: 'Move to folder',
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: picked.isEmpty
                ? null
                : () async {
                    final f = await askFolder(context);
                    if (f == null) return;
                    for (final n in s.notes.where((n) => picked.contains(n.id))) {
                      n.sectionId = f.isEmpty ? null : f;
                      s.saveNote(n);
                    }
                    onDone();
                  },
          ),
          IconButton(
            tooltip: 'Archive',
            icon: const Icon(Icons.archive_outlined),
            onPressed: picked.isEmpty
                ? null
                : () {
                    archiveNotes(context, picked.toList());
                    onDone();
                  },
          ),
          IconButton(
            tooltip: 'Move to Trash',
            icon: const Icon(Icons.delete_outline_rounded, color: C.red),
            onPressed: picked.isEmpty
                ? null
                : () {
                    deleteNotes(context, picked.toList());
                    onDone();
                  },
          ),
        ]),
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? tag;
  String q = '';
  bool selecting = false;
  final picked = <String>{};

  void _toggle(String id) => setState(() {
        if (!picked.remove(id)) picked.add(id);
        if (picked.isEmpty) selecting = false;
      });
  void _start(String id) => setState(() {
        selecting = true;
        picked.add(id);
      });
  void _stop() => setState(() {
        selecting = false;
        picked.clear();
      });

  // Computers: folders | notes list | open note (web design).
  String folder = 'all'; // all | pinned | none | folder id
  String? openId;

  Widget _desktop(BuildContext context, Store s) {
    final muted = context.mutedText;
    bool inFolder(Note n) => switch (folder) {
          'all' => true,
          'pinned' => n.pinned,
          'none' => n.sectionId == null || s.sections.every((x) => x.id != n.sectionId),
          _ => n.sectionId == folder,
        };
    final list = s.notes.where((n) => inFolder(n) && (tag == null || n.tags.contains(tag)) && (q.isEmpty || n.title.toLowerCase().contains(q) || n.allText.toLowerCase().contains(q))).toList()
      ..sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.updatedAt.compareTo(a.updatedAt));
    final isFolder = !const {'all', 'pinned', 'none'}.contains(folder);
    final open = list.where((n) => n.id == openId).firstOrNull ?? list.firstOrNull;
    final title = switch (folder) { 'all' => 'All notes', 'pinned' => 'Pinned', 'none' => 'No folder', _ => s.sections.where((x) => x.id == folder).firstOrNull?.title ?? 'Notes' };

    Widget fold(String key, IconData icon, String label, int count, Color c) {
      final on = folder == key;
      return InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() {
          folder = key;
          openId = null;
        }),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: on ? (context.isDark ? Colors.white10 : context.selTint) : null, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Icon(icon, size: 18, color: on ? context.accent : c),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? context.selInk : null))),
            Text('$count', style: TextStyle(fontSize: 12, color: on ? context.selInk : muted)),
          ]),
        ),
      );
    }

    Widget tb(IconData ic, String tip, VoidCallback onTap, {bool main = false}) => Tooltip(
          message: tip,
          child: Material(
            color: main ? context.accent : (context.isDark ? Colors.white10 : context.softFill),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: SizedBox(width: 34, height: 34, child: Icon(ic, size: 18, color: main ? Colors.white : const Color(0xFF4B4B5A)))),
          ),
        );

    final folders = Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: softCard(18, context.surface),
      child: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
          child: Row(children: [
            Expanded(child: Text('Folders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted))),
            tb(Icons.add_rounded, 'New folder', () async {
              final name = await askText(context, title: 'New folder', hint: 'e.g. Client briefs');
              if (name != null && name.isNotEmpty) s.saveSection(NoteSection(id: newId(), title: name, order: s.sections.length));
            }),
          ]),
        ),
        fold('all', Icons.notes_rounded, 'All notes', s.notes.length, muted),
        fold('pinned', Icons.push_pin_outlined, 'Pinned', s.notes.where((n) => n.pinned).length, muted),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Divider()),
        for (var i = 0; i < s.sections.length; i++)
          GestureDetector(
            onSecondaryTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(id: s.sections[i].id))),
            child: fold(s.sections[i].id, Icons.folder_rounded, s.sections[i].title, s.notes.where((n) => n.sectionId == s.sections[i].id).length, pastel((i * 3 + 2) % pastels.length).fg),
          ),
        fold('none', Icons.folder_outlined, 'No folder', s.notes.where((n) => n.sectionId == null || s.sections.every((x) => x.id != n.sectionId)).length, muted),
        if (s.tags.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Divider()),
          Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: Text('Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < s.tags.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => setState(() => tag = tag == s.tags[i] ? null : s.tags[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: pastel((i * 5) % pastels.length).bg,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: tag == s.tags[i] ? pastel((i * 5) % pastels.length).fg : Colors.transparent, width: 1.5),
                    ),
                    child: Text('#${s.tags[i]}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: pastel((i * 5) % pastels.length).fg)),
                  ),
                ),
            ]),
          ),
        ],
      ]),
    );

    final notesList = Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: softCard(18, context.surface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 4, 8),
          child: Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
            if (isFolder)
              Padding(padding: const EdgeInsets.only(right: 6), child: tb(Icons.more_horiz_rounded, 'Folder options', () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(id: folder))))),
            tb(Icons.download_rounded, 'Import a document', () => importNotes(context, folderId: isFolder ? folder : null)),
            const SizedBox(width: 6),
            tb(Icons.add_rounded, 'New note', () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(sectionId: isFolder ? folder : null), fullscreenDialog: true)), main: true),
          ]),
        ),
        Container(
          height: 38,
          margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: context.isDark ? Colors.white10 : context.softFill, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 17, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(hintText: 'Search notes', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.zero),
              ),
            ),
          ]),
        ),
        const Divider(),
        Expanded(
          child: list.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text(s.notes.isEmpty ? 'No notes yet. Tap + to write one.' : 'No notes here.', style: TextStyle(color: muted)))
              : ListView(padding: const EdgeInsets.only(top: 6), children: [
                  for (final n in list)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => openId = n.id),
                      onSecondaryTap: () => showNoteActions(context, n),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(color: n.id == open?.id ? (context.isDark ? Colors.white10 : context.selTint) : null, borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: n.color == 0 ? const Color(0xFFCDBEFF) : Color.lerp(noteColor(n.color), Colors.black, 0.1), borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: n.id == open?.id ? FontWeight.w700 : FontWeight.w600))),
                            if (n.pinned) Icon(Icons.push_pin, size: 14, color: context.accent),
                          ]),
                          if (n.preview.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(n.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.45, color: muted))),
                          Padding(padding: const EdgeInsets.only(top: 4), child: Text(fmtDue(n.updatedAt), style: TextStyle(fontSize: 11.5, color: muted))),
                        ]),
                      ),
                    ),
                ]),
        ),
      ]),
    );

    final editor = Expanded(
      child: Container(
        decoration: softCard(18, context.surface),
        clipBehavior: Clip.antiAlias,
        child: open == null
            ? Center(child: Text('Pick a note to read or edit it here.', style: TextStyle(color: muted)))
            : NoteEditor(key: ValueKey(open.id), id: open.id, onClose: () => setState(() => openId = null)),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [folders, const SizedBox(width: 16), notesList, const SizedBox(width: 16), editor]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    if (isDesktop(context) && MediaQuery.sizeOf(context).width >= 1000) return _desktop(context, s);
    bool match(Note n) => (tag == null || n.tags.contains(tag)) && (q.isEmpty || n.title.toLowerCase().contains(q) || n.allText.toLowerCase().contains(q));
    final filtering = tag != null || q.isNotEmpty;
    final loose = s.notes.where((n) => match(n) && (filtering || n.sectionId == null || s.sections.every((x) => x.id != n.sectionId))).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SyncRefresh(
          child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 130), children: [
            MainHeader('Notes', subtitle: '${s.notes.length} notes · ${s.sections.length} folders', actions: [
              if (selecting)
                TextButton(onPressed: _stop, child: const Text('Cancel'))
              else ...[
                RoundButton(icon: Icons.upload_file_rounded, tooltip: 'Import Word, Google Docs or text files', onTap: () => importNotes(context)),
                RoundButton(icon: prefs.notesGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, tooltip: prefs.notesGrid ? 'List view' : 'Grid view', onTap: () => prefs.notesGrid = !prefs.notesGrid),
              ],
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(decoration: const InputDecoration(hintText: 'Search notes', prefixIcon: Icon(Icons.search_rounded)), onChanged: (v) => setState(() => q = v.trim().toLowerCase())),
                SizedBox(
                  height: 50,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 8), children: [
                    Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(const Tag('all', 'All', 19, 'all_inclusive'), selected: tag == null, onTap: () => setState(() => tag = null))),
                    for (final t in s.tags)
                      Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(Tag(t, '#$t', 0, 'tag'), selected: tag == t, onTap: () => setState(() => tag = tag == t ? null : t))),
                    TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabelsScreen())), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit tags')),
                  ]),
                ),
                if (!filtering) ...[
                  Label('Folders', trailing: GestureDetector(
                    onTap: () async {
                      final name = await askText(context, title: 'New folder', hint: 'e.g. Client briefs');
                      if (name != null && name.isNotEmpty) s.saveSection(NoteSection(id: newId(), title: name, order: s.sections.length));
                    },
                    child: Text('+ New folder', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                  )),
                  if (s.sections.isEmpty)
                    Box(padding: const EdgeInsets.all(16), child: Text('Group notes in folders, like “Client briefs” or “Ideas”. A folder can be pinned to Home.', style: TextStyle(color: context.mutedText, height: 1.5)))
                  else if (prefs.notesGrid)
                    LayoutBuilder(builder: (context, c) => GridView.count(
                      crossAxisCount: (c.maxWidth / 210).floor().clamp(2, 6),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: [for (var i = 0; i < s.sections.length; i++) FadeIn(index: i, child: _FolderCard(f: s.sections[i], count: s.notes.where((n) => n.sectionId == s.sections[i].id).length, color: i))],
                    ))
                  else
                    Box(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < s.sections.length; i++) ...[
                          if (i > 0) const Divider(),
                          FadeIn(index: i, child: _FolderRow(f: s.sections[i], count: s.notes.where((n) => n.sectionId == s.sections[i].id).length, color: i)),
                        ],
                      ]),
                    ),
                ],
                Label(filtering ? 'Results · ${loose.length}' : 'Notes · ${loose.length}'),
                if (s.notes.isEmpty && s.loaded)
                  const EmptyState(icon: Icons.sticky_note_2_outlined, title: 'No notes yet', body: 'Tap + and choose Note. Add tabs, lists, checklists, links and images.')
                else
                  NotesGrid(notes: loose, selecting: selecting, picked: picked, onToggle: _toggle, onStartSelect: _start),
              ]),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: selecting ? NotesSelectBar(picked: picked, onDone: _stop) : null,
    );
  }
}

class _FolderCard extends StatelessWidget {
  final NoteSection f;
  final int count;
  final int color;
  const _FolderCard({required this.f, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    final p = pastel((color * 3 + 2) % pastels.length);
    return Box(
      color: context.isDark ? p.fg.withOpacity(0.22) : p.bg,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(id: f.id))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.folder_rounded, color: context.isDark ? Colors.white : p.fg, size: 26),
          const Spacer(),
          if (f.onHome) Icon(Icons.home_rounded, size: 16, color: context.isDark ? Colors.white70 : p.fg),
        ]),
        const Spacer(),
        Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: context.isDark ? Colors.white : C.ink)),
        Text('$count notes', style: TextStyle(fontSize: 12, color: context.isDark ? Colors.white70 : p.fg)),
      ]),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final NoteSection f;
  final int count;
  final int color;
  const _FolderRow({required this.f, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    final p = pastel((color * 3 + 2) % pastels.length);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(id: f.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: context.isDark ? p.fg.withOpacity(0.25) : p.bg, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.folder_rounded, size: 21, color: context.isDark ? Colors.white : p.fg)),
          const SizedBox(width: 12),
          Expanded(child: Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
          if (f.onHome) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.home_rounded, size: 16, color: context.mutedText)),
          Text('$count', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600)),
          Icon(Icons.chevron_right_rounded, color: context.mutedText),
        ]),
      ),
    );
  }
}

/// One folder: its notes, plus rename / show on Home / delete.
class FolderScreen extends StatefulWidget {
  final String id;
  const FolderScreen({super.key, required this.id});
  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool selecting = false;
  final picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    final f = s.sections.where((x) => x.id == widget.id).firstOrNull;
    if (f == null) return Scaffold(body: SafeArea(child: Column(children: const [Header('Folder'), EmptyState(icon: Icons.folder_off_outlined, title: 'Folder removed', body: '')])));
    final notes = s.notes.where((n) => n.sectionId == f.id).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
          Header(f.title, actions: [
            RoundButton(icon: prefs.notesGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, tooltip: prefs.notesGrid ? 'List view' : 'Grid view', onTap: () => prefs.notesGrid = !prefs.notesGrid),
            RoundButton(icon: Icons.note_add_outlined, tooltip: 'New note here', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(sectionId: f.id), fullscreenDialog: true))),
            RoundButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Folder options',
              onTap: () => showActions(context, title: f.title, items: [
                ActionItem(f.onHome ? Icons.home_rounded : Icons.add_home_outlined, f.onHome ? 'Remove from Home' : 'Show on Home', () {
                  f.onHome = !f.onHome;
                  s.saveSection(f);
                }),
                ActionItem(Icons.edit_outlined, 'Rename', () async {
                  final t = await askText(context, title: 'Rename folder', initial: f.title);
                  if (t != null && t.isNotEmpty) {
                    f.title = t;
                    s.saveSection(f);
                  }
                }),
                ActionItem(Icons.upload_file_rounded, 'Import documents here', () => importNotes(context, folderId: f.id)),
                ActionItem(Icons.checklist_rounded, 'Select notes', () => setState(() => selecting = true)),
                ActionItem(Icons.delete_outline_rounded, 'Delete folder (keep notes)', () async {
                  final m = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final undo = await s.deleteDocs('sections', [f.id]);
                  m.showSnackBar(SnackBar(content: const Text('Folder deleted · notes kept'), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
                }, danger: true),
              ]),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: notes.isEmpty
                ? const EmptyState(icon: Icons.folder_open_outlined, title: 'Empty folder', body: 'Tap the note icon above to add a note here, or move notes in from their menu.')
                : NotesGrid(
                    notes: notes,
                    selecting: selecting,
                    picked: picked,
                    onToggle: (id) => setState(() {
                      if (!picked.remove(id)) picked.add(id);
                      if (picked.isEmpty) selecting = false;
                    }),
                    onStartSelect: (id) => setState(() {
                      selecting = true;
                      picked.add(id);
                    }),
                  ),
          ),
        ]),
      ),
      bottomNavigationBar: selecting
          ? NotesSelectBar(
              picked: picked,
              onDone: () => setState(() {
                selecting = false;
                picked.clear();
              }))
          : null,
    );
  }
}

class NoteCard extends StatelessWidget {
  final Note note;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onStartSelect;
  const NoteCard({super.key, required this.note, this.selecting = false, this.selected = false, this.onToggle, this.onStartSelect});
  @override
  Widget build(BuildContext context) {
    final n = note;
    final plainBg = n.color == 0;
    final bg = context.isDark && plainBg ? context.surface : noteColor(n.color);
    final ink = context.isDark && plainBg ? null : C.ink;
    final checks = n.blocks.where((b) => b.type == 'check' || b.type == 'bullets').expand((b) => b.items.map((i) => (b.type, i))).toList();
    final drops = n.blocks.where((b) => b.type == 'dropdown').toList();
    final img = n.firstImage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selecting ? onToggle : () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(id: n.id))),
          onLongPress: selecting ? onToggle : () => showNoteActions(context, n, onSelect: onStartSelect),
          onSecondaryTap: selecting ? onToggle : () => showNoteActions(context, n, onSelect: onStartSelect), // right-click on computers
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? context.accent : (context.isDark ? Colors.white10 : C.line), width: selected ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (img != null) SizedBox(height: 100, width: double.infinity, child: Image.network(img.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (selecting)
                      Padding(padding: const EdgeInsets.only(right: 6), child: Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: context.accent))
                    else
                      Padding(padding: const EdgeInsets.only(right: 6), child: Icon(iconOf(n.icon), size: 17, color: ink ?? context.accent)),
                    Expanded(child: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: ink))),
                    if (n.pinned) Icon(Icons.push_pin, size: 14, color: ink ?? context.mutedText),
                  ]),
                  if (n.preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(n.preview, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.45, color: ink?.withOpacity(0.75) ?? context.mutedText)),
                  ],
                  for (final c in checks.take(3))
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(children: [
                        Icon(c.$1 == 'bullets' ? Icons.circle : (c.$2.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded), size: c.$1 == 'bullets' ? 6 : 15, color: ink),
                        SizedBox(width: c.$1 == 'bullets' ? 9 : 6),
                        Expanded(child: Text(c.$2.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: ink, decoration: c.$2.done && c.$1 == 'check' ? TextDecoration.lineThrough : null))),
                      ]),
                    ),
                  if (checks.length > 3) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+${checks.length - 3} more', style: TextStyle(fontSize: 12, color: ink?.withOpacity(0.6) ?? context.mutedText))),
                  for (final d in drops.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(children: [Icon(Icons.arrow_right_rounded, size: 18, color: ink), Expanded(child: Text(d.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink)))]),
                    ),
                  if (n.tabs.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Icon(Icons.tab_rounded, size: 14, color: ink?.withOpacity(0.6) ?? context.mutedText),
                        const SizedBox(width: 4),
                        Text('${n.tabs.length} tabs', style: TextStyle(fontSize: 11.5, color: ink?.withOpacity(0.6) ?? context.mutedText)),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Edited ${fmtStamp(n.updatedAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: ink?.withOpacity(0.55) ?? context.mutedText)),
                  ),
                  if (n.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final t in n.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(context.isDark && plainBg ? 0.08 : 0.7), borderRadius: BorderRadius.circular(10)),
                          child: Text('#$t', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.isDark && plainBg ? context.accent : C.purpleDark)),
                        ),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class LabelsScreen extends StatelessWidget {
  const LabelsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final c = TextEditingController();
    void add() {
      final v = c.text.trim().replaceAll('#', '').replaceAll(' ', '-').toLowerCase();
      if (v.isEmpty || s.tags.contains(v)) return;
      s.saveTags([...s.tags, v]);
      c.clear();
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Labels & tags'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: TextField(controller: c, onSubmitted: (_) => add(), decoration: const InputDecoration(hintText: 'New tag, e.g. client', prefixText: '#'))),
                const SizedBox(width: 8),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 54)), onPressed: add, child: const Text('Add')),
              ]),
              const SizedBox(height: 14),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final t in s.tags)
                    ListTile(
                      leading: const Icon(Icons.local_offer_outlined),
                      title: Text('#$t', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${s.notes.where((n) => n.tags.contains(t)).length} notes'),
                      trailing: IconButton(
                        tooltip: 'Delete tag',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          final before = List<String>.of(s.tags);
                          s.saveTags(before.where((x) => x != t).toList());
                          showUndo(context, 'Tag #$t deleted', () => s.saveTags(before));
                        },
                      ),
                    ),
                  if (s.tags.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No tags yet.')),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
