import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'focus_service.dart';
import 'prefs.dart';

/// Taps on the focus timer's buttons (Pause, Resume, +5 min, Stop) while the
/// app is closed run here, in the background.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final sp = await SharedPreferences.getInstance();
  await NotifyService.initPlugin(background: true);
  await FocusEngine.handleAction(sp, r.actionId ?? '');
}

/// Phone notifications: reminders, focus timer, update alerts, app news.
class NotifyService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Set by main.dart: what to do when the user taps an "update" notification.
  static void Function()? onOpenUpdate;
  static void Function()? onOpenFocus;

  static const icon = 'ic_stat_taskora';

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> initPlugin({bool background = false}) async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(android: AndroidInitializationSettings(icon));
    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: background ? null : _onTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static Future<void> init() async {
    if (kIsWeb) return;
    await initPlugin();
    // Create the channels up front so they appear in the phone's settings.
    final a = _android;
    if (a != null) {
      for (final c in const [
        AndroidNotificationChannel('reminders', 'Reminders', description: 'Reminders for to-dos and projects', importance: Importance.high),
        AndroidNotificationChannel('general', 'TaskOra', description: 'Backups, sync and other app news', importance: Importance.high),
        AndroidNotificationChannel('updates', 'App updates', description: 'Tells you when a new version of TaskOra is ready', importance: Importance.high),
        AndroidNotificationChannel('focus', 'Focus timer', description: 'The running focus timer', importance: Importance.low, playSound: false, enableVibration: false),
        AndroidNotificationChannel('focus_done', 'Focus finished', description: 'When a focus session ends', importance: Importance.high),
      ]) {
        await a.createNotificationChannel(c);
      }
    }
  }

  static Future<void> _onTap(NotificationResponse r) async {
    final action = r.actionId ?? '';
    if (action.isNotEmpty) {
      await FocusService.instance.handleAction(action);
      return;
    }
    final p = r.payload ?? '';
    if (p == 'update') onOpenUpdate?.call();
    if (p == 'focus') onOpenFocus?.call();
  }

  /// Asks Android for permission to show notifications (Android 13+) and
  /// to ring reminders on time. Call once the app is on screen.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final a = _android;
    if (a == null) return true;
    final ok = await a.requestNotificationsPermission() ?? false;
    return ok;
  }

  static Future<bool> enabled() async => kIsWeb ? false : await _android?.areNotificationsEnabled() ?? true;

  static Future<bool> canExact() async => kIsWeb ? true : await _android?.canScheduleExactNotifications() ?? true;
  static Future<void> askExact() async => kIsWeb ? null : _android?.requestExactAlarmsPermission();

  static Future<void> cancelAll() async => kIsWeb ? null : plugin.cancelAll();

  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  static const _reminders = AndroidNotificationDetails('reminders', 'Reminders',
      channelDescription: 'Reminders for to-dos and projects', importance: Importance.high, priority: Priority.high, icon: icon, category: AndroidNotificationCategory.reminder);
  static const _updates = AndroidNotificationDetails('updates', 'App updates',
      channelDescription: 'Tells you when a new version of TaskOra is ready', importance: Importance.high, priority: Priority.high, icon: icon);
  static const _general = AndroidNotificationDetails('general', 'TaskOra',
      channelDescription: 'Backups, sync and other app news', importance: Importance.high, priority: Priority.high, icon: icon);

  static bool get _on => Prefs.instance.notificationsOn;

  /// Schedules at an exact time; falls back to "about then" if the phone
  /// doesn't allow exact alarms.
  static Future<void> schedule(int id, String title, String body, DateTime when, NotificationDetails details, {String? payload}) async {
    if (kIsWeb) return;
    final at = tz.TZDateTime.from(when, tz.local);
    try {
      await plugin.zonedSchedule(id, title, body, at, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload);
    } catch (_) {
      await plugin.zonedSchedule(id, title, body, at, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload);
    }
  }

  static Future<void> scheduleFor(String id, String title, String body, DateTime? when) async {
    if (kIsWeb) return;
    await cancelFor(id);
    if (when == null || !_on || !Prefs.instance.remindersOn || when.isBefore(DateTime.now())) return;
    try {
      await schedule(_idFor(id), title.isEmpty ? 'Reminder' : title, body, when, const NotificationDetails(android: _reminders), payload: 'item:$id');
    } catch (e) {
      debugPrint('Reminder not scheduled: $e');
    }
  }

  static Future<void> cancelFor(String id) async => kIsWeb ? null : plugin.cancel(_idFor(id));

  /// Shows any in-app notice in the phone's notification panel too.
  static Future<void> showNotice(String title, String body) async {
    if (kIsWeb) return;
    if (!_on || !Prefs.instance.appNews) return;
    try {
      await plugin.show(DateTime.now().millisecondsSinceEpoch & 0x7fffffff, title, body, const NotificationDetails(android: _general), payload: 'notice');
    } catch (_) {}
  }

  static Future<void> showUpdate(String version, String summary) async {
    if (kIsWeb) return;
    if (!_on) return;
    await plugin.show(
      777,
      'TaskOra $version is ready',
      summary.isEmpty ? 'Tap to see what’s new and update.' : summary,
      const NotificationDetails(android: _updates),
      payload: 'update',
    );
  }

  /// "Send a test" on the notification settings page. Ignores the on/off
  /// switches so you can check the phone side works.
  static Future<void> test({int inSeconds = 0}) async {
    if (kIsWeb) return;
    const d = NotificationDetails(android: _reminders);
    if (inSeconds == 0) {
      await plugin.show(778, 'TaskOra test 🔔', 'Notifications are working on this phone.', d, payload: 'notice');
    } else {
      await schedule(779, 'TaskOra reminder test ⏰', 'This reminder was scheduled $inSeconds seconds ago.', DateTime.now().add(Duration(seconds: inSeconds)), d, payload: 'notice');
    }
  }
}
