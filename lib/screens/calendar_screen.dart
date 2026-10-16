import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
