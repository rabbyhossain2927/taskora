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
  m.showSnackBar(SnackBar(content: Text('“${p.title}” moved to Trash'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
}

Future<void> archiveProject(BuildContext context, Project p) async {
  final s = context.read<Store>();
  await s.archive('projects', [p.id]);
  if (context.mounted) showUndo(context, '“${p.title}” archived', () => s.archive('projects', [p.id], false));
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
    ActionItem(Icons.archive_outlined, 'Archive', () {
      if (fromDetail) Navigator.maybePop(context);
      archiveProject(context, p);
    }),
    ActionItem(Icons.delete_outline_rounded, 'Move to Trash', () {
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
  bool showDone = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    final view = prefs.projectView;
    final board = view == 'board';
    final grid = view == 'grid';
    Widget cards(List<Project> list, {bool faded = false}) => grid
        ? LayoutBuilder(builder: (context, c) {
            final n = (c.maxWidth / 230).floor().clamp(2, 6);
            final w = (c.maxWidth - 12 * (n - 1)) / n;
            return GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              // square cover + info card below it
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: w + ProjectTile.infoHeight),
              itemCount: list.length,
              itemBuilder: (_, i) => FadeIn(index: i, child: Opacity(opacity: faded ? 0.72 : 1, child: ProjectTile(p: list[i]))),
            );
          })
        : Column(children: [
            for (var i = 0; i < list.length; i++) FadeIn(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Opacity(opacity: faded ? 0.72 : 1, child: _SwipeProject(p: list[i])))),
          ]);
    final active = s.projects.where((p) => !p.done).toList();
    final done = s.projects.where((p) => p.done).toList();
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MainHeader('Projects', subtitle: '${active.length} active · ${done.length} completed', actions: [
          RoundButton(
            icon: switch (view) { 'grid' => Icons.view_agenda_outlined, 'list' => Icons.view_kanban_outlined, _ => Icons.grid_view_rounded },
            tooltip: switch (view) { 'grid' => 'List view', 'list' => 'Board view', _ => 'Grid view' },
            onTap: () => prefs.projectView = switch (view) { 'grid' => 'list', 'list' => 'board', _ => 'grid' },
          ),
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
                              child: Text(grid ? 'Tap to open · hold for options' : 'Swipe right to complete · hold for options', style: TextStyle(fontSize: 11.5, color: context.mutedText)),
                            ),
                          cards(active),
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
                              child: showDone ? cards(done, faded: true) : const SizedBox(width: double.infinity),
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
            label: 'Trash',
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
    final screen = MediaQuery.of(context).size.width;
    final width = screen >= 700 ? 300.0 : screen * 0.78;
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
        onSecondaryTap: () => showProjectActions(context, p), // right-click on computers
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
                  Text(fmtDue(p.deadline!), style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w500)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Grid card: a square (1:1) cover on top, the project's details below it.
class ProjectTile extends StatelessWidget {
  final Project p;
  const ProjectTile({super.key, required this.p});
  static const infoHeight = 138.0;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final c = pastel(p.color);
    final pr = s.progressOf(p.id);
    final tasks = s.todosOf(p.id);
    final st = s.status(p.status);
    final cat = s.projectCat(p.category);
    final cover = p.cover;
    final showMoney = context.watch<Prefs>().showMoney;
    // Days until the deadline
    final now = DateTime.now();
    final days = p.deadline == null ? null : DateTime(p.deadline!.year, p.deadline!.month, p.deadline!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final dueText = days == null
        ? ''
        : p.done
            ? 'done'
            : days < 0
                ? '${-days}d late'
                : days == 0
                    ? 'today'
                    : days == 1
                        ? 'tomorrow'
                        : '${days}d left';
    final dueColor = days != null && !p.done && days < 0 ? C.red : (days != null && !p.done && days <= 2 ? const Color(0xFFD48806) : context.mutedText);
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
        onLongPress: () => showProjectActions(context, p),
        onSecondaryTap: () => showProjectActions(context, p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              if (cover != null)
                Image.network(cover.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c.bg))
              else
                Container(
                  color: context.isDark ? c.fg.withOpacity(0.22) : c.bg,
                  child: Center(child: Icon(iconOf(p.icon), size: 54, color: context.isDark ? Colors.white70 : c.fg.withOpacity(0.55))),
                ),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: Row(children: [
                  if (cover != null)
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(10)),
                      child: Icon(iconOf(p.icon), size: 16, color: c.fg),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: priorityColor(p.priority), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(st.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pastel(st.color).fg)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          SizedBox(
            height: infoHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, decoration: p.done ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 5),
                // category + priority
                Row(children: [
                  Icon(iconOf(cat.icon), size: 12, color: pastel(cat.color).fg),
                  const SizedBox(width: 4),
                  Flexible(child: Text(cat.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pastel(cat.color).fg))),
                  const SizedBox(width: 8),
                  Icon(Icons.flag_rounded, size: 12, color: priorityColor(p.priority)),
                  const SizedBox(width: 2),
                  Text(priorityName(p.priority), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.mutedText)),
                ]),
                const Spacer(),
                // progress
                Row(children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pr),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 5, color: c.fg, backgroundColor: c.bg)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${(pr * 100).round()}%', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.fg)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 11, color: context.mutedText),
                  const SizedBox(width: 3),
                  Text('${tasks.where((t) => t.done).length}/${tasks.length}', style: TextStyle(fontSize: 11, color: context.mutedText, fontWeight: FontWeight.w600)),
                  if (p.files.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.attach_file_rounded, size: 11, color: context.mutedText),
                    Text('${p.files.length}', style: TextStyle(fontSize: 11, color: context.mutedText, fontWeight: FontWeight.w600)),
                  ],
                  const Spacer(),
                  if (showMoney && (p.amount ?? 0) > 0)
                    Flexible(child: Text(fmtMoney(p.net, p.currency), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.green))),
                ]),
                const SizedBox(height: 4),
                // deadline with days left
                Row(children: [
                  Icon(Icons.event_outlined, size: 11, color: dueColor),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      p.deadline == null ? 'No deadline' : '${fmtDue(p.deadline!)} · $dueText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: dueColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
