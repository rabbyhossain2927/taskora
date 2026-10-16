import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_detail.dart';
import 'project_editor.dart';
import 'todo_editor.dart';

/// Mark a project done (or open again) and tell the user, with Undo.
void setProjectDone(BuildContext context, Project p, bool done) {
  final s = context.read<Store>();
  final before = Project.fromMap(p.id, p.toMap());
  p.done = done;
  if (done) {
    p.status = 'complete';
  } else if (p.status == 'complete') {
    p.status = s.statuses.firstWhere((t) => t.key != 'complete', orElse: () => s.statuses.first).key;
  }
  s.saveProject(p);
  HapticFeedback.lightImpact();
  showUndo(context, done ? '“${p.title}” completed 🎉' : '“${p.title}” is open again', () => s.saveProject(before));
}

Future<void> deleteProject(BuildContext context, Project p) async {
  final s = context.read<Store>();
  final m = ScaffoldMessenger.of(context);
  final undo = await s.deleteDocs('projects', [p.id]);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text('“${p.title}” deleted'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
}

Future<void> pickProjectStatus(BuildContext context, Project p) async {
  final s = context.read<Store>();
  final v = await pickOne<String>(context, title: 'Status', current: p.status, options: [for (final t in s.statuses) (t.key, t.label)]);
  if (v == null) return;
  p.status = v;
  p.done = v == 'complete';
  s.saveProject(p);
}

Future<void> pickProjectPriority(BuildContext context, Project p) async {
  final v = await pickOne<int>(context, title: 'Priority', current: p.priority, options: [for (var i = 1; i <= 5; i++) (i, priorityName(i))]);
  if (v == null || !context.mounted) return;
  p.priority = v;
  context.read<Store>().saveProject(p);
}

Future<void> pickProjectCategory(BuildContext context, Project p) async {
  final s = context.read<Store>();
  final v = await pickOne<String>(context, title: 'Category', current: p.category, options: [for (final t in s.projectCats) (t.key, t.label)]);
  if (v == null) return;
  p.category = v;
  s.saveProject(p);
}

/// Long-press menu for a project (also the ⋯ menu on the project page).
void showProjectActions(BuildContext context, Project p, {bool fromDetail = false}) {
  HapticFeedback.mediumImpact();
  showActions(context, title: p.title, subtitle: p.done ? 'Completed' : null, items: [
    ActionItem(p.done ? Icons.replay_rounded : Icons.task_alt_rounded, p.done ? 'Mark as not done' : 'Mark as complete', () => setProjectDone(context, p, !p.done)),
    ActionItem(Icons.edit_outlined, 'Edit project', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectEditor(id: p.id)))),
    ActionItem(Icons.add_task_rounded, 'Add a task', () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(projectId: p.id), fullscreenDialog: true))),
    ActionItem(Icons.flag_outlined, 'Change status', () => pickProjectStatus(context, p)),
    ActionItem(Icons.low_priority_rounded, 'Change priority', () => pickProjectPriority(context, p)),
    ActionItem(Icons.category_outlined, 'Change category', () => pickProjectCategory(context, p)),
    if (!fromDetail) ActionItem(Icons.open_in_new_rounded, 'Open', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id)))),
    ActionItem(Icons.delete_outline_rounded, 'Delete', () {
      if (fromDetail) Navigator.maybePop(context);
      deleteProject(context, p);
    }, danger: true),
  ]);
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool board = false;
  bool showDone = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final active = s.projects.where((p) => !p.done).toList();
    final done = s.projects.where((p) => p.done).toList();
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MainHeader('Projects', subtitle: '${active.length} active · ${done.length} completed', actions: [
          RoundButton(icon: board ? Icons.view_agenda_outlined : Icons.view_kanban_outlined, tooltip: board ? 'List view' : 'Board view', onTap: () => setState(() => board = !board)),
        ]),
        Expanded(
          child: SyncRefresh(
            child: s.projects.isEmpty && s.loaded
                ? ListView(children: const [EmptyState(icon: Icons.work_outline, title: 'No projects yet', body: 'Tap + and choose Project. You can split it into to-dos as you create it.')])
                : board
                    ? _Board(store: s)
                    : SlidableAutoCloseBehavior(
                        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
                          if (active.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, left: 4),
                              child: Text('Swipe right to complete · hold for options', style: TextStyle(fontSize: 11.5, color: context.mutedText)),
                            ),
                          for (var i = 0; i < active.length; i++)
                            FadeIn(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _SwipeProject(p: active[i]))),
                          if (done.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => showDone = !showDone),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                child: Row(children: [
                                  AnimatedRotation(turns: showDone ? 0.25 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.chevron_right_rounded, color: context.mutedText)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.task_alt_rounded, size: 18, color: C.green),
                                  const SizedBox(width: 8),
                                  Text('Completed · ${done.length}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                ]),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: showDone
                                  ? Column(children: [
                                      for (final p in done) Padding(padding: const EdgeInsets.only(bottom: 10), child: Opacity(opacity: 0.72, child: _SwipeProject(p: p))),
                                    ])
                                  : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ]),
                      ),
          ),
        ),
      ]),
    );
  }
}

