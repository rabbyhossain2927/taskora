import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
          if (wide && isDesktop(context)) {
            return _DesktopHome(g: g, first: first, s: s, prefs: prefs, dueToday: dueToday, upcoming: upcoming, active: active, homeSections: homeSections, total: total, doneToday: doneToday);
          }
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

/// Computers: the web design's Home (header, Today list, Focus, This week,
/// Active projects table, Recent notes).
class _DesktopHome extends StatelessWidget {
  final (String, IconData, Color) g;
  final String first;
  final Store s;
  final Prefs prefs;
  final List<Todo> dueToday, upcoming;
  final List<Project> active;
  final List<NoteSection> homeSections;
  final int total, doneToday;
  const _DesktopHome({required this.g, required this.first, required this.s, required this.prefs, required this.dueToday, required this.upcoming, required this.active, required this.homeSections, required this.total, required this.doneToday});

  void _open(BuildContext context, Widget page, {bool modal = false}) => Navigator.push(context, MaterialPageRoute(builder: (_) => page, fullscreenDialog: modal));
  void _side(BuildContext context, String key, Widget page) {
    final sh = ShellState.of(context);
    sh == null ? _open(context, page) : sh.openSide(key, page);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = dueToday.where((t) => t.deadline!.isBefore(today)).toList();
    final todayList = dueToday.where((t) => !t.deadline!.isBefore(today)).toList();
    final doneTodayList = s.todos.where((t) => t.done && t.completedAt != null && !t.completedAt!.isBefore(today)).toList();
    final sub = '${DateFormat('EEEE, d MMMM').format(now)} · ${todayList.length} to-do${todayList.length == 1 ? '' : 's'} left today${overdue.isEmpty ? '' : ' · ${overdue.length} overdue'}';
    final notes = [...s.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final muted = context.mutedText;

    Widget head(String title, {String? extra, Widget? mid, String? link, VoidCallback? onLink}) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (extra != null) ...[const SizedBox(width: 10), Text(extra, style: TextStyle(fontSize: 12.5, color: muted))],
            if (mid != null) ...[const SizedBox(width: 10), mid],
            const Spacer(),
            if (link != null) _Link(link, onLink!),
          ]),
        );
    Widget group(String t, Color c) => Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 2), child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)));

    // ---------- Today ----------
    final pct = total == 0 ? 0.0 : doneToday / total;
    final todayCard = Box(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        head('Today',
            extra: '$doneToday of $total done',
            mid: SizedBox(width: 200, child: _Bar(pct, context.accent)),
            link: 'Open to-do',
            onLink: () => ShellState.of(context)?.go(2)),
        if (overdue.isNotEmpty) ...[group('Overdue', const Color(0xFFB42318)), for (final t in overdue.take(4)) TodoRow(todo: t)],
        if (todayList.isNotEmpty) ...[group('Today', context.selInk), for (final t in todayList.take(8)) TodoRow(todo: t)],
        if (doneTodayList.isNotEmpty) ...[group('Done', muted), for (final t in doneTodayList.take(3)) TodoRow(todo: t)],
        if (dueToday.isEmpty && doneTodayList.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Text('Nothing due today. Enjoy the calm.', style: TextStyle(color: muted))),
        const SizedBox(height: 6),
        const _QuickAdd(),
      ]),
    );

    // ---------- Focus ----------
    final focusCard = Consumer<FocusService>(builder: (context, f, _) {
      final left = f.active ? FocusEngine.fmt(f.leftMs) : '${prefs.focusMinutes}:00';
      final state = f.running ? 'Running' : (f.paused ? 'Paused' : 'Ready when you are');
      Widget btn(String t, IconData? ic, bool main, VoidCallback onTap) => Material(
            color: main ? context.accent : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (ic != null) ...[Icon(ic, size: 18, color: main ? Colors.white : context.selInk), SizedBox(width: 6)],
                    Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: main ? Colors.white : context.selInk)),
                  ]),
                ),
              ),
            ),
          );
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE6DEFF), Color(0xFFDDE3FF)]),
          boxShadow: const [BoxShadow(color: Color(0x0F281E6E), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Focus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.selInk)),
              const SizedBox(height: 2),
              Text(f.label.isEmpty ? state : '$state · ${f.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF4F4596))),
              const SizedBox(height: 10),
              Text(left, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1, color: Color(0xFF2A2170), fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
          SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (f.running) btn('Pause', Icons.pause_rounded, true, f.pause)
            else if (f.paused) btn('Resume', Icons.play_arrow_rounded, true, f.resume)
            else btn('Start', Icons.play_arrow_rounded, true, () => _side(context, 'focus', const FocusScreen())),
            const SizedBox(height: 8),
            f.active ? btn('Stop', null, false, f.stop) : btn('Options', null, false, () => _side(context, 'focus', const FocusScreen())),
          ]),)
        ]),
      );
    });

    // ---------- This week ----------
    final days = [for (var k = 6; k >= 0; k--) today.subtract(Duration(days: k))];
    final perDay = [for (final d in days) s.todos.where((t) => t.done && t.completedAt != null && DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day) == d).length];
    final weekDone = perDay.fold<int>(0, (a, b) => a + b);
    final weekFocus = context.watch<FocusService>().summary.$3;
    final maxV = perDay.fold<int>(1, math.max);
    final weekCard = Box(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('This week', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(child: Text('$weekDone to-dos done · ${weekFocus ~/ 60}h ${weekFocus % 60}m focus', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: muted))),
          _Link('Stats', () => _side(context, 'stats', const StatsScreen())),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var k = 0; k < 7; k++) ...[
              if (k > 0) const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${perDay[k]}', style: TextStyle(fontSize: 11, color: k == 6 ? context.selInk : muted, fontWeight: k == 6 ? FontWeight.w700 : FontWeight.w400)),
                  const SizedBox(height: 6),
                  Container(height: 8 + 70.0 * perDay[k] / maxV, decoration: BoxDecoration(color: k == 6 ? context.accent : const Color(0xFFDCDDFD), borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Text(DateFormat('E').format(days[k]).substring(0, 2), style: TextStyle(fontSize: 11.5, color: k == 6 ? context.selInk : muted, fontWeight: k == 6 ? FontWeight.w700 : FontWeight.w400)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );

    // ---------- Active projects ----------
    const cols = [22, 10, 14, 9];
    Widget cells(List<Widget> w) => Row(children: [for (var k = 0; k < 4; k++) ...[if (k > 0) const SizedBox(width: 12), Expanded(flex: cols[k], child: w[k])]]);
    final projectsCard = Box(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        head('Active projects', link: 'All projects', onLink: () => ShellState.of(context)?.go(1)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted),
            child: cells(const [Text('Project'), Text('Status'), Text('Progress'), Text('Due', textAlign: TextAlign.right)]),
          ),
        ),
        if (active.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Text('No active projects.', style: TextStyle(color: muted))),
        for (final p in active.take(6)) _ProjectRow(p: p, cells: cells),
      ]),
    );

    // ---------- Recent notes ----------
    final notesCard = Box(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        head('Recent notes', link: 'All notes', onLink: () => ShellState.of(context)?.go(3)),
        if (notes.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Text('No notes yet.', style: TextStyle(color: muted))),
        for (final n in notes.take(5))
          _HoverRow(
            onTap: () => _open(context, NoteEditor(id: n.id)),
            child: Row(children: [
              Container(width: 8, height: 34, decoration: BoxDecoration(color: n.color == 0 ? const Color(0xFFCDBEFF) : Color.lerp(noteColor(n.color), Colors.black, 0.12), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (n.preview.isNotEmpty) Text(n.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: muted)),
                ]),
              ),
              const SizedBox(width: 12),
              Text(_when(n.updatedAt), style: TextStyle(fontSize: 11.5, color: muted)),
            ]),
          ),
      ]),
    );

    return ListView(padding: const EdgeInsets.fromLTRB(28, 22, 28, 28), children: [
      FadeIn(
        index: 0,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${g.$1}${first.isEmpty ? '' : ', $first'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: muted)),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 340, child: _SearchField(onTap: () => _open(context, const SearchScreen()))),
          const SizedBox(width: 12),
          Badge(
            isLabelVisible: s.unreadCount > 0,
            label: Text('${s.unreadCount}'),
            backgroundColor: C.red,
            child: _IconBtn(Icons.notifications_none_rounded, 'Notifications', () => _side(context, 'inbox', const NotificationsScreen())),
          ),
          const SizedBox(width: 12),
          const _NewButton(),
        ]),
      ),
      const SizedBox(height: 18),
      FadeIn(
        index: 1,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 384), child: todayCard)),
          const SizedBox(width: 18),
          Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [focusCard, const SizedBox(height: 18), weekCard])),
        ]),
      ),
      const SizedBox(height: 18),
      FadeIn(
        index: 2,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 7, child: projectsCard),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: notesCard),
          ]),
        ),
      ),
      if (prefs.showNotesOnHome && homeSections.isNotEmpty) ...[
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, c) {
          final per = (c.maxWidth / 420).floor().clamp(1, homeSections.length);
          final w = (c.maxWidth - 20 * (per - 1)) / per;
          return Wrap(spacing: 20, runSpacing: 4, children: [for (final sec in homeSections) SizedBox(width: w, child: _HomeSection(sec: sec))]);
        }),
      ],
    ]);
  }

  static String _when(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day ? DateFormat('h:mm a').format(d) : fmtDue(DateTime(d.year, d.month, d.day));
  }
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Link(this.text, this.onTap);
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.selInk))),
      );
}

