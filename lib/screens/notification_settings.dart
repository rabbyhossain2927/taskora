import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notify_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Turn notifications on or off, check the phone allows them, and send a test.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  bool? allowed;
  bool? exact;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(); // back from phone settings
  }

  Future<void> _check() async {
    final a = await NotifyService.enabled();
    final e = await NotifyService.canExact();
    if (mounted) {
      setState(() {
        allowed = a;
        exact = e;
      });
    }
  }

  /// Reminders are re-scheduled after switching things back on.
  Future<void> _reschedule() async {
    final s = context.read<Store>();
    for (final t in s.todos) {
      await NotifyService.scheduleFor(t.id, t.title, 'To-do reminder', t.done ? null : t.reminder);
    }
    for (final p in s.projects) {
      await NotifyService.scheduleFor(p.id, p.title, 'Project reminder', p.reminder);
    }
  }

  Widget _switch(String title, bool v, ValueChanged<bool> set, {String? sub, IconData? icon, int color = 0, bool enabled = true}) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: RowTile(icon: icon, color: color, title: title, subtitle: sub, trailing: Switch(value: v && enabled, onChanged: enabled ? set : null)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Prefs>();
    final on = p.notificationsOn;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Notification settings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Master switch
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: on ? LinearGradient(colors: [Color.lerp(context.accent, Colors.white, 0.1)!, context.accent]) : null,
                  color: on ? null : context.surface,
                ),
                child: Row(children: [
                  Icon(on ? Icons.notifications_active_rounded : Icons.notifications_off_outlined, color: on ? Colors.white : context.mutedText, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: on ? Colors.white : null)),
                      Text(on ? 'On for this phone' : 'All TaskOra notifications are off', style: TextStyle(fontSize: 12.5, color: on ? Colors.white70 : context.mutedText)),
                    ]),
                  ),
                  Switch(
                    value: on,
                    activeTrackColor: Colors.white.withOpacity(0.35),
                    onChanged: (v) async {
                      p.notificationsOn = v;
                      if (v) {
                        await NotifyService.requestPermission();
                        await _reschedule();
                        _check();
                      } else {
                        await NotifyService.plugin.cancelAll();
                      }
                    },
                  ),
                ]),
              ),
              // Phone permission
              if (allowed == false || exact == false) ...[
                const SizedBox(height: 12),
                Box(
                  color: C.amberBg,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: C.amber),
                      const SizedBox(width: 8),
                      Expanded(child: Text(allowed == false ? 'Your phone is blocking TaskOra’s notifications' : 'Reminders may arrive a few minutes late', style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink))),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      allowed == false ? 'Allow notifications so reminders, the focus timer and alerts can reach your notification panel.' : 'Allow “Alarms & reminders” so reminders ring at the exact minute.',
                      style: const TextStyle(color: C.ink, height: 1.4, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                      onPressed: () async {
                        if (allowed == false) {
                          await NotifyService.requestPermission();
                        } else {
                          await NotifyService.askExact();
                        }
                        _check();
                      },
                      child: Text(allowed == false ? 'Allow notifications' : 'Allow exact reminders'),
                    ),
                  ]),
                ),
              ],
              const Label('What to show'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _switch('Reminders', p.remindersOn, (v) async {
                    p.remindersOn = v;
                    await _reschedule();
                  }, sub: 'For to-dos and projects', icon: Icons.alarm_rounded, color: 4, enabled: on),
                  const Divider(),
                  _switch('Focus timer', p.focusAlerts, (v) => p.focusAlerts = v, sub: 'Live countdown with Pause / Stop', icon: Icons.timer_outlined, color: 0, enabled: on),
                  const Divider(),
                  _switch('Backups & sync', p.appNews, (v) => p.appNews = v, sub: 'Backup done, restore finished and similar', icon: Icons.cloud_done_outlined, color: 10, enabled: on),
                  const Divider(),
                  _switch('Update alerts', p.autoUpdateCheck, (v) => p.autoUpdateCheck = v, sub: 'When a new version is ready', icon: Icons.system_update_alt_rounded, color: 12, enabled: on),
                ]),
              ),
              const Label('Test'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  RowTile(
                    icon: Icons.notifications_active_outlined,
                    color: 8,
                    title: 'Send a test notification',
                    subtitle: 'Shows up in your notification panel now',
                    onTap: () async {
                      await NotifyService.requestPermission();
                      await NotifyService.test();
                      _check();
                      if (context.mounted) toast(context, 'Test sent. Check your notification panel.');
                    },
                  ),
                  const Divider(),
                  RowTile(
                    icon: Icons.schedule_rounded,
                    color: 2,
                    title: 'Test a reminder in 10 seconds',
                    subtitle: 'Lock your phone and wait for it',
                    onTap: () async {
                      await NotifyService.requestPermission();
                      try {
                        await NotifyService.test(inSeconds: 10);
                        if (context.mounted) toast(context, 'Reminder set for 10 seconds from now.');
                      } catch (e) {
                        if (context.mounted) toast(context, 'Couldn’t schedule it: $e');
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                'If nothing arrives: open your phone’s Settings › Apps › TaskOra › Notifications and make sure they’re allowed. Some phones also need Battery › “Unrestricted” for TaskOra.',
                style: TextStyle(color: context.mutedText, fontSize: 12.5, height: 1.5),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
