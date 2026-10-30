import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/focus_service.dart';
import '../services/notify_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';

/// Focus timer. It keeps running when you leave this page or close the app,
/// with a live countdown and Pause / +5 min / Stop in the notification panel.
class FocusScreen extends StatefulWidget {
  final String? todoId;
  const FocusScreen({super.key, this.todoId});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with TickerProviderStateMixin {
  late final AnimationController orbs = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  String mode = 'focus';
  late int minutes = Prefs.instance.focusMinutes;
  String? todoId;
  String label = '';

  static const _modes = [('focus', 'Focus', Icons.bolt_rounded), ('short', 'Short break', Icons.coffee_rounded), ('long', 'Long break', Icons.spa_rounded)];

  @override
  void initState() {
    super.initState();
    final f = FocusService.instance;
    todoId = widget.todoId ?? (f.active ? f.todoId : null);
    if (f.active) {
      mode = f.mode;
      label = f.label;
      minutes = (f.totalMs / 60000).round();
    }
    f.onFinished = _finished;
  }

  @override
  void dispose() {
    if (FocusService.instance.onFinished == _finished) FocusService.instance.onFinished = null;
    orbs.dispose();
    pulse.dispose();
    super.dispose();
  }

  int _defaultFor(String m) => switch (m) { 'short' => 5, 'long' => 15, _ => Prefs.instance.focusMinutes };

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    final s = context.read<Store>();
    final t = todoId == null ? null : s.todos.where((x) => x.id == todoId).firstOrNull;
    final ok = await NotifyService.enabled();
    if (!ok) await NotifyService.requestPermission();
    await FocusService.instance.start(minutes: minutes, mode: mode, label: t?.title ?? label, todoId: todoId);
  }

