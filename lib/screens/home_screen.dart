import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/focus_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'calendar_screen.dart';
import 'focus_screen.dart';
import 'note_editor.dart';
import 'notes_screen.dart';
import 'notifications_screen.dart';
import 'project_detail.dart';
import 'project_editor.dart';
import 'search_screen.dart';
import 'shell.dart';
import 'stats_screen.dart';
import 'todo_editor.dart';
import 'todos_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  (String, IconData, Color) _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return ('Good night', Icons.nightlight_round, const Color(0xFF6C6FD8));
    if (h < 12) return ('Good morning', Icons.wb_sunny_rounded, const Color(0xFFF5A524));
    if (h < 17) return ('Good afternoon', Icons.wb_twilight_rounded, const Color(0xFFF08C2E));
    if (h < 21) return ('Good evening', Icons.nights_stay_rounded, const Color(0xFF7A5AF8));
    return ('Good night', Icons.nightlight_round, const Color(0xFF6C6FD8));
  }

  void _open(BuildContext context, Widget page, {bool modal = false}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page, fullscreenDialog: modal));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final prefs = context.watch<Prefs>();
    final u = FirebaseAuth.instance.currentUser;
    final first = (u?.displayName ?? '').trim().split(' ').first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in7 = today.add(const Duration(days: 8));
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    bool isToday(DateTime? d) => d != null && day(d) == today;
    final dueToday = s.todos.where((t) => !t.done && t.deadline != null && !day(t.deadline!).isAfter(today)).toList();
    final doneToday = s.todos.where((t) => t.done && isToday(t.completedAt)).length;
    final upcoming = s.todos.where((t) => !t.done && t.deadline != null && day(t.deadline!).isAfter(today) && t.deadline!.isBefore(in7)).toList();
    final active = s.projects.where((p) => !p.done && p.status != 'complete' && p.status != 'cancelled').toList();
    final homeSections = s.sections.where((x) => x.onHome).toList();
    final total = dueToday.length + doneToday;
    final g = _greeting();
    var i = 0;

    final top = <Widget>[
          // ---------- greeting ----------
          FadeIn(
            index: i++,
            child: Row(children: [
              Breathing(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: g.$3.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(g.$2, color: g.$3, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.$1, style: TextStyle(color: context.mutedText, fontSize: T.small, fontWeight: FontWeight.w500)),
                  Text(first.isEmpty ? 'Welcome' : first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                ]),
              ),
              // On computers these live in the sidebar.
              if (!isDesktop(context)) ...[
                RoundButton(icon: Icons.calendar_month_outlined, tooltip: 'Calendar', onTap: () => _open(context, const CalendarScreen())),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: s.unreadCount > 0,
                  label: Text('${s.unreadCount}'),
                  backgroundColor: C.red,
                  child: RoundButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => _open(context, const NotificationsScreen())),
                ),
                const SizedBox(width: 8),
                const ProfileButton(),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          // ---------- search ----------
          FadeIn(
            index: i++,
            child: Material(
              color: context.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _open(context, const SearchScreen()),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: context.isDark ? Colors.white10 : C.line)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: context.mutedText, size: 21),
                    const SizedBox(width: 10),
                    Text('Search projects, to-dos, notes…', style: TextStyle(color: context.mutedText, fontSize: T.body)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
    ];
    final left = <Widget>[
          // ---------- today ----------
          FadeIn(index: i++, child: _TodayCard(total: total, done: doneToday, due: dueToday.length, active: active.length, notes: s.notes.length)),
          const SizedBox(height: 12),

          // ---------- due today ----------
          FadeIn(
            index: i++,
            child: Label('Due today${dueToday.isEmpty ? '' : ' · ${dueToday.length}'}',
                trailing: _SeeAll(onTap: () => ShellState.of(context)?.go(2))),
          ),
          FadeIn(
            index: i++,
            child: dueToday.isEmpty
                ? Box(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.celebration_outlined, color: C.green, size: 21)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Nothing due. Enjoy the calm!', style: TextStyle(color: context.mutedText))),
                    ]),
                  )
                : Box(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(children: [for (final t in dueToday.take(6)) TodoRow(todo: t)]),
                  ),
          ),

          // ---------- upcoming ----------
          if (upcoming.isNotEmpty) ...[
            FadeIn(index: i++, child: Label('Next 7 days · ${upcoming.length}', trailing: _SeeAll(onTap: () => _open(context, const CalendarScreen())))),
            FadeIn(
              index: i++,
              child: Box(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Column(children: [for (final t in upcoming.take(5)) TodoRow(todo: t)]),
              ),
            ),
          ],

    ];
    final right = <Widget>[
          // ---------- projects ----------
          if (active.isNotEmpty) ...[
            FadeIn(index: i++, child: Label('Active projects', trailing: _SeeAll(onTap: () => ShellState.of(context)?.go(1)))),
            FadeIn(
              index: i++,
              child: SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: active.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, k) => _ProjectMini(p: active[k]),
                ),
              ),
            ),
          ],

          // ---------- stats + focus ----------
          const SizedBox(height: 14),
          FadeIn(
            index: i++,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _StatsTile(store: s, onTap: () => _open(context, const StatsScreen()))),
                const SizedBox(width: 12),
                Expanded(child: _FocusTile(minutes: prefs.focusMinutes, onTap: () => _open(context, const FocusScreen()))),
              ]),
            ),
          ),

          // ---------- notes ----------
          if (prefs.showNotesOnHome && homeSections.isNotEmpty) ...[
            FadeIn(index: i++, child: const Label('From your notes')),
            for (final sec in homeSections) FadeIn(index: i++, child: _HomeSection(sec: sec)),
          ],
    ];
    return SafeArea(
      bottom: false,
      child: SyncRefresh(
        child: LayoutBuilder(builder: (context, c) {
          // Wide screens: two columns side by side.
          final wide = c.maxWidth >= 980;
          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 20, isDesktop(context) ? 22 : 10, wide ? 28 : 20, isDesktop(context) ? 40 : 120),
            children: wide
                ? [
                    ...top,
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                      const SizedBox(width: 24),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
                    ]),
                  ]
                : [...top, ...left, ...right],
          );
        }),
      ),
    );
  }
}

