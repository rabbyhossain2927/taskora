import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';
import 'about_screens.dart';
import 'backup_screen.dart';
import 'badges_screen.dart';
import 'bin_screen.dart';
import 'feedback_screen.dart';
import 'howto_screen.dart';
import 'notes_screen.dart';
import 'notification_settings.dart';
import 'taxonomy_screen.dart';
import 'update_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 1000) return const _DesktopAccount();
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
                    RowTile(icon: Icons.notifications_none_rounded, color: 4, title: 'Notifications', subtitle: 'On / off, test notification', onTap: () => _open(context, const NotificationSettingsScreen())),
                    const Divider(),
                    RowTile(icon: Icons.cloud_sync_outlined, color: 12, title: 'Backup & sync', onTap: () => _open(context, const BackupScreen())),
                  ]),
                ),
              ),
              const Label('Storage'),
              FadeIn(
                index: 4,
                child: Box(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    RowTile(icon: Icons.archive_outlined, color: 10, title: 'Archive', value: s.archived.isEmpty ? null : '${s.archived.length}', onTap: () => _open(context, const BinScreen(trash: false))),
                    const Divider(),
                    RowTile(icon: Icons.delete_outline_rounded, color: 2, title: 'Trash', subtitle: 'Kept for ${Store.trashDays} days', value: s.trash.isEmpty ? null : '${s.trash.length}', onTap: () => _open(context, const BinScreen(trash: true))),
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
                    if (!kIsWeb)
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
                    if (!kIsWeb) const Divider(),
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

/// Computers: settings with the menu always on the left; the right side
/// switches between Account, Theme, Preferences and the other settings pages.
class _DesktopAccount extends StatefulWidget {
  const _DesktopAccount();
  @override
  State<_DesktopAccount> createState() => _DesktopAccountState();
}

class _DesktopAccountState extends State<_DesktopAccount> {
  String page = 'account';

  static final _pages = <(String, String, Widget?)>[
    ('account', 'Account', null),
    ('theme', 'Theme', null),
    ('prefs', 'Preferences', const PreferencesScreen()),
    ('notify', 'Notifications', const NotificationSettingsScreen()),
    ('backup', 'Backup & sync', const BackupScreen()),
    ('badges', 'Achievements', const BadgesScreen()),
    ('howto', 'How to use', const HowToScreen()),
    ('feedback', 'Send feedback', const FeedbackScreen()),
    ('about', 'About', const AboutScreen()),
  ];

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _line => _dark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F0F8);

  Widget _card(Widget child, {Gradient? gradient}) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: softCard(18, context.surface).copyWith(gradient: _dark ? null : gradient),
        child: child,
      );
  Widget _h(String t, [Widget? trailing]) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Expanded(child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))), if (trailing != null) trailing]),
      );
  Widget _btn(String t, VoidCallback onTap, {String kind = 'soft', bool wide = false}) {
    final (bg, fg) = switch (kind) {
      'primary' => (context.accent, Colors.white),
      'danger' => (_dark ? const Color(0x33B42318) : C.redBg, _dark ? const Color(0xFFFF8A80) : const Color(0xFFB42318)),
      'ink' => (_dark ? Colors.white : C.ink, _dark ? C.ink : Colors.white),
      _ => (_dark ? Colors.white.withOpacity(0.07) : context.softFill, _dark ? Colors.white : context.selInk),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(height: 38, width: wide ? double.infinity : null, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: fg))),
      ),
    );
  }

  Widget _pill(String t, Color bg, Color fg, {Widget? lead}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [if (lead != null) ...[lead, const SizedBox(width: 5)], Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg))]),
      );

  // ---------------- menu ----------------
  Widget _menu() => Container(
        width: 210,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        decoration: softCard(18, context.surface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(12, 4, 12, 10), child: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
          for (final p in _pages.where((p) => p.$1 != 'badges'))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => setState(() => page = p.$1),
                  hoverColor: context.hoverTint,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 38,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: page == p.$1 ? (_dark ? Colors.white.withOpacity(0.07) : context.selTint) : null,
                    ),
                    child: Text(p.$2, style: TextStyle(fontSize: 13.5, fontWeight: page == p.$1 ? FontWeight.w700 : FontWeight.w500, color: page == p.$1 ? (_dark ? Colors.white : context.selInk) : null)),
                  ),
                ),
              ),
            ),
        ]),
      );

  // ---------------- theme ----------------
  Widget _theme({bool big = false}) {
    final p = context.watch<Prefs>();
    final muted = context.mutedText;
    final idx = p.themeIndex.clamp(0, appThemes.length - 1);
    final ring = _dark ? Colors.white : C.ink;
    Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted)));
    final modes = Row(children: [
      for (final m in const [('light', 'Light', Icons.light_mode_outlined), ('dark', 'Dark', Icons.dark_mode_outlined), ('system', 'Match device', Icons.contrast_rounded)]) ...[
        Expanded(
          child: Material(
            color: p.themeMode == m.$1 ? (_dark ? Colors.white.withOpacity(0.09) : context.selTint) : (_dark ? Colors.white.withOpacity(0.03) : Color(0xFFF8F7FC)),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => p.themeMode = m.$1,
              child: SizedBox(
                height: 44,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(m.$3, size: 18, color: p.themeMode == m.$1 ? (_dark ? Colors.white : context.selInk) : muted),
                  const SizedBox(width: 8),
                  Text(m.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.themeMode == m.$1 ? (_dark ? Colors.white : context.selInk) : muted)),
                ]),
              ),
            ),
          ),
        ),
        if (m.$1 != 'system') const SizedBox(width: 8),
      ],
    ]);
    final colours = Wrap(spacing: 10, runSpacing: 10, children: [
      for (var i = 0; i < appThemes.length; i++)
        Tooltip(
          message: appThemes[i].name,
          child: GestureDetector(
            onTap: () => p.themeIndex = i,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: i == idx ? ring : Colors.transparent, width: 2)),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: appThemes[i].accent, shape: BoxShape.circle),
                  child: i == idx ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                ),
              ),
            ),
          ),
        ),
    ]);
    final backgrounds = Wrap(spacing: 10, runSpacing: 10, children: [
      for (final b in bgStyles)
        GestureDetector(
          onTap: () => p.bgStyle = b.$1,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 96,
                height: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _dark ? const Color(0xFF1C1C23) : const Color(0xFFFAFAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.bgStyle == b.$1 ? ring : (_dark ? Colors.white.withOpacity(0.06) : const Color(0xFFEAEAF0)), width: p.bgStyle == b.$1 ? 1.5 : 1),
                ),
                child: Stack(children: [
                  // A small, neutral preview of the pattern (not the full page colour).
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.55,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(size: const Size(300, 200)),
                        child: AppBackground(t: appThemes[idx], dark: _dark, style: b.$1, child: const SizedBox()),
                      ),
                    ),
                  ),
                  if (p.bgStyle == b.$1)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(width: 18, height: 18, decoration: BoxDecoration(color: ring, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 12, color: _dark ? C.ink : Colors.white)),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(b.$2, style: TextStyle(fontSize: 12, fontWeight: p.bgStyle == b.$1 ? FontWeight.w700 : FontWeight.w500, color: p.bgStyle == b.$1 ? null : muted)),
            ]),
          ),
        ),
    ]);
    if (big) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_h('Appearance'), modes])),
        const SizedBox(height: 18),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_h('Colour'), label(appThemes[idx].name), colours])),
        const SizedBox(height: 18),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_h('Background'), label('Shown behind your pages. Soft glow gives the pastel look.'), backgrounds])),
      ]);
    }
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _h('Theme', TextButton(onPressed: () => setState(() => page = 'theme'), child: const Text('All options'))),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [label('Colour · ${appThemes[idx].name}'), colours])),
        const SizedBox(width: 28),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [label('Appearance'), modes])),
      ]),
    ]));
  }

  // ---------------- account ----------------
  Widget _account() {
    final s = context.watch<Store>();
    final u = FirebaseAuth.instance.currentUser;
    final muted = context.mutedText;
    final google = u?.providerData.any((x) => x.providerId == 'google.com') ?? false;
    final since = u?.metadata.creationTime;
    final last = u?.metadata.lastSignInTime;
    final off = DateTime.now().timeZoneOffset;
    final tz = 'GMT${off.isNegative ? '-' : '+'}${off.inHours.abs()}${off.inMinutes % 60 == 0 ? '' : ':${(off.inMinutes.abs() % 60).toString().padLeft(2, '0')}'}';
    final syncText = s.syncError != null ? 'Offline — will sync later' : (s.syncing ? 'Syncing…' : (s.hasPendingWrites ? '${s.pendingCount} changes waiting' : 'Everything is synced'));
    final syncColor = s.syncError != null ? C.red : (s.hasPendingWrites || s.syncing ? const Color(0xFFD48806) : const Color(0xFF23845A));
    final earned = stickersOf(s).where((x) => x.earned).toList();
    final streak = streakOf(s);
    final level = levelOf(s);

    Widget row(String k, String v, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: _line))),
          child: Row(children: [
            SizedBox(width: 130, child: Text(k, style: TextStyle(fontSize: 13.5, color: muted))),
            Expanded(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          ]),
        );
    Widget check(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [const Icon(Icons.check_rounded, size: 17, color: Color(0xFF23845A)), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5)))]),
        );
    final chipBg = _dark ? Colors.white.withOpacity(0.07) : Colors.white;
    final chipFg = _dark ? Colors.white : const Color(0xFF33333F);

    final banner = Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: _dark
          ? softCard(22, context.surface)
          : BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [Color(0xFFFFD9EC), Color(0xFFE6DEFF), Color(0xFFD6ECFF)], stops: [0, 0.45, 1]),
              boxShadow: const [BoxShadow(color: Color(0x1F7859DC), blurRadius: 30, offset: Offset(0, 10))],
            ),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _dark ? Colors.white12 : Colors.white, width: 4)),
          child: const Avatar(size: 72, ring: false),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u?.displayName ?? 'You', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            Text(u?.email ?? '', style: TextStyle(fontSize: 13.5, color: _dark ? Colors.white60 : const Color(0xFF4B4B5A))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _pill('Free plan', chipBg, _dark ? Colors.white : const Color(0xFF4A3FC4)),
              _pill(google ? 'Signed in with Google' : 'Signed in with email', chipBg, chipFg),
              _pill(syncText, s.syncError != null ? C.redBg : (_dark ? const Color(0x2623845A) : const Color(0xFFDDF5E8)), s.syncError != null ? C.red : const Color(0xFF2FA36B), lead: Container(width: 6, height: 6, decoration: BoxDecoration(color: syncColor, shape: BoxShape.circle))),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        // Badges: level, streak and earned stickers -> Achievements
        Material(
          color: _dark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => page = 'badges'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('Level $level', _dark ? Colors.white.withOpacity(0.08) : const Color(0xFFEDE7FF), _dark ? Colors.white : const Color(0xFF4A3FC4)),
                  const SizedBox(width: 6),
                  _pill('$streak-day streak', _dark ? const Color(0x26F08C2E) : const Color(0xFFFFEDD9), const Color(0xFFD9731A), lead: const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFF08C2E))),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (earned.isEmpty) Text('No badges yet', style: TextStyle(fontSize: 12.5, color: muted)),
                  for (final b in earned.take(6))
                    Tooltip(
                      message: b.name,
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _dark ? Colors.white.withOpacity(0.06) : pastel(b.color).bg, shape: BoxShape.circle),
                        child: Text(b.emoji, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  if (earned.length > 6) Text('+${earned.length - 6}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: muted)),
                ]),
                const SizedBox(height: 6),
                Text('${earned.length} of ${stickersOf(s).length} badges', style: TextStyle(fontSize: 11.5, color: muted)),
              ]),
            ),
          ),
        ),
      ]),
    );

    final details = _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _h('Account details', _btn('Edit', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())))),
      row('Name', u?.displayName ?? '—'),
      row('Email', u?.email ?? '—'),
      row('Sign-in', google ? 'Google' : 'Email and password'),
      row('Member since', since == null ? '—' : DateFormat('MMMM y').format(since)),
      row('Time zone', '${DateTime.now().timeZoneName} ($tz)'),
      row('Language', 'English', last: true),
    ]));

    final plan = _card(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Colors.white, Color(0xFFF3EEFF)], stops: [0, 0.4, 1]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _h('Plan & usage'),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          const Text('Free', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('your current plan', style: TextStyle(fontSize: 13, color: muted)),
        ]),
        const SizedBox(height: 12),
        check('Unlimited projects, to-dos and notes'),
        check('Sync on phone and web'),
        check('Backup to a file or Google Drive'),
        const SizedBox(height: 4),
        Text('${s.projects.length} projects · ${s.todos.length} to-dos · ${s.notes.length} notes', style: TextStyle(fontSize: 12.5, color: muted)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _btn('Upgrade to Pro', () => toast(context, 'Pro plans are coming soon.'), kind: 'ink', wide: true)),
          const SizedBox(width: 8),
          const SoonPill(),
        ]),
      ]),
    );

    final security = _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _h('Security'),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('This browser', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              Text(last == null ? 'Web app' : 'Web app · signed in ${fmtDue(last)}', style: TextStyle(fontSize: 12.5, color: muted)),
            ]),
          ),
          _pill('This device', _dark ? const Color(0x2623845A) : const Color(0xFFDDF5E8), const Color(0xFF2FA36B)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text('Your phone app stays signed in on its own. Signing out here only signs out this browser.', style: TextStyle(fontSize: 12.5, color: muted, height: 1.45)),
      ),
      Row(children: [
        _btn('Sign out', () async {
          Navigator.of(context).popUntil((r) => r.isFirst);
          await AuthService.signOut();
        }, kind: 'danger'),
        const Spacer(),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())), style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5484D)), child: const Text('Delete account')),
      ]),
    ]));

    final backup = _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _h('Backup & storage'),
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: syncColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(syncText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
      ]),
      const SizedBox(height: 10),
      Text('Your data syncs to your own server. Keep an extra copy as a file or in Google Drive.', style: TextStyle(fontSize: 12.5, color: muted, height: 1.45)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _btn('Back up or restore', () => setState(() => page = 'backup'), kind: 'primary'),
        _btn('Sync now', () => s.sync()),
        _btn('Archive & Trash', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BinScreen(trash: false)))),
      ]),
    ]));

    Widget pair(Widget a, Widget b) => IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 18), Expanded(child: b)]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      banner,
      const SizedBox(height: 18),
      pair(details, plan),
      const SizedBox(height: 18),
      pair(security, backup),
      const SizedBox(height: 18),
      _theme(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _pages.firstWhere((p) => p.$1 == page);
    final Widget pane = switch (page) {
      'account' => SingleChildScrollView(padding: const EdgeInsets.only(bottom: 28), child: _account()),
      'theme' => SingleChildScrollView(padding: const EdgeInsets.only(bottom: 28), child: _theme(big: true)),
      // Other settings pages open inside the panel, so the menu stays.
      _ => Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: softCard(18, context.surface),
            child: DeskPane(
              child: Navigator(
                key: ValueKey(page),
                onGenerateRoute: (_) => PageRouteBuilder(pageBuilder: (_, __, ___) => NoBack(child: sel.$3!), transitionDuration: Duration.zero),
              ),
            ),
          ),
        ),
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SingleChildScrollView(child: _menu()),
            const SizedBox(width: 18),
            Expanded(child: pane),
          ]),
        ),
      ),
    );
  }
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
                RowTile(icon: Icons.notifications_active_outlined, color: 4, title: 'Notification settings', subtitle: 'On / off, reminders, focus, test', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),
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
