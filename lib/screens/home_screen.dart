import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'focus_screen.dart';
import 'note_editor.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'project_detail.dart';
import 'shell.dart';
import 'todos_screen.dart';

class Avatar extends StatelessWidget {
  final double size;
  final bool ring;
  const Avatar({super.key, this.size = 46, this.ring = true});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName?.trim().isNotEmpty ?? false) ? u!.displayName! : (u?.email ?? 'You');
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    final pic = u?.photoURL;
    return Container(
      padding: EdgeInsets.all(ring ? size * 0.05 : 0),
      decoration: ring ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.accent, width: size * 0.05)) : null,
      child: Container(
        padding: EdgeInsets.all(ring ? size * 0.03 : 0),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
        child: CircleAvatar(
          radius: size / 2 - (ring ? size * 0.08 : 0),
          backgroundColor: const Color(0xFFE6DEFF),
          foregroundImage: pic != null ? NetworkImage(pic) : null,
          child: Text(initials, style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF5B3FD0), fontSize: size * 0.32)),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    final u = FirebaseAuth.instance.currentUser;
    final first = (u?.displayName ?? '').split(' ').first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isToday(DateTime? d) => d != null && DateTime(d.year, d.month, d.day) == today;
    final dueToday = s.todos.where((t) => !t.done && (isToday(t.deadline) || (t.deadline != null && t.deadline!.isBefore(today)))).toList();
    final doneToday = s.todos.where((t) => t.done && isToday(t.completedAt)).length;
    final active = s.projects.where((p) => !p.done && p.status != 'complete' && p.status != 'cancelled').toList();
    final homeSections = s.sections.where((x) => x.onHome).toList();
    final total = dueToday.length + doneToday;

    return SafeArea(
      bottom: false,
      child: SyncRefresh(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
          Row(children: [
            GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())), child: const Avatar()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting(), style: TextStyle(color: context.mutedText, fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(first.isEmpty ? 'Welcome' : first, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ]),
            ),
            Badge(
              isLabelVisible: s.unreadCount > 0,
              label: Text('${s.unreadCount}'),
              backgroundColor: C.red,
              child: RoundButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            ),
          ]),
          const SizedBox(height: 18),

          // Today card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dLong.format(now), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(total == 0 ? 'A clear day' : '$doneToday of $total done today', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${active.length} active projects · ${s.notes.length} notes', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(value: total == 0 ? 1 : doneToday / total, strokeWidth: 7, backgroundColor: Colors.white24, color: Colors.white, strokeCap: StrokeCap.round),
                  Text(total == 0 ? '✓' : '${(doneToday * 100 / total).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Overview tiles
          Row(children: [
            _Overview(icon: Icons.work_outline, color: 0, value: '${active.length}', label: 'Projects', onTap: () => ShellState.of(context)?.go(1)),
            const SizedBox(width: 10),
            _Overview(icon: Icons.check_circle_outline, color: 8, value: '${s.todos.where((t) => !t.done).length}', label: 'Open to-dos', onTap: () => ShellState.of(context)?.go(3)),
            const SizedBox(width: 10),
            _Overview(icon: Icons.sticky_note_2_outlined, color: 6, value: '${s.notes.length}', label: 'Notes', onTap: () => ShellState.of(context)?.go(4)),
          ]),

          Label('Due today', trailing: GestureDetector(onTap: () => ShellState.of(context)?.go(3), child: Text('See all', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 13)))),
          if (dueToday.isEmpty)
            Box(child: Row(children: [const Icon(Icons.celebration_outlined, color: C.green), const SizedBox(width: 10), Expanded(child: Text('Nothing due. Enjoy the calm!', style: TextStyle(color: context.mutedText)))]))
          else
            Box(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in dueToday.take(5)) TodoRow(todo: t, dense: true)])),

          if (active.isNotEmpty) ...[
            Label('Active projects', trailing: GestureDetector(onTap: () => ShellState.of(context)?.go(1), child: Text('See all', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 13)))),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: active.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _ProjectMini(p: active[i]),
              ),
            ),
          ],

          if (prefs.showNotesOnHome && homeSections.isNotEmpty) ...[
            const Label('From your notes'),
            for (final sec in homeSections) _HomeSection(sec: sec),
          ],

          const SizedBox(height: 14),
          Box(
            color: const Color(0xFF1A1A1F),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen())),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.timer_outlined, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Start a focus session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${prefs.focusMinutes} minutes, no distractions', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
            ]),
          ),
          const SizedBox(height: 10),
          Center(child: TextButton.icon(onPressed: () => ShellState.of(context)?.go(2), icon: const Icon(Icons.insights_rounded, size: 18), label: const Text('See all your stats'))),
        ]),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final IconData icon;
  final int color;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _Overview({required this.icon, required this.color, required this.value, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return Expanded(
      child: Box(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: p.fg)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ProjectMini extends StatelessWidget {
  final Project p;
  const _ProjectMini({required this.p});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final pr = s.progressOf(p.id);
    final c = pastel(p.color);
    return SizedBox(
      width: 200,
      child: Box(
        color: c.bg,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(12)), child: Icon(iconOf(p.icon), color: c.fg, size: 19)),
            const Spacer(),
            if (p.deadline != null) Text(dShort.format(p.deadline!), style: TextStyle(color: c.fg, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const Spacer(),
          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.ink)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pr, minHeight: 6, color: c.fg, backgroundColor: Colors.white70)),
          const SizedBox(height: 4),
          Text('${(pr * 100).round()}% done', style: TextStyle(color: c.fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final NoteSection sec;
  const _HomeSection({required this.sec});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final notes = s.notes.where((n) => n.sectionId == sec.id).take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          if (notes.isEmpty) Text('No notes in this section yet.', style: TextStyle(color: context.mutedText, fontSize: 13)),
          for (final n in notes)
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(id: n.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: noteColor(n.color) == Colors.white ? C.line : noteColor(n.color), shape: BoxShape.circle, border: Border.all(color: C.line))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(dShort.format(n.updatedAt), style: TextStyle(color: context.mutedText, fontSize: 12)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