/// Swipe right → complete (or reopen). Swipe left → delete. Hold → menu.
class _SwipeProject extends StatelessWidget {
  final Project p;
  const _SwipeProject({required this.p});
  @override
  Widget build(BuildContext context) => Slidable(
        key: ValueKey('swipe-${p.id}-${p.done}'),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.32,
          dismissible: DismissiblePane(
            dismissThreshold: 0.45,
            closeOnCancel: true,
            confirmDismiss: () async {
              setProjectDone(context, p, !p.done);
              return false; // keep the card; it moves to the right group
            },
            onDismissed: () {},
          ),
          children: [
            SlidableAction(
              onPressed: (_) => setProjectDone(context, p, !p.done),
              backgroundColor: p.done ? const Color(0xFF8A8A99) : C.green,
              foregroundColor: Colors.white,
              icon: p.done ? Icons.replay_rounded : Icons.task_alt_rounded,
              label: p.done ? 'Reopen' : 'Complete',
              borderRadius: BorderRadius.circular(22),
            ),
          ],
        ),
        endActionPane: ActionPane(motion: const BehindMotion(), extentRatio: 0.28, children: [
          SlidableAction(
            onPressed: (_) => deleteProject(context, p),
            backgroundColor: C.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(22),
          ),
        ]),
        child: ProjectCard(p: p),
      );
}

class _Board extends StatelessWidget {
  final Store store;
  const _Board({required this.store});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.78;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 110),
      children: [
        for (final st in store.statuses)
          Builder(builder: (context) {
            final items = store.projects.where((p) => p.status == st.key).toList();
            return Container(
              width: width,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.isDark ? Colors.white10 : C.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                  child: Row(children: [
                    TagChip(st, small: true),
                    const Spacer(),
                    Text('${items.length}', style: TextStyle(fontWeight: FontWeight.w700, color: context.mutedText)),
                  ]),
                ),
                Expanded(
                  child: ListView(children: [
                    for (final p in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: ProjectCard(p: p)),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text('Hold a project and choose\n“Change status” to move it here', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, fontSize: 12.5)),
                      ),
                  ]),
                ),
              ]),
            );
          }),
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
    final showMoney = context.watch<Prefs>().showMoney;
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
        onLongPress: () => showProjectActions(context, p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (p.cover != null)
            SizedBox(
              height: 92,
              child: Image.network(p.cover!.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c.bg)),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconTile(icon: p.icon, color: p.color, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, decoration: p.done ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 2),
                    Text(s.status(p.status).label, style: TextStyle(fontSize: 12, color: pastel(s.status(p.status).color).fg, fontWeight: FontWeight.w600)),
                  ]),
                ),
                PriorityBadge(p.priority),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                TagChip(s.projectCat(p.category), small: true),
                if (showMoney && p.amount != null && p.amount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(fmtMoney(p.net, p.currency), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.green)),
                  ),
                if (p.files.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.attach_file_rounded, size: 12, color: context.onTint),
                      Text('${p.files.length}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.onTint)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pr),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 6, color: c.fg, backgroundColor: c.bg)),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text('${tasks.where((t) => t.done).length}/${tasks.length} tasks', style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w500)),
                const Spacer(),
                if (p.deadline != null) ...[
                  Icon(Icons.event_outlined, size: 13, color: context.mutedText),
                  const SizedBox(width: 3),
                  Text(dShort.format(p.deadline!), style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w500)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
