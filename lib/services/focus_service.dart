import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notify_service.dart';

/// The focus timer's state lives in the phone's settings store, so it keeps
/// running when you leave the page or close the app, and the buttons in the
/// notification panel (Pause / Resume / +5 min / Stop) can change it even
/// while the app is closed.
class FocusEngine {
  static const _state = 'f_state', _end = 'f_end', _left = 'f_left', _total = 'f_total', _label = 'f_label', _mode = 'f_mode', _todo = 'f_todo', _log = 'f_log';
  static const ongoingId = 4242, doneId = 4243;

  static String state(SharedPreferences p) => p.getString(_state) ?? 'idle';
  static int end(SharedPreferences p) => p.getInt(_end) ?? 0;
  static int leftMs(SharedPreferences p) {
    final s = state(p);
    if (s == 'running') return (end(p) - DateTime.now().millisecondsSinceEpoch).clamp(0, 1 << 31);
    if (s == 'paused') return p.getInt(_left) ?? 0;
    return 0;
  }

  static int totalMs(SharedPreferences p) => p.getInt(_total) ?? 0;
  static String label(SharedPreferences p) => p.getString(_label) ?? '';
  static String mode(SharedPreferences p) => p.getString(_mode) ?? 'focus';
  static String? todo(SharedPreferences p) => p.getString(_todo);

  /// Finished sessions: "endedAtMs|minutes|mode"
  static List<String> log(SharedPreferences p) => p.getStringList(_log) ?? const [];

  static Future<void> start(SharedPreferences p, {required int minutes, required String mode, String label = '', String? todoId}) async {
    final ms = minutes * 60000;
    await p.setInt(_total, ms);
    await p.setInt(_end, DateTime.now().millisecondsSinceEpoch + ms);
    await p.setString(_state, 'running');
    await p.setString(_mode, mode);
    await p.setString(_label, label);
    if (todoId == null) {
      await p.remove(_todo);
    } else {
      await p.setString(_todo, todoId);
    }
    await show(p);
  }

  static Future<void> pause(SharedPreferences p) async {
    if (state(p) != 'running') return;
    await p.setInt(_left, leftMs(p));
    await p.setString(_state, 'paused');
    await show(p);
  }

  static Future<void> resume(SharedPreferences p) async {
    if (state(p) != 'paused') return;
    await p.setInt(_end, DateTime.now().millisecondsSinceEpoch + (p.getInt(_left) ?? 0));
    await p.setString(_state, 'running');
    await show(p);
  }

  static Future<void> addMinutes(SharedPreferences p, int m) async {
    final s = state(p);
    if (s == 'running') await p.setInt(_end, end(p) + m * 60000);
    if (s == 'paused') await p.setInt(_left, (p.getInt(_left) ?? 0) + m * 60000);
    if (s == 'idle') return;
    await p.setInt(_total, totalMs(p) + m * 60000);
    await show(p);
  }

  static Future<void> stop(SharedPreferences p) async {
    await p.setString(_state, 'idle');
    await NotifyService.plugin.cancel(ongoingId);
    await NotifyService.plugin.cancel(doneId);
  }

  /// Called when the time is up: logs the session and clears the timer.
  static Future<void> finish(SharedPreferences p) async {
    final minutes = (totalMs(p) / 60000).round();
    final l = List<String>.of(log(p))..add('${DateTime.now().millisecondsSinceEpoch}|$minutes|${mode(p)}');
    if (l.length > 400) l.removeRange(0, l.length - 400);
    await p.setStringList(_log, l);
    await p.setString(_state, 'idle');
    await NotifyService.plugin.cancel(ongoingId);
  }

  static Future<void> handleAction(SharedPreferences p, String action) async {
    switch (action) {
      case 'f_pause':
        await pause(p);
      case 'f_resume':
        await resume(p);
      case 'f_add5':
        await addMinutes(p, 5);
      case 'f_stop':
        await stop(p);
    }
  }

