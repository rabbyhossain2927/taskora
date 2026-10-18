import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../services/focus_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Stats: completed to-dos, completion, streak, earnings, projects by status
/// and categories. Week / Month / Year, or any From–To range.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String period = 'week';
  DateTimeRange? custom;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: custom ?? DateTimeRange(start: now.subtract(const Duration(days: 13)), end: now),
      helpText: 'Show stats from – to',
      saveText: 'Show',
    );
    if (r != null) {
      setState(() {
        custom = r;
        period = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final focus = context.watch<FocusService>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dark = context.isDark;
    final a = context.accent;
    final pal = softPalette(a, 8, dark: dark);

    // ---------- buckets for the bar chart ----------
    late List<DateTime> starts;
    late List<String> labels;
    late DateTime rangeEnd; // exclusive
    if (period == 'custom' && custom != null) {
      final from = DateTime(custom!.start.year, custom!.start.month, custom!.start.day);
      rangeEnd = DateTime(custom!.end.year, custom!.end.month, custom!.end.day).add(const Duration(days: 1));
      final days = rangeEnd.difference(from).inDays;
      if (days <= 14) {
        starts = [for (var i = 0; i < days; i++) from.add(Duration(days: i))];
        labels = [for (final d in starts) days <= 7 ? DateFormat('E').format(d).substring(0, 2) : '${d.day}'];
      } else if (days <= 120) {
        starts = [for (var d = from; d.isBefore(rangeEnd); d = d.add(const Duration(days: 7))) d];
        labels = [for (final d in starts) DateFormat('d/M').format(d)];
      } else {
        starts = [for (var d = DateTime(from.year, from.month, 1); d.isBefore(rangeEnd); d = DateTime(d.year, d.month + 1, 1)) d];
        if (starts.isNotEmpty) starts[0] = from;
        labels = [for (final d in starts) DateFormat('MMM').format(d).substring(0, 1)];
      }
    } else if (period == 'week') {
      starts = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
      labels = [for (final d in starts) DateFormat('E').format(d).substring(0, 2)];
      rangeEnd = today.add(const Duration(days: 1));
    } else if (period == 'month') {
      starts = [for (var i = 3; i >= 0; i--) today.subtract(Duration(days: 7 * i + 6))];
      labels = ['W1', 'W2', 'W3', 'W4'];
      rangeEnd = today.add(const Duration(days: 1));
    } else {
      starts = [for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
      labels = [for (final d in starts) DateFormat('MMM').format(d).substring(0, 1)];
      rangeEnd = DateTime(now.year, now.month + 1, 1);
    }
    DateTime endOf(int i) => i + 1 < starts.length ? starts[i + 1] : rangeEnd;
    bool inRange(DateTime d) => !d.isBefore(starts.first) && d.isBefore(rangeEnd);

    final done = s.todos.where((t) => t.done && t.completedAt != null).toList();
    final counts = [for (var i = 0; i < starts.length; i++) done.where((t) => !t.completedAt!.isBefore(starts[i]) && t.completedAt!.isBefore(endOf(i))).length];
    final inPeriod = counts.fold<int>(0, (x, y) => x + y);
    final created = s.todos.where((t) => inRange(t.createdAt)).length;
    final rate = created == 0 ? 0.0 : (inPeriod / math.max(created, inPeriod)).clamp(0.0, 1.0);

    // Streak: consecutive days (ending today or yesterday) with a completed to-do
    var streak = 0;
    var day = today;
    final doneDays = done.map((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day)).toSet();
    if (!doneDays.contains(day)) day = day.subtract(const Duration(days: 1));
    while (doneDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    // Money from projects created in the range, grouped by currency
    final money = <String, (double, double)>{};
    for (final p in s.projects.where((p) => (p.amount ?? 0) > 0 && (period == 'custom' ? inRange(p.createdAt) : true))) {
      final cur = money[p.currency] ?? (0.0, 0.0);
      money[p.currency] = (cur.$1 + p.net, cur.$2 + p.fee);
    }

    final byStatus = [for (final st in s.statuses) (st, s.projects.where((p) => p.status == st.key).length)].where((e) => e.$2 > 0).toList();
    final byCat = [for (final c in s.todoCats) (c, done.where((t) => t.category == c.key && inRange(t.completedAt!)).length)]..sort((x, y) => y.$2.compareTo(x.$2));
    final catTotal = byCat.fold<int>(0, (x, y) => x + y.$2);
    final f = focus.summary;

    final rangeText = period == 'custom' && custom != null
        ? '${DateFormat('d MMM y').format(custom!.start)} – ${DateFormat('d MMM y').format(custom!.end)}'
        : '${DateFormat('d MMM').format(starts.first)} – ${DateFormat('d MMM').format(rangeEnd.subtract(const Duration(days: 1)))}';

    return Scaffold(
      body: SafeArea(
        child: SyncRefresh(
          child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 40), children: [
            const Header('Stats'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 4),
                Segmented<String>(
                  items: const [('week', 'Week'), ('month', 'Month'), ('year', 'Year'), ('custom', 'Custom')],
                  value: period,
                  onChanged: (v) {
                    if (v == 'custom') {
                      _pickRange();
                    } else {
                      setState(() => period = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                // From – to
                Material(
                  color: context.tint,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickRange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(children: [
                        Icon(Icons.date_range_rounded, size: 19, color: context.onTint),
                        const SizedBox(width: 10),
                        Expanded(child: Text(rangeText, style: TextStyle(fontWeight: FontWeight.w600, color: context.onTint, fontSize: 13.5))),
                        Text('Change', style: TextStyle(color: context.onTint.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 12.5)),
                        Icon(Icons.chevron_right_rounded, size: 18, color: context.onTint),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _Kpi(value: '$inPeriod', label: 'Done', icon: Icons.task_alt_rounded, color: pal[0]),
                  const SizedBox(width: 10),
                  _Kpi(value: '${(rate * 100).round()}%', label: 'Completion', icon: Icons.donut_large_rounded, color: pal[1]),
                  const SizedBox(width: 10),
                  _Kpi(value: '$streak', label: 'Day streak', icon: Icons.local_fire_department_outlined, color: pal[2]),
                ]),
                const Label('Completed to-dos'),
                Box(child: SizedBox(height: 170, child: _Bars(values: counts, labels: labels, color: a))),
                if (money.isNotEmpty) ...[
                  const Label('Earnings'),
                  for (final e in money.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Box(
                        child: Row(children: [
                          _Bubble(icon: Icons.payments_outlined, color: pal[3]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('You receive · ${e.key}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600, fontSize: 12.5)),
                              Text(fmtMoney(e.value.$1, e.key), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _ink(pal[3], dark))),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('Platform fees', style: TextStyle(fontSize: 12, color: context.mutedText)),
                            Text(fmtMoney(e.value.$2, e.key), style: TextStyle(fontWeight: FontWeight.w700, color: _ink(pal[2], dark))),
                          ]),
                        ]),
                      ),
                    ),
                ],
                if (byStatus.isNotEmpty) ...[
                  const Label('Projects by status'),
                  Box(
                    child: Row(children: [
                      SizedBox(
                        width: 124,
                        height: 124,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => CustomPaint(
                            painter: _Donut([for (var i = 0; i < byStatus.length; i++) (pal[i % pal.length], byStatus[i].$2.toDouble())], v, track: a.withOpacity(0.08)),
                            child: Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text('${s.projects.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                                Text('projects', style: TextStyle(fontSize: 11, color: context.mutedText)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(children: [
                          for (var i = 0; i < byStatus.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: pal[i % pal.length], borderRadius: BorderRadius.circular(3))),
                                const SizedBox(width: 8),
                                Expanded(child: Text(byStatus[i].$1.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5))),
                                Text('${byStatus[i].$2}', style: TextStyle(fontWeight: FontWeight.w700, color: _ink(pal[i % pal.length], dark))),
                              ]),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ],
                const Label('Where your time goes'),
                Box(
                  child: catTotal == 0
                      ? Text('Finish a few to-dos in this period and you’ll see which categories take your time.', style: TextStyle(color: context.mutedText, height: 1.5))
                      : Column(children: [
                          for (final (i, e) in byCat.where((e) => e.$2 > 0).indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                _Bubble(icon: iconOf(e.$1.icon), color: pal[i % pal.length], size: 34),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(e.$1.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      Text('${(e.$2 * 100 / catTotal).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: _ink(pal[i % pal.length], dark))),
                                    ]),
                                    const SizedBox(height: 5),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: e.$2 / catTotal),
                                      duration: Duration(milliseconds: 600 + i * 80),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, v, __) => ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(value: v, minHeight: 7, color: pal[i % pal.length], backgroundColor: pal[i % pal.length].withOpacity(0.16)),
                                      ),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                        ]),
                ),
                const Label('Focus'),
                Row(children: [
                  _Kpi(value: '${f.$1}', label: 'Sessions today', icon: Icons.timer_outlined, color: pal[4]),
                  const SizedBox(width: 10),
                  _Kpi(value: '${f.$2}m', label: 'Focus today', icon: Icons.self_improvement_rounded, color: pal[5]),
                  const SizedBox(width: 10),
                  _Kpi(value: '${(f.$3 / 60).toStringAsFixed(f.$3 < 600 ? 1 : 0)}h', label: 'Last 7 days', icon: Icons.bolt_rounded, color: pal[6]),
                ]),
                const Label('All time'),
                Row(children: [
                  _Kpi(value: '${s.projects.length}', label: 'Projects', icon: Icons.work_outline_rounded, color: pal[0]),
                  const SizedBox(width: 10),
                  _Kpi(value: '${done.length}', label: 'To-dos done', icon: Icons.check_circle_outline_rounded, color: pal[1]),
                  const SizedBox(width: 10),
                  _Kpi(value: '${s.notes.length}', label: 'Notes', icon: Icons.sticky_note_2_outlined, color: pal[3]),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Readable text in a soft colour (a bit deeper in light mode).
Color _ink(Color c, bool dark) => dark ? c : Color.lerp(c, Colors.black, 0.25)!;

class _Bubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _Bubble({required this.icon, required this.color, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withOpacity(context.isDark ? 0.22 : 0.16), borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, size: size * 0.5, color: _ink(color, context.isDark)),
      );
}

class _Kpi extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _Kpi({required this.value, required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Box(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Bubble(icon: icon, color: color, size: 34),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: context.mutedText, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _Bars extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final Color color;
  const _Bars({required this.values, required this.labels, required this.color});
  @override
  Widget build(BuildContext context) {
    final maxV = math.max(1, values.fold<int>(0, math.max));
    final peak = values.isEmpty ? -1 : values.indexOf(values.fold<int>(0, math.max));
    final soft = Color.lerp(color, Colors.white, context.isDark ? 0.15 : 0.35)!;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: values.length > 10 ? 1.5 : 3),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(values[i] == 0 ? '' : '${values[i]}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: context.mutedText)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 6 + 110 * values[i] / maxV),
                duration: Duration(milliseconds: 500 + i * 40),
                curve: Curves.easeOutCubic,
                builder: (_, h, __) => Container(
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: i == peak && values[i] > 0 ? [soft, color] : [color.withOpacity(0.22), color.withOpacity(0.12)],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i], maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 10.5, color: context.mutedText, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
    ]);
  }
}

class _Donut extends CustomPainter {
  final List<(Color, double)> parts;
  final double progress;
  final Color track;
  _Donut(this.parts, this.progress, {required this.track});
  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold<double>(0, (a, b) => a + b.$2);
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 9);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final p in parts) {
      final sweep = 2 * math.pi * p.$2 / total * progress;
      canvas.drawArc(rect, start + 0.05, math.max(0.0, sweep - 0.10), false, Paint()
        ..color = p.$1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => true;
}
