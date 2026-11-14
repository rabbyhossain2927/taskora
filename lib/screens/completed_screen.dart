import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';
import 'project_detail.dart';
import 'projects_screen.dart';
import 'todos_screen.dart';

/// Finished projects and to-dos live here (they leave Projects and To-do).
/// Tap Reopen to bring one back.
class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});
  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _Item {
  final Project? p;
  final Todo? t;
  final DateTime when;
  _Item({this.p, this.t, required this.when});
  String get title => p?.title ?? t!.title;
}

class _CompletedScreenState extends State<CompletedScreen> {
  String show = 'all'; // all | projects | todos
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final muted = context.mutedText;
    final projects = s.projects.where((p) => p.done).toList();
    final todos = s.todos.where((t) => t.done).toList();
    final items = <_Item>[
      if (show != 'todos') for (final p in projects) _Item(p: p, when: p.completedAt ?? p.deadline ?? p.createdAt),
      if (show != 'projects') for (final t in todos) _Item(t: t, when: t.completedAt ?? t.createdAt),
    ].where((i) => q.isEmpty || i.title.toLowerCase().contains(q)).toList()
      ..sort((a, b) => b.when.compareTo(a.when));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));
    final groups = <(String, List<_Item>)>[
      ('Today', items.where((i) => !i.when.isBefore(today)).toList()),
      ('This week', items.where((i) => i.when.isBefore(today) && !i.when.isBefore(weekAgo)).toList()),
      ('Earlier', items.where((i) => i.when.isBefore(weekAgo)).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();

    String sub(_Item i) {
      if (i.p != null) {
        final tasks = s.todosOf(i.p!.id);
        return 'Project · ${tasks.where((t) => t.done).length}/${tasks.length} tasks${(i.p!.amount ?? 0) > 0 ? ' · ${fmtMoney(i.p!.net, i.p!.currency)}' : ''}';
      }
      final proj = s.projects.where((p) => p.id == i.t!.projectId).firstOrNull;
      return 'To-do${proj == null ? '' : ' · ${proj.title}'}';
    }

    void reopen(_Item i) {
      if (i.p != null) {
        setProjectDone(context, i.p!, false);
      } else {
        s.toggleTodo(i.t!);
        showUndo(context, '“${i.t!.title}” is open again', () => s.toggleTodo(i.t!));
      }
    }

    Widget row(_Item i, bool last) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => i.p != null ? Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: i.p!.id))) : showTodoActions(context, i.t!),
            hoverColor: context.hoverTint,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
              decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.05) : deskLine))),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: Color(0xFF2FA36B), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, decoration: TextDecoration.lineThrough, decorationColor: muted.withOpacity(0.6))),
                    Text('${sub(i)} · ${fmtStamp(i.when)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
                  ]),
                ),
                TextButton(onPressed: () => reopen(i), child: const Text('Reopen')),
              ]),
            ),
          ),
        );

    Widget chip(String key, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DeskFilter(label, on: show == key, onTap: () => setState(() => show = key)),
        );

    final body = <Widget>[
      Wrap(children: [chip('all', 'All · ${projects.length + todos.length}'), chip('projects', 'Projects · ${projects.length}'), chip('todos', 'To-dos · ${todos.length}')]),
      const SizedBox(height: 12),
      TextField(
        onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
        decoration: const InputDecoration(hintText: 'Search completed', prefixIcon: Icon(Icons.search_rounded)),
      ),
      const SizedBox(height: 14),
      if (groups.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(q.isEmpty ? 'Nothing completed yet. Finished projects and to-dos show up here.' : 'No match.', textAlign: TextAlign.center, style: TextStyle(color: muted)))),
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Text('${g.$1} · ${g.$2.length}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: g.$1 == 'Today' ? const Color(0xFF1E7A50) : muted)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: softCard(18, context.surface),
          child: Column(children: [for (var k = 0; k < g.$2.length; k++) row(g.$2[k], k == g.$2.length - 1)]),
        ),
        const SizedBox(height: 14),
      ],
    ];

    if (deskWide(context)) {
      return DeskScroll(children: [
        DeskHead('Completed', subtitle: '${projects.length} projects · ${todos.length} to-dos done · they no longer show on Projects or To-do'),
        const SizedBox(height: 16),
        ...body,
      ]);
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Completed'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body)),
        ]),
      ),
    );
  }
}
