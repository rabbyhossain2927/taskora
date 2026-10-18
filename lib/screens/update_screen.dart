import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notify_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screens.dart';

/// Checks for updates when the app opens, then shows a popup screen
/// and a phone notification.
class UpdatePrompt {
  static bool _showing = false;
  static bool _checkedThisLaunch = false;

  static Future<void> checkInBackground(BuildContext context) async {
    final prefs = Prefs.instance;
    if (kIsWeb || !prefs.autoUpdateCheck || _showing) return; // the website is always the newest version
    final now = DateTime.now().millisecondsSinceEpoch;
    // Every app start; when coming back to the app, at most once an hour.
    if (_checkedThisLaunch && now - prefs.lastUpdateCheck < const Duration(hours: 1).inMilliseconds) return;
    _checkedThisLaunch = true;
    prefs.lastUpdateCheck = now;
    UpdateInfo? u;
    try {
      u = await UpdateService.check();
    } catch (_) {
      return;
    }
    if (u == null || u.version == prefs.skippedVersion || !context.mounted) return;
    if (prefs.lastNotifiedVersion != u.version) {
      prefs.lastNotifiedVersion = u.version;
      NotifyService.showUpdate(u.version, u.summary);
      try {
        context.read<Store>().addNotice('TaskOra ${u.version} is ready', u.summary.isEmpty ? 'Tap to update.' : u.summary, 'update');
      } catch (_) {}
    }
    if (context.mounted) show(context, u);
  }

  /// The popup screen shown when a new version is available.
  static Future<void> show(BuildContext context, UpdateInfo u) async {
    _showing = true;
    final cur = await UpdateService.current();
    if (!context.mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Update',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
      ),
      pageBuilder: (ctx, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: ctx.surface,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(ctx.accent, Colors.white, 0.1)!, Color.lerp(ctx.accent, Colors.black, 0.15)!])),
                  child: Column(children: [
                    const Breathing(child: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 46)),
                    const SizedBox(height: 12),
                    const Text('New update available', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Version ${cur.version}  →  ${u.version}', style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      _info(ctx, Icons.download_rounded, 'Download size', u.sizeBytes > 0 ? UpdateService.mb(u.sizeBytes) : '—'),
                      const SizedBox(width: 10),
                      _info(ctx, Icons.new_releases_outlined, 'New version', u.version),
                    ]),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final f in u.added.take(6)) _line('New', f, ctx.accent),
                          for (final f in u.fixed.take(6)) _line('Fixed', f, C.green),
                          if (u.fixed.isEmpty && u.added.isEmpty) Text(u.summary.isEmpty ? 'Bug fixes and improvements.' : u.summary),
                        ]),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateScreen(autoDownload: u)));
                        },
                        icon: const Icon(Icons.system_update_alt_rounded, size: 20),
                        label: const Text('Update now'),
                      ),
                    ),
                  ]),
                ),
                TextButton(
                  onPressed: () {
                    Prefs.instance.skippedVersion = u.version;
                    Navigator.pop(ctx);
                  },
                  child: Text('Skip this version', style: TextStyle(color: ctx.mutedText, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 6),
              ]),
            ),
          ),
        ),
      ),
    );
    _showing = false;
  }

  static Widget _info(BuildContext context, IconData icon, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(icon, size: 20, color: context.onTint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 11, color: context.onTint.withOpacity(0.75))),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.onTint)),
              ]),
            ),
          ]),
        ),
      );

  static Widget _line(String tag, String text, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$tag · ', style: TextStyle(fontWeight: FontWeight.w700, color: c)),
            TextSpan(text: text),
          ]),
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
      );
}

/// Profile > Check for update. Downloads and installs inside the app.
class UpdateScreen extends StatefulWidget {
  /// When set, starts downloading this update straight away.
  final UpdateInfo? autoDownload;
  const UpdateScreen({super.key, this.autoDownload});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String state = 'checking'; // checking | latest | available | downloading | ready | error
  String error = '';
  UpdateInfo? info;
  AppVersion? cur;
  int received = 0, total = 0;
  bool cancel = false;
  File? apk;

