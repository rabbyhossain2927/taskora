import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/focus_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';

/// Stats: what you finished, added and focused on, with charts.
/// Week / Month / Quarter / Year, or any From–To range; compared with the
/// same length of time just before.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

// Chart colours (soft, readable on white and dark).
const _violet = Color(0xFF8B7CF6), _pink = Color(0xFFF49AC1), _teal = Color(0xFF5FC8B8), _amber = Color(0xFFF6C36B);
const _blue = Color(0xFF9CC3FF), _green = Color(0xFF8FDDB4), _grey = Color(0xFFD9D6E6), _rose = Color(0xFFF7C7E0);
const _chartCols = [_violet, _teal, _amber, _pink, _blue, _green, _rose, _grey];

class _StatsScreenState extends State<StatsScreen> {
  String period = 'month';
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
    final f = context.watch<FocusService>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final muted = context.mutedText;

    // ---------- the time range and its buckets ----------
    late DateTime from, to; // to = exclusive
    if (period == 'custom' && custom != null) {
      from = DateTime(custom!.start.year, custom!.start.month, custom!.start.day);
      to = DateTime(custom!.end.year, custom!.end.month, custom!.end.day).add(const Duration(days: 1));
    } else {
      to = today.add(const Duration(days: 1));
      from = switch (period) {
        'week' => today.subtract(const Duration(days: 6)),
        'quarter' => today.subtract(const Duration(days: 90)),
        'year' => DateTime(now.year - 1, now.month + 1, 1),
        _ => today.subtract(const Duration(days: 29)),
      };
    }
    final days = to.difference(from).inDays;
    final prevFrom = from.subtract(Duration(days: days));
    late List<DateTime> starts;
    late String Function(DateTime) label;
    if (days <= 14) {
      starts = [for (var i = 0; i < days; i++) from.add(Duration(days: i))];
      label = (d) => days <= 7 ? DateFormat('E').format(d).substring(0, 2) : '${d.day}';
    } else if (days <= 120) {
      starts = [for (var d = from; d.isBefore(to); d = d.add(const Duration(days: 7))) d];
      label = (d) => DateFormat('d MMM').format(d);
    } else {
      starts = [for (var d = DateTime(from.year, from.month, 1); d.isBefore(to); d = DateTime(d.year, d.month + 1, 1)) d];
      starts[0] = from;
      label = (d) => DateFormat('MMM').format(d);
    }
    DateTime endOf(int i) => i + 1 < starts.length ? starts[i + 1] : to;
    bool inR(DateTime? d) => d != null && !d.isBefore(from) && d.isBefore(to);
    bool inPrev(DateTime? d) => d != null && !d.isBefore(prevFrom) && d.isBefore(from);
    List<int> bucket(Iterable<DateTime> dates) => [for (var i = 0; i < starts.length; i++) dates.where((d) => !d.isBefore(starts[i]) && d.isBefore(endOf(i))).length];

    // ---------- numbers ----------
    final doneDates = s.todos.where((t) => t.done && t.completedAt != null).map((t) => t.completedAt!).toList();
    final todosDone = doneDates.where(inR).length, todosPrev = doneDates.where(inPrev).length;
    final projDone = s.projects.where((p) => p.done && inR(p.completedAt)).toList();
    final projPrev = s.projects.where((p) => p.done && inPrev(p.completedAt)).length;
    final notesNew = s.notes.where((n) => inR(n.createdAt)).length, notesPrev = s.notes.where((n) => inPrev(n.createdAt)).length;
    final sessions = [
      for (final e in (f.ready ? FocusEngine.log(f.p) : const <String>[]))
        if (e.split('|').length >= 3 && e.split('|')[2] == 'focus') (DateTime.fromMillisecondsSinceEpoch(int.tryParse(e.split('|')[0]) ?? 0), int.tryParse(e.split('|')[1]) ?? 0),
    ];
    final focusMin = sessions.where((x) => inR(x.$1)).fold<int>(0, (a, b) => a + b.$2);
    final focusPrev = sessions.where((x) => inPrev(x.$1)).fold<int>(0, (a, b) => a + b.$2);
    final money = <String, double>{};
    for (final p in projDone.where((p) => (p.amount ?? 0) > 0)) {
      money[p.currency] = (money[p.currency] ?? 0) + p.net;
    }
    final moneyPrev = s.projects.where((p) => p.done && inPrev(p.completedAt) && (p.amount ?? 0) > 0).fold<double>(0, (a, p) => a + p.net);

