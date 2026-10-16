import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sync status, full backups (phone + Google Drive), restore, and storage use.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busyDrive = false, busyLocal = false, loadingDrive = true;
  List<BackupEntry> local = [], drive = [];
  (int, int)? storage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      local = await BackupService.listLocal();
    } catch (_) {}
    if (mounted) setState(() {});
    try {
      if (Prefs.instance.driveAuto) drive = await BackupService.listDrive();
    } catch (_) {}
    try {
      storage = await FileService.usage();
    } catch (_) {}
    if (mounted) setState(() => loadingDrive = false);
  }

  String _when(int ms) {
    if (ms == 0) return 'Never';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay ? 'Today at ${DateFormat('h:mm a').format(d)}' : DateFormat('d MMM, h:mm a').format(d);
  }

  Future<void> _backupLocal() async {
    setState(() => busyLocal = true);
    try {
      await BackupService.backupLocal(context.read<Store>());
      if (mounted) toast(context, 'Backup saved on this phone');
    } catch (e) {
      if (mounted) toast(context, 'Backup failed: $e');
    } finally {
      if (mounted) setState(() => busyLocal = false);
      _load();
    }
  }

  Future<void> _backupDrive() async {
    setState(() => busyDrive = true);
    try {
      final ok = await BackupService.backupDrive(context.read<Store>());
      if (mounted) toast(context, ok ? 'Backed up to Google Drive' : 'Google Drive wasn’t connected');
    } catch (e) {
      if (mounted) toast(context, BackupService.friendlyDriveError(e));
    } finally {
      if (mounted) setState(() => busyDrive = false);
      _load();
    }
  }

  Future<void> _restore(BackupEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text('${DateFormat('d MMM y, h:mm a').format(e.time.toLocal())}\n\nItems in the backup replace items with the same name. Everything else stays.'),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Restore'))],
      ),
    );
    if (ok != true || !mounted) return;
    final s = context.read<Store>();
    try {
      final n = e.onDrive ? await BackupService.restoreDrive(s, e.id) : await BackupService.restoreLocal(s, e.id);
      if (mounted) toast(context, 'Restored $n items');
    } catch (err) {
      if (mounted) toast(context, e.onDrive ? BackupService.friendlyDriveError(err) : 'Restore failed: $err');
    }
  }

  Future<void> _restoreFromFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    try {
      final n = await BackupService.importFromText(context.read<Store>(), await File(path).readAsString());
      if (mounted) toast(context, 'Restored $n items');
    } catch (e) {
      if (mounted) toast(context, 'That file is not a TaskOra backup.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Prefs>();
    final s = context.watch<Store>();
    final err = s.syncError != null;
    final (statusText, statusIcon, statusColor) = err
        ? ('Can’t reach the server', Icons.cloud_off_rounded, C.red)
        : s.hasPendingWrites
            ? ('${s.pendingCount} changes waiting', Icons.cloud_upload_rounded, const Color(0xFFD48806))
            : ('Everything is synced', Icons.cloud_done_rounded, context.accent);

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
                // ---------- status ----------
                FadeIn(
                  child: Box(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                    radius: 26,
                    child: Column(children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
                        child: s.syncing ? Padding(padding: const EdgeInsets.all(22), child: CircularProgressIndicator(strokeWidth: 3, color: statusColor)) : Icon(statusIcon, color: statusColor, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(statusText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(FirebaseAuth.instance.currentUser?.email ?? '', style: TextStyle(color: context.mutedText, fontSize: 13)),
                      if (err) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.syncError!, textAlign: TextAlign.center, style: const TextStyle(color: C.red, fontSize: 12.5))),
                      const SizedBox(height: 16),
                      Row(children: [
                        _count(context, s.projects.length, 'Projects'),
                        _count(context, s.todos.length, 'To-dos'),
                        _count(context, s.notes.length, 'Notes'),
                      ]),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: s.syncing ? null : () => syncNow(context),
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(s.syncing ? 'Syncing…' : 'Sync now'),
                      ),
                      const SizedBox(height: 8),
                      Text(s.lastSyncedAt == null ? 'Not synced yet' : 'Last synced ${_when(s.lastSyncedAt!.millisecondsSinceEpoch)}', style: TextStyle(color: context.mutedText, fontSize: 12.5)),
                    ]),
                  ),
                ),

                // ---------- full backup ----------
                const Label('Full backup'),
                FadeIn(
                  index: 1,
                  child: Box(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      RowTile(
                        icon: Icons.download_rounded,
                        color: 0,
                        title: 'Back up now',
                        subtitle: 'Everything, saved on this phone',
                        trailing: busyLocal ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                        onTap: busyLocal ? null : _backupLocal,
                      ),
                      const Divider(),
                      DropdownTile<String>(
                        icon: Icons.schedule_rounded,
                        color: 12,
                        title: 'Automatic backup',
                        subtitle: 'Last: ${_when(p.lastLocal)}',
                        value: p.localAuto ? p.localFreq : 'Off',
                        options: const [('Daily', 'Every day'), ('Weekly', 'Every week'), ('Monthly', 'Every month'), ('Off', 'Off')],
                        onChanged: (v) {
                          if (v == 'Off') {
                            p.localAuto = false;
                          } else {
                            p.localAuto = true;
                            p.localFreq = v;
                          }
                        },
                      ),
                      const Divider(),
                      RowTile(icon: Icons.restore_page_outlined, color: 8, title: 'Restore from a file', subtitle: 'Pick a TaskOra backup (.json)', onTap: _restoreFromFile),
                    ]),
                  ),
                ),

                // ---------- google drive ----------
                const Label('Google Drive'),
                FadeIn(
                  index: 2,
                  child: Box(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      RowTile(
                        icon: Icons.add_to_drive_rounded,
                        color: 12,
                        title: 'Back up to Google Drive',
                        subtitle: 'Private app folder · last: ${_when(p.lastDrive)}',
                        trailing: Switch(value: p.driveAuto, onChanged: (v) => p.driveAuto = v),
                      ),
                      if (p.driveAuto) ...[
                        const Divider(),
                        DropdownTile<String>(
                          icon: Icons.schedule_rounded,
                          color: 12,
                          title: 'How often',
                          value: p.driveFreq,
                          options: const [('Daily', 'Every day'), ('Weekly', 'Every week'), ('Monthly', 'Every month')],
                          onChanged: (v) => p.driveFreq = v,
                        ),
                      ],
                      const Divider(),
                      RowTile(
                        icon: Icons.cloud_upload_outlined,
                        color: 10,
                        title: 'Back up to Drive now',
                        trailing: busyDrive ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                        onTap: busyDrive ? null : _backupDrive,
                      ),
                    ]),
                  ),
                ),

                // ---------- lists ----------
                Label('Backups on this phone · ${local.length} of ${p.keepBackups}'),
                FadeIn(
                  index: 3,
                  child: Box(
                    padding: EdgeInsets.zero,
                    child: local.isEmpty
                        ? Padding(padding: const EdgeInsets.all(16), child: Text('No backups yet.', style: TextStyle(color: context.mutedText)))
                        : Column(children: [
                            for (var i = 0; i < local.length; i++) ...[
                              if (i > 0) const Divider(),
                              _entry(local[i], latest: i == 0),
                            ],
                          ]),
                  ),
                ),
                if (drive.isNotEmpty) ...[
                  Label('On Google Drive · ${drive.length}'),
                  Box(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < drive.length && i < 10; i++) ...[
                        if (i > 0) const Divider(),
                        _entry(drive[i], latest: i == 0),
                      ],
                    ]),
                  ),
                ],

                // ---------- storage ----------
                if (storage != null) ...[
                  const Label('File storage'),
                  Box(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(FileService.sizeLabel(storage!.$1), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(' of ${FileService.sizeLabel(storage!.$2)} used', style: TextStyle(color: context.mutedText)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(value: storage!.$2 == 0 ? 0 : storage!.$1 / storage!.$2, minHeight: 8, backgroundColor: context.tint),
                      ),
                      const SizedBox(height: 6),
                      Text('Images and files you attach to projects and notes. Up to 30 MB each.', style: TextStyle(fontSize: 12, color: context.mutedText)),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _count(BuildContext context, int v, String l) => Expanded(
        child: Column(children: [
          AnimatedCount(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(l, style: TextStyle(fontSize: 12, color: context.mutedText)),
        ]),
      );

  Widget _entry(BackupEntry e, {bool latest = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: latest ? context.tint : (context.isDark ? Colors.white10 : const Color(0xFFF1F1F5)), borderRadius: BorderRadius.circular(13)),
            child: Icon(latest ? Icons.verified_rounded : (e.onDrive ? Icons.add_to_drive_rounded : Icons.inventory_2_outlined), color: latest ? context.accent : context.mutedText, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEE, d MMM y · h:mm a').format(e.time.toLocal()), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              Text('${(e.size / 1024).toStringAsFixed(0)} KB${latest ? ' · latest' : ''}', style: TextStyle(fontSize: 12, color: context.mutedText)),
            ]),
          ),
          IconButton(tooltip: 'Restore', icon: Icon(Icons.settings_backup_restore_rounded, color: context.accent), onPressed: () => _restore(e)),
          if (!e.onDrive) ...[
            IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share_rounded), onPressed: () => BackupService.shareLocal(e.id)),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, color: C.red),
              onPressed: () async {
                await BackupService.deleteLocal(e.id);
                _load();
              },
            ),
          ],
        ]),
      );
}