  static String fmt(int ms) {
    final s = (ms / 1000).ceil();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String modeName(String m) => switch (m) { 'short' => 'Short break', 'long' => 'Long break', _ => 'Focus' };

  /// The live notification with the countdown and buttons.
  static Future<void> show(SharedPreferences p) async {
    final s = state(p);
    await NotifyService.plugin.cancel(doneId);
    if (s == 'idle') {
      await NotifyService.plugin.cancel(ongoingId);
      return;
    }
    if (!(p.getBool('notificationsOn') ?? true) || !(p.getBool('focusAlerts') ?? true)) return;
    final running = s == 'running';
    final left = leftMs(p);
    final name = modeName(mode(p));
    final lbl = label(p);
    final details = AndroidNotificationDetails(
      'focus',
      'Focus timer',
      channelDescription: 'The running focus timer',
      icon: NotifyService.icon,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: running,
      when: running ? end(p) : null,
      usesChronometer: running,
      chronometerCountDown: running,
      timeoutAfter: running ? left + 1500 : null,
      category: AndroidNotificationCategory.stopwatch,
      showProgress: true,
      maxProgress: 100,
      progress: totalMs(p) == 0 ? 0 : (100 - left * 100 / totalMs(p)).round().clamp(0, 100),
      actions: running
          ? const [
              AndroidNotificationAction('f_pause', 'Pause', cancelNotification: false),
              AndroidNotificationAction('f_add5', '+5 min', cancelNotification: false),
              AndroidNotificationAction('f_stop', 'Stop', cancelNotification: true),
            ]
          : const [
              AndroidNotificationAction('f_resume', 'Resume', cancelNotification: false),
              AndroidNotificationAction('f_stop', 'Stop', cancelNotification: true),
            ],
    );
    await NotifyService.plugin.show(
      ongoingId,
      running ? '$name · ends ${_clock(DateTime.fromMillisecondsSinceEpoch(end(p)))}' : '$name paused · ${fmt(left)} left',
      lbl.isNotEmpty ? lbl : (running ? 'Stay with it. Your phone can wait.' : 'Tap Resume when you’re ready.'),
      NotificationDetails(android: details),
      payload: 'focus',
    );
    if (running) {
      try {
        await NotifyService.schedule(
          doneId,
          mode(p) == 'focus' ? 'Focus complete 🎉' : 'Break’s over',
          mode(p) == 'focus' ? (lbl.isNotEmpty ? '“$lbl” · time for a short break.' : 'Nice work. Time for a short break.') : 'Ready for another focus session?',
          DateTime.fromMillisecondsSinceEpoch(end(p)),
          const NotificationDetails(
            android: AndroidNotificationDetails('focus_done', 'Focus finished', channelDescription: 'When a focus session ends', icon: NotifyService.icon, importance: Importance.high, priority: Priority.high),
          ),
          payload: 'focus',
        );
      } catch (_) {}
    }
  }

  static String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// The app-side view of the timer. Ticks every second and notices changes
/// made from the notification panel.
class FocusService extends ChangeNotifier {
  static final instance = FocusService._();
  FocusService._();

  SharedPreferences? _p;
  Timer? _tick;
  int _n = 0;

  /// Called when a session ends while the app is open.
  void Function(String mode, String? todoId)? onFinished;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _ensureTicking();
  }

  SharedPreferences get p => _p!;
  bool get ready => _p != null;
  String get state => ready ? FocusEngine.state(p) : 'idle';
  bool get running => state == 'running';
  bool get paused => state == 'paused';
  bool get active => state != 'idle';
  int get leftMs => ready ? FocusEngine.leftMs(p) : 0;
  int get totalMs => ready ? FocusEngine.totalMs(p) : 0;
  double get progress => totalMs == 0 ? 0 : (1 - leftMs / totalMs).clamp(0.0, 1.0);
  String get mode => ready ? FocusEngine.mode(p) : 'focus';
  String get label => ready ? FocusEngine.label(p) : '';
  String? get todoId => ready ? FocusEngine.todo(p) : null;

  /// (sessions today, focus minutes today, focus minutes this week, all sessions)
  (int, int, int, int) get summary {
    if (!ready) return (0, 0, 0, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(const Duration(days: 6));
    var s = 0, m = 0, w = 0, all = 0;
    for (final e in FocusEngine.log(p)) {
      final parts = e.split('|');
      if (parts.length < 3 || parts[2] != 'focus') continue;
      final at = DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[0]) ?? 0);
      final min = int.tryParse(parts[1]) ?? 0;
      all++;
      if (!at.isBefore(today)) {
        s++;
        m += min;
      }
      if (!at.isBefore(week)) w += min;
    }
    return (s, m, w, all);
  }

  void _ensureTicking() {
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Future<void> _onTick() async {
    if (!ready) return;
    // Pick up taps on the notification buttons (they run separately).
    if (_n++ % 2 == 0) await p.reload();
    if (running && leftMs <= 0) {
      final m = mode, t = todoId;
      await FocusEngine.finish(p);
      onFinished?.call(m, t);
    }
    final st = state;
    if (st != 'idle' || st != _lastState) notifyListeners();
    _lastState = st;
  }

  String _lastState = 'idle';

  /// Back in the app: refresh right away.
  Future<void> refresh() async {
    if (!ready) return;
    await p.reload();
    notifyListeners();
  }

  Future<void> start({required int minutes, required String mode, String label = '', String? todoId}) async {
    await FocusEngine.start(p, minutes: minutes, mode: mode, label: label, todoId: todoId);
    notifyListeners();
  }

  Future<void> pause() async {
    await FocusEngine.pause(p);
    notifyListeners();
  }

  Future<void> resume() async {
    await FocusEngine.resume(p);
    notifyListeners();
  }

  Future<void> addMinutes(int m) async {
    await FocusEngine.addMinutes(p, m);
    notifyListeners();
  }

  Future<void> stop() async {
    await FocusEngine.stop(p);
    notifyListeners();
  }

  Future<void> handleAction(String a) async {
    await FocusEngine.handleAction(p, a);
    notifyListeners();
  }
}