    final doneSeries = bucket(doneDates);
    final addedSeries = bucket(s.todos.map((t) => t.createdAt));
    String hm(int m) => m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
    String delta(num now, num before, {String Function(num)? fmt}) {
      final d = now - before;
      if (d == 0) return 'Same as before';
      final v = fmt != null ? fmt(d.abs()) : '${d.abs().round()}';
      return '${d > 0 ? '+' : '−'}$v vs before';
    }

    final rangeText = period == 'custom' && custom != null
        ? '${DateFormat('d MMM y').format(from)} – ${DateFormat('d MMM y').format(to.subtract(const Duration(days: 1)))}'
        : '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM y').format(today)} · compared with the ${days} days before';

    // ---------- breakdowns ----------
    final active = s.projects.where((p) => !p.done).toList();
    final byStatus = [for (final st in s.statuses) (st.label, st.key == 'complete' ? s.projects.where((p) => p.done).length : active.where((p) => p.status == st.key).length)].where((e) => e.$2 > 0).toList();
    final doneTodos = s.todos.where((t) => t.done && inR(t.completedAt)).toList();
    final byCat = [for (final c in s.todoCats) (c.label, doneTodos.where((t) => t.category == c.key).length)].where((e) => e.$2 > 0).toList()..sort((a, b) => b.$2 - a.$2);
    final byFolder = [for (final sec in s.sections) (sec.title, s.notes.where((n) => n.sectionId == sec.id).length)].where((e) => e.$2 > 0).toList()..sort((a, b) => b.$2 - a.$2);
    final flow = <(String, int, Color)>[
      ('Added', s.projects.where((p) => inR(p.createdAt)).length, const Color(0xFFC9C0FF)),
      for (final st in s.statuses.where((st) => st.key != 'complete' && st.key != 'cancelled').take(3)) (st.label, active.where((p) => p.status == st.key).length, pastel(st.color).bg),
      ('Complete', projDone.length, _green),
    ];
    // Busiest days: last 12 weeks, Monday-first rows
    final weekStart = today.subtract(Duration(days: today.weekday - 1 + 7 * 11));
    final heat = List.generate(7, (r) => List.generate(12, (c) {
          final d = weekStart.add(Duration(days: c * 7 + r));
          return d.isAfter(today) ? -1 : doneDates.where((x) => x.year == d.year && x.month == d.month && x.day == d.day).length;
        }));
    final perWeekday = List.generate(7, (i) => doneDates.where((d) => d.weekday == i + 1).length);
    final busiest = perWeekday.every((v) => v == 0) ? null : DateFormat('EEEE').format(DateTime(2024, 1, 1 + perWeekday.indexOf(perWeekday.reduce(math.max)))); // 1 Jan 2024 = Monday
    final focusByDay = List.generate(7, (i) => sessions.where((x) => inR(x.$1) && x.$1.weekday == i + 1).fold<int>(0, (a, b) => a + b.$2));

    // ---------- pieces ----------
    final kpis = <Widget>[
      _Kpi('To-dos done', '$todosDone', delta(todosDone, todosPrev), const Color(0xFFE3F7EC), const Color(0xFF2FA36B), doneSeries),
      _Kpi('Projects completed', '${projDone.length}', delta(projDone.length, projPrev), const Color(0xFFEFEBFF), const Color(0xFF6E5CE6), bucket(projDone.map((p) => p.completedAt!))),
      _Kpi('Notes written', '$notesNew', delta(notesNew, notesPrev), const Color(0xFFFFF3DC), const Color(0xFFC98A12), bucket(s.notes.map((n) => n.createdAt))),
      _Kpi('Focus time', hm(focusMin), delta(focusMin, focusPrev, fmt: (v) => hm(v.round())), const Color(0xFFF5E9FF), const Color(0xFF9B4FD6), bucket([for (final x in sessions) for (var k = 0; k < (x.$2 / 25).ceil(); k++) x.$1])),
      _Kpi(
        'Earned',
        money.isEmpty ? '—' : money.entries.map((e) => fmtMoney(e.value, e.key)).join(' · '),
        money.isEmpty ? 'From completed projects' : delta(money.values.fold<double>(0, (a, b) => a + b), moneyPrev, fmt: (v) => v.round().toString()),
        const Color(0xFFE6F1FF),
        const Color(0xFF3E7BFA),
        bucket(projDone.where((p) => (p.amount ?? 0) > 0).map((p) => p.completedAt!)),
      ),
    ];

    Widget legendRow(String l, String v, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        );
    Widget donutCard(String title, List<(String, int)> data, String centerLabel, {bool percent = false}) {
      final total = data.fold<int>(0, (a, b) => a + b.$2);
      return _Card(
        title: title,
        child: total == 0
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Nothing here yet.', style: TextStyle(color: muted)))
            : Row(children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(size: const Size(130, 130), painter: _Donut([for (var i = 0; i < data.length; i++) (data[i].$2.toDouble(), _chartCols[i % _chartCols.length])])),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(centerLabel, style: TextStyle(fontSize: 11, color: muted)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(children: [
                    for (var i = 0; i < data.length && i < 6; i++)
                      legendRow(data[i].$1, percent ? '${(100 * data[i].$2 / total).round()}%' : '${data[i].$2}', _chartCols[i % _chartCols.length]),
                  ]),
                ),
              ]),
      );
    }

    final activity = _Card(
      title: 'Activity flow',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 3, color: _violet),
        Text('  Done   ', style: TextStyle(fontSize: 11.5, color: muted)),
        Container(width: 14, height: 3, color: _pink),
        Text('  Added', style: TextStyle(fontSize: 11.5, color: muted)),
      ]),
      child: Column(children: [
        SizedBox(height: 190, width: double.infinity, child: CustomPaint(painter: _Area(doneSeries, addedSeries, context.isDark))),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < starts.length; i++)
            Expanded(
              child: Text(starts.length > 8 && i % (starts.length / 6).ceil() != 0 ? '' : label(starts[i]),
                  textAlign: i == 0 ? TextAlign.left : (i == starts.length - 1 ? TextAlign.right : TextAlign.center), maxLines: 1, style: TextStyle(fontSize: 10.5, color: muted)),
            ),
        ]),
      ]),
    );

    final flowCard = _Card(
      title: 'Project flow',
      subtitle: 'Added in this time, where active projects are now, and what you completed',
      child: SizedBox(
        height: 190,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < flow.length; i++) ...[
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 40 + 110.0 * flow[i].$2 / math.max(1, flow.map((e) => e.$2).reduce(math.max)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.isDark ? flow[i].$3.withOpacity(0.35) : flow[i].$3, borderRadius: BorderRadius.circular(14)),
                  child: Text('${flow[i].$2}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2A2A3A))),
                ),
                const SizedBox(height: 8),
                Text(flow[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (i < flow.length - 1) Padding(padding: const EdgeInsets.only(bottom: 30, left: 4, right: 4), child: Icon(Icons.arrow_forward_rounded, size: 18, color: muted)),
          ],
        ]),
      ),
    );

    final foldersCard = _Card(
      title: 'Notes by folder',
      child: byFolder.isEmpty
          ? Text('No notes in folders yet.', style: TextStyle(color: muted))
          : Column(children: [
              for (var i = 0; i < byFolder.length && i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [Expanded(child: Text(byFolder[i].$1, style: const TextStyle(fontSize: 13))), Text('${byFolder[i].$2}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
                    const SizedBox(height: 5),
                    deskBar(byFolder[i].$2 / byFolder.first.$2, _chartCols[i % _chartCols.length], h: 8),
                  ]),
                ),
            ]),
    );

    final heatCard = _Card(
      title: 'Your busiest days',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var r = 0; r < 7; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              SizedBox(width: 18, child: Text('MTWTFSS'[r], style: TextStyle(fontSize: 10, color: muted))),
              for (var c = 0; c < 12; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: heat[r][c] < 0
                              ? Colors.transparent
                              : [context.isDark ? Colors.white10 : const Color(0xFFF1EFFB), const Color(0xFFDDD6FF), const Color(0xFFB9ACFA), _violet, const Color(0xFF6E5CE6)][math.min(4, heat[r][c])],
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 6),
        Text(busiest == null ? 'Finish some to-dos to see your rhythm.' : 'You get the most done on ${busiest}s', style: TextStyle(fontSize: 12, color: muted)),
      ]),
    );

    final maxFocus = math.max(1, focusByDay.reduce(math.max));
    final focusCard = _Card(
      title: 'Focus time',
      child: Column(children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 36, child: Text(DateFormat('E').format(DateTime(2024, 1, 1 + i)), style: TextStyle(fontSize: 12.5, color: muted))),
              Expanded(child: deskBar(focusByDay[i] / maxFocus, _violet, h: 10)),
              SizedBox(width: 64, child: Text(focusByDay[i] == 0 ? '—' : hm(focusByDay[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
            ]),
          ),
      ]),
    );

    final status = donutCard('Projects by status', byStatus, 'projects');
    final cats = donutCard('To-dos by category', byCat, 'done', percent: true);
    final periodItems = const [('week', 'Week'), ('month', 'Month'), ('quarter', 'Quarter'), ('year', 'Year'), ('custom', 'Custom')];
    void pick(String v) => v == 'custom' ? _pickRange() : setState(() => period = v);

    // ---------- computers ----------
    if (deskWide(context)) {
      Widget row(List<(int, Widget)> cells) => IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: 18), Expanded(flex: cells[i].$1, child: cells[i].$2)],
            ]),
          );
      return DeskScroll(children: [
        DeskHead('Your stats', subtitle: rangeText, actions: [DeskSeg<String>(items: periodItems, value: period, onChanged: pick)]),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < kpis.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: kpis[i])]]),
        const SizedBox(height: 18),
        row([(8, activity), (4, status)]),
        const SizedBox(height: 18),
        row([(8, flowCard), (4, cats)]),
        const SizedBox(height: 18),
        row([(4, foldersCard), (4, heatCard), (4, focusCard)]),
      ]);
    }

    // ---------- phones ----------
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Your stats'),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              for (final it in periodItems) Padding(padding: const EdgeInsets.only(right: 8), child: DeskFilter(it.$2, on: period == it.$1, onTap: () => pick(it.$1))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(22, 10, 22, 12), child: Text(rangeText, style: TextStyle(fontSize: 12.5, color: muted))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: kpis.take(4).toList(),
              ),
              const SizedBox(height: 10),
              kpis[4],
              for (final w in [activity, status, cats, flowCard, foldersCard, heatCard, focusCard]) ...[const SizedBox(height: 12), w],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const _Card({required this.title, this.subtitle, this.trailing, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: softCard(20, context.surface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))), if (trailing != null) trailing!]),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: TextStyle(fontSize: 12, color: context.mutedText))),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _Kpi extends StatelessWidget {
  final String label, value, delta;
  final Color bg, fg;
  final List<int> series;
  const _Kpi(this.label, this.value, this.delta, this.bg, this.fg, this.series);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: softCard(20, context.surface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: context.isDark ? fg.withOpacity(0.2) : bg, borderRadius: BorderRadius.circular(9)), child: Center(child: Container(width: 9, height: 9, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)))),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.mutedText))),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
                Text(delta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: delta.startsWith('−') ? const Color(0xFFD9731A) : (delta.startsWith('+') ? const Color(0xFF1E7A50) : context.mutedText))),
              ]),
            ),
            if (series.length > 1) SizedBox(width: 70, height: 28, child: CustomPaint(painter: _Spark(series, fg))),
          ]),
        ]),
      );
}

