import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/file_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_editor.dart';
import 'projects_screen.dart';
import 'todo_editor.dart';
import 'todos_screen.dart';

class ProjectDetail extends StatefulWidget {
  final String id;
  const ProjectDetail({super.key, required this.id});
  @override
  State<ProjectDetail> createState() => _ProjectDetailState();
}

class _ProjectDetailState extends State<ProjectDetail> {
  bool uploading = false;

  Future<void> _pickDate(Project p, {required bool start}) async {
    final now = DateTime.now();
    final init = (start ? p.start : p.deadline) ?? now;
    final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 10));
    if (d == null || !mounted) return;
    if (start) {
      p.start = d;
    } else {
      p.deadline = d;
    }
    context.read<Store>().saveProject(p);
  }

  Future<void> _pickReminder(Project p) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: p.reminder ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 5));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    p.reminder = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0);
    if (mounted) context.read<Store>().saveProject(p);
  }

  Future<void> _upload(Project p, {bool cover = false}) async {
    setState(() => uploading = true);
    try {
      final a = await FileService.pickAndUpload(imagesOnly: cover);
      if (a == null) return;
      if (cover) {
        p.cover = a;
      } else {
        p.files.add(a);
      }
      if (mounted) {
        context.read<Store>().saveProject(p);
        toast(context, cover ? 'Cover photo added' : '${a.name} uploaded');
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _removeFile(Project p, Attachment a) {
    final s = context.read<Store>();
    p.files.removeWhere((f) => f.id == a.id);
    s.saveProject(p);
    showUndo(context, '${a.name} removed', () async {
      p.files.add(a);
      await s.saveProject(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final p = s.project(widget.id);
    if (p == null) {
      return Scaffold(body: SafeArea(child: Column(children: const [Header('Project'), EmptyState(icon: Icons.delete_outline, title: 'Project removed', body: 'This project was deleted.')])));
    }
    final c = pastel(p.color);
    final tasks = s.todosOf(p.id);
    final done = tasks.where((t) => t.done).length;
    final pr = s.progressOf(p.id);
    final st = s.status(p.status), cat = s.projectCat(p.category);

    Widget cell(String label, Widget value, VoidCallback onTap) => Expanded(
          child: Material(
            color: context.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.mutedText))),
                    Icon(Icons.expand_more_rounded, size: 16, color: context.mutedText),
                  ]),
                  const SizedBox(height: 6),
                  value,
                ]),
              ),
            ),
          ),
        );
    Text v(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5));

    return Scaffold(
      body: SafeArea(
        child: SyncRefresh(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            Header('', actions: [
              RoundButton(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectEditor(id: p.id)))),
              RoundButton(icon: Icons.more_horiz_rounded, tooltip: 'More', onTap: () => showProjectActions(context, p, fromDetail: true)),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ---------- cover + title ----------
                FadeIn(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: context.isDark ? c.fg.withOpacity(0.25) : c.bg, borderRadius: BorderRadius.circular(26)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GestureDetector(
                        onTap: uploading ? null : () => _upload(p, cover: true),
                        child: p.cover != null
                            ? Stack(children: [
                                SizedBox(height: 150, width: double.infinity, child: Image.network(p.cover!.url, fit: BoxFit.cover)),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Material(
                                    color: Colors.black38,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Remove cover',
                                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                      onPressed: () {
                                        p.cover = null;
                                        s.saveProject(p);
                                      },
                                    ),
                                  ),
                                ),
                              ])
                            : Container(
                                height: 46,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Row(children: [
                                  Icon(uploading ? Icons.hourglass_top_rounded : Icons.add_photo_alternate_outlined, size: 18, color: c.fg),
                                  const SizedBox(width: 8),
                                  Text(uploading ? 'Uploading…' : 'Add cover photo', style: TextStyle(color: c.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                                ]),
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(18, p.cover != null ? 16 : 0, 18, 18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16)), child: Icon(iconOf(p.icon), color: c.fg, size: 25)),
                            const Spacer(),
                            ActionChip(
                              avatar: Icon(p.done ? Icons.replay_rounded : Icons.task_alt_rounded, size: 16, color: p.done ? null : C.green),
                              label: Text(p.done ? 'Reopen' : 'Mark complete'),
                              onPressed: () => setProjectDone(context, p, !p.done),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(p.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.isDark ? Colors.white : C.ink)),
                          if (p.description.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(p.description, style: TextStyle(color: context.isDark ? Colors.white70 : const Color(0xFF3F3F4A), height: 1.5))),
                          const SizedBox(height: 14),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: pr),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (_, val, __) => ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: val, minHeight: 8, color: c.fg, backgroundColor: Colors.white70)),
                          ),
                          const SizedBox(height: 6),
                          Text('${(pr * 100).round()}% · $done of ${tasks.length} tasks done', style: TextStyle(color: context.isDark ? Colors.white70 : c.fg, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),

                // ---------- tappable details ----------
                FadeIn(
                  index: 1,
                  child: Column(children: [
                    Row(children: [
                      cell('Status', TagChip(st, small: true), () => pickProjectStatus(context, p)),
                      const SizedBox(width: 10),
                      cell('Category', TagChip(cat, small: true), () => pickProjectCategory(context, p)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      cell('Start', v(p.start == null ? 'Set' : dShort.format(p.start!)), () => _pickDate(p, start: true)),
                      const SizedBox(width: 10),
                      cell('Deadline', v(p.deadline == null ? 'Set' : dShort.format(p.deadline!)), () => _pickDate(p, start: false)),
                      const SizedBox(width: 10),
                      cell('Priority', PriorityBadge(p.priority, showNone: true), () => pickProjectPriority(context, p)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      cell('Reminder', v(p.reminder == null ? 'Add reminder' : dTime.format(p.reminder!)), () => _pickReminder(p)),
                      const SizedBox(width: 10),
                      cell('Assigned', const Row(children: [SoonPill()]), () => toast(context, 'Teammates are coming soon')),
                    ]),
                  ]),
                ),

                // ---------- money ----------
                if ((p.amount ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  FadeIn(
                    index: 2,
                    child: Box(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectEditor(id: p.id))),
                      child: Row(children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.payments_outlined, color: C.green)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${p.platform.name[0].toUpperCase()}${p.platform.name.substring(1)} · ${fmtMoney(p.amount!, p.currency)}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w500, fontSize: 13)),
                            Text('− ${fmtMoney(p.fee, p.currency)} fee', style: const TextStyle(color: C.red, fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('You receive', style: TextStyle(fontSize: 12, color: context.mutedText)),
                          Text(fmtMoney(p.net, p.currency), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.green)),
                        ]),
                      ]),
                    ),
                  ),
                ],

                // ---------- tasks ----------
                Label('Tasks · ${tasks.length}',
                    trailing: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(projectId: p.id), fullscreenDialog: true)),
                      child: Text('+ Add task', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                    )),
                if (tasks.isEmpty)
                  Box(padding: const EdgeInsets.all(16), child: Text('No tasks yet. Split this project into small steps — they also show in To-do.', style: TextStyle(color: context.mutedText, height: 1.5)))
                else
                  Box(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: Column(children: [for (final t in tasks) TodoRow(todo: t)])),

                // ---------- files ----------
                Label('Files · ${p.files.length}',
                    trailing: GestureDetector(
                      onTap: uploading ? null : () => _upload(p),
                      child: Text(uploading ? 'Uploading…' : '+ Upload', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                    )),
                if (p.files.isEmpty)
                  Box(
                    onTap: uploading ? null : () => _upload(p),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.cloud_upload_outlined, color: context.accent),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Attach briefs, images, PDFs or any file up to 30 MB.', style: TextStyle(color: context.mutedText))),
                    ]),
                  )
                else
                  Box(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final f in p.files)
                        ListTile(
                          onTap: () => FileService.open(f),
                          leading: f.isImage
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(f.url, width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined)))
                              : Container(width: 42, height: 42, decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(10)), child: Icon(f.isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, color: context.onTint)),
                          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(f.sizeLabel, style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(tooltip: 'Remove', icon: Icon(Icons.delete_outline_rounded, color: context.mutedText), onPressed: () => _removeFile(p, f)),
                        ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
