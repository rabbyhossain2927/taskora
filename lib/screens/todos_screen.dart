import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'todo_editor.dart';

/// One to-do line: checkbox, title, sub-task count, date, priority flag.
/// Swipe left for Delete.
class TodoRow extends StatelessWidget {
  final Todo todo;
  final bool dense;
  const TodoRow({super.key, required this.todo, this.dense = false});
  @override
  Widget build(BuildContext context) {
    final s = context.read<Store>();
    final t = todo;
    final cat = s.todoCat(t.category);
    final proj = s.project(t.projectId);
    final now = DateTime.now();
    final overdue = !t.done && t.deadline != null && t.deadline!.isBefore(DateTime(now.year, now.month, now.day));
    final subDone = t.subtasks.where((x) => x.done).length;
    return Slidable(
      key: ValueKey(t.id),
      endActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.28, children: [
        SlidableAction(
          onPressed: (_) async {
            final undo = await s.deleteDocs('todos', [t.id]);
            if (context.mounted) showUndo(context, 'To-do deleted', undo);
          },
          backgroundColor: C.red,
          foregroundColor: Colors.white,
          icon: Icons.delete_outline,
          label: 'Delete',
        ),
      ]),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(id: t.id))),
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, dense ? 2 : 6, 16, dense ? 2 : 6),
          child: Row(children: [
            CheckDot(value: t.done, color: priorityColor(t.priority), onTap: () => s.toggleTodo(t)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title.isEmpty ? 'Untitled' : t.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? context.mutedText : null)),
                const SizedBox(height: 3),
                Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (t.deadline != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_outlined, size: 13, color: overdue ? C.red : context.mutedText),
                      const SizedBox(width: 3),
                      Text(dShort.format(t.deadline!), style: TextStyle(fontSize: 12, color: overdue ? C.red : context.mutedText, fontWeight: FontWeight.w600)),
                    ]),
                  if (t.subtasks.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_tree_outlined, size: 13, color: context.mutedText),
                      const SizedBox(width: 3),
                      Text('$subDone/${t.subtasks.length}', style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w600)),
                    ]),
                  if (t.reminder != null) Icon(Icons.alarm, size: 13, color: context.mutedText),
                  if (proj != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(iconOf(proj.icon), size: 13, color: pastel(proj.color).fg),
                      const SizedBox(width: 3),
                      Text(proj.title, style: TextStyle(fontSize: 12, color: pastel(proj.color).fg, fontWeight: FontWeight.w700)),
                    ]),
                ]),
              ]),
            ),
            if (!dense) TagChip(cat, small: true),
          ]),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    var list = s.todos.where((t) => cat == null || t.category == cat).toList();
    final open = list.where((t) => !t.done).toList();
    final groups = <String, List<Todo>>{
      'Overdue': open.where((t) => t.deadline != null && t.deadline!.isBefore(today)).toList(),
      'Today': open.where((t) => t.deadline != null && !t.deadline!.isBefore(today) && t.deadline!.isBefore(tomorrow)).toList(),
      'Upcoming': open.where((t) => t.deadline != null && !t.deadline!.isBefore(tomorrow)).toList(),
      'No date': open.where((t) => t.deadline == null).toList(),
      if (prefs.showCompleted) 'Completed': list.where((t) => t.done).toList(),
    };

    return SafeArea(
      bottom: false,
      child: SyncRefresh(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(children: [
                const Expanded(child: Text('To-do', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
                Text('${open.length} open', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TagChip(const Tag('all', 'All', 19, 'all_inclusive'), selected: cat == null, onTap: () => setState(() => cat = null)),
                ),
                for (final c in s.todoCats)
                  Padding(padding: const EdgeInsets.only(right: 8), child: TagChip(c, selected: cat == c.key, onTap: () => setState(() => cat = c.key))),
              ]),
            ),
          ),
          if (s.todos.isEmpty && s.loaded)
            const SliverToBoxAdapter(child: EmptyState(icon: Icons.check_circle_outline, title: 'No to-dos yet', body: 'Tap + to add one. Big job? Add sub-tasks inside it.')),
          for (final g in groups.entries)
            if (g.value.isNotEmpty) ...[
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Label('${g.key} · ${g.value.length}'))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Box(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in g.value) TodoRow(todo: t)])),
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ]),
      ),
    );
  }
}
