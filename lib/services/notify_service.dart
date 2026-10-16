import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'prefs.dart';

/// Phone notifications: to-do / project reminders and "update ready" alerts.
class NotifyService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Set by main.dart: what to do when the user taps an "update" notification.
  static void Function()? onOpenUpdate;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: (r) {
      if (r.payload == 'update') onOpenUpdate?.call();
    });
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  static const _reminders = AndroidNotificationDetails('reminders', 'Reminders',
      channelDescription: 'Reminders for to-dos and projects', importance: Importance.high, priority: Priority.high);
  static const _updates = AndroidNotificationDetails('updates', 'App updates',
      channelDescription: 'Tells you when a new version of TaskOra is ready', importance: Importance.high, priority: Priority.high);

  static Future<void> scheduleFor(String id, String title, String body, DateTime? when) async {
    await cancelFor(id);
    if (when == null || !Prefs.instance.remindersOn || when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        _idFor(id),
        title.isEmpty ? 'Reminder' : title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(android: _reminders),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'item:$id',
      );
    } catch (e) {
      debugPrint('Reminder not scheduled: $e');
    }
  }

  static Future<void> cancelFor(String id) => _plugin.cancel(_idFor(id));

  static const _general = AndroidNotificationDetails('general', 'TaskOra', channelDescription: 'Backups, sync and other app news', importance: Importance.defaultImportance, priority: Priority.defaultPriority);

  /// Shows any in-app notice in the phone's notification panel too.
  static Future<void> showNotice(String title, String body) async {
    try {
      await _plugin.show(DateTime.now().millisecondsSinceEpoch & 0x7fffffff, title, body, const NotificationDetails(android: _general), payload: 'notice');
    } catch (_) {}
  }

  static Future<void> showUpdate(String version, String summary) => _plugin.show(
        777,
        'TaskOra $version is ready',
        summary.isEmpty ? 'Tap to see what’s new and update.' : summary,
        const NotificationDetails(android: _updates),
        payload: 'update',
      );
}
