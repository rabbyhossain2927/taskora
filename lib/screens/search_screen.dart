import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'note_editor.dart';
import 'project_detail.dart';
import 'todo_editor.dart';

/// Search everything: projects, to-dos (and their sub-tasks), notes (all tabs).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  String scope = 'all';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final w = q.toLowerCase();
    bool has(String x) => x.toLowerCase().contains(w);
    final List<Project> projects = w.isEmpty || scope == 'todos' || scope == 'notes'
        ? const <Project>[]
        : s.projects.where((p) => has(p.title) || has(p.description) || has(s.projectCat(p.category).label) || has(s.status(p.status).label)).toList();
    final List<Todo> todos = w.isEmpty || scope == 'projects' || scope == 'notes'
        ? const <Todo>[]
        : s.todos.where((t) => has(t.title) || has(t.notes) || t.subtasks.any((x) => has(x.title)) || has(s.todoCat(t.category).label)).toList();
    final List<Note> notes = w.isEmpty || scope == 'projects' || scope == 'todos'
        ? const <Note>[]
        : s.notes.where((n) => has(n.title) || has(n.allText) || n.tags.any(has)).toList();
    final count = projects.length + todos.length + notes.length;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Row(children: [
              RoundButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Back', onTap: () => Navigator.maybePop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => q = v.trim()),
                  decoration: const InputDecoration(hintText: 'Search everything', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), children: [
              for (final o in const [('all', 'All'), ('projects', 'Projects'), ('todos', 'To-dos'), ('notes', 'Notes')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(o.$2), selected: scope == o.$1, onSelected: (_) => setState(() => scope = o.$1)),
                ),
            ]),
          ),
          Expanded(
            child: w.isEmpty
                ? const EmptyState(icon: Icons.manage_search_rounded, title: 'Find anything', body: 'Type a word from a project, to-do, sub-task, note or tag.')
                : count == 0
                    ? EmptyState(icon: Icons.search_off_rounded, title: 'No results', body: 'Nothing matches “$q”.')
                    : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
                        if (projects.isNotEmpty) Label('Projects · ${projects.length}'),
                        for (final p in projects)
                          _Result(
                            icon: iconOf(p.icon),
                            color: p.color,
                            title: p.title,
                            sub: '${s.status(p.status).label} · ${s.projectCat(p.category).label}',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
                          ),
                        if (todos.isNotEmpty) Label('To-dos · ${todos.length}'),
                        for (final t in todos)
                          _Result(
                            icon: t.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: s.todoCat(t.category).color,
                            title: t.title,
                            sub: [s.todoCat(t.category).label, if (t.deadline != null) dShort.format(t.deadline!), if (t.subtasks.isNotEmpty) '${t.subtasks.length} sub-tasks'].join(' · '),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(id: t.id))),
                          ),
                        if (notes.isNotEmpty) Label('Notes · ${notes.length}'),
                        for (final n in notes)
                          _Result(
                            icon: iconOf(n.icon),
                            color: 6,
                            title: n.title.isEmpty ? 'Untitled' : n.title,
                            sub: n.preview.isEmpty ? dShort.format(n.updatedAt) : n.preview,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(id: n.id))),
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final IconData icon;
  final int color;
  final String title, sub;
  final VoidCallback onTap;
  const _Result({required this.icon, required this.color, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        radius: 18,
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 18, color: p.fg)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.mutedText)),
            ]),
          ),
        ]),
      ),
    );
  }
}