class _SeeAll extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAll({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text('See all', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _TodayCard extends StatelessWidget {
  final int total, done, due, active, notes;
  const _TodayCard({required this.total, required this.done, required this.due, required this.active, required this.notes});
  @override
  Widget build(BuildContext context) {
    final a = context.accent;
    final clear = total == 0;
    final pct = clear ? 1.0 : done / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(a, Colors.white, 0.12)!, Color.lerp(a, Colors.black, 0.12)!]),
        boxShadow: [BoxShadow(color: a.withOpacity(0.30), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(right: -30, top: -40, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)))),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dLong.format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: T.small, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(clear ? 'A clear day' : (due == 0 ? 'All done for today' : '$due left today'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(clear ? 'Nothing due. Plan something or take it easy.' : '$done of $total finished',
                  style: const TextStyle(color: Colors.white70, fontSize: T.small)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Pill(icon: Icons.work_outline_rounded, text: '$active projects'),
                _Pill(icon: Icons.sticky_note_2_outlined, text: '$notes notes'),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          AnimatedRing(
            value: pct,
            size: 84,
            stroke: 8,
            color: Colors.white,
            track: Colors.white24,
            center: clear
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                : Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500)),
        ]),
      );
}

class _StatsTile extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;
  const _StatsTile({required this.store, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = [
      for (var d = 6; d >= 0; d--)
        store.todos.where((t) => t.done && t.completedAt != null && DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day) == today.subtract(Duration(days: d))).length
    ];
    final maxV = math.max(1, counts.fold<int>(0, math.max));
    final week = counts.fold<int>(0, (a, b) => a + b);
    return Box(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, size: 18, color: context.accent),
          const SizedBox(width: 6),
          const Expanded(child: Text('Stats', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          Icon(Icons.chevron_right_rounded, size: 18, color: context.mutedText),
        ]),
        const SizedBox(height: 4),
        Text('$week done this week', style: TextStyle(fontSize: 11.5, color: context.mutedText)),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var k = 0; k < counts.length; k++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 4 + 34 * counts[k] / maxV),
                    duration: Duration(milliseconds: 500 + k * 60),
                    curve: Curves.easeOutCubic,
                    builder: (_, h, __) => Container(height: h, decoration: BoxDecoration(color: k == 6 ? context.accent : context.accent.withOpacity(0.25), borderRadius: BorderRadius.circular(4))),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _FocusTile extends StatelessWidget {
  final int minutes;
  final VoidCallback onTap;
  const _FocusTile({required this.minutes, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.accent;
    final f = context.watch<FocusService>();
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.tint, Color.lerp(context.tint, a, 0.25)!])),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.timer_outlined, size: 18, color: context.onTint),
                const SizedBox(width: 6),
                Expanded(child: Text('Focus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.onTint))),
              ]),
              const SizedBox(height: 4),
              Text(f.active ? '${FocusEngine.fmt(f.leftMs)} left${f.paused ? ' · paused' : ''}' : '$minutes min · no distractions', style: TextStyle(fontSize: 11.5, color: context.onTint.withOpacity(0.75), fontWeight: f.active ? FontWeight.w700 : FontWeight.w400)),
              const Spacer(),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.active ? Icons.timer_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(f.active ? 'Open' : 'Start', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
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
      width: 196,
      child: Box(
        color: context.isDark ? c.fg.withOpacity(0.22) : c.bg,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), borderRadius: BorderRadius.circular(11)), child: Icon(iconOf(p.icon), color: c.fg, size: 18)),
            const Spacer(),
            if (p.deadline != null) Text(dShort.format(p.deadline!), style: TextStyle(color: context.isDark ? Colors.white70 : c.fg, fontWeight: FontWeight.w600, fontSize: 11.5)),
          ]),
          const Spacer(),
          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: context.isDark ? Colors.white : C.ink)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pr),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 6, color: c.fg, backgroundColor: Colors.white70)),
          ),
          const SizedBox(height: 4),
          Text('${(pr * 100).round()}% done', style: TextStyle(color: context.isDark ? Colors.white70 : c.fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
    final all = s.notes.where((n) => n.sectionId == sec.id).toList();
    final notes = all.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(id: sec.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Icons.folder_rounded, size: 18, color: context.accent),
              const SizedBox(width: 6),
              Expanded(child: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
              Text(all.length > 4 ? 'All ${all.length}' : '${all.length} notes', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 12.5)),
              Icon(Icons.chevron_right_rounded, size: 18, color: context.accent),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        if (notes.isEmpty)
          Box(padding: const EdgeInsets.all(14), child: Text('No notes in this folder yet.', style: TextStyle(color: context.mutedText, fontSize: 13)))
        else
          LayoutBuilder(builder: (context, c) => GridView.count(
            crossAxisCount: (c.maxWidth / 190).floor().clamp(2, 4),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [for (final n in notes) _HomeNote(n: n)],
          )),
      ]),
    );
  }
}

