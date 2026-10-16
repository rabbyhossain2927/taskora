import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            const Header('About'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Box(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    const Logo(),
                    const SizedBox(height: 12),
                    Text.rich(TextSpan(children: [const TextSpan(text: 'Task'), TextSpan(text: 'Ora', style: TextStyle(color: context.accent))]),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    FutureBuilder<AppVersion>(
                      future: UpdateService.current(),
                      builder: (_, s) => Text(s.hasData ? 'Version ${s.data!.version} (build ${s.data!.build})' : '', style: TextStyle(color: context.mutedText, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                    Text('Projects, to-dos and notes in one calm place. Everything links to everything, works offline and syncs to all your phones.',
                        textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, height: 1.6)),
                  ]),
                ),
                const SizedBox(height: 14),
                Box(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    RowTile(icon: Icons.description_outlined, color: 0, title: 'Terms & conditions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen()))),
                    const Divider(),
                    RowTile(icon: Icons.shield_outlined, color: 8, title: 'Privacy policy', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(privacy: true)))),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('© ${DateTime.now().year} TaskOra · rabbyhossain.com\nMade for people who juggle a lot.', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, fontSize: 12, height: 1.6)),
              ]),
            ),
          ]),
        ),
      );
}

class LegalScreen extends StatefulWidget {
  final bool privacy;
  const LegalScreen({super.key, this.privacy = false});
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late bool privacy = widget.privacy;
  static const terms = [
    ('1. Using TaskOra', 'TaskOra helps you plan projects, to-dos and notes. You may use it for personal or work purposes as long as you follow these terms and the law.'),
    ('2. Your account', 'You sign in with Google or email. Keep your login safe. You are responsible for what happens in your account.'),
    ('3. Your content', 'Everything you create stays yours. We only store it so the app can sync and back it up for you.'),
    ('4. Licence and payments', 'A lifetime licence works on the number of phones shown on the License page. Licences are personal and cannot be resold.'),
    ('5. Changes', 'We may update the app and these terms. We will tell you in the app before important changes take effect.'),
  ];
  static const policy = [
    ('What we collect', 'Your name, email and the projects, to-dos and notes you create. We do not sell your data or show ads.'),
    ('Where it is stored', 'Your data is saved on your phone and synced to the TaskOra server at rabbyhossain.com. Google Firebase is used only to sign you in. Backups go to your own Google Drive or phone storage.'),
    ('Who can see it', 'Only you. Our team never reads your notes.'),
    ('Your choices', 'Export everything as a file at any time, or delete your account from Edit profile. Deletion removes your data from the server straight away.'),
    ('Contact', 'Questions about privacy? Use Contact support on the About page.'),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            const Header('Legal'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Segmented<bool>(items: const [(false, 'Terms & conditions'), (true, 'Privacy policy')], value: privacy, onChanged: (v) => setState(() => privacy = v)),
                const SizedBox(height: 12),
                Text('Last updated 16 October 2026', style: TextStyle(color: context.mutedText, fontSize: 12)),
                for (final s in privacy ? policy : terms) ...[
                  const SizedBox(height: 16),
                  Text(s.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(s.$2, style: const TextStyle(height: 1.6)),
                ],
              ]),
            ),
          ]),
        ),
      );
}

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});
  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  bool show = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            const Header('License'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(26)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)),
                      child: const Text('● Active', style: TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Lifetime', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                    const Text('Pay once. All updates included.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                      child: Text(show ? 'TKORA-FREE-EARLY-ACCESS' : 'TKORA-••••-••••-ACCESS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                    ),
                    TextButton(onPressed: () => setState(() => show = !show), child: Text(show ? 'Hide key' : 'Show full key', style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline))),
                  ]),
                ),
                const SizedBox(height: 14),
                Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Have a new key?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Expanded(child: TextField(decoration: InputDecoration(hintText: 'TKORA-XXXX-XXXX-XXXX'))),
                      const SizedBox(width: 8),
                      FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 54)), onPressed: () => toast(context, 'Licence keys arrive with paid plans — everything is unlocked for now.'), child: const Text('Activate')),
                    ]),
                    const SizedBox(height: 8),
                    Text('During early access every feature is unlocked. Licence keys and phone limits arrive with paid plans.', style: TextStyle(color: context.mutedText, fontSize: 12.5, height: 1.5)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
}

/// Release notes, read from your GitHub Releases (so they're always current).
class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});
  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  late Future<List<UpdateInfo>> future = UpdateService.releases();
  int sel = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: FutureBuilder<List<UpdateInfo>>(
            future: future,
            builder: (context, snap) {
              final list = snap.data ?? const <UpdateInfo>[];
              return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                const Header('What’s new'),
                if (snap.connectionState != ConnectionState.done) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                if (snap.hasError)
                  EmptyState(icon: Icons.wifi_off_rounded, title: 'Couldn’t load release notes', body: 'Check your internet and try again.\n${snap.error}'),
                if (snap.connectionState == ConnectionState.done && !snap.hasError && list.isEmpty)
                  const EmptyState(icon: Icons.auto_awesome, title: 'No releases yet', body: 'Release notes show here after the first update is published.'),
                if (list.isNotEmpty) ...[
                  SizedBox(
                    height: 44,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                      for (var i = 0; i < list.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(label: Text('v${list[i].version}${i == 0 ? ' · latest' : ''}'), selected: sel == i, onSelected: (_) => setState(() => sel = i)),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(24)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (list[sel].published != null) Text(dLong.format(list[sel].published!.toLocal()), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('Version ${list[sel].version}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                          if (list[sel].summary.isNotEmpty) Text(list[sel].summary, style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                      _section(context, 'New features', Icons.auto_awesome, 0, list[sel].added),
                      _section(context, 'Fixed', Icons.build_outlined, 8, list[sel].fixed),
                    ]),
                  ),
                ],
              ]);
            },
          ),
        ),
      );

  Widget _section(BuildContext context, String title, IconData icon, int color, List<String> items) {
    final p = pastel(color);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 15, color: p.fg)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('${items.length}', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w700)),
        ]),
      ),
      Box(
        child: items.isEmpty
            ? Text('Nothing in this release.', style: TextStyle(color: context.mutedText))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(color == 8 ? Icons.check_circle : Icons.circle, size: color == 8 ? 16 : 8, color: p.fg)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(i, style: const TextStyle(height: 1.45))),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}
