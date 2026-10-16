import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screens.dart';
import 'backup_screen.dart';
import 'badges_screen.dart';
import 'home_screen.dart';
import 'notes_screen.dart';
import 'notifications_screen.dart';
import 'taxonomy_screen.dart';
import 'update_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final u = FirebaseAuth.instance.currentUser;
    final done = s.todos.where((t) => t.done).length;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Stack(children: [
                  const Avatar(size: 96),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: s.hasPendingWrites ? C.amber : C.green, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3)),
                      child: Icon(s.hasPendingWrites ? Icons.sync_rounded : Icons.check_rounded, size: 13, color: Colors.white),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Text(u?.displayName ?? 'You', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(u?.email ?? '', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText)),
              const SizedBox(height: 4),
              Center(child: TextButton(onPressed: () => _open(context, const EditProfileScreen()), child: const Text('Edit profile'))),
              Row(children: [
                _stat(context, '${s.projects.length}', 'Projects'),
                const SizedBox(width: 10),
                _stat(context, '$done', 'Done'),
                const SizedBox(width: 10),
                _stat(context, '${s.notes.length}', 'Notes'),
              ]),
              const SizedBox(height: 12),
              Box(
                color: const Color(0xFFFFF2DE),
                onTap: () => _open(context, const BadgesScreen()),
                child: Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${streakOf(s)}-day streak', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.ink)),
                      const Text('See your sticker book and level', style: TextStyle(color: Color(0xFF8F5A12), fontSize: 13)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF8F5A12)),
                ]),
              ),
              const Label('Personalise'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  RowTile(icon: Icons.tune_rounded, color: 0, title: 'Preferences', onTap: () => _open(context, const PreferencesScreen())),
                  const Divider(),
                  RowTile(icon: Icons.palette_outlined, color: 2, title: 'Theme', value: appThemes[Prefs.instance.themeIndex.clamp(0, appThemes.length - 1)].name, onTap: () => _open(context, const ThemeScreen())),
                  const Divider(),
                  RowTile(icon: Icons.notifications_none_rounded, color: 6, title: 'Notifications', value: s.unreadCount > 0 ? '${s.unreadCount} new' : null, onTap: () => _open(context, const NotificationsScreen())),
                ]),
              ),
              const Label('Data'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  RowTile(icon: Icons.cloud_sync_outlined, color: 12, title: 'Backup & sync', onTap: () => _open(context, const BackupScreen())),
                  const Divider(),
                  RowTile(icon: Icons.local_offer_outlined, color: 8, title: 'Labels & tags', onTap: () => _open(context, const LabelsScreen())),
                  const Divider(),
                  RowTile(icon: Icons.category_outlined, color: 4, title: 'Statuses & categories', onTap: () => _open(context, const TaxonomyScreen())),
                ]),
              ),
              const Label('App'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  FutureBuilder<UpdateInfo?>(
                    future: UpdateService.cachedCheck(),
                    builder: (_, snap) => RowTile(
                      icon: Icons.system_update_alt_rounded,
                      color: 12,
                      title: 'Check for update',
                      trailing: snap.data != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(10)),
                              child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                            )
                          : null,
                      onTap: () => _open(context, const UpdateScreen()),
                    ),
                  ),
                  const Divider(),
                  RowTile(icon: Icons.auto_awesome, color: 6, title: 'What’s new', onTap: () => _open(context, const WhatsNewScreen())),
                  const Divider(),
                  RowTile(icon: Icons.verified_outlined, color: 10, title: 'License', value: 'Lifetime', onTap: () => _open(context, const LicenseScreen())),
                  const Divider(),
                  RowTile(icon: Icons.info_outline, color: 19, title: 'About', onTap: () => _open(context, const AboutScreen())),
                ]),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder(), foregroundColor: C.red),
                onPressed: () async {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await AuthService.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              FutureBuilder<AppVersion>(
                future: UpdateService.current(),
                builder: (_, v) => Text(v.hasData ? 'TaskOra ${v.data!.version} (build ${v.data!.build})' : '', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(BuildContext context, String v, String l) => Expanded(
        child: Box(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(l, style: TextStyle(color: context.mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final name = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          const Header('Edit profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: Avatar(size: 96)),
              const SizedBox(height: 8),
              Center(child: Text('Your photo comes from your Google account.', style: TextStyle(color: context.mutedText, fontSize: 12.5))),
              const SizedBox(height: 18),
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(enabled: false, controller: TextEditingController(text: u?.email ?? ''), decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  await AuthService.updateName(name.text);
                  if (context.mounted) {
                    toast(context, 'Profile saved');
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
              const SizedBox(height: 26),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: C.red),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete account?'),
                      content: const Text('This permanently deletes your account and all cloud data. Back up first if you want to keep anything.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  final s = context.read<Store>();
                  try {
                    await s.deleteEverything(); // your server + this phone
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    await FirebaseAuth.instance.currentUser?.delete();
                  } catch (e) {
                    if (context.mounted) toast(context, 'Please sign out, sign in again, then retry. ($e)');
                  }
                },
                child: const Text('Delete account'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<Prefs>();
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          const Header('Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Segmented<String>(items: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'System')], value: p.themeMode, onChanged: (v) => p.themeMode = v),
              const Label('Colour themes'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  for (var i = 0; i < appThemes.length; i++)
                    GestureDetector(
                      onTap: () => p.themeIndex = i,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appThemes[i].bg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: p.themeIndex == i ? appThemes[i].accent : C.line, width: p.themeIndex == i ? 2.5 : 1),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 26, height: 26, decoration: BoxDecoration(color: appThemes[i].accent, shape: BoxShape.circle)),
                            const Spacer(),
                            if (p.themeIndex == i) Icon(Icons.check_circle_rounded, color: appThemes[i].accent),
                          ]),
                          const Spacer(),
                          Container(height: 10, width: 80, decoration: BoxDecoration(color: appThemes[i].tint, borderRadius: BorderRadius.circular(5))),
                          const SizedBox(height: 6),
                          Container(height: 10, width: 50, decoration: BoxDecoration(color: appThemes[i].tint, borderRadius: BorderRadius.circular(5))),
                          const SizedBox(height: 10),
                          Text(appThemes[i].name, style: const TextStyle(fontWeight: FontWeight.w800, color: C.ink)),
                        ]),
                      ),
                    ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  Widget _cycle<T>(BuildContext context, String title, T value, List<(T, String)> options, ValueChanged<T> set, {IconData? icon, int color = 0}) {
    final idx = options.indexWhere((o) => o.$1 == value);
    final label = idx < 0 ? options.first.$2 : options[idx].$2;
    return RowTile(
      icon: icon,
      color: color,
      title: title,
      trailing: TextButton(
        onPressed: () => set(options[(idx + 1) % options.length].$1),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w800)), const Icon(Icons.unfold_more_rounded, size: 18)]),
      ),
    );
  }

  Widget _switch(String title, bool v, ValueChanged<bool> set, {String? sub, IconData? icon, int color = 0}) =>
      RowTile(icon: icon, color: color, title: title, subtitle: sub, trailing: Switch(value: v, onChanged: set));

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Prefs>();
    Widget group(String t, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Label(t),
          Box(padding: EdgeInsets.zero, child: Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]]])),
        ]);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
          const Padding(padding: EdgeInsets.only(left: 0), child: Header('Preferences')),
          group('General', [
            _cycle(context, 'Open app on', p.startTab, const [(0, 'Home'), (1, 'Projects'), (2, 'Stats'), (3, 'To-do'), (4, 'Notes')], (v) => p.startTab = v, icon: Icons.home_outlined),
            _cycle(context, 'Week starts on', p.weekStart, const [('Saturday', 'Saturday'), ('Sunday', 'Sunday'), ('Monday', 'Monday')], (v) => p.weekStart = v, icon: Icons.calendar_month_outlined, color: 12),
            _switch('Haptic feedback', p.haptics, (v) => p.haptics = v, icon: Icons.vibration, color: 6),
          ]),
          group('To-do', [
            _cycle(context, 'Default priority', p.defaultPriority, const [(1, 'P1'), (2, 'P2'), (3, 'P3'), (4, 'P4')], (v) => p.defaultPriority = v, icon: Icons.flag_outlined, color: 2),
            _cycle(context, 'Default reminder', p.defaultReminder, const [('none', 'None'), ('1h', '1 h before'), ('1d', '1 day before')], (v) => p.defaultReminder = v, icon: Icons.alarm, color: 4),
            _switch('Show completed', p.showCompleted, (v) => p.showCompleted = v, icon: Icons.task_alt, color: 8),
          ]),
          group('Projects', [
            _cycle(context, 'Default currency', p.defaultCurrency, [for (final c in currencySymbols.keys) (c, c)], (v) => p.defaultCurrency = v, icon: Icons.payments_outlined, color: 8),
            _cycle(context, 'Default platform', p.defaultPlatform, const [('direct', 'Direct'), ('fiverr', 'Fiverr 20%'), ('upwork', 'Upwork 10%'), ('custom', 'Custom')], (v) => p.defaultPlatform = v, icon: Icons.storefront_outlined, color: 10),
            _switch('Show money on cards', p.showMoney, (v) => p.showMoney = v, icon: Icons.visibility_outlined, color: 12),
          ]),
          group('Notes', [
            _switch('Grid view', p.notesGrid, (v) => p.notesGrid = v, icon: Icons.grid_view_rounded, color: 6),
            _switch('Show pinned sections on Home', p.showNotesOnHome, (v) => p.showNotesOnHome = v, icon: Icons.home_outlined, color: 0),
          ]),
          group('Notifications', [
            _switch('Reminders', p.remindersOn, (v) => p.remindersOn = v, sub: 'For to-dos and projects', icon: Icons.notifications_active_outlined, color: 4),
            _switch('Update alerts', p.autoUpdateCheck, (v) => p.autoUpdateCheck = v, sub: 'Popup when a new version is ready', icon: Icons.system_update_alt_rounded, color: 12),
          ]),
          group('Focus & sync', [
            _cycle(context, 'Focus length', p.focusMinutes, const [(15, '15 min'), (25, '25 min'), (45, '45 min'), (60, '60 min')], (v) => p.focusMinutes = v, icon: Icons.timer_outlined, color: 0),
            _cycle(context, 'Keep backups', p.keepBackups, const [(5, '5'), (10, '10'), (30, '30')], (v) => p.keepBackups = v, icon: Icons.inventory_2_outlined, color: 19),
          ]),
        ]),
      ),
    );
  }
}

/// Days in a row (ending today or yesterday) with a finished to-do.
int streakOf(Store s) {
  final days = s.todos.where((t) => t.done && t.completedAt != null).map((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day)).toSet();
  final now = DateTime.now();
  var d = DateTime(now.year, now.month, now.day);
  if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(d)) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}
