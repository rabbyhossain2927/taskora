import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
    if (!widget.trash) return 'Archived ${i.when.millisecondsSinceEpoch == 0 ? '' : fmtStamp(i.when)}';
    final left = Store.trashDays - DateTime.now().difference(i.when).inDays;
    return 'Deleted ${fmtStamp(i.when)} · ${left <= 1 ? 'goes today' : '$left days left'}';
  }

  void _menu(Store s, BinItem i) {
    showActions(context, title: _name(i), subtitle: '${i.kind} · ${_when(i)}', items: [
      ActionItem(widget.trash ? Icons.restore_rounded : Icons.unarchive_outlined, widget.trash ? 'Restore' : 'Unarchive', () => _restore(s, [i])),
      if (!widget.trash) ActionItem(Icons.delete_outline_rounded, 'Move to Trash', () => _toTrash(s, [i]), danger: true),
      if (widget.trash) ActionItem(Icons.delete_forever_outlined, 'Delete for good', () => _deleteForever(s, [i]), danger: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final all = widget.trash ? s.trash : s.archived;
    final list = all.where((i) => filter == 'all' || i.col == filter).toList();
    final chosen = list.where((i) => picked.contains(i.key)).toList();
    final allPicked = list.isNotEmpty && chosen.length == list.length;
    final title = widget.trash ? 'Trash' : 'Archive';
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
                  Icon(widget.trash ? Icons.auto_delete_outlined : Icons.inventory_2_outlined, color: context.onTint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.trash
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
                      icon: widget.trash ? Icons.delete_outline_rounded : Icons.archive_outlined,
                      title: widget.trash ? 'Trash is empty' : 'Nothing archived',
                      body: widget.trash ? 'Things you delete show up here for ${Store.trashDays} days.' : 'Hold a project, to-do or note and choose Archive.',
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
                                tooltip: widget.trash ? 'Restore' : 'Unarchive',
                                icon: Icon(widget.trash ? Icons.restore_rounded : Icons.unarchive_outlined, color: context.accent),
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
                      icon: Icon(widget.trash ? Icons.restore_rounded : Icons.unarchive_outlined),
                      label: Text('Restore (${chosen.length})'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.red, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
                      onPressed: chosen.isEmpty ? null : () => widget.trash ? _deleteForever(s, chosen) : _toTrash(s, chosen),
                      icon: Icon(widget.trash ? Icons.delete_forever_outlined : Icons.delete_outline_rounded),
                      label: Text(widget.trash ? 'Delete (${chosen.length})' : 'Trash (${chosen.length})'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
