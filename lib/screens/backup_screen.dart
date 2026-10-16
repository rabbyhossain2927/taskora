import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Live sync status + automatic backups to Google Drive and phone storage.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busyDrive = false, busyLocal = false, loading = true;
  List<BackupEntry> local = [], drive = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      local = await BackupService.listLocal();
    } catch (_) {}
    try {
      drive = await BackupService.listDrive();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  String _ago(int ms) {
    if (ms == 0) return 'Never';
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} days ago';
  }

  Future<void> _run(bool toDrive) async {
    final s = context.read<Store>();
    setState(() {
      if (toDrive) {
        busyDrive = true;
      } else {
        busyLocal = true;
      }
    });
    try {
      if (toDrive) {
        final ok = await BackupService.backupDrive(s);
        if (mounted) toast(context, ok ? 'Backed up to Google Drive' : 'Google Drive wasn’t connected');
      } else {
        await BackupService.backupLocal(s);
        if (mounted) toast(context, 'Saved to phone storage');
      }
      await s.addNotice('Backup complete', toDrive ? 'Saved to Google Drive.' : 'Saved to phone storage.', 'backup');
    } catch (e) {
      if (mounted) toast(context, 'Backup failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          busyDrive = false;
          busyLocal = false;
        });
        _load();
      }
    }
  }

  Future<void> _restore(BackupEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text('${e.name}\n\nItems in the backup replace items with the same id. Everything else stays.'),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Restore'))],
      ),
    );
    if (ok != true || !mounted) return;
    final s = context.read<Store>();
    try {
      final n = e.onDrive ? await BackupService.restoreDrive(s, e.id) : await BackupService.restoreLocal(s, e.id);
      if (mounted) toast(context, 'Restored $n items');
    } catch (err) {
      if (mounted) toast(context, 'Restore failed: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Prefs>();
    final s = context.watch<Store>();
    final all = [...drive, ...local]..sort((a, b) => b.time.compareTo(a.time));
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await syncNow(context);
            await _load();
          },
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const Header('Backup & sync'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Box(
                  color: s.syncError != null ? C.redBg : (s.hasPendingWrites ? C.amberBg : C.greenBg),
                  child: Row(children: [
                    s.syncing
                        ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3))
                        : Icon(s.syncError != null ? Icons.cloud_off_outlined : (s.hasPendingWrites ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined),
                            color: s.syncError != null ? C.red : (s.hasPendingWrites ? C.amber : C.green), size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.syncError != null ? 'Can’t reach your server' : (s.hasPendingWrites ? '${s.pendingCount} changes waiting' : 'Synced with your server'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.ink)),
                        Text(
                            s.syncError ??
                                (s.lastSyncedAt == null ? 'Not synced yet.' : 'Last synced ${_ago(s.lastSyncedAt!.millisecondsSinceEpoch)} · checks every minute'),
                            style: const TextStyle(color: Color(0xFF3F3F4A), fontSize: 13, height: 1.4)),
                      ]),
                    ),
                    TextButton(onPressed: s.syncing ? null : () => syncNow(context), child: const Text('Sync')),
                  ]),
                ),
                const Label('Automatic backups'),
                _card(
                  icon: Icons.add_to_drive_rounded,
                  color: 12,
                  title: 'Google Drive',
                  sub: 'Private app folder in your Drive',
                  auto: p.driveAuto,
                  setAuto: (v) => p.driveAuto = v,
                  freq: p.driveFreq,
                  setFreq: (v) => p.driveFreq = v,
                  last: _ago(p.lastDrive),
                  busy: busyDrive,
                  onRun: () => _run(true),
                ),
                const SizedBox(height: 10),
                _card(
                  icon: Icons.phone_android_rounded,
                  color: 8,
                  title: 'Phone storage',
                  sub: 'Saved on this phone',
                  auto: p.localAuto,
                  setAuto: (v) => p.localAuto = v,
                  freq: p.localFreq,
                  setFreq: (v) => p.localFreq = v,
                  last: _ago(p.lastLocal),
                  busy: busyLocal,
                  onRun: () => _run(false),
                ),
                Label('Restore', trailing: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null),
                Box(
                  padding: EdgeInsets.zero,
                  child: all.isEmpty
                      ? Padding(padding: const EdgeInsets.all(16), child: Text('No backups yet.', style: TextStyle(color: context.mutedText)))
                      : Column(children: [
                          for (final e in all.take(12))
                            ListTile(
                              leading: Icon(e.onDrive ? Icons.add_to_drive_rounded : Icons.phone_android_rounded, color: pastel(e.onDrive ? 12 : 8).fg),
                              title: Text(dTime.format(e.time.toLocal()), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${e.onDrive ? 'Google Drive' : 'Phone'} · ${(e.size / 1024).toStringAsFixed(1)} KB'),
                              trailing: TextButton(onPressed: () => _restore(e), child: const Text('Restore')),
                            ),
                        ]),
                ),
                const Label('Move your data'),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
                      onPressed: () => BackupService.exportAndShare(s),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        final text = data?.text ?? '';
                        if (text.trim().isEmpty) {
                          if (context.mounted) toast(context, 'Copy the backup file’s text first, then tap Import.');
                          return;
                        }
                        try {
                          final n = await BackupService.importFromText(s, text);
                          if (context.mounted) toast(context, 'Imported $n items');
                        } catch (e) {
                          if (context.mounted) toast(context, 'Not a TaskOra backup');
                        }
                      },
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('Import'),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required int color,
    required String title,
    required String sub,
    required bool auto,
    required ValueChanged<bool> setAuto,
    required String freq,
    required ValueChanged<String> setFreq,
    required String last,
    required bool busy,
    required VoidCallback onRun,
  }) {
    final c = pastel(color);
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: c.fg)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              Text(sub, style: TextStyle(color: context.mutedText, fontSize: 12.5)),
            ]),
          ),
          Switch(value: auto, onChanged: setAuto),
        ]),
        const SizedBox(height: 12),
        Segmented<String>(items: const [('Daily', 'Daily'), ('Weekly', 'Weekly'), ('Monthly', 'Monthly')], value: freq, onChanged: setFreq),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('Last backup: $last', style: TextStyle(color: context.mutedText, fontSize: 13, fontWeight: FontWeight.w600))),
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: busy ? null : onRun,
            child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Back up now'),
          ),
        ]),
      ]),
    );
  }
}
