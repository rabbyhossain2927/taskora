import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';
import 'todo_editor.dart';

Future<void> deleteTodos(BuildContext context, List<String> ids) async {
  final s = context.read<Store>();
  final m = ScaffoldMessenger.of(context);
  final undo = await s.deleteDocs('todos', ids);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(ids.length == 1 ? 'To-do moved to Trash' : '${ids.length} to-dos moved to Trash'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
}

Future<void> archiveTodos(BuildContext context, List<String> ids) async {
  final s = context.read<Store>();
  await s.archive('todos', ids);
  if (context.mounted) showUndo(context, ids.length == 1 ? 'To-do archived' : '${ids.length} to-dos archived', () => s.archive('todos', ids, false));
}

Future<int?> askPriority(BuildContext context, [int? current]) =>
    pickOne<int>(context, title: 'Priority', current: current, options: [for (var i = 1; i <= 5; i++) (i, priorityName(i))], icons: const [Icons.flag_rounded, Icons.flag_rounded, Icons.flag_rounded, Icons.flag_rounded, Icons.outlined_flag_rounded]);

Future<String?> askTodoCategory(BuildContext context, [String? current]) async {
  final s = context.read<Store>();
  final v = await pickOne<String>(context, title: 'Category', current: current, options: [for (final t in s.todoCats) (t.key, t.label), ('__new', '+ New category…')]);
  if (v != '__new' || !context.mounted) return v;
  final name = await askText(context, title: 'New category', hint: 'e.g. Freelance');
  if (name == null || name.isEmpty) return null;
  return addCategory(s, 'todoCats', name);
}

/// Long-press menu for one to-do.
void showTodoActions(BuildContext context, Todo t, {VoidCallback? onSelect}) {
  final s = context.read<Store>();
  HapticFeedback.mediumImpact();
  showActions(context, title: t.title.isEmpty ? 'To-do' : t.title, items: [
    ActionItem(t.done ? Icons.replay_rounded : Icons.check_circle_outline_rounded, t.done ? 'Mark as not done' : 'Mark as done', () => s.toggleTodo(t)),
    ActionItem(Icons.edit_outlined, 'Edit', () => openEditor(context, TodoEditor(id: t.id))),
    ActionItem(Icons.low_priority_rounded, 'Change priority', () async {
      final v = await askPriority(context, t.priority);
      if (v != null) {
        t.priority = v;
        s.saveTodo(t);
      }
    }),
    ActionItem(Icons.category_outlined, 'Change category', () async {
      final v = await askTodoCategory(context, t.category);
      if (v != null) {
        t.category = v;
        s.saveTodo(t);
      }
    }),
    ActionItem(Icons.event_outlined, 'Change deadline', () async {
      final d = await pickDeadline(context, t.deadline);
      if (d != null) {
        t.deadline = d;
        s.saveTodo(t);
      }
    }),
    if (onSelect != null) ActionItem(Icons.checklist_rounded, 'Select several', onSelect),
    ActionItem(Icons.archive_outlined, 'Archive', () => archiveTodos(context, [t.id])),
    ActionItem(Icons.delete_outline_rounded, 'Move to Trash', () => deleteTodos(context, [t.id]), danger: true),
  ]);
}

/// One to-do line: checkbox, title, details, and a dropdown for its sub-tasks.
class TodoRow extends StatefulWidget {
  final Todo todo;
  final bool selecting;
  final bool selected;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onStartSelect;
  const TodoRow({super.key, required this.todo, this.selecting = false, this.selected = false, this.onSelectToggle, this.onStartSelect});
  @override
  State<TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<TodoRow> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final s = context.read<Store>();
    final t = widget.todo;
    final cat = s.todoCat(t.category);
    final proj = s.project(t.projectId);
    final now = DateTime.now();
    final overdue = !t.done && t.deadline != null && t.deadline!.isBefore(DateTime(now.year, now.month, now.day));
    final subDone = t.subtasks.where((x) => x.done).length;
    final row = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.selecting ? widget.onSelectToggle : () => openEditor(context, TodoEditor(id: t.id)),
      onLongPress: widget.selecting ? widget.onSelectToggle : () => showTodoActions(context, t, onSelect: widget.onStartSelect),
      onSecondaryTap: widget.selecting ? widget.onSelectToggle : () => showTodoActions(context, t, onSelect: widget.onStartSelect), // right-click on computers
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(color: widget.selected ? context.tint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Column(children: [
          Row(children: [
            if (widget.selecting)
              Checkbox(value: widget.selected, onChanged: (_) => widget.onSelectToggle?.call())
            else
              CheckDot(value: t.done, color: priorityColor(t.priority), onTap: () {
                HapticFeedback.lightImpact();
                s.toggleTodo(t);
              }),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title.isEmpty ? 'Untitled' : t.title,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? context.mutedText : null)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (t.deadline != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_outlined, size: 13, color: overdue ? C.red : context.mutedText),
                        const SizedBox(width: 3),
                        Text(fmtDue(t.deadline!), style: TextStyle(fontSize: 12, color: overdue ? C.red : context.mutedText, fontWeight: FontWeight.w500)),
                      ]),
                    PriorityBadge(t.priority),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(iconOf(cat.icon), size: 13, color: pastel(cat.color).fg),
                      const SizedBox(width: 3),
                      Text(cat.label, style: TextStyle(fontSize: 12, color: pastel(cat.color).fg, fontWeight: FontWeight.w500)),
                    ]),
                    if (t.reminder != null) Icon(Icons.alarm_rounded, size: 13, color: context.mutedText),
                    if (proj != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(iconOf(proj.icon), size: 13, color: pastel(proj.color).fg),
                        const SizedBox(width: 3),
                        Text(proj.title, style: TextStyle(fontSize: 12, color: pastel(proj.color).fg, fontWeight: FontWeight.w600)),
                      ]),
                  ]),
                ]),
              ),
            ),
            if (t.subtasks.isNotEmpty && !widget.selecting)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => open = !open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$subDone/${t.subtasks.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.mutedText)),
                    AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, size: 20, color: context.mutedText)),
                  ]),
                ),
              ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open && !widget.selecting
                ? Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 6),
                    child: Column(children: [
                      for (final sub in t.subtasks)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            sub.done = !sub.done;
                            s.saveTodo(t);
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              Icon(sub.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: sub.done ? context.accent : context.mutedText),
                              const SizedBox(width: 8),
                              Expanded(child: Text(sub.title, style: TextStyle(fontSize: 13.5, decoration: sub.done ? TextDecoration.lineThrough : null, color: sub.done ? context.mutedText : null))),
                            ]),
                          ),
                        ),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
    if (widget.selecting) return row;
    return Slidable(
      key: ValueKey(t.id),
      endActionPane: ActionPane(motion: const BehindMotion(), extentRatio: 0.26, children: [
        SlidableAction(
          onPressed: (_) => deleteTodos(context, [t.id]),
          backgroundColor: C.red,
          foregroundColor: Colors.white,
          icon: Icons.delete_outline_rounded,
          label: 'Trash',
          borderRadius: BorderRadius.circular(16),
        ),
      ]),
      startActionPane: ActionPane(motion: const BehindMotion(), extentRatio: 0.26, children: [
        SlidableAction(
          onPressed: (_) => s.toggleTodo(t),
          backgroundColor: C.green,
          foregroundColor: Colors.white,
          icon: t.done ? Icons.replay_rounded : Icons.check_rounded,
          label: t.done ? 'Undo' : 'Done',
          borderRadius: BorderRadius.circular(16),
        ),
      ]),
      child: row,
    );
  }
}

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});
  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  String? cat;
  String show = 'all'; // computers: all | today | upcoming | done
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }
  bool selecting = false;
  final picked = <String>{};
  final closed = <String>{'Completed'};

  void _toggle(String id) => setState(() {
        if (!picked.remove(id)) picked.add(id);
        if (picked.isEmpty) selecting = false;
      });

  void _startSelect(String id) => setState(() {
        selecting = true;
        picked.add(id);
      });

  void _stopSelect() => setState(() {
        selecting = false;
        picked.clear();
      });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final list = s.todos.where((t) => cat == null || t.category == cat).toList();
    final open = list.where((t) => !t.done).toList();
    final groups = <String, List<Todo>>{
      'Overdue': open.where((t) => t.deadline != null && t.deadline!.isBefore(today)).toList(),
      'Today': open.where((t) => t.deadline != null && !t.deadline!.isBefore(today) && t.deadline!.isBefore(tomorrow)).toList(),
      'Upcoming': open.where((t) => t.deadline != null && !t.deadline!.isBefore(tomorrow)).toList(),
      'No date': open.where((t) => t.deadline == null).toList(),
      if (prefs.showCompleted) 'Completed': list.where((t) => t.done).toList(),
    };
    var idx = 0;

    if (deskWide(context)) {
      final muted = context.mutedText;
      final doneToday = list.where((t) => t.done && t.completedAt != null && !t.completedAt!.isBefore(today)).toList();
      final sections = <(String, Color, List<Todo>)>[
        if (show == 'all' || show == 'today') ('Overdue', const Color(0xFFB42318), groups['Overdue']!),
        if (show == 'all' || show == 'today') ('Today', context.selInk, groups['Today']!),
        if (show == 'all' || show == 'upcoming') ('Upcoming', const Color(0xFF4B4B5A), groups['Upcoming']!),
        if (show == 'all') ('No date', const Color(0xFF4B4B5A), groups['No date']!),
        if (show == 'all') ('Done today', const Color(0xFF4B4B5A), doneToday),
        if (show == 'done') ('Done', const Color(0xFF4B4B5A), list.where((t) => t.done).toList()),
      ].where((x) => x.$3.isNotEmpty).toList();
      void quickAdd() {
        final t = _add.text.trim();
        if (t.isEmpty) return;
        s.saveTodo(Todo(id: newId(), title: t, category: cat ?? 'work', deadline: show == 'today' ? today : null, priority: prefs.defaultPriority));
        _add.clear();
      }
      final weekAgo = today.subtract(const Duration(days: 6));
      final weekDone = s.todos.where((t) => t.done && t.completedAt != null && !t.completedAt!.isBefore(weekAgo)).length;
      return DeskScroll(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DeskHead('To-do', subtitle: '${open.length} open${groups['Overdue']!.isEmpty ? '' : ' · ${groups['Overdue']!.length} overdue'} · ${doneToday.length} done today', actions: [
                DeskSeg<String>(items: const [('all', 'All'), ('today', 'Today'), ('upcoming', 'Upcoming'), ('done', 'Done')], value: show, onChanged: (v) => setState(() => show = v)),
                DeskBtn('New to-do', kind: 'primary', icon: Icons.add_rounded, onTap: () => openEditor(context, const TodoEditor())),
              ]),
              const SizedBox(height: 14),
              DeskCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  Icon(Icons.add_rounded, color: muted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _add,
                      onSubmitted: (_) => quickAdd(),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: show == 'today' ? 'Add a to-do for today…' : 'Add a to-do…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  deskChip('Enter', context.softFill, muted),
                ]),
              ),
              const SizedBox(height: 14),
              DeskCard(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                child: sections.isEmpty
                    ? Padding(padding: const EdgeInsets.all(16), child: Text(show == 'done' ? 'Nothing done yet.' : 'Nothing here. Enjoy the calm.', style: TextStyle(color: muted)))
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final sec in sections) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                            child: Text('${sec.$1}  ${sec.$3.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sec.$2)),
                          ),
                          for (final t in sec.$3) TodoRow(todo: t),
                        ],
                      ]),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 340,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DeskCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const DeskH('Categories'),
                  for (final c in [const Tag('all', 'All to-dos', 19, 'all_inclusive'), ...s.todoCats])
                    DeskHover(
                      wash: true,
                      onTap: () => setState(() => cat = c.key == 'all' ? null : c.key),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: pastel(c.color).bg, borderRadius: BorderRadius.circular(9)),
                          child: Icon(iconOf(c.icon), size: 15, color: pastel(c.color).fg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(c.label,
                              style: TextStyle(fontSize: 13.5, fontWeight: (cat ?? 'all') == c.key ? FontWeight.w700 : FontWeight.w500, color: (cat ?? 'all') == c.key ? context.selInk : null)),
                        ),
                        Text('${s.todos.where((t) => !t.done && (c.key == 'all' || t.category == c.key)).length}', style: TextStyle(fontSize: 12.5, color: muted)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              DeskCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const DeskH('This week'),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$weekDone', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text('done in 7 days', style: TextStyle(fontSize: 12.5, color: muted))])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${groups['Upcoming']!.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text('coming up', style: TextStyle(fontSize: 12.5, color: muted))])),
                  ]),
                  const SizedBox(height: 12),
                  Text('Tip: right-click a to-do for more options.', style: TextStyle(fontSize: 12, color: muted)),
                ]),
              ),
            ]),
          ),
        ]),
      ]);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SyncRefresh(
          child: SlidableAutoCloseBehavior(
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: MainHeader('To-do', subtitle: '${open.length} open · ${list.length - open.length} done', actions: [
                  if (list.isNotEmpty)
                    selecting
                        ? TextButton(onPressed: _stopSelect, child: const Text('Cancel'))
                        : RoundButton(icon: Icons.checklist_rounded, tooltip: 'Select', onTap: () => setState(() => selecting = true)),
                ]),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), children: [
                    Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(const Tag('all', 'All', 19, 'all_inclusive'), selected: cat == null, onTap: () => setState(() => cat = null))),
                    for (final c in s.todoCats)
                      Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(c, selected: cat == c.key, onTap: () => setState(() => cat = cat == c.key ? null : c.key))),
                  ]),
                ),
              ),
              if (s.todos.isEmpty && s.loaded)
                const SliverToBoxAdapter(child: EmptyState(icon: Icons.check_circle_outline, title: 'No to-dos yet', body: 'Tap + to add one. Big job? Add sub-tasks inside it.')),
              for (final g in groups.entries)
                if (g.value.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 20, 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => closed.contains(g.key) ? closed.remove(g.key) : closed.add(g.key)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(children: [
                            AnimatedRotation(turns: closed.contains(g.key) ? 0 : 0.25, duration: const Duration(milliseconds: 200), child: Icon(Icons.chevron_right_rounded, size: 20, color: context.mutedText)),
                            const SizedBox(width: 4),
                            Text(g.key, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: g.key == 'Overdue' ? C.red : null)),
                            const SizedBox(width: 6),
                            Text('${g.value.length}', style: TextStyle(fontSize: 12.5, color: context.mutedText, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  if (!closed.contains(g.key))
                    SliverToBoxAdapter(
                      child: FadeIn(
                        index: idx++,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Box(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: Column(children: [
                              for (final t in g.value)
                                TodoRow(
                                  key: ValueKey('row-${t.id}'),
                                  todo: t,
                                  selecting: selecting,
                                  selected: picked.contains(t.id),
                                  onSelectToggle: () => _toggle(t.id),
                                  onStartSelect: () => _startSelect(t.id),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: selecting
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))]),
                child: Row(children: [
                  const SizedBox(width: 8),
                  Text('${picked.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Mark done',
                    icon: const Icon(Icons.done_all_rounded),
                    onPressed: picked.isEmpty
                        ? null
                        : () {
                            for (final t in s.todos.where((t) => picked.contains(t.id) && !t.done)) {
                              s.toggleTodo(t);
                            }
                            _stopSelect();
                          },
                  ),
                  IconButton(
                    tooltip: 'Priority',
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: picked.isEmpty
                        ? null
                        : () async {
                            final v = await askPriority(context);
                            if (v == null) return;
                            for (final t in s.todos.where((t) => picked.contains(t.id))) {
                              t.priority = v;
                              s.saveTodo(t);
                            }
                            _stopSelect();
                          },
                  ),
                  IconButton(
                    tooltip: 'Category',
                    icon: const Icon(Icons.category_outlined),
                    onPressed: picked.isEmpty
                        ? null
                        : () async {
                            final v = await askTodoCategory(context);
                            if (v == null) return;
                            for (final t in s.todos.where((t) => picked.contains(t.id))) {
                              t.category = v;
                              s.saveTodo(t);
                            }
                            _stopSelect();
                          },
                  ),
                  IconButton(
                    tooltip: 'Archive',
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: picked.isEmpty
                        ? null
                        : () {
                            archiveTodos(context, picked.toList());
                            _stopSelect();
                          },
                  ),
                  IconButton(
                    tooltip: 'Move to Trash',
                    icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                    onPressed: picked.isEmpty
                        ? null
                        : () {
                            deleteTodos(context, picked.toList());
                            _stopSelect();
                          },
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