/// Ring chart.
class _Donut extends CustomPainter {
  final List<(double, Color)> parts;
  _Donut(this.parts);
  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold<double>(0, (a, b) => a + b.$1);
    if (total == 0) return;
    const th = 18.0;
    final rect = Rect.fromLTWH(th / 2, th / 2, size.width - th, size.height - th);
    var start = -math.pi / 2;
    for (final p in parts) {
      final sweep = 2 * math.pi * p.$1 / total;
      canvas.drawArc(rect, start + 0.03, math.max(0.001, sweep - 0.06), false, Paint()
        ..color = p.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = th
        ..strokeCap = StrokeCap.butt);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut o) => true;
}

/// Smooth "done" area + dashed "added" line.
class _Area extends CustomPainter {
  final List<int> a, b;
  final bool dark;
  _Area(this.a, this.b, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = dark ? Colors.white10 : const Color(0xFFEFEDF8)
      ..strokeWidth = 1;
    for (var k = 1; k < 4; k++) {
      canvas.drawLine(Offset(0, size.height * k / 4), Offset(size.width, size.height * k / 4), grid);
    }
    final n = a.length;
    if (n < 2) return;
    final mx = math.max(1, [...a, ...b].reduce(math.max)) * 1.15;
    List<Offset> pts(List<int> v) => [for (var i = 0; i < n; i++) Offset(i * size.width / (n - 1), size.height - v[i] / mx * size.height)];
    Path smooth(List<Offset> p) {
      final path = Path()..moveTo(p[0].dx, p[0].dy);
      for (var i = 1; i < p.length; i++) {
        final cx = (p[i - 1].dx + p[i].dx) / 2;
        path.cubicTo(cx, p[i - 1].dy, cx, p[i].dy, p[i].dx, p[i].dy);
      }
      return path;
    }

    final pa = smooth(pts(a));
    final fill = Path.from(pa)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_violet.withOpacity(0.28), _violet.withOpacity(0)]).createShader(Offset.zero & size));
    canvas.drawPath(pa, Paint()
      ..color = _violet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    // dashed "added"
    final pb = smooth(pts(b));
    final dash = Paint()
      ..color = _pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final m in pb.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Area o) => true;
}

/// Tiny trend line for the number cards.
class _Spark extends CustomPainter {
  final List<int> v;
  final Color c;
  _Spark(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final mx = math.max(1, v.reduce(math.max));
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final p = Offset(i * size.width / (v.length - 1), size.height - 2 - v[i] / mx * (size.height - 4));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _Spark o) => true;
}