  Future<void> _finished(String m, String? tid) async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final s = context.read<Store>();
    final t = tid == null ? null : s.todos.where((x) => x.id == tid).firstOrNull;
    final wasFocus = m == 'focus';
    final next = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        icon: Text(wasFocus ? '🎉' : '☕', style: const TextStyle(fontSize: 40)),
        title: Text(wasFocus ? 'Session done' : 'Break’s over'),
        content: Text(t != null && wasFocus && !t.done ? 'Mark “${t.title}” as done?' : (wasFocus ? 'Great focus. Take a short break?' : 'Ready for another round?'), textAlign: TextAlign.center),
        actions: [
          if (t != null && wasFocus && !t.done)
            TextButton(onPressed: () => Navigator.pop(d, 'done'), child: const Text('Mark done')),
          TextButton(onPressed: () => Navigator.pop(d, ''), child: const Text('Close')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, wasFocus ? 'short' : 'focus'),
            child: Text(wasFocus ? 'Start break' : 'Focus again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (next == 'done' && t != null) await s.toggleTodo(t);
    if (next == 'short' || next == 'focus') {
      setState(() {
        mode = next!;
        minutes = _defaultFor(next);
      });
      await _start();
    } else {
      setState(() {});
    }
  }

  Future<void> _pickTask() async {
    final s = context.read<Store>();
    final open = s.todos.where((t) => !t.done).take(40).toList();
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 16), children: [
            const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text('What are you working on?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Type a name'), onTap: () => Navigator.pop(c, '__type')),
            if (todoId != null || label.isNotEmpty) ListTile(leading: const Icon(Icons.close_rounded), title: const Text('Nothing in particular'), onTap: () => Navigator.pop(c, '__none')),
            if (open.isNotEmpty) const Divider(),
            for (final t in open)
              ListTile(
                leading: Icon(Icons.radio_button_unchecked_rounded, color: priorityColor(t.priority)),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                selected: t.id == todoId,
                onTap: () => Navigator.pop(c, t.id),
              ),
          ]),
        ),
      ),
    );
    if (v == null || !mounted) return;
    if (v == '__none') {
      setState(() {
        todoId = null;
        label = '';
      });
    } else if (v == '__type') {
      final t = await askText(context, title: 'Working on', hint: 'e.g. Logo concepts', initial: label);
      if (t != null) {
        setState(() {
          label = t;
          todoId = null;
        });
      }
    } else {
      setState(() => todoId = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FocusService>();
    final s = context.watch<Store>();
    final a = context.accent;
    final active = f.active;
    final curMode = active ? f.mode : mode;
    final total = active ? f.totalMs : minutes * 60000;
    final left = active ? f.leftMs : total;
    final progress = active ? f.progress : 0.0;
    final t = todoId == null ? null : s.todos.where((x) => x.id == todoId).firstOrNull;
    final working = active ? f.label : (t?.title ?? label);
    final sum = f.summary;
    final hue = HSLColor.fromColor(a);
    final c1 = hue.withLightness((hue.lightness * 0.85).clamp(0.2, 0.5)).toColor();
    final c2 = hue.withHue((hue.hue + (curMode == 'focus' ? 35 : -60)) % 360).withLightness(0.32).toColor();
    final c3 = Color.lerp(a, Colors.black, 0.62)!;
    final endsAt = DateTime.now().add(Duration(milliseconds: left));
    final status = f.running ? 'Ends at ${TimeOfDay.fromDateTime(endsAt).format(context)}' : (f.paused ? 'Paused' : 'Ready when you are');

    if (deskWide(context)) {
      const ink = Color(0xFF2A2170), soft = Color(0xFF4F4596);
      final muted = context.mutedText;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final log = [
        for (final e in (f.ready ? FocusEngine.log(f.p) : const <String>[]))
          if (e.split('|').length >= 3) e.split('|'),
      ].map((x) => (DateTime.fromMillisecondsSinceEpoch(int.tryParse(x[0]) ?? 0), int.tryParse(x[1]) ?? 0, x[2])).where((x) => !x.$1.isBefore(today)).toList().reversed.toList();
      final next = (s.todos.where((t) => !t.done).toList()
            ..sort((x, y) => (x.deadline ?? DateTime(9999)).compareTo(y.deadline ?? DateTime(9999))))
          .take(5)
          .toList();
      Widget modeBtn((String, String, IconData) m) {
        final on = curMode == m.$1;
        return DeskHover(
          onTap: active ? null : () => setState(() {
                mode = m.$1;
                minutes = _defaultFor(m.$1);
              }),
          radius: 99,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? Colors.white : Colors.white.withOpacity(0.45), borderRadius: BorderRadius.circular(99)),
            child: Text(m.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? ink : soft.withOpacity(active && !on ? 0.5 : 1))),
          ),
        );
      }
      Widget lenBtn(String label, bool on, VoidCallback? onTap) => DeskHover(
            onTap: onTap,
            radius: 10,
            child: Container(
              height: 36,
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? ink : Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : ink)),
            ),
          );
      Widget glassBtn(String t, VoidCallback onTap) => Material(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Container(height: 44, padding: EdgeInsets.symmetric(horizontal: 18), alignment: Alignment.center, child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: context.selInk)))),
          );
      final hero = Container(
        constraints: const BoxConstraints(minHeight: 560),
        padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE9E2FF), Color(0xFFDCE3FF), Color(0xFFE6F0FF)], stops: [0, 0.55, 1]),
          boxShadow: const [BoxShadow(color: Color(0x14281E6E), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Focus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(width: 14),
            for (final m in _modes) ...[modeBtn(m), const SizedBox(width: 8)],
            const Spacer(),
            Text('${sum.$1} today · ${sum.$2 ~/ 60}h ${sum.$2 % 60}m', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: soft)),
          ]),
          const SizedBox(height: 70),
          DeskHover(
            onTap: active ? null : _pickTask,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: working.isEmpty ? 'Working on ' : 'Working on '),
                TextSpan(text: working.isEmpty ? 'pick a to-do…' : working, style: const TextStyle(color: ink, decoration: TextDecoration.underline, decorationColor: Color(0x554F4596))),
              ]),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: soft),
            ),
          ),
          const SizedBox(height: 12),
          Text(FocusEngine.fmt(left), style: const TextStyle(fontSize: 132, height: 1, fontWeight: FontWeight.w800, letterSpacing: -5, color: ink, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 16),
          SizedBox(
            width: 560,
            child: Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: progress, minHeight: 10, color: a, backgroundColor: const Color(0x243B2E8F)))),
              const SizedBox(width: 12),
              Text(status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: soft)),
            ]),
          ),
          const SizedBox(height: 70),
          Row(children: [
            SizedBox(
              width: 170,
              child: DeskBtn(f.running ? 'Pause' : (f.paused ? 'Resume' : 'Start'), kind: 'primary', height: 44, icon: f.running ? Icons.pause_rounded : Icons.play_arrow_rounded, onTap: () {
                if (f.running) {
                  f.pause();
                } else if (f.paused) {
                  f.resume();
                } else {
                  _start();
                }
              }),
            ),
            if (active) ...[
              const SizedBox(width: 10),
              glassBtn('+5 min', () => f.addMinutes(5)),
              const SizedBox(width: 10),
              glassBtn('Stop', f.stop),
            ],
            const Spacer(),
            if (!active) ...[
              for (final m in const [15, 25, 45, 60, 90]) ...[lenBtn('$m', minutes == m, () => setState(() => minutes = m)), const SizedBox(width: 6)],
              lenBtn(const [15, 25, 45, 60, 90].contains(minutes) ? 'Custom' : '$minutes', !const [15, 25, 45, 60, 90].contains(minutes), () async {
                final v = await askText(context, title: 'Minutes', hint: 'e.g. 50', initial: '$minutes', number: true);
                final n = int.tryParse(v ?? '');
                if (n != null && n > 0 && n <= 600) setState(() => minutes = n);
              }),
            ],
          ]),
        ]),
      );
      return DeskScroll(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 8, child: hero),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DeskCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const DeskH('Today’s sessions'),
                  if (log.isEmpty) Text('No sessions yet today.', style: TextStyle(color: muted, fontSize: 13.5)),
                  for (var i = 0; i < log.length && i < 8; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(border: i == log.length - 1 || i == 7 ? null : const Border(bottom: BorderSide(color: deskLine))),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: log[i].$3 == 'focus' ? a : const Color(0xFF0E9384), shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(FocusEngine.modeName(log[i].$3), style: const TextStyle(fontSize: 13.5))),
                        Text('${log[i].$2} min', style: TextStyle(fontSize: 13, color: muted)),
                        SizedBox(width: 74, child: Text(TimeOfDay.fromDateTime(log[i].$1).format(context), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: muted))),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              DeskCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const DeskH('Focus on next'),
                  if (next.isEmpty) Text('No open to-dos.', style: TextStyle(color: muted, fontSize: 13.5)),
                  for (final t in next)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DeskHover(
                        onTap: active ? null : () => setState(() => todoId = t.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: todoId == t.id ? a : const Color(0xFFECEBF6), width: todoId == t.id ? 1.5 : 1),
                          ),
                          child: Row(children: [
                            Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
                            if (t.deadline != null)
                              Text(
                                t.deadline!.isBefore(today) ? 'Overdue' : fmtDue(t.deadline!),
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.deadline!.isBefore(today) ? const Color(0xFFB42318) : muted),
                              ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ]);
    }

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2, c3])),
        child: Stack(children: [
          // Drifting soft orbs
          AnimatedBuilder(
            animation: orbs,
            builder: (_, __) {
              final v = orbs.value * 2 * math.pi;
              return Stack(children: [
                _Orb(x: 0.15 + 0.08 * math.sin(v), y: 0.18 + 0.05 * math.cos(v), r: 170, color: Colors.white.withOpacity(0.10)),
                _Orb(x: 0.92 + 0.06 * math.cos(v * 1.3), y: 0.42 + 0.06 * math.sin(v), r: 210, color: c2.withOpacity(0.55)),
                _Orb(x: 0.30 + 0.07 * math.cos(v * 0.8), y: 0.92 + 0.04 * math.sin(v * 1.2), r: 190, color: Colors.white.withOpacity(0.07)),
              ]);
            },
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  _Glass(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
                  const Spacer(),
                  _Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 17),
                      const SizedBox(width: 6),
                      Text('${sum.$1} today · ${sum.$2} min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              // Modes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Glass(
                  padding: const EdgeInsets.all(4),
                  child: Row(children: [
                    for (final m in _modes)
                      Expanded(
                        child: GestureDetector(
                          onTap: active
                              ? null
                              : () => setState(() {
                                    mode = m.$1;
                                    minutes = _defaultFor(m.$1);
                                  }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: curMode == m.$1 ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(m.$3, size: 16, color: curMode == m.$1 ? c1 : Colors.white.withOpacity(active ? 0.45 : 0.85)),
                              const SizedBox(width: 5),
                              Flexible(child: Text(m.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: curMode == m.$1 ? c1 : Colors.white.withOpacity(active ? 0.45 : 0.85)))),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const Spacer(),
              // Ring
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) {
                  final glow = f.running ? 0.25 + 0.2 * pulse.value : 0.12;
                  return Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withOpacity(glow), blurRadius: 60, spreadRadius: 4)]),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, p, __) => CustomPaint(
                        painter: _Ring(progress: p),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(FocusEngine.modeName(curMode).toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5, letterSpacing: 2, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(FocusEngine.fmt(left), style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.w700, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
                            const SizedBox(height: 4),
                            Text(status, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              // What you're working on
              _Glass(
                onTap: active ? null : _pickTask,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(working.isEmpty ? Icons.add_task_rounded : Icons.track_changes_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: Text(working.isEmpty ? 'What are you working on?' : working, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // Session dots (4 sessions = a long break)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i < sum.$1 % 4 || (sum.$1 > 0 && sum.$1 % 4 == 0) ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(i < sum.$1 % 4 || (sum.$1 > 0 && sum.$1 % 4 == 0) ? 0.95 : 0.3), borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              const Spacer(),
              // Length chips (only before starting)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: active
                    ? Padding(
                        key: const ValueKey('tip'),
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text('Keeps running if you leave. Pause or stop it from your notification panel too.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5, height: 1.4)),
                      )
                    : SizedBox(
                        key: const ValueKey('chips'),
                        height: 42,
                        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                          for (final m in curMode == 'focus' ? const [15, 25, 45, 60, 90] : const [5, 10, 15, 20, 30])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Glass(
                                selected: minutes == m,
                                onTap: () => setState(() => minutes = m),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Text('$m min', style: TextStyle(color: minutes == m ? c1 : Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          _Glass(
                            onTap: () async {
                              final v = await askText(context, title: 'Minutes', hint: 'e.g. 50', initial: '$minutes', number: true);
                              final n = int.tryParse(v ?? '');
                              if (n != null && n > 0 && n <= 600) setState(() => minutes = n);
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 17),
                          ),
                        ]),
                      ),
              ),
              const SizedBox(height: 18),
              // Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(children: [
                  _CircleBtn(
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop',
                    enabled: active,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      f.stop();
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 62,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: c1, shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (f.running) {
                            f.pause();
                          } else if (f.paused) {
                            f.resume();
                          } else {
                            _start();
                          }
                        },
                        icon: Icon(f.running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                        label: Text(f.running ? 'Pause' : (f.paused ? 'Resume' : 'Start')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _CircleBtn(
                    label: '+5',
                    tooltip: 'Add 5 minutes',
                    enabled: active,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      f.addMinutes(5);
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double x, y, r;
  final Color color;
  const _Orb({required this.x, required this.y, required this.r, required this.color});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: size.width * x - r,
      top: size.height * y - r,
      child: Container(width: r * 2, height: r * 2, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0)]))),
    );
  }
}

/// Frosted pill used across the focus page.
class _Glass extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool selected;
  const _Glass({required this.child, this.onTap, this.padding = const EdgeInsets.all(11), this.selected = false});
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Colors.white : Colors.white.withOpacity(0.14),
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.18))),
        child: InkWell(customBorder: const StadiumBorder(), onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class _CircleBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  const _CircleBtn({this.icon, this.label, required this.tooltip, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.35,
          child: Material(
            color: Colors.white.withOpacity(0.16),
            shape: CircleBorder(side: BorderSide(color: Colors.white.withOpacity(0.22))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: 58,
                height: 58,
                child: Center(child: icon != null ? Icon(icon, color: Colors.white, size: 26) : Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
              ),
            ),
          ),
        ),
      );
}

/// Ring with 60 ticks, a soft track and a glowing end dot.
class _Ring extends CustomPainter {
  final double progress;
  _Ring({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;
    // ticks
    for (var i = 0; i < 60; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 60;
      final long = i % 5 == 0;
      final p1 = c + Offset(math.cos(ang), math.sin(ang)) * (r + 10);
      final p2 = c + Offset(math.cos(ang), math.sin(ang)) * (r + (long ? 3 : 6));
      canvas.drawLine(p1, p2, Paint()
        ..color = Colors.white.withOpacity(i / 60 <= progress ? 0.9 : 0.25)
        ..strokeWidth = long ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round);
    }
    final rect = Rect.fromCircle(center: c, radius: r - 10);
    canvas.drawArc(rect, 0, 2 * math.pi, false, Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(startAngle: 0, endAngle: 2 * math.pi, colors: [Colors.white.withOpacity(0.55), Colors.white], transform: const GradientRotation(-math.pi / 2)).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    final end = -math.pi / 2 + sweep;
    final dot = c + Offset(math.cos(end), math.sin(end)) * (r - 10);
    canvas.drawCircle(dot, 13, Paint()..color = Colors.white.withOpacity(0.25));
    canvas.drawCircle(dot, 7.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _Ring o) => o.progress != progress;
}