class _Bar extends StatelessWidget {
  final double v;
  final Color c;
  final Color bg;
  const _Bar(this.v, this.c, [this.bg = const Color(0xFFECEBFA)]);
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: v.clamp(0, 1), minHeight: 6, color: c, backgroundColor: bg));
}

class _HoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverRow({required this.child, required this.onTap});
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => h = true),
        onExit: (_) => setState(() => h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: h ? (context.isDark ? Colors.white10 : context.hoverTint) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: widget.child,
          ),
        ),
      );
}

class _SearchField extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchField({required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0F281E6E), blurRadius: 2, offset: Offset(0, 1))]),
            child: Row(children: [
              Icon(Icons.search_rounded, color: context.mutedText, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text('Search projects, to-dos, notes', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.mutedText, fontSize: 13.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: context.softFill, borderRadius: BorderRadius.circular(99)),
                child: Text('Ctrl K', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.mutedText)),
              ),
            ]),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: const Color(0xFF4B4B5A)))),
        ),
      );
}

/// "+ New" with Project / To-do / Note / Focus.
class _NewButton extends StatelessWidget {
  const _NewButton();
  @override
  Widget build(BuildContext context) {
    void open(Widget p) => Navigator.push(context, MaterialPageRoute(builder: (_) => p, fullscreenDialog: true));
    PopupMenuItem<int> it(int v, IconData ic, String t, String k, int c) => PopupMenuItem(
          value: v,
          child: Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: pastel(c).bg, borderRadius: BorderRadius.circular(9)), child: Icon(ic, size: 16, color: pastel(c).fg)),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(k, style: TextStyle(fontSize: 11.5, color: context.mutedText)),
          ]),
        );
    return PopupMenuButton<int>(
      tooltip: 'New project, to-do or note',
      offset: const Offset(0, 46),
      onSelected: (v) {
        if (v == 0) open(const ProjectEditor());
        if (v == 1) open(const TodoEditor());
        if (v == 2) open(const NoteEditor());
        if (v == 3) ShellState.of(context)?.openSide('focus', const FocusScreen());
      },
      itemBuilder: (_) => [
        it(0, Icons.work_outline_rounded, 'Project', 'Alt+P', 0),
        it(1, Icons.check_circle_outline_rounded, 'To-do', 'Alt+T', 8),
        it(2, Icons.sticky_note_2_outlined, 'Note', 'Alt+N', 6),
        const PopupMenuDivider(),
        it(3, Icons.timer_outlined, 'Start focus', 'Alt+F', 12),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: context.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

/// "Add a to-do for today…" — Enter saves it, due today.
class _QuickAdd extends StatefulWidget {
  const _QuickAdd();
  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _save() {
    final t = c.text.trim();
    if (t.isEmpty) return;
    final n = DateTime.now();
    context.read<Store>().saveTodo(Todo(id: newId(), title: t, deadline: DateTime(n.year, n.month, n.day)));
    c.clear();
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD9D7EE), style: BorderStyle.solid)),
        child: Row(children: [
          Icon(Icons.add_rounded, size: 19, color: context.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: c,
              onSubmitted: (_) => _save(),
              style: const TextStyle(fontSize: 13.5),
              decoration: const InputDecoration(hintText: 'Add a to-do for today…', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.zero),
            ),
          ),
        ]),
      );
}

