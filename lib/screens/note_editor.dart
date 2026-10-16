import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A note made of blocks: text, checklist and collapsible dropdowns.
/// Saves automatically when you go back.
class NoteEditor extends StatefulWidget {
  final String? id;
  final String? sectionId;
  const NoteEditor({super.key, this.id, this.sectionId});
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late Note n;
  late bool isNew;
  bool deleted = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<Store>();
    final ex = widget.id == null ? null : s.notes.where((x) => x.id == widget.id).firstOrNull;
    isNew = ex == null;
    n = ex != null ? Note.fromMap(ex.id, ex.toMap()) : Note(id: newId(), sectionId: widget.sectionId);
    if (n.blocks.isEmpty) n.blocks.add(NoteBlock());
  }

  bool get _empty => n.title.trim().isEmpty && n.blocks.every((b) => b.text.trim().isEmpty && b.body.trim().isEmpty && b.items.isEmpty);

  void _saveOnExit() {
    if (deleted) return;
    if (isNew && _empty) return;
    context.read<Store>().saveNote(n);
  }

  void _add(String type) => setState(() => n.blocks.add(NoteBlock(type: type, items: type == 'check' ? [SubTask('')] : null)));

  Future<void> _style() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (context, set) {
        void upd(VoidCallback f) {
          setState(f);
          set(() {});
        }

        final store = context.read<Store>();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Label('Colour · ${noteColors.length}'),
              ColorDots(colors: noteColors, value: n.color, size: 30, onChanged: (i) => upd(() => n.color = i)),
              const Label('Icon'),
              IconQuickPick(
                value: n.icon,
                color: 0,
                quick: const ['note', 'lightbulb', 'checklist', 'book', 'star', 'heart', 'cart', 'flag'],
                onChanged: (k) => upd(() => n.icon = k),
              ),
              const Label('Section'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('None'), selected: n.sectionId == null, onSelected: (_) => upd(() => n.sectionId = null)),
                for (final sec in store.sections) ChoiceChip(label: Text(sec.title), selected: n.sectionId == sec.id, onSelected: (_) => upd(() => n.sectionId = sec.id)),
              ]),
              const Label('Tags'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in store.tags)
                  FilterChip(label: Text('#$t'), selected: n.tags.contains(t), onSelected: (v) => upd(() {
                    if (v) {
                      n.tags.add(t);
                    } else {
                      n.tags.remove(t);
                    }
                  })),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark && n.color == 0 ? Theme.of(context).scaffoldBackgroundColor : noteColor(n.color);
    final ink = context.isDark && n.color == 0 ? null : C.ink;
    final noBorder = const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6));
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveOnExit();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [
            Header('', actions: [
              RoundButton(icon: n.pinned ? Icons.push_pin : Icons.push_pin_outlined, tooltip: n.pinned ? 'Unpin' : 'Pin', onTap: () => setState(() => n.pinned = !n.pinned)),
              RoundButton(icon: Icons.palette_outlined, tooltip: 'Colour, icon, tags', onTap: _style),
              if (!isNew)
                RoundButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onTap: () async {
                    deleted = true;
                    final s = context.read<Store>();
                    final m = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final undo = await s.deleteDocs('notes', [n.id]);
                    m.showSnackBar(SnackBar(content: const Text('Note deleted'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
                  },
                ),
            ]),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 30), children: [
                Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final k = await pickIcon(context, current: n.icon);
                      if (k != null) setState(() => n.icon = k);
                    },
                    child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(14)), child: Icon(iconOf(n.icon), color: C.purpleDark)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: n.title,
                      autofocus: isNew,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) => n.title = v,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink),
                      decoration: noBorder.copyWith(hintText: 'Title'),
                    ),
                  ),
                ]),
                if (n.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, children: [for (final t in n.tags) Chip(label: Text('#$t'), visualDensity: VisualDensity.compact)]),
                  ),
                const SizedBox(height: 8),
                for (var i = 0; i < n.blocks.length; i++) _block(n.blocks[i], i, ink, noBorder),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ActionChip(avatar: const Icon(Icons.notes, size: 18), label: const Text('Text'), onPressed: () => _add('text')),
                  ActionChip(avatar: const Icon(Icons.checklist, size: 18), label: const Text('Checklist'), onPressed: () => _add('check')),
                  ActionChip(avatar: const Icon(Icons.arrow_drop_down_circle_outlined, size: 18), label: const Text('Dropdown'), onPressed: () => _add('dropdown')),
                ]),
                const SizedBox(height: 16),
                Text('Edited ${dTime.format(n.updatedAt)}', style: TextStyle(fontSize: 12, color: (ink ?? context.mutedText).withOpacity(0.6))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _blockMenu(int i) => PopupMenuButton<String>(
        tooltip: 'Block options',
        icon: const Icon(Icons.more_horiz, size: 20),
        onSelected: (v) => setState(() {
          if (v == 'up' && i > 0) n.blocks.insert(i - 1, n.blocks.removeAt(i));
          if (v == 'down' && i < n.blocks.length - 1) n.blocks.insert(i + 1, n.blocks.removeAt(i));
          if (v == 'delete') n.blocks.removeAt(i);
        }),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'up', child: Text('Move up')),
          PopupMenuItem(value: 'down', child: Text('Move down')),
          PopupMenuItem(value: 'delete', child: Text('Delete block')),
        ],
      );

  Widget _block(NoteBlock b, int i, Color? ink, InputDecoration deco) {
    switch (b.type) {
      case 'check':
        return Container(
          key: ObjectKey(b),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            for (var j = 0; j < b.items.length; j++)
              Row(key: ObjectKey(b.items[j]), children: [
                Checkbox(value: b.items[j].done, onChanged: (v) => setState(() => b.items[j].done = v ?? false)),
                Expanded(
                  child: TextFormField(
                    initialValue: b.items[j].title,
                    onChanged: (v) => b.items[j].title = v,
                    onFieldSubmitted: (_) => setState(() => b.items.insert(j + 1, SubTask(''))),
                    style: TextStyle(color: ink, decoration: b.items[j].done ? TextDecoration.lineThrough : null),
                    decoration: deco.copyWith(hintText: 'List item'),
                  ),
                ),
                IconButton(tooltip: 'Remove item', icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => b.items.removeAt(j))),
              ]),
            Row(children: [
              TextButton.icon(onPressed: () => setState(() => b.items.add(SubTask(''))), icon: const Icon(Icons.add, size: 18), label: const Text('Add item')),
              const Spacer(),
              _blockMenu(i),
            ]),
          ]),
        );
      case 'dropdown':
        return Container(
          key: ObjectKey(b),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Row(children: [
              IconButton(
                tooltip: b.open ? 'Collapse' : 'Expand',
                onPressed: () => setState(() => b.open = !b.open),
                icon: AnimatedRotation(turns: b.open ? 0.25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.arrow_right_rounded, size: 28)),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: b.text,
                  onChanged: (v) => b.text = v,
                  style: TextStyle(fontWeight: FontWeight.w800, color: ink),
                  decoration: deco.copyWith(hintText: 'Dropdown title'),
                ),
              ),
              _blockMenu(i),
            ]),
            if (b.open)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 12, 4),
                child: TextFormField(
                  initialValue: b.body,
                  onChanged: (v) => b.body = v,
                  maxLines: null,
                  style: TextStyle(color: ink, height: 1.5),
                  decoration: deco.copyWith(hintText: 'Hidden content…'),
                ),
              ),
          ]),
        );
      default:
        return Row(key: ObjectKey(b), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextFormField(
              initialValue: b.text,
              onChanged: (v) => b.text = v,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 15.5, height: 1.55, color: ink),
              decoration: deco.copyWith(hintText: i == 0 ? 'Start writing…' : 'Text'),
            ),
          ),
          if (n.blocks.length > 1) _blockMenu(i),
        ]);
    }
  }
}
