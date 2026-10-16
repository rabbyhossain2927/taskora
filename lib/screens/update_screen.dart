import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notify_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screens.dart';

/// Background check + the "Update ready" popup.
class UpdatePrompt {
  static bool _showing = false;

  /// Runs on app start and whenever the app comes back to the front
  /// (at most every 3 hours). Shows a phone notification + a popup.
  static Future<void> checkInBackground(BuildContext context) async {
    final prefs = Prefs.instance;
    if (!prefs.autoUpdateCheck || _showing) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - prefs.lastUpdateCheck < const Duration(hours: 3).inMilliseconds) return;
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

  static Future<void> show(BuildContext context, UpdateInfo u) async {
    _showing = true;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: ctx.accent, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.download_rounded, color: Colors.white, size: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Update ready', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(['Version ${u.version}', if (u.sizeLabel.isNotEmpty) u.sizeLabel].join(' · '), style: TextStyle(color: ctx.mutedText, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ctx.isDark ? Colors.white10 : C.bg, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final f in u.fixed.take(3)) _line('Fixed', f, C.green),
              for (final f in u.added.take(3)) _line('New', f, C.purpleDark),
              if (u.fixed.isEmpty && u.added.isEmpty) Text(u.summary.isEmpty ? 'Bug fixes and improvements.' : u.summary),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  UpdateService.download(u);
                },
                child: const Text('Update now'),
              ),
            ),
          ]),
          TextButton(
            onPressed: () {
              Prefs.instance.skippedVersion = u.version;
              Navigator.pop(ctx);
            },
            child: Text('Skip this version', style: TextStyle(color: ctx.mutedText)),
          ),
        ]),
      ),
    );
    _showing = false;
  }

  static Widget _line(String tag, String text, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$tag · ', style: TextStyle(fontWeight: FontWeight.w700, color: c)),
          TextSpan(text: text),
        ]), style: const TextStyle(fontSize: 13.5, height: 1.45)),
      );
}

/// Profile > Check for update.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String state = 'checking'; // checking | latest | available | error
  String error = '';
  UpdateInfo? info;
  AppVersion? cur;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => state = 'checking');
    try {
      cur = await UpdateService.current();
      final u = await UpdateService.check();
      Prefs.instance.lastUpdateCheck = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        info = u;
        state = u == null ? 'latest' : 'available';
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        state = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<Prefs>();
    final (title, sub, icon, bg, fg) = switch (state) {
      'latest' => ('You’re up to date', 'TaskOra ${cur?.version ?? ''} is the latest version.', Icons.check_rounded, C.greenBg, C.green),
      'available' => ('Version ${info!.version} is available', info!.summary.isEmpty ? 'Tap below to download it.' : info!.summary, Icons.download_rounded, const Color(0xFFEFEAFE), C.purple),
      'error' => ('Couldn’t check', error, Icons.wifi_off_rounded, C.redBg, C.red),
      _ => ('Checking…', 'Looking for a newer version.', Icons.sync_rounded, const Color(0xFFEFEAFE), C.purple),
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          const Header('App updates'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Box(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: state == 'checking' ? Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 4, color: fg)) : Icon(icon, size: 34, color: fg),
                  ),
                  const SizedBox(height: 12),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(sub, textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, height: 1.5)),
                  const SizedBox(height: 16),
                  if (state == 'available')
                    FilledButton.icon(onPressed: () => UpdateService.download(info!), icon: const Icon(Icons.download_rounded), label: Text(['Download update', if (info!.sizeLabel.isNotEmpty) info!.sizeLabel].join(' · ')))
                  else
                    FilledButton(onPressed: state == 'checking' ? null : _check, child: Text(state == 'checking' ? 'Checking…' : 'Check again')),
                ]),
              ),
              if (state == 'available' && (info!.added.isNotEmpty || info!.fixed.isNotEmpty)) ...[
                Label('In version ${info!.version}'),
                Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final f in info!.added) UpdatePrompt._line('New', f, C.purpleDark),
                    for (final f in info!.fixed) UpdatePrompt._line('Fixed', f, C.green),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  RowTile(title: 'Installed version', value: cur == null ? '…' : '${cur!.version} (build ${cur!.build})'),
                  const Divider(),
                  RowTile(
                    title: 'Check automatically',
                    subtitle: 'Shows a notification and a popup when a fix is ready',
                    trailing: Switch(value: prefs.autoUpdateCheck, onChanged: (v) => prefs.autoUpdateCheck = v),
                  ),
                  const Divider(),
                  RowTile(title: 'All release notes', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsNewScreen()))),
                ]),
              ),
              const SizedBox(height: 12),
              Text('Updates download as an APK. The first time, Android asks you to allow installs from your browser — tap Settings, allow, then go back and tap Install.',
                  style: TextStyle(color: context.mutedText, fontSize: 12.5, height: 1.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}
