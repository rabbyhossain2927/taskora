import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';
import 'project_detail.dart';
import 'todo_editor.dart';
import 'todos_screen.dart';

/// Month view: dots on days with to-dos or project deadlines; tap a day to see them.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime selected = DateUtils.dateOnly(DateTime.now());

  int get _weekStart => switch (Prefs.instance.weekStart) { 'Sunday' => DateTime.sunday, 'Monday' => DateTime.monday, _ => DateTime.saturday };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    DateTime d0(DateTime d) => DateUtils.dateOnly(d);
    final todosOn = <DateTime, int>{};
    for (final t in s.todos.where((t) => t.deadline != null && !t.done)) {
      todosOn[d0(t.deadline!)] = (todosOn[d0(t.deadline!)] ?? 0) + 1;
    }
    final projOn = <DateTime>{for (final p in s.projects.where((p) => p.deadline != null && !p.done)) d0(p.deadline!)};

    final first = DateTime(month.year, month.month, 1);
    final lead = (first.weekday - _weekStart + 7) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = <DateTime?>[for (var i = 0; i < lead; i++) null, for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d)];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final names = [for (var i = 0; i < 7; i++) DateFormat('E').format(DateTime(2024, 1, 1 + ((_weekStart - 1 + i) % 7))).substring(0, 2)];
    final dayTodos = s.todos.where((t) => t.deadline != null && d0(t.deadline!) == selected).toList();
    final dayProjects = s.projects.where((p) => p.deadline != null && d0(p.deadline!) == selected).toList();
    final today = d0(DateTime.now());

    if (deskWide(context)) {
      final muted = context.mutedText;
      Widget navBtn(IconData ic, String tip, VoidCallback onTap) => Tooltip(
            message: tip,
            child: Material(color: context.surface, borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: SizedBox(width: 36, height: 36, child: Icon(ic, size: 20)))),
          );
      List<(String, Color, Color, VoidCallback)> eventsOn(DateTime d) => [
            for (final p in s.projects.where((p) => p.deadline != null && !p.done && d0(p.deadline!) == d))
              (p.title, pastel(p.color).bg, pastel(p.color).fg, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id)))),
            for (final t in s.todos.where((t) => t.deadline != null && !t.done && d0(t.deadline!) == d))
              (t.title, const Color(0xFFE6DEFF), const Color(0xFF5B3FD0), () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(id: t.id)))),
          ];
      final open = dayTodos.where((t) => !t.done).length;
      final late = dayTodos.where((t) => !t.done && t.deadline!.isBefore(DateTime.now())).length;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(DateFormat('MMMM y').format(month), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
                    navBtn(Icons.chevron_left_rounded, 'Previous month', () => setState(() => month = DateTime(month.year, month.month - 1))),
                    const SizedBox(width: 10),
                    DeskBtn('Today', kind: 'white', height: 36, onTap: () => setState(() {
                      month = DateTime(today.year, today.month);
                      selected = today;
                    })),
                    const SizedBox(width: 10),
                    navBtn(Icons.chevron_right_rounded, 'Next month', () => setState(() => month = DateTime(month.year, month.month + 1))),
                  ]),
                  const SizedBox(height: 14),
                  Expanded(
                    child: DeskCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                          child: Row(children: [for (final n in names) Expanded(child: Padding(padding: const EdgeInsets.only(left: 10), child: Text(n, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted))))]),
                        ),
                        for (var r = 0; r < cells.length ~/ 7; r++)
                          Expanded(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              for (var c = 0; c < 7; c++)
                                Expanded(
                                  child: Builder(builder: (_) {
                                    final d = cells[r * 7 + c];
                                    final ev = d == null ? const <(String, Color, Color, VoidCallback)>[] : eventsOn(d);
                                    final isSel = d != null && d == selected, isToday = d == today;
                                    return DeskHover(
                                      onTap: d == null ? null : () => setState(() => selected = d),
                                      radius: 0,
                                      wash: true,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSel ? (context.isDark ? Colors.white10 : const Color(0xFFF6F5FF)) : null,
                                          border: const Border(top: BorderSide(color: deskLine), left: BorderSide(color: deskLine)),
                                        ),
                                        child: d == null
                                            ? const SizedBox()
                                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  alignment: Alignment.center,
                                                  decoration: isToday ? BoxDecoration(color: context.accent, shape: BoxShape.circle) : null,
                                                  child: Text('${d.day}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isToday ? Colors.white : null)),
                                                ),
                                                const SizedBox(height: 4),
                                                for (final e in ev.take(2))
                                                  Container(
                                                    margin: const EdgeInsets.only(bottom: 3),
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(color: e.$2, borderRadius: BorderRadius.circular(6)),
                                                    child: Text(e.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: e.$3)),
                                                  ),
                                                if (ev.length > 2) Text('+${ev.length - 2} more', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted)),
                                              ]),
                                      ),
                                    );
                                  }),
                                ),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 360,
                child: DeskCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    Text(DateFormat('EEEE, d MMM').format(selected), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(dayTodos.isEmpty && dayProjects.isEmpty ? 'Nothing on this day' : '$open to-do${open == 1 ? '' : 's'}${late > 0 ? ' · $late overdue' : ''}${dayProjects.isEmpty ? '' : ' · ${dayProjects.length} project deadline${dayProjects.length == 1 ? '' : 's'}'}', style: TextStyle(fontSize: 13, color: muted)),
                    ),
                    for (final p in dayProjects)
                      DeskHover(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
                        wash: true,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: Row(children: [
                          IconTile(icon: p.icon, color: p.color, size: 30),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                          Text('Deadline', style: TextStyle(fontSize: 12, color: muted)),
                        ]),
                      ),
                    for (final t in dayTodos) TodoRow(todo: t),
                    const SizedBox(height: 10),
                    DeskBtn('+ Add to-do on this day', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(deadline: selected), fullscreenDialog: true))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          Header('Calendar', actions: [
            RoundButton(
              icon: Icons.today_rounded,
              tooltip: 'Today',
              onTap: () => setState(() {
                month = DateTime(today.year, today.month);
                selected = today;
              }),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FadeIn(
                child: Box(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  child: Column(children: [
                    Row(children: [
                      IconButton(tooltip: 'Previous month', onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
                      Expanded(child: Text(DateFormat('MMMM y').format(month), textAlign: TextAlign.center, style: const TextStyle(fontSize: T.heading, fontWeight: FontWeight.w700))),
                      IconButton(tooltip: 'Next month', onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [for (final n in names) Expanded(child: Center(child: Text(n, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.mutedText))))]),
                    const SizedBox(height: 6),
                    for (var r = 0; r < cells.length ~/ 7; r++)
                      Row(children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(
                            child: Builder(builder: (_) {
                              final d = cells[r * 7 + c];
                              if (d == null) return const SizedBox(height: 46);
                              final isSel = d == selected, isToday = d == today;
                              final n = todosOn[d] ?? 0;
                              return GestureDetector(
                                onTap: () => setState(() => selected = d),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 46,
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSel ? context.accent : (isToday ? context.tint : Colors.transparent),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text('${d.day}', style: TextStyle(fontWeight: isSel || isToday ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : (isToday ? context.onTint : null))),
                                    const SizedBox(height: 3),
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      if (n > 0) _dot(isSel ? Colors.white : context.accent),
                                      if (projOn.contains(d)) _dot(isSel ? Colors.white70 : const Color(0xFFF08C2E)),
                                    ]),
                                  ]),
                                ),
                              );
                            }),
                          ),
                      ]),
                  ]),
                ),
              ),
              Label(DateFormat('EEEE, d MMMM').format(selected),
                  trailing: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoEditor(deadline: selected), fullscreenDialog: true)),
                    child: Text('+ Add to-do', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                  )),
              if (dayTodos.isEmpty && dayProjects.isEmpty)
                Box(padding: const EdgeInsets.all(18), child: Text('Nothing on this day.', style: TextStyle(color: context.mutedText))),
              for (final p in dayProjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Box(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetail(id: p.id))),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      IconTile(icon: p.icon, color: p.color, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${p.title} · project deadline', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Icon(iconOf('flag'), size: 18, color: const Color(0xFFF08C2E)),
                    ]),
                  ),
                ),
              if (dayTodos.isNotEmpty)
                Box(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: Column(children: [for (final t in dayTodos) TodoRow(todo: t)])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
