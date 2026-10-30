import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';

/// Archive (trash: false) or Trash (trash: true) for projects, to-dos and notes.
/// Tap an item for Restore / Delete; "Select" to act on many at once.
class BinScreen extends StatefulWidget {
  final bool trash;
  const BinScreen({super.key, required this.trash});
  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  String filter = 'all';
  bool? _place; // computers: switch Archive / Trash in place
  bool get trash => _place ?? widget.trash;
  bool selecting = false;
  final picked = <String>{}; // "col/id"

  static const _kinds = {
    'projects': (Icons.work_outline_rounded, 12),
    'todos': (Icons.check_circle_outline_rounded, 8),
    'notes': (Icons.sticky_note_2_outlined, 6),
  };

  Map<String, List<String>> _group(Iterable<BinItem> items) {
    final m = <String, List<String>>{};
    for (final i in items) {
      (m[i.col] ??= []).add(i.id);
    }
    return m;
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(d, true), style: TextButton.styleFrom(foregroundColor: C.red), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _restore(Store s, List<BinItem> items) async {
    for (final e in _group(items).entries) {
      await s.restore(e.key, e.value);
    }
    if (mounted) toast(context, items.length == 1 ? '“${_name(items.first)}” restored' : '${items.length} items restored');
    _done();
  }

  Future<void> _deleteForever(Store s, List<BinItem> items) async {
    final ok = await _confirm(items.length == 1 ? 'Delete for good?' : 'Delete ${items.length} items for good?', 'This can’t be undone.', 'Delete');
    if (!ok) return;
    for (final e in _group(items).entries) {
      await s.deleteForever(e.key, e.value);
    }
    if (mounted) toast(context, items.length == 1 ? 'Deleted for good' : '${items.length} items deleted for good');
    _done();
  }

  Future<void> _toTrash(Store s, List<BinItem> items) async {
    for (final e in _group(items).entries) {
      await s.moveToTrash(e.key, e.value);
    }
    if (mounted) toast(context, items.length == 1 ? 'Moved to Trash' : '${items.length} items moved to Trash');
    _done();
  }

  void _done() => setState(() {
        selecting = false;
        picked.clear();
      });

  String _name(BinItem i) => i.title.trim().isEmpty ? 'Untitled' : i.title;

  String _when(BinItem i) {
    if (!trash) return 'Archived ${i.when.millisecondsSinceEpoch == 0 ? '' : fmtStamp(i.when)}';
    final left = Store.trashDays - DateTime.now().difference(i.when).inDays;
    return 'Deleted ${fmtStamp(i.when)} · ${left <= 1 ? 'goes today' : '$left days left'}';
  }

  void _menu(Store s, BinItem i) {
    showActions(context, title: _name(i), subtitle: '${i.kind} · ${_when(i)}', items: [
      ActionItem(trash ? Icons.restore_rounded : Icons.unarchive_outlined, trash ? 'Restore' : 'Unarchive', () => _restore(s, [i])),
      if (!trash) ActionItem(Icons.delete_outline_rounded, 'Move to Trash', () => _toTrash(s, [i]), danger: true),
      if (trash) ActionItem(Icons.delete_forever_outlined, 'Delete for good', () => _deleteForever(s, [i]), danger: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final all = trash ? s.trash : s.archived;
    final list = all.where((i) => filter == 'all' || i.col == filter).toList();
    final chosen = list.where((i) => picked.contains(i.key)).toList();
    final allPicked = list.isNotEmpty && chosen.length == list.length;
    final title = trash ? 'Trash' : 'Archive';
    if (deskWide(context)) {
      final muted = context.mutedText;
      Widget cells(List<Widget> w) => Row(children: [
            SizedBox(width: 48, child: w[0]),
            Expanded(flex: 5, child: w[1]),
            Expanded(flex: 2, child: w[2]),
            Expanded(flex: 3, child: w[3]),
            Expanded(flex: 2, child: w[4]),
            SizedBox(width: 200, child: Align(alignment: Alignment.centerRight, child: w[5])),
          ]);
      String goes(BinItem i) {
        final left = Store.trashDays - DateTime.now().difference(i.when).inDays;
        return left <= 1 ? 'Today' : '$left days';
      }
      Color goesColor(BinItem i) {
        final left = Store.trashDays - DateTime.now().difference(i.when).inDays;
        return left > 20 ? const Color(0xFF1E7A50) : (left > 9 ? const Color(0xFF8A5A00) : const Color(0xFFB42318));
      }
      return DeskScroll(children: [
        DeskHead('Archive & Trash', subtitle: 'Trash is emptied automatically ${Store.trashDays} days after deleting.', actions: [
          DeskSeg<bool>(items: [(false, 'Archive · ${s.archived.length}'), (true, 'Trash · ${s.trash.length}')], value: trash, onChanged: (v) => setState(() {
                _place = v;
                picked.clear();
              })),
          DeskSeg<String>(items: const [('all', 'All'), ('projects', 'Projects'), ('todos', 'To-dos'), ('notes', 'Notes')], value: filter, onChanged: (v) => setState(() {
                filter = v;
                picked.clear();
              })),
        ]),
        const SizedBox(height: 14),
        DeskCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (chosen.isNotEmpty)
              Container(
                color: context.isDark ? Colors.white10 : const Color(0xFFEEEEFD),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(children: [
                  Text('${chosen.length} selected', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF3B2E8F))),
                  const Spacer(),
                  DeskBtn(trash ? 'Restore' : 'Unarchive', kind: 'white', height: 34, onTap: () => _restore(s, chosen)),
                  const SizedBox(width: 8),
                  trash ? DeskBtn('Delete for good', kind: 'danger', height: 34, onTap: () => _deleteForever(s, chosen)) : DeskBtn('Move to Trash', kind: 'danger', height: 34, onTap: () => _toTrash(s, chosen)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
                child: cells([
                  Checkbox(
                    value: allPicked,
                    onChanged: list.isEmpty ? null : (_) => setState(() => allPicked ? picked.clear() : picked.addAll(list.map((i) => i.key))),
                  ),
                  const Text('Name'),
                  const Text('Type'),
                  Text(trash ? 'Deleted' : 'Archived'),
                  Text(trash ? 'Goes in' : ''),
                  const SizedBox(),
                ]),
              ),
            ),
            if (list.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 22), child: Align(alignment: Alignment.centerLeft, child: Text(trash ? 'Trash is empty.' : 'Nothing archived.', style: TextStyle(color: muted)))),
            for (final i in list)
              DeskHover(
                wash: true,
                radius: 0,
                onTap: () => setState(() => picked.contains(i.key) ? picked.remove(i.key) : picked.add(i.key)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: picked.contains(i.key) ? (context.isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8F7FF)) : null,
                    border: const Border(top: BorderSide(color: deskLine)),
                  ),
                  child: cells([
                    Checkbox(value: picked.contains(i.key), onChanged: (_) => setState(() => picked.contains(i.key) ? picked.remove(i.key) : picked.add(i.key))),
                    Text(_name(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(i.kind, style: TextStyle(fontSize: 13, color: muted)),
                    Text(i.when.millisecondsSinceEpoch == 0 ? '—' : fmtStamp(i.when), style: TextStyle(fontSize: 13, color: muted)),
                    Text(trash ? goes(i) : '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: goesColor(i))),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      DeskBtn(trash ? 'Restore' : 'Unarchive', height: 32, onTap: () => _restore(s, [i])),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: trash ? 'Delete for good' : 'Move to Trash',
                        icon: Icon(trash ? Icons.delete_forever_outlined : Icons.delete_outline_rounded, size: 19, color: const Color(0xFFB42318)),
                        onPressed: () => trash ? _deleteForever(s, [i]) : _toTrash(s, [i]),
                      ),
                    ]),
                  ]),
                ),
              ),
          ]),
        ),
      ]);
    }
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Header(title, actions: [
            if (list.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  selecting = !selecting;
                  picked.clear();
                }),
                child: Text(selecting ? 'Cancel' : 'Select', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Box(
                color: context.tint,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(trash ? Icons.auto_delete_outlined : Icons.inventory_2_outlined, color: context.onTint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      trash
                          ? 'Deleted projects, to-dos and notes stay here for ${Store.trashDays} days, then they’re removed for good.'
                          : 'Archived items are hidden from your lists but kept safe. Restore them any time.',
                      style: TextStyle(color: context.onTint, fontSize: 12.5, height: 1.45),
                    ),
                  ),
                ]),
              ),
              SizedBox(
                height: 52,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 8), children: [
                  for (final f in const [('all', 'All'), ('projects', 'Projects'), ('todos', 'To-dos'), ('notes', 'Notes')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${f.$2} · ${f.$1 == 'all' ? all.length : all.where((i) => i.col == f.$1).length}'),
                        selected: filter == f.$1,
                        onSelected: (_) => setState(() => filter = f.$1),
                      ),
                    ),
                ]),
              ),
              if (selecting)
                Row(children: [
                  Checkbox(
                    value: allPicked,
                    onChanged: (_) => setState(() {
                      if (allPicked) {
                        picked.removeAll(list.map((i) => i.key));
                      } else {
                        picked.addAll(list.map((i) => i.key));
                      }
                    }),
                  ),
                  Text(allPicked ? 'Unselect all' : 'Select all', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${chosen.length} selected', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600)),
                ]),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(children: [
                    EmptyState(
                      icon: trash ? Icons.delete_outline_rounded : Icons.archive_outlined,
                      title: trash ? 'Trash is empty' : 'Nothing archived',
                      body: trash ? 'Things you delete show up here for ${Store.trashDays} days.' : 'Hold a project, to-do or note and choose Archive.',
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, k) {
                      final i = list[k];
                      final kind = _kinds[i.col]!;
                      final p = pastel(kind.$2);
                      final on = picked.contains(i.key);
                      void toggle() => setState(() => on ? picked.remove(i.key) : picked.add(i.key));
                      return FadeIn(
                        index: k,
                        child: Box(
                          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                          onTap: selecting ? toggle : () => _menu(s, i),
                          child: Row(children: [
                            if (selecting) Checkbox(value: on, onChanged: (_) => toggle()),
                            Container(width: 40, height: 40, decoration: BoxDecoration(color: context.isDark ? p.fg.withOpacity(0.25) : p.bg, borderRadius: BorderRadius.circular(13)), child: Icon(kind.$1, size: 20, color: context.isDark ? Colors.white : p.fg)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_name(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                const SizedBox(height: 2),
                                Text('${i.kind} · ${_when(i)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.mutedText)),
                              ]),
                            ),
                            if (!selecting)
                              IconButton(
                                tooltip: trash ? 'Restore' : 'Unarchive',
                                icon: Icon(trash ? Icons.restore_rounded : Icons.unarchive_outlined, color: context.accent),
                                onPressed: () => _restore(s, [i]),
                              ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      bottomNavigationBar: selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
                      onPressed: chosen.isEmpty ? null : () => _restore(s, chosen),
                      icon: Icon(trash ? Icons.restore_rounded : Icons.unarchive_outlined),
                      label: Text('Restore (${chosen.length})'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.red, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
                      onPressed: chosen.isEmpty ? null : () => trash ? _deleteForever(s, chosen) : _toTrash(s, chosen),
                      icon: Icon(trash ? Icons.delete_forever_outlined : Icons.delete_outline_rounded),
                      label: Text(trash ? 'Delete (${chosen.length})' : 'Trash (${chosen.length})'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
