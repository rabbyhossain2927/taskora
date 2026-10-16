import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_detail.dart';

/// Trello-style board: one column per status. Long-press a card to move it.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool board = true;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(children: [
            const Expanded(child: Text('Projects', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
            SizedBox(
              width: 150,
              child: Segmented<bool>(items: const [(true, 'Board'), (false, 'List')], value: board, onChanged: (v) => setState(() => board = v)),
            ),
          ]),
        ),
        Expanded(
          child: SyncRefresh(
            child: s.projects.isEmpty && s.loaded
                ? ListView(children: const [EmptyState(icon: Icons.work_outline, title: 'No projects yet', body: 'Tap + and choose Project. You can split it into to-dos as you create it.')])
                : board
                    ? _Board(store: s)
                    : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), children: [
                        for (final p in s.projects) Padding(padding: const EdgeInsets.only(bottom: 10), child: ProjectCard(p: p)),
                      ]),
          ),
        ),
      ]),
    );
  }
}

class _Board extends StatelessWidget {
  final Store store;
  const _Board({required this.store});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.78;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 110),
      children: [
        for (final st in store.statuses)
          DragTarget<String>(
            onAcceptWithDetails: (d) {
              final p = store.project(d.data);
              if (p == null) return;
              p.status = st.key;
              p.done = st.key == 'complete';
              store.saveProject(p);
            },
            builder: (context, cand, _) {
              final items = store.projects.where((p) => p.status == st.key).toList();
              final c = pastel(st.color);
              return Container(
                width: width,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cand.isNotEmpty ? c.bg : (context.isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1EEF8)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                    child: Row(children: [
                      TagChip(st, small: true),
                      const Spacer(),
                      Text('${items.length}', style: TextStyle(fontWeight: FontWeight.w800, color: context.mutedText)),
                    ]),
                  ),
                  Expanded(
                    child: ListView(children: [
                      for (final p in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LongPressDraggable<String>(
                            data: p.id,
                            feedback: Material(color: Colors.transparent, child: SizedBox(width: width - 20, child: Opacity(opacity: 0.9, child: ProjectCard(p: p)))),
                            childWhenDragging: Opacity(opacity: 0.3, child: ProjectCard(p: p)),
                            child: ProjectCard(p: p),
                          ),
                        ),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text('Drop a project here', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText)),
                        ),
                    ]),
                  ),
                ]),
              );
            },
          ),
      ],
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Project p;
  const ProjectCard({super.key, required this.p});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final c = pastel(p.color);
    final pr = s.progressOf(p.id);
    final tasks = s.todosOf(p.id);
    return Box(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTile(icon: p.icon, color: p.color, size: 38),
          const SizedBox(width: 10),
          Expanded(child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          Icon(Icons.flag_rounded, size: 16, color: priorityColor(p.priority)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TagChip(s.projectCat(p.category), small: true),
          if (p.amount != null && p.amount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(12)),
              child: Text(fmtMoney(p.net, p.currency), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.green)),
            ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pr, minHeight: 6, color: c.fg, backgroundColor: c.bg)),
        const SizedBox(height: 6),
        Row(children: [
          Text('${tasks.where((t) => t.done).length}/${tasks.length} tasks', style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (p.deadline != null) ...[
            Icon(Icons.event_outlined, size: 13, color: context.mutedText),
            const SizedBox(width: 3),
            Text(dShort.format(p.deadline!), style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w600)),
          ],
        ]),
      ]),
    );
  }
}