/// One project as a table row (computers' Home).
class _ProjectRow extends StatelessWidget {
  final Project p;
  final Widget Function(List<Widget>) cells;
  const _ProjectRow({required this.p, required this.cells});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final pr = s.progressOf(p.id);
    final c = pastel(p.color);
    final st = s.statuses.where((x) => x.key == p.status).firstOrNull;
    final sp = st == null ? null : pastel(st.color);
    final now = DateTime.now();
    final late = p.deadline != null && p.deadline!.isBefore(DateTime(now.year, now.month, now.day));
    final lateDays = late ? DateTime(now.year, now.month, now.day).difference(DateTime(p.deadline!.year, p.deadline!.month, p.deadline!.day)).inDays : 0;
    return _HoverRow(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
      child: cells([
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(10)), child: Icon(iconOf(p.icon), color: c.fg, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ]),
        Align(
          alignment: Alignment.centerLeft,
          child: st == null
              ? const SizedBox()
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: sp!.bg, borderRadius: BorderRadius.circular(99)),
                  child: Text(st.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sp.fg)),
                ),
        ),
        Row(children: [
          Expanded(child: _Bar(pr, c.fg)),
          const SizedBox(width: 8),
          Text('${(pr * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: c.fg)),
        ]),
        Text(
          p.deadline == null ? '—' : (late ? '${lateDays}d late' : fmtDue(DateTime(p.deadline!.year, p.deadline!.month, p.deadline!.day))),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12.5, color: late ? const Color(0xFFB42318) : context.mutedText, fontWeight: late ? FontWeight.w600 : FontWeight.w400),
        ),
      ]),
    );
  }
}
