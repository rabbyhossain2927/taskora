import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_editor.dart';
import 'todo_editor.dart';
import 'todos_screen.dart';

class ProjectDetail extends StatelessWidget {
  final String id;
  const ProjectDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final p = s.project(id);
    if (p == null) {
      return Scaffold(body: SafeArea(child: Column(children: const [Header('Project'), EmptyState(icon: Icons.delete_outline, title: 'Project removed', body: 'This project was deleted.')])));
    }
    final c = pastel(p.color);
    final tasks = s.todosOf(p.id);
    final done = tasks.where((t) => t.done).length;
    final pr = s.progressOf(p.id);

    Widget cell(String label, Widget value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.mutedText, letterSpacing: 0.4)),
              const SizedBox(height: 6),
              value,
            ]),
          ),
        );
    Text v(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SyncRefresh(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            Header('', actions: [
              RoundButton(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectEditor(id: p.id)))),
              RoundButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete project?'),
                      content: Text('This also deletes its ${tasks.length} to-dos. You can undo right after.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  final m = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final undo = await s.deleteDocs('projects', [p.id]);
                  m.showSnackBar(SnackBar(content: const Text('Project deleted'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
                },
              ),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(28)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(18)), child: Icon(iconOf(p.icon), color: c.fg, size: 27)),
                      const Spacer(),
                      if (p.done) const Chip(label: Text('Done'), avatar: Icon(Icons.check_rounded, size: 16)),
                    ]),
                    const SizedBox(height: 12),
                    Text(p.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink)),
                    if (p.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(p.description, style: const TextStyle(color: Color(0xFF3F3F4A), height: 1.5))),
                    const SizedBox(height: 14),
                    ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: pr, minHeight: 8, color: c.fg, backgroundColor: Colors.white70)),
                    const SizedBox(height: 6),
                    Text('${(pr * 100).round()}% · $done of ${tasks.length} tasks done', style: TextStyle(color: c.fg, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  cell('STATUS', TagChip(s.status(p.status), small: true)),
                  const SizedBox(width: 10),
                  cell('CATEGORY', TagChip(s.projectCat(p.category), small: true)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  cell('START', v(p.start == null ? '—' : dShort.format(p.start!))),
                  const SizedBox(width: 10),
                  cell('DEADLINE', v(p.deadline == null ? '—' : dShort.format(p.deadline!))),
                  const SizedBox(width: 10),
                  cell('PRIORITY', Row(children: [Icon(Icons.flag_rounded, size: 16, color: priorityColor(p.priority)), const SizedBox(width: 4), v('P${p.priority}')])),
                ]),
                if (p.reminder != null) ...[
                  const SizedBox(height: 10),
                  Box(padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.alarm, size: 20), const SizedBox(width: 10), Text('Reminder · ${dTime.format(p.reminder!)}', style: const TextStyle(fontWeight: FontWeight.w700))])),
                ],
                if ((p.amount ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  Box(
                    child: Row(children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.payments_outlined, color: C.green)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.platform.name[0].toUpperCase()}${p.platform.name.substring(1)} · ${fmtMoney(p.amount!, p.currency)}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('− ${fmtMoney(p.fee, p.currency)} fee', style: const TextStyle(color: C.red, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('You receive', style: TextStyle(fontSize: 12, color: context.mutedText)),
                        Text(fmtMoney(p.net, p.currency), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.green)),
                      ]),
                    ]),
                  ),
                ],
                Label('Tasks', trailing: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(projectId: p.id), fullscreenDialog: true)),
                  child: Text('+ Add task', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                )),
                if (tasks.isEmpty)
                  Box(child: Text('No tasks yet. Split this project into small steps — they also show in To-do.', style: TextStyle(color: context.mutedText, height: 1.5)))
                else
                  Box(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in tasks) TodoRow(todo: t)])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
