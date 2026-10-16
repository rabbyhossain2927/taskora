import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'note_editor.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? tag;
  String q = '';
  final closed = <String>{};

  Future<String?> _ask(String title, [String initial = '']) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Section title')),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Save'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    bool match(Note n) =>
        (tag == null || n.tags.contains(tag)) &&
        (q.isEmpty || n.title.toLowerCase().contains(q) || n.preview.toLowerCase().contains(q));
    final notes = s.notes.where(match).toList();
    final loose = notes.where((n) => n.sectionId == null || s.sections.every((x) => x.id != n.sectionId)).toList();

    Widget grid(List<Note> list) => prefs.notesGrid
        ? LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 10) / 2;
            final left = <Note>[], right = <Note>[];
            for (var i = 0; i < list.length; i++) {
              (i.isEven ? left : right).add(list[i]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: w, child: Column(children: [for (final n in left) NoteCard(note: n)])),
              const SizedBox(width: 10),
              SizedBox(width: w, child: Column(children: [for (final n in right) NoteCard(note: n)])),
            ]);
          })
        : Column(children: [for (final n in list) NoteCard(note: n)]);

    return SafeArea(
      bottom: false,
      child: SyncRefresh(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
          Row(children: [
            const Expanded(child: Text('Notes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
            RoundButton(icon: prefs.notesGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, tooltip: prefs.notesGrid ? 'List view' : 'Grid view', onTap: () => prefs.notesGrid = !prefs.notesGrid),
          ]),
          const SizedBox(height: 12),
          TextField(decoration: const InputDecoration(hintText: 'Search notes', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => q = v.trim().toLowerCase())),
          SizedBox(
            height: 50,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 8), children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(const Tag('all', 'All', 19, 'all_inclusive'), selected: tag == null, onTap: () => setState(() => tag = null))),
              for (final t in s.tags)
                Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(Tag(t, '#$t', 0, 'tag'), selected: tag == t, onTap: () => setState(() => tag = tag == t ? null : t))),
              TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabelsScreen())), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit tags')),
            ]),
          ),
          if (s.notes.isEmpty && s.loaded)
            const EmptyState(icon: Icons.sticky_note_2_outlined, title: 'No notes yet', body: 'Tap + and choose Note. Add checklists, dropdowns and colours.'),
          for (final sec in s.sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Row(children: [
                InkWell(
                  onTap: () => setState(() => closed.contains(sec.id) ? closed.remove(sec.id) : closed.add(sec.id)),
                  child: Row(children: [
                    AnimatedRotation(turns: closed.contains(sec.id) ? -0.25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.expand_more_rounded)),
                    const SizedBox(width: 4),
                    Text(sec.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('${notes.where((n) => n.sectionId == sec.id).length}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Spacer(),
                ActionChip(
                  avatar: Icon(sec.onHome ? Icons.home_rounded : Icons.add_home_outlined, size: 16, color: sec.onHome ? context.accent : context.mutedText),
                  label: Text(sec.onHome ? 'On Home' : 'Add to Home', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sec.onHome ? context.accent : null)),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: sec.onHome ? context.accent : C.line),
                  onPressed: () {
                    sec.onHome = !sec.onHome;
                    s.saveSection(sec);
                  },
                ),
                PopupMenuButton<String>(
                  tooltip: 'Section options',
                  onSelected: (v) async {
                    if (v == 'add') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(sectionId: sec.id), fullscreenDialog: true));
                    } else if (v == 'rename') {
                      final t = await _ask('Rename section', sec.title);
                      if (t != null && t.isNotEmpty) {
                        sec.title = t;
                        s.saveSection(sec);
                      }
                    } else if (v == 'delete') {
                      final undo = await s.deleteDocs('sections', [sec.id]);
                      if (context.mounted) showUndo(context, 'Section deleted · notes kept', undo);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'add', child: Text('New note here')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete section')),
                  ],
                ),
              ]),
            ),
            if (!closed.contains(sec.id)) grid(notes.where((n) => n.sectionId == sec.id).toList()),
          ],
          if (loose.isNotEmpty) ...[
            if (s.sections.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 14, bottom: 8), child: Text('Other notes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            grid(loose),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
            onPressed: () async {
              final t = await _ask('New section');
              if (t != null && t.isNotEmpty) s.saveSection(NoteSection(id: newId(), title: t, order: s.sections.length));
            },
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('New section'),
          ),
        ]),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  final Note note;
  const NoteCard({super.key, required this.note});
  @override
  Widget build(BuildContext context) {
    final n = note;
    final bg = context.isDark && n.color == 0 ? context.surface : noteColor(n.color);
    final ink = context.isDark && n.color == 0 ? null : C.ink;
    final checks = n.blocks.where((b) => b.type == 'check').expand((b) => b.items).toList();
    final drops = n.blocks.where((b) => b.type == 'dropdown').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(id: n.id))),
          onLongPress: () async {
            final s = context.read<Store>();
            final undo = await s.deleteDocs('notes', [n.id]);
            if (context.mounted) showUndo(context, 'Note deleted', undo);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: context.isDark ? Colors.white10 : C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(iconOf(n.icon), size: 18, color: ink ?? context.accent),
                const SizedBox(width: 6),
                Expanded(child: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink))),
                if (n.pinned) Icon(Icons.push_pin, size: 15, color: ink),
              ]),
              if (n.preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(n.preview, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.45, color: ink?.withOpacity(0.75))),
              ],
              for (final c in checks.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(children: [
                    Icon(c.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16, color: ink),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: ink, decoration: c.done ? TextDecoration.lineThrough : null))),
                  ]),
                ),
              if (checks.length > 3) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+${checks.length - 3} more', style: TextStyle(fontSize: 12, color: ink?.withOpacity(0.6)))),
              for (final d in drops.take(2))
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(children: [Icon(Icons.arrow_right_rounded, size: 18, color: ink), Expanded(child: Text(d.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)))]),
                ),
              if (n.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final t in n.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                      child: Text('#$t', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.purpleDark)),
                    ),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Add, rename and delete note tags.
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
