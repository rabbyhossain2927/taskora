import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart' show streakOf;
import '../theme.dart';
import 'focus_service.dart';
import 'prefs.dart';
import 'store.dart';

/// Android home screen widgets: write what they show, draw the two picture
/// widgets (Today ring, Dashboard), and ask Android to refresh them.
class HomeWidgets {
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Timer? _t;

  static const _providers = ['TodayRingWidget', 'TodosWidget', 'FocusWidget', 'QuickAddWidget', 'DashboardWidget', 'PinnedNoteWidget', 'StreakWidget'];

  /// Refresh a moment after things change (many changes -> one refresh).
  static void refreshSoon(Store s, FocusService f) {
    if (!supported) return;
    _t?.cancel();
    _t = Timer(const Duration(seconds: 2), () => _push(s, f).catchError((_) {}));
  }

  static Future<void> _push(Store s, FocusService f) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final open = s.todos.where((t) => !t.done && t.deadline != null && t.deadline!.isBefore(tomorrow)).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final doneToday = s.todos.where((t) => t.done && t.completedAt != null && !t.completedAt!.isBefore(today)).length;
    final total = open.length + doneToday;
    String when(DateTime d) {
      if (d.isBefore(today)) return 'Overdue';
      return d.hour == 0 && d.minute == 0 ? 'Today' : DateFormat('h:mm a').format(d);
    }

    await HomeWidget.saveWidgetData<String>('today_count', '$doneToday of $total');
    for (var i = 0; i < 4; i++) {
      final t = i < open.length ? open[i] : null;
      await HomeWidget.saveWidgetData<String>('todo${i}_id', t?.id ?? '');
      await HomeWidget.saveWidgetData<String>('todo${i}_title', t?.title ?? '');
      await HomeWidget.saveWidgetData<String>('todo${i}_when', t == null ? '' : when(t.deadline!));
    }

    // Focus
    final mins = Prefs.instance.focusMinutes;
    await HomeWidget.saveWidgetData<String>('focus_end', f.running ? '${now.millisecondsSinceEpoch + f.leftMs}' : '0');
    await HomeWidget.saveWidgetData<String>('focus_time', f.active ? FocusEngine.fmt(f.leftMs) : '$mins:00');
    await HomeWidget.saveWidgetData<String>('focus_state', f.running ? (f.label.isEmpty ? 'Running' : f.label) : (f.paused ? 'Paused' : 'Ready when you are'));

    // Streak + pinned note
    final streak = streakOf(s);
    await HomeWidget.saveWidgetData<String>('streak', '$streak');
    final pinned = s.notes.where((n) => n.pinned).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final note = pinned.isEmpty ? null : pinned.first;
    await HomeWidget.saveWidgetData<String>('note_id', note?.id ?? '');
    await HomeWidget.saveWidgetData<String>('note_title', note == null ? 'No pinned note' : (note.title.isEmpty ? 'Untitled' : note.title));
    await HomeWidget.saveWidgetData<String>('note_body', note == null ? 'Pin a note in TaskOra to see it here.' : note.preview);

    // Pictures
    final accent = appThemes[Prefs.instance.themeIndex.clamp(0, appThemes.length - 1)].accent;
    final week = [
      for (var k = 6; k >= 0; k--)
        s.todos.where((t) => t.done && t.completedAt != null && DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day) == today.subtract(Duration(days: k))).length,
    ];
    final sum = f.summary;
    await HomeWidget.renderFlutterWidget(_Ring(doneToday, total, accent), key: 'ring_img', logicalSize: const Size(160, 160), pixelRatio: 2.5);
    await HomeWidget.renderFlutterWidget(
      _Dashboard(
        greeting: now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening'),
        date: DateFormat('EEEE, d MMM').format(now),
        streak: streak,
        done: doneToday,
        total: total,
        focus: sum.$2,
        next: [for (final t in open.take(3)) (t.title, when(t.deadline!))],
        week: week,
        accent: accent,
      ),
      key: 'dash_img',
      logicalSize: const Size(330, 330),
      pixelRatio: 2.5,
    );

    for (final p in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.taskora.taskora.$p');
    }
  }
}

const _ink = Color(0xFF2A2A3A), _muted = Color(0xFF7A7A8C);

class _Ring extends StatelessWidget {
  final int done, total;
  final Color accent;
  const _Ring(this.done, this.total, this.accent);
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 160,
          height: 160,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(120, 120), painter: _RingPainter(total == 0 ? 1 : done / total, accent)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$done/$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink)),
              Text(total - done <= 0 ? 'all done' : '${total - done} left', style: const TextStyle(fontSize: 12, color: _muted)),
            ]),
          ]),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color c;
  _RingPainter(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = c.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v.clamp(0.0, 1.0), false, Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Dashboard extends StatelessWidget {
  final String greeting, date;
  final int streak, done, total, focus;
  final List<(String, String)> next;
  final List<int> week;
  final Color accent;
  const _Dashboard({required this.greeting, required this.date, required this.streak, required this.done, required this.total, required this.focus, required this.next, required this.week, required this.accent});
  @override
  Widget build(BuildContext context) {
    final mx = math.max(1, week.reduce(math.max));
    Widget box(String v, String l, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
              Text(l, style: const TextStyle(fontSize: 11, color: _muted)),
            ]),
          ),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 330,
        height: 330,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(date, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
                Text(greeting, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              ]),
            ),
            if (streak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFEDD9), borderRadius: BorderRadius.circular(99)),
                child: Text('$streak-day streak', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD9731A))),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            box('$done/$total', 'to-dos today', accent.withOpacity(0.10)),
            const SizedBox(width: 10),
            box(focus >= 60 ? '${focus ~/ 60}h ${focus % 60}m' : '${focus}m', 'focus today', const Color(0xFFF5E9FF)),
          ]),
          const SizedBox(height: 12),
          const Text('Next up', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          if (next.isEmpty) const Text('Nothing due today', style: TextStyle(fontSize: 13, color: _muted)),
          for (final n in next.take(2))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFC9C2EE), width: 2))),
                const SizedBox(width: 8),
                Expanded(child: Text(n.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _ink))),
                Text(n.$2, style: TextStyle(fontSize: 11, color: n.$2 == 'Overdue' ? const Color(0xFFD83A3A) : _muted)),
              ]),
            ),
          const Spacer(),
          const Text('This week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: Container(height: 6 + 46.0 * week[i] / mx, decoration: BoxDecoration(color: i == 6 ? accent : accent.withOpacity(0.25), borderRadius: BorderRadius.circular(6)))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
