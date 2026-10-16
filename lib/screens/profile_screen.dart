import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screens.dart';
import 'backup_screen.dart';
import 'badges_screen.dart';
import 'feedback_screen.dart';
import 'howto_screen.dart';
import 'notes_screen.dart';
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
    final streak = streakOf(s);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FadeIn(
                child: Column(children: [
                  Stack(children: [
                    const Avatar(size: 92),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: s.syncError != null ? C.red : (s.hasPendingWrites ? C.amber : C.green), shape: BoxShape.circle, border: Border.all(color: Theme.of(context).canvasColor, width: 3)),
                        child: Icon(s.syncError != null ? Icons.cloud_off_rounded : (s.hasPendingWrites ? Icons.sync_rounded : Icons.check_rounded), size: 12, color: Colors.white),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(u?.displayName ?? 'You', textAlign: TextAlign.center, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w700)),
                  Text(u?.email ?? '', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, fontSize: T.small)),
                  TextButton(onPressed: () => _open(context, const EditProfileScreen()), child: const Text('Edit profile')),
                ]),
              ),
              FadeIn(
                index: 1,
                child: Row(children: [
                  _stat(context, s.projects.length, 'Projects'),
                  const SizedBox(width: 10),
                  _stat(context, done, 'Done'),
                  const SizedBox(width: 10),
                  _stat(context, s.notes.length, 'Notes'),
                ]),
              ),
              const SizedBox(height: 12),
              FadeIn(
                index: 2,
                child: Material(
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFB347), Color(0xFFFF7A59)])),
                    child: InkWell(
                      onTap: () => _open(context, const BadgesScreen()),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          const Breathing(child: Text('🔥', style: TextStyle(fontSize: 30))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$streak-day streak', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                              const Text('Your sticker book and level', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              const Label('Settings'),
              FadeIn(
                index: 3,
                child: Box(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    RowTile(icon: Icons.tune_rounded, color: 0, title: 'Preferences', subtitle: 'Defaults, tags, statuses, categories', onTap: () => _open(context, const PreferencesScreen())),
                    const Divider(),
                    RowTile(icon: Icons.palette_outlined, color: 2, title: 'Theme', value: appThemes[Prefs.instance.themeIndex.clamp(0, appThemes.length - 1)].name, onTap: () => _open(context, const ThemeScreen())),
                    const Divider(),
                    RowTile(icon: Icons.cloud_sync_outlined, color: 12, title: 'Backup & sync', onTap: () => _open(context, const BackupScreen())),
                  ]),
                ),
              ),
              const Label('Help'),
              FadeIn(
                index: 4,
                child: Box(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    RowTile(icon: Icons.menu_book_outlined, color: 10, title: 'How to use TaskOra', onTap: () => _open(context, const HowToScreen())),
                    const Divider(),
                    RowTile(icon: Icons.chat_bubble_outline_rounded, color: 8, title: 'Send feedback', subtitle: 'Report a problem or share an idea', onTap: () => _open(context, const FeedbackScreen())),
                    const Divider(),
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
                                child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                              )
                            : null,
                        onTap: () => _open(context, const UpdateScreen()),
                      ),
                    ),
                    const Divider(),
                    RowTile(icon: Icons.auto_awesome_outlined, color: 6, title: 'What’s new', onTap: () => _open(context, const WhatsNewScreen())),
                    const Divider(),
                    RowTile(icon: Icons.info_outline_rounded, color: 19, title: 'About', onTap: () => _open(context, const AboutScreen())),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: C.red),
                onPressed: () async {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await AuthService.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 26),
              const AppCredits(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(BuildContext context, int v, String l) => Expanded(
        child: Box(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            AnimatedCount(v, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            Text(l, style: TextStyle(color: context.mutedText, fontSize: 12, fontWeight: FontWeight.w500)),
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
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Segmented<String>(items: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'System')], value: p.themeMode, onChanged: (v) => p.themeMode = v),
              const Label('Background'),
              SizedBox(
                height: 104,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final b in bgStyles)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => p.bgStyle = b.$1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 92,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: p.bgStyle == b.$1 ? context.accent : (context.isDark ? Colors.white12 : C.line), width: p.bgStyle == b.$1 ? 2.5 : 1),
                          ),
                          child: Stack(children: [
                            Positioned.fill(child: AppBackground(t: appThemes[p.themeIndex.clamp(0, appThemes.length - 1)], dark: context.isDark, style: b.$1, child: const SizedBox())),
                            Positioned(left: 8, right: 8, bottom: 8, child: Text(b.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              const Label('Theme colour'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  for (var i = 0; i < appThemes.length; i++)
                    FadeIn(
                      index: i,
                      child: Material(
                        color: p.themeIndex == i ? context.tint : context.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: p.themeIndex == i ? context.accent : (context.isDark ? Colors.white10 : C.line), width: p.themeIndex == i ? 2 : 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => p.themeIndex = i,
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: appThemes[i].accent,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: appThemes[i].accent.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))],
                              ),
                              child: p.themeIndex == i ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                            ),
                            const SizedBox(height: 10),
                            Text(appThemes[i].name, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.themeIndex == i ? context.onTint : null)),
                          ]),
                        ),
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

  Widget _switch(String title, bool v, ValueChanged<bool> set, {String? sub, IconData? icon, int color = 0}) =>
      RowTile(icon: icon, color: color, title: title, subtitle: sub, trailing: Switch(value: v, onChanged: set));

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Prefs>();
    var gi = 0;
    Widget group(String t, List<Widget> rows) => FadeIn(
          index: gi++,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Label(t),
            Box(padding: EdgeInsets.zero, child: Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]]])),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Preferences'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              group('Organise', [
                RowTile(icon: Icons.local_offer_outlined, color: 8, title: 'Labels & tags', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabelsScreen()))),
                RowTile(icon: Icons.flag_outlined, color: 12, title: 'Statuses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaxonomyScreen(initial: 'statuses')))),
                RowTile(icon: Icons.category_outlined, color: 4, title: 'Categories', subtitle: 'For projects and to-dos', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaxonomyScreen(initial: 'todoCats')))),
              ]),
              group('General', [
                DropdownTile<int>(icon: Icons.home_outlined, title: 'Open app on', value: p.startTab.clamp(0, 3), options: const [(0, 'Home'), (1, 'Projects'), (2, 'To-do'), (3, 'Notes')], onChanged: (v) => p.startTab = v),
                DropdownTile<String>(icon: Icons.calendar_month_outlined, color: 12, title: 'Week starts on', value: p.weekStart, options: const [('Saturday', 'Saturday'), ('Sunday', 'Sunday'), ('Monday', 'Monday')], onChanged: (v) => p.weekStart = v),
                _switch('Haptic feedback', p.haptics, (v) => p.haptics = v, icon: Icons.vibration, color: 6),
              ]),
              group('To-do', [
                DropdownTile<int>(icon: Icons.flag_outlined, color: 2, title: 'Default priority', value: p.defaultPriority.clamp(1, 5), options: [for (var i = 1; i <= 5; i++) (i, priorityName(i))], onChanged: (v) => p.defaultPriority = v),
                DropdownTile<String>(icon: Icons.alarm, color: 4, title: 'Default reminder', value: p.defaultReminder, options: const [('none', 'None'), ('1h', '1 h before'), ('1d', '1 day before')], onChanged: (v) => p.defaultReminder = v),
                _switch('Show completed', p.showCompleted, (v) => p.showCompleted = v, icon: Icons.task_alt, color: 8),
              ]),
              group('Projects', [
                DropdownTile<String>(icon: Icons.payments_outlined, color: 8, title: 'Default currency', value: p.defaultCurrency, options: [for (final c in currencySymbols.keys) (c, c)], onChanged: (v) => p.defaultCurrency = v),
                DropdownTile<String>(icon: Icons.storefront_outlined, color: 10, title: 'Default platform', value: p.defaultPlatform, options: const [('direct', 'Direct'), ('fiverr', 'Fiverr 20%'), ('upwork', 'Upwork 10%'), ('custom', 'Custom')], onChanged: (v) => p.defaultPlatform = v),
                _switch('Show money on cards', p.showMoney, (v) => p.showMoney = v, icon: Icons.visibility_outlined, color: 12),
              ]),
              group('Notes', [
                _switch('Grid view', p.notesGrid, (v) => p.notesGrid = v, icon: Icons.grid_view_rounded, color: 6),
                _switch('Show pinned folders on Home', p.showNotesOnHome, (v) => p.showNotesOnHome = v, icon: Icons.home_outlined, color: 0),
              ]),
              group('Notifications', [
                _switch('Reminders', p.remindersOn, (v) => p.remindersOn = v, sub: 'For to-dos and projects', icon: Icons.notifications_active_outlined, color: 4),
                _switch('Update alerts', p.autoUpdateCheck, (v) => p.autoUpdateCheck = v, sub: 'When a new version is ready', icon: Icons.system_update_alt_rounded, color: 12),
              ]),
              group('Focus & backups', [
                DropdownTile<int>(icon: Icons.timer_outlined, title: 'Focus length', value: p.focusMinutes, options: const [(15, '15 min'), (25, '25 min'), (45, '45 min'), (60, '60 min'), (90, '90 min')], onChanged: (v) => p.focusMinutes = v),
                DropdownTile<int>(icon: Icons.inventory_2_outlined, color: 19, title: 'Keep backups', value: p.keepBackups, options: const [(5, '5'), (10, '10'), (30, '30')], onChanged: (v) => p.keepBackups = v),
              ]),
            ]),
          ),
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


/// Footer: app name + version, developer, copyright and website.
class AppCredits extends StatelessWidget {
  const AppCredits({super.key});
  @override
  Widget build(BuildContext context) {
    final muted = context.mutedText;
    return FadeIn(
      index: 6,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          FutureBuilder<AppVersion>(
            future: UpdateService.current(),
            builder: (_, v) => Text(v.hasData ? 'TaskOra ${v.data!.version}' : 'TaskOra', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Developed by Rabby Hossain', style: TextStyle(color: muted, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text('© ${DateTime.now().year} TaskOra. All rights reserved.', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://rabbyhossain.com'), mode: LaunchMode.externalApplication),
          child: Text('rabbyhossain.com', style: TextStyle(color: context.accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