class _HomeNote extends StatelessWidget {
  final Note n;
  const _HomeNote({required this.n});
  @override
  Widget build(BuildContext context) {
    final plain = n.color == 0;
    final bg = context.isDark && plain ? context.surface : noteColor(n.color);
    final ink = context.isDark && plain ? null : C.ink;
    final img = n.firstImage;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(id: n.id))),
        onLongPress: () => showNoteActions(context, n),
        onSecondaryTap: () => showNoteActions(context, n),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: context.isDark ? Colors.white10 : C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (img != null) SizedBox(height: 54, width: double.infinity, child: Image.network(img.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(iconOf(n.icon), size: 15, color: ink ?? context.accent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: ink))),
                    if (n.pinned) Icon(Icons.push_pin, size: 12, color: ink ?? context.mutedText),
                  ]),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Text(n.preview.isEmpty ? n.allText.trim() : n.preview, maxLines: img != null ? 1 : 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.4, color: ink?.withOpacity(0.7) ?? context.mutedText)),
                  ),
                  Row(children: [
                    Icon(Icons.edit_outlined, size: 11, color: ink?.withOpacity(0.5) ?? context.mutedText),
                    const SizedBox(width: 3),
                    Expanded(child: Text(fmtStamp(n.updatedAt), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: ink?.withOpacity(0.55) ?? context.mutedText, fontWeight: FontWeight.w500))),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
