import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Edit statuses and categories: name, colour and icon.
class TaxonomyScreen extends StatefulWidget {
  final String initial; // statuses | projectCats | todoCats
  const TaxonomyScreen({super.key, this.initial = 'statuses'});
  @override
  State<TaxonomyScreen> createState() => _TaxonomyScreenState();
}

class _TaxonomyScreenState extends State<TaxonomyScreen> {
  late String field = widget.initial;

  List<Tag> _list(Store s) => switch (field) { 'projectCats' => s.projectCats, 'todoCats' => s.todoCats, _ => s.statuses };

  Future<void> _edit(Store s, Tag? tag) async {
    final list = List<Tag>.of(_list(s));
    final res = await showModalBottomSheet<Tag>(context: context, isScrollControlled: true, builder: (_) => _TagSheet(tag: tag ?? Tag(newId().substring(0, 8), '', 0, 'label')));
    if (res == null || res.label.trim().isEmpty) return;
    final i = list.indexWhere((t) => t.key == res.key);
    if (i >= 0) {
      list[i] = res;
    } else {
      list.add(res);
    }
    await s.saveTaxonomy(field, list);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final list = _list(s);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Statuses & categories'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Segmented<String>(
                items: const [('statuses', 'Statuses'), ('projectCats', 'Project types'), ('todoCats', 'To-do types')],
                value: field,
                onChanged: (v) => setState(() => field = v),
              ),
              const SizedBox(height: 14),
              Box(
                padding: EdgeInsets.zero,
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (a, b) {
                    final l = List<Tag>.of(list);
                    if (b > a) b--;
                    l.insert(b, l.removeAt(a));
                    s.saveTaxonomy(field, l);
                  },
                  children: [
                    for (var i = 0; i < list.length; i++)
                      Material(
                        key: ValueKey(list[i].key),
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () => _edit(s, list[i]),
                          leading: IconTile(icon: list[i].icon, color: list[i].color, size: 38),
                          title: Text(list[i].label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(pastel(list[i].color).name),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (list.length > 1)
                              IconButton(
                                tooltip: 'Delete',
                                icon: Icon(Icons.delete_outline, color: context.mutedText),
                                onPressed: () async {
                                  final before = List<Tag>.of(list);
                                  await s.saveTaxonomy(field, List.of(list)..removeAt(i));
                                  if (context.mounted) showUndo(context, '“${before[i].label}” removed', () => s.saveTaxonomy(field, before));
                                },
                              ),
                            ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator_rounded, color: context.mutedText)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
                onPressed: () => _edit(s, null),
                icon: const Icon(Icons.add_rounded),
                label: Text(field == 'statuses' ? 'Add status' : 'Add category'),
              ),
              const SizedBox(height: 10),
              Text('Items already using a deleted status or category show the first one instead.', style: TextStyle(color: context.mutedText, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TagSheet extends StatefulWidget {
  final Tag tag;
  const _TagSheet({required this.tag});
  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  late Tag t = widget.tag;
  late final name = TextEditingController(text: widget.tag.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              TagChip(t.copyWith(label: name.text.isEmpty ? 'Preview' : name.text)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: name, autofocus: widget.tag.label.isEmpty, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Name')),
            const Label('Colour'),
            ColorDots(colors: [for (final x in pastels) x.bg], rings: [for (final x in pastels) x.fg], value: t.color, size: 30, onChanged: (i) => setState(() => t = t.copyWith(color: i))),
            const Label('Icon'),
            IconQuickPick(
              value: t.icon,
              color: t.color,
              quick: const ['circle', 'pending', 'review', 'pause', 'check', 'cancel', 'flag', 'star'],
              onChanged: (k) => setState(() => t = t.copyWith(icon: k)),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: () => Navigator.pop(context, t.copyWith(label: name.text.trim())), child: const Text('Save')),
          ]),
        ),
      );
}