  @override
  void initState() {
    super.initState();
    if (widget.autoDownload != null) {
      info = widget.autoDownload;
      UpdateService.current().then((v) => mounted ? setState(() => cur = v) : null);
      _download();
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => state = 'checking');
    try {
      cur = await UpdateService.current();
      final u = await UpdateService.check();
      Prefs.instance.lastUpdateCheck = DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        setState(() {
          info = u;
          state = u == null ? 'latest' : 'available';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          state = 'error';
        });
      }
    }
  }

  Future<void> _download() async {
    final u = info;
    if (u == null) return;
    setState(() {
      state = 'downloading';
      received = 0;
      total = u.sizeBytes;
      cancel = false;
    });
    try {
      final f = await UpdateService.downloadApk(u, (r, t) {
        if (!mounted) return;
        // Update the bar at most every ~1%
        if (t > 0 && r < t && (r - received) < t ~/ 100) return;
        setState(() {
          received = r;
          total = t;
        });
      }, cancelled: () => cancel);
      if (!mounted) return;
      setState(() {
        apk = f;
        state = 'ready';
      });
      _install();
    } catch (e) {
      if (!mounted) return;
      if (cancel) {
        setState(() => state = 'available');
      } else {
        setState(() {
          error = e.toString();
          state = 'error';
        });
      }
    }
  }

  Future<void> _install() async {
    final f = apk;
    if (f == null) return;
    final msg = await UpdateService.install(f);
    if (msg != null && mounted) toast(context, 'Couldn’t open the installer: $msg');
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<Prefs>();
    final pct = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    final (title, sub, icon, color) = switch (state) {
      'latest' => ('You’re up to date', 'TaskOra ${cur?.version ?? ''} is the latest version.', Icons.verified_rounded, C.green),
      'available' => ('Version ${info!.version} is available', info!.summary.isEmpty ? 'Download and install it right here.' : info!.summary, Icons.system_update_alt_rounded, context.accent),
      'downloading' => ('Downloading update…', 'You can keep using the app while it downloads.', Icons.downloading_rounded, context.accent),
      'ready' => ('Ready to install', 'Tap Install. Android will ask you to confirm. Your data stays safe.', Icons.install_mobile_rounded, C.green),
      'error' => ('Something went wrong', error, Icons.error_outline_rounded, C.red),
      _ => ('Checking for updates…', 'Looking for a newer version.', Icons.sync_rounded, context.accent),
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          const Header('App updates'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FadeIn(
                child: Box(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  radius: 26,
                  child: Column(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Container(
                        key: ValueKey(state),
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                        child: state == 'checking'
                            ? Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 3, color: color))
                            : Icon(icon, size: 36, color: color),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(sub, textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, height: 1.5)),
                    if (info != null) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        _pill(context, 'Installed', cur?.version ?? '…'),
                        const SizedBox(width: 8),
                        _pill(context, 'New', info!.version),
                        const SizedBox(width: 8),
                        _pill(context, 'Size', info!.sizeBytes > 0 ? UpdateService.mb(info!.sizeBytes) : '—'),
                      ]),
                    ],
                    if (state == 'downloading' || state == 'ready') ...[
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: state == 'ready' ? 1 : pct),
                        duration: const Duration(milliseconds: 250),
                        builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: context.tint)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${UpdateService.mb(received)} of ${total > 0 ? UpdateService.mb(total) : '…'}', style: TextStyle(fontSize: 12.5, color: context.mutedText)),
                        const Spacer(),
                        Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.accent)),
                      ]),
                    ],
                    const SizedBox(height: 18),
                    if (state == 'available')
                      FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download_rounded), label: Text('Download & install · ${info!.sizeBytes > 0 ? UpdateService.mb(info!.sizeBytes) : ''}'))
                    else if (state == 'downloading')
                      OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () => setState(() => cancel = true), child: const Text('Cancel'))
                    else if (state == 'ready')
                      FilledButton.icon(onPressed: _install, icon: const Icon(Icons.install_mobile_rounded), label: const Text('Install now'))
                    else if (state == 'error') ...[
                      FilledButton(onPressed: info != null ? _download : _check, child: const Text('Try again')),
                      if (info != null)
                        TextButton(onPressed: () => UpdateService.openInBrowser(info!), child: const Text('Download in browser instead')),
                    ] else
                      FilledButton(onPressed: state == 'checking' ? null : _check, child: Text(state == 'checking' ? 'Checking…' : 'Check again')),
                  ]),
                ),
              ),
              if (info != null && (info!.added.isNotEmpty || info!.fixed.isNotEmpty)) ...[
                Label('What’s in ${info!.version}'),
                FadeIn(
                  index: 1,
                  child: Box(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final f in info!.added) UpdatePrompt._line('New', f, context.accent),
                      for (final f in info!.fixed) UpdatePrompt._line('Fixed', f, C.green),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FadeIn(
                index: 2,
                child: Box(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    RowTile(
                      title: 'Check automatically',
                      subtitle: 'Popup and notification when a new version is ready',
                      trailing: Switch(value: prefs.autoUpdateCheck, onChanged: (v) => prefs.autoUpdateCheck = v),
                    ),
                    const Divider(),
                    RowTile(title: 'All release notes', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsNewScreen()))),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('The first time, Android asks to allow installs from TaskOra — tap Settings, switch it on, then go back and tap Install.',
                  style: TextStyle(color: context.mutedText, fontSize: 12.5, height: 1.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.onTint.withOpacity(0.75))),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.onTint)),
          ]),
        ),
      );
}
