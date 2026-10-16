import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Stats tab: everything that used to sit at the bottom of Home.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String period = 'week';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Buckets for the bar chart
    late List<DateTime> starts;
    late List<String> labels;
    if (period == 'week') {
      starts = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
      labels = [for (final d in starts) DateFormat('E').format(d).substring(0, 2)];
    } else if (period == 'month') {
      starts = [for (var i = 3; i >= 0; i--) today.subtract(Duration(days: 7 * i + 6))];
      labels = ['W1', 'W2', 'W3', 'W4'];
    } else {
      starts = [for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
      labels = [for (final d in starts) DateFormat('MMM').format(d).substring(0, 1)];
    }
    DateTime endOf(int i) => i + 1 < starts.length ? starts[i + 1] : (period == 'year' ? DateTime(now.year, now.month + 1, 1) : today.add(const Duration(days: 1)));
    final done = s.todos.where((t) => t.done && t.completedAt != null).toList();
    final counts = [for (var i = 0; i < starts.length; i++) done.where((t) => !t.completedAt!.isBefore(starts[i]) && t.completedAt!.isBefore(endOf(i))).length];
    final inPeriod = counts.fold<int>(0, (a, b) => a + b);
    final created = s.todos.where((t) => !t.createdAt.isBefore(starts.first)).length;
    final rate = created == 0 ? 0.0 : (inPeriod / math.max(created, inPeriod)).clamp(0.0, 1.0);

    // Streak: consecutive days (ending today or yesterday) with at least one completed to-do
    var streak = 0;
    var day = today;
    bool hasDone(DateTime d) => done.any((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day) == d);
    if (!hasDone(day)) day = day.subtract(const Duration(days: 1));
    while (hasDone(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    // Money (all projects with an amount), grouped by currency
    final money = <String, (double, double)>{};
    for (final p in s.projects.where((p) => (p.amount ?? 0) > 0)) {
      final cur = money[p.currency] ?? (0.0, 0.0);
      money[p.currency] = (cur.$1 + p.net, cur.$2 + p.fee);
    }

    // Projects by status
    final byStatus = [for (final st in s.statuses) (st, s.projects.where((p) => p.status == st.key).length)].where((e) => e.$2 > 0).toList();

    // Where your time goes: done to-dos by category
    final byCat = [for (final c in s.todoCats) (c, done.where((t) => t.category == c.key && !t.completedAt!.isBefore(starts.first)).length)]..sort((a, b) => b.$2.compareTo(a.$2));
    final catTotal = byCat.fold<int>(0, (a, b) => a + b.$2);

    return Scaffold(
      body: SafeArea(
      child: SyncRefresh(
        child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 40), children: [
          const Header('Stats'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 4),
          Segmented<String>(items: const [('week', 'Week'), ('month', 'Month'), ('year', 'Year')], value: period, onChanged: (v) => setState(() => period = v)),
          const SizedBox(height: 12),
          Row(children: [
            _Kpi(value: '$inPeriod', label: 'Done', icon: Icons.task_alt, color: 8),
            const SizedBox(width: 10),
            _Kpi(value: '${(rate * 100).round()}%', label: 'Completion', icon: Icons.donut_large_rounded, color: 0),
            const SizedBox(width: 10),
            _Kpi(value: '$streak', label: 'Day streak', icon: Icons.local_fire_department_outlined, color: 4),
          ]),
          const Label('Completed to-dos'),
          Box(
            child: SizedBox(
              height: 170,
              child: _Bars(values: counts, labels: labels, color: context.accent),
            ),
          ),
          if (money.isNotEmpty) ...[
            const Label('Earnings'),
            for (final e in money.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Box(
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.payments_outlined, color: C.green)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('You receive · ${e.key}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(fmtMoney(e.value.$1, e.key), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.green)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Platform fees', style: TextStyle(fontSize: 12, color: context.mutedText)),
                      Text(fmtMoney(e.value.$2, e.key), style: const TextStyle(fontWeight: FontWeight.w700, color: C.red)),
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
                  width: 120,
                  height: 120,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CustomPaint(
                      painter: _Donut([for (final e in byStatus) (pastel(e.$1.color).fg, e.$2.toDouble())], v),
                      child: Center(child: Text('${s.projects.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(children: [
                    for (final e in byStatus)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: pastel(e.$1.color).fg, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.$1.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text('${e.$2}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                ? Text('Finish a few to-dos and you’ll see which categories take your time.', style: TextStyle(color: context.mutedText, height: 1.5))
                : Column(children: [
                    for (final e in byCat.where((e) => e.$2 > 0))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          IconTile(icon: e.$1.icon, color: e.$1.color, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(e.$1.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                                Text('${(e.$2 * 100 / catTotal).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: pastel(e.$1.color).fg)),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: e.$2 / catTotal, minHeight: 6, color: pastel(e.$1.color).fg, backgroundColor: pastel(e.$1.color).bg)),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
          ),
          const Label('All time'),
          Row(children: [
            _Kpi(value: '${s.projects.length}', label: 'Projects', icon: Icons.work_outline, color: 12),
            const SizedBox(width: 10),
            _Kpi(value: '${done.length}', label: 'To-dos done', icon: Icons.check_circle_outline, color: 8),
            const SizedBox(width: 10),
            _Kpi(value: '${s.notes.length}', label: 'Notes', icon: Icons.sticky_note_2_outlined, color: 6),
          ]),
          ])),
        ]),
      ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final int color;
  const _Kpi({required this.value, required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return Expanded(
      child: Box(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: p.fg, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final Color color;
  const _Bars({required this.values, required this.labels, required this.color});
  @override
  Widget build(BuildContext context) {
    final maxV = math.max(1, values.fold<int>(0, math.max));
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(values[i] == 0 ? '' : '${values[i]}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.mutedText)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 6 + 110 * values[i] / maxV),
                duration: Duration(milliseconds: 500 + i * 50),
                curve: Curves.easeOutCubic,
                builder: (_, h, __) => Container(
                height: h,
                decoration: BoxDecoration(color: i == values.length - 1 ? color : color.withOpacity(0.28), borderRadius: BorderRadius.circular(8)),
              )),
              const SizedBox(height: 6),
              Text(labels[i], style: TextStyle(fontSize: 11.5, color: context.mutedText, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);
  }
}

class _Donut extends CustomPainter {
  final List<(Color, double)> parts;
  final double progress;
  _Donut(this.parts, [this.progress = 1]);
  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold<double>(0, (a, b) => a + b.$2);
    if (total == 0) return;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 9);
    var start = -math.pi / 2;
    for (final p in parts) {
      final sweep = 2 * math.pi * p.$2 / total * progress;
      canvas.drawArc(rect, start + 0.04, math.max(0.0, sweep - 0.08), false, Paint()
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
