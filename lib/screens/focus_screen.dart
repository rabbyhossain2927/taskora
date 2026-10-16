import 'dart:ui' show FontFeature;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../widgets/common.dart';

/// Simple focus timer. Optionally linked to a to-do.
class FocusScreen extends StatefulWidget {
  final String? todoId;
  const FocusScreen({super.key, this.todoId});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late int total = Prefs.instance.focusMinutes * 60;
  late int left = total;
  Timer? timer;
  bool get running => timer != null;

  void _toggle() {
    if (running) {
      timer!.cancel();
      setState(() => timer = null);
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left <= 1) {
        timer?.cancel();
        timer = null;
        HapticFeedback.heavyImpact();
        setState(() => left = 0);
        _finished();
      } else {
        setState(() => left--);
      }
    });
    setState(() {});
  }

  Future<void> _finished() async {
    final s = context.read<Store>();
    final t = widget.todoId == null ? null : s.todos.where((x) => x.id == widget.todoId).firstOrNull;
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Session done 🎉'),
        content: Text(t == null ? 'Nice focus. Take a short break.' : 'Mark “${t.title}” as done?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(t == null ? 'OK' : 'Not yet')),
          if (t != null && !t.done)
            TextButton(
              onPressed: () {
                s.toggleTodo(t);
                Navigator.pop(d);
              },
              child: const Text('Mark done'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final t = widget.todoId == null ? null : s.todos.where((x) => x.id == widget.todoId).firstOrNull;
    final mm = (left ~/ 60).toString().padLeft(2, '0'), ss = (left % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: const Color(0xFF15151B),
      body: SafeArea(
        child: Column(children: [
          Theme(
            data: Theme.of(context).copyWith(textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white)),
            child: Header('Focus', actions: const []),
          ),
          const Spacer(),
          if (t != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(t.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(value: total == 0 ? 0 : left / total, strokeWidth: 12, color: context.accent, backgroundColor: Colors.white10, strokeCap: StrokeCap.round)),
              Text('$mm:$ss', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
          const SizedBox(height: 30),
          Wrap(spacing: 8, children: [
            for (final m in [15, 25, 45, 60])
              ChoiceChip(
                label: Text('$m min'),
                selected: total == m * 60,
                onSelected: running
                    ? null
                    : (_) => setState(() {
                          total = m * 60;
                          left = total;
                        }),
              ),
          ]),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
            child: Row(children: [
              IconButton.filledTonal(
                tooltip: 'Reset',
                onPressed: () {
                  timer?.cancel();
                  setState(() {
                    timer = null;
                    left = total;
                  });
                },
                icon: const Icon(Icons.restart_alt_rounded),
                iconSize: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(running ? 'Pause' : (left == total ? 'Start' : 'Resume')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
