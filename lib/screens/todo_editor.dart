import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'focus_screen.dart';

/// Create or edit a to-do (with sub-tasks).
class TodoEditor extends StatefulWidget {
  final String? id;
  final String? projectId;
  final DateTime? deadline;
  const TodoEditor({super.key, this.id, this.projectId, this.deadline});
  @override
  State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  late Todo t;
  late bool isNew;
  final title = TextEditingController(), notes = TextEditingController(), sub = TextEditingController();
  String reminderMode = 'none'; // none | 1h | 1d | custom

  @override
  void initState() {
    super.initState();
    final s = context.read<Store>();
    final existing = widget.id == null ? null : s.todos.where((x) => x.id == widget.id).firstOrNull;
    isNew = existing == null;
    t = existing != null
        ? Todo.fromMap(existing.id, existing.toMap())
        : Todo(id: newId(), projectId: widget.projectId, priority: Prefs.instance.defaultPriority, start: DateTime.now(), deadline: widget.deadline, category: s.todoCats.first.key);
    if (isNew) reminderMode = Prefs.instance.defaultReminder;
    if (!isNew && t.reminder != null) reminderMode = 'custom';
    title.text = t.title;
    notes.text = t.notes;
  }

  void _applyReminder() {
    final d = t.deadline;
    if (reminderMode == 'none') t.reminder = null;
    if (reminderMode == '1h' && d != null) t.reminder = DateTime(d.year, d.month, d.day, 9).subtract(const Duration(hours: 1));
    if (reminderMode == '1d' && d != null) t.reminder = DateTime(d.year, d.month, d.day, 9).subtract(const Duration(days: 1));
  }

  Future<void> _save() async {
    t.title = title.text.trim();
    t.notes = notes.text.trim();
    if (t.title.isEmpty) {
      toast(context, 'Give the to-do a name first.');
      return;
    }
    _applyReminder();
    final s = context.read<Store>();
    Navigator.pop(context);
    await s.saveTodo(t);
  }

  void _addSub() {
    final v = sub.text.trim();
    if (v.isEmpty) return;
    setState(() => t.subtasks.add(SubTask(v)));
    sub.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final subDone = t.subtasks.where((x) => x.done).length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Header(isNew ? 'New to-do' : 'To-do', actions: [
            if (!isNew)
              RoundButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onTap: () async {
                  final m = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final undo = await s.deleteDocs('todos', [t.id]);
                  m.showSnackBar(SnackBar(content: const Text('To-do deleted'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
                },
              ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              Box(
                padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
                child: Row(children: [
                  CheckDot(value: t.done, color: priorityColor(t.priority), onTap: () => setState(() => t.done = !t.done)),
                  Expanded(
                    child: TextField(
                      controller: title,
                      autofocus: isNew,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(hintText: 'What needs doing?', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              TextField(controller: notes, minLines: 2, maxLines: 6, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Notes (optional)')),
              const Label('Project'),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TagChip(const Tag('none', 'No project', 19, 'inbox'), selected: t.projectId == null, onTap: () => setState(() => t.projectId = null)),
                  ),
                  for (final p in s.projects.where((p) => !p.done))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TagChip(Tag(p.id, p.title, p.color, p.icon), selected: t.projectId == p.id, onTap: () => setState(() => t.projectId = p.id)),
                    ),
                ]),
              ),
              const Label('Dates'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  DateRow(label: 'Start', icon: Icons.play_circle_outline, value: t.start, onChanged: (d) => setState(() => t.start = d)),
                  const Divider(),
                  DateRow(label: 'Deadline', icon: Icons.flag_outlined, value: t.deadline, onChanged: (d) => setState(() => t.deadline = d)),
                  const Divider(),
                  RowTile(icon: Icons.person_add_alt_1_outlined, color: 6, title: 'Assigned', subtitle: 'Share to-dos with teammates', trailing: const SoonPill()),
                ]),
              ),
              const Label('Reminder'),
              Segmented<String>(
                items: const [('none', 'None'), ('1h', '1 h before'), ('1d', '1 day'), ('custom', 'Pick')],
                value: reminderMode,
                onChanged: (v) async {
                  if (v != 'none' && v != 'custom' && t.deadline == null) {
                    toast(context, 'Set a deadline first.');
                    return;
                  }
                  setState(() => reminderMode = v);
                  if (v == 'custom') {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: context, initialDate: t.reminder ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 5));
                    if (d == null || !context.mounted) return;
                    final tm = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                    setState(() => t.reminder = DateTime(d.year, d.month, d.day, tm?.hour ?? 9, tm?.minute ?? 0));
                  }
                },
              ),
              if (reminderMode == 'custom' && t.reminder != null)
                Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text('Reminds you ${dTime.format(t.reminder!)}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600))),
              const Label('Priority'),
              PriorityPicker(value: t.priority, onChanged: (v) => setState(() => t.priority = v)),
              Label('Category', trailing: Icon(iconOf('label'), size: 16, color: context.mutedText)),
              TagPicker(
                tags: s.todoCats,
                value: t.category,
                onChanged: (v) => setState(() => t.category = v),
                onAdd: (name) async {
                  final k = await addCategory(s, 'todoCats', name);
                  setState(() => t.category = k);
                },
              ),
              Label('Sub-tasks', trailing: t.subtasks.isEmpty ? null : Text('$subDone/${t.subtasks.length}', style: TextStyle(fontWeight: FontWeight.w700, color: context.accent))),
              Box(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                child: Column(children: [
                  if (t.subtasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                      child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: subDone / t.subtasks.length, minHeight: 6)),
                    ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (a, b) => setState(() {
                      if (b > a) b--;
                      t.subtasks.insert(b, t.subtasks.removeAt(a));
                    }),
                    children: [
                      for (var i = 0; i < t.subtasks.length; i++)
                        Row(key: ValueKey('sub$i${t.subtasks[i].title}'), children: [
                          CheckDot(value: t.subtasks[i].done, size: 20, onTap: () => setState(() => t.subtasks[i].done = !t.subtasks[i].done)),
                          Expanded(child: Text(t.subtasks[i].title, style: TextStyle(decoration: t.subtasks[i].done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600))),
                          IconButton(tooltip: 'Remove', icon: Icon(Icons.close_rounded, size: 18, color: context.mutedText), onPressed: () => setState(() => t.subtasks.removeAt(i))),
                          ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator_rounded, color: context.mutedText)),
                        ]),
                    ],
                  ),
                  Row(children: [
                    const SizedBox(width: 12),
                    Icon(Icons.add_rounded, color: context.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: sub,
                        onSubmitted: (_) => _addSub(),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(hintText: 'Add a sub-task', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                      ),
                    ),
                    TextButton(onPressed: _addSub, child: const Text('Add')),
                  ]),
                ]),
              ),
              if (!isNew) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FocusScreen(todoId: t.id))),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Focus on this'),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: FilledButton(onPressed: _save, child: Text(isNew ? 'Add to-do' : 'Save changes')),
          ),
        ]),
      ),
    );
  }
}

/// Small helper used on Home and Stats.
Color catColor(Tag t) => pastel(t.color).fg;
