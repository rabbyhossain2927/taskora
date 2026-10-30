import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../services/prefs.dart';
import '../widgets/common.dart';
import '../widgets/desk.dart';
import 'notification_settings.dart';
import 'update_screen.dart';

/// Swipe a notification right-to-left for Read / Delete.
/// Tap "Select" to pick many and delete or mark them read together.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool selecting = false;
  final picked = <String>{};
  String show = 'all'; // computers: all | reminder | update | backup

  static const kinds = {
    'reminder': (Icons.alarm, 0),
    'update': (Icons.system_update_alt_rounded, 12),
    'sync': (Icons.cloud_done_outlined, 8),
    'badge': (Icons.emoji_events_outlined, 6),
    'backup': (Icons.backup_outlined, 10),
  };

  Future<void> _delete(Store s, Iterable<String> ids) async {
    final list = ids.toList();
    final undo = await s.deleteDocs('notices', list);
    setState(() {
      picked.clear();
      selecting = false;
    });
    if (mounted) showUndo(context, list.length == 1 ? 'Notification deleted' : '${list.length} notifications deleted', undo);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final list = s.notices;
    final allPicked = list.isNotEmpty && picked.length == list.length;
    if (deskWide(context)) {
      final p = context.watch<Prefs>();
      final muted = context.mutedText;
      final shown = list.where((n) => show == 'all' || n.kind == show || (show == 'backup' && n.kind == 'sync')).toList();
      return DeskScroll(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DeskHead('Notifications', subtitle: s.unreadCount == 0 ? 'All caught up' : '${s.unreadCount} unread', actions: [
                DeskSeg<String>(items: const [('all', 'All'), ('reminder', 'Reminders'), ('update', 'Updates'), ('backup', 'Backups')], value: show, onChanged: (v) => setState(() => show = v)),
                if (s.unreadCount > 0) DeskBtn('Mark all as read', kind: 'white', onTap: () => s.markRead(list.where((n) => !n.read).map((n) => n.id))),
              ]),
              const SizedBox(height: 14),
              DeskCard(
                padding: EdgeInsets.zero,
                child: shown.isEmpty
                    ? Padding(padding: const EdgeInsets.all(22), child: Text('Nothing here. Reminders, update alerts and backup news show up here.', style: TextStyle(color: muted)))
                    : Column(children: [
                        for (var i = 0; i < shown.length; i++)
                          Builder(builder: (_) {
                            final n = shown[i];
                            final k = kinds[n.kind] ?? kinds['reminder']!;
                            final pp = pastel(k.$2);
                            return DeskHover(
                              wash: true,
                              radius: 0,
                              onTap: () {
                                if (!n.read) s.markRead([n.id]);
                                if (n.kind == 'update') Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateScreen()));
                              },
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                                decoration: BoxDecoration(
                                  color: n.read ? null : (context.isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFFAF8FF)),
                                  border: i == shown.length - 1 ? null : const Border(bottom: BorderSide(color: deskLine)),
                                ),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(width: 38, height: 38, decoration: BoxDecoration(color: pp.bg, borderRadius: BorderRadius.circular(12)), child: Icon(k.$1, size: 19, color: pp.fg)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w700, fontSize: 14)),
                                      if (n.body.isNotEmpty) Text(n.body, style: TextStyle(fontSize: 13, color: muted)),
                                    ]),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(fmtStamp(n.createdAt), style: TextStyle(fontSize: 12, color: muted)),
                                  const SizedBox(width: 10),
                                  Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: n.read ? Colors.transparent : context.accent, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<int>(
                                    tooltip: 'More',
                                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: muted),
                                    onSelected: (v) => v == 0 ? s.markRead([n.id], !n.read) : _delete(s, [n.id]),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 0, child: Text(n.read ? 'Mark as unread' : 'Mark as read')),
                                      const PopupMenuItem(value: 1, child: Text('Delete', style: TextStyle(color: C.red))),
                                    ],
                                  ),
                                ]),
                              ),
                            );
                          }),
                      ]),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 360,
            child: DeskCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                const Text('What to show', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                DeskSwitch('Notifications', p.notificationsOn, (v) => p.notificationsOn = v),
                DeskSwitch('Reminders', p.remindersOn, (v) => p.remindersOn = v),
                DeskSwitch('Focus timer', p.focusAlerts, (v) => p.focusAlerts = v),
                DeskSwitch('Daily summary', p.dailySummary, (v) => p.dailySummary = v, last: true),
                const SizedBox(height: 8),
                Text('On the web, reminders show while TaskOra is open. Your phone still reminds you when it’s closed.', style: TextStyle(fontSize: 12.5, height: 1.5, color: muted)),
                const SizedBox(height: 12),
                DeskBtn('More settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),
              ]),
            ),
          ),
        ]),
      ]);
    }
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Header('Notifications', actions: [
            if (!selecting) RoundButton(icon: Icons.settings_outlined, tooltip: 'Notification settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),
            if (list.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  selecting = !selecting;
                  picked.clear();
                }),
                child: Text(selecting ? 'Cancel' : 'Select', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]),
          if (selecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 20, 4),
              child: Row(children: [
                Checkbox(value: allPicked, onChanged: (_) => setState(() {
                  if (allPicked) {
                    picked.clear();
                  } else {
                    picked.addAll(list.map((n) => n.id));
                  }
                })),
                Text(allPicked ? 'Unselect all' : 'Select all', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${picked.length} selected', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w700)),
              ]),
            )
          else if (s.unreadCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(onPressed: () => s.markRead(list.where((n) => !n.read).map((n) => n.id)), child: const Text('Mark all as read')),
              ),
            ),
          Expanded(
            child: SyncRefresh(
              child: list.isEmpty
                  ? ListView(children: const [EmptyState(icon: Icons.notifications_none_rounded, title: 'All caught up', body: 'Reminders, update alerts and backup news show up here.')])
                  : SlidableAutoCloseBehavior(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => FadeIn(index: i, child: _row(s, list[i])),
                      ),
                    ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
                      onPressed: picked.isEmpty
                          ? null
                          : () async {
                              await s.markRead(picked);
                              setState(() {
                                picked.clear();
                                selecting = false;
                              });
                            },
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Mark read'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.red),
                      onPressed: picked.isEmpty ? null : () => _delete(s, Set.of(picked)),
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Delete (${picked.length})'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }

  Widget _row(Store s, AppNotice n) {
    final k = kinds[n.kind] ?? kinds['reminder']!;
    final p = pastel(k.$2);
    final tile = Box(
      onTap: () {
        if (selecting) {
          setState(() => picked.contains(n.id) ? picked.remove(n.id) : picked.add(n.id));
          return;
        }
        if (!n.read) s.markRead([n.id]);
        if (n.kind == 'update') Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateScreen()));
      },
      color: n.read ? null : (context.isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF6F2FF)),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (selecting) Padding(padding: const EdgeInsets.only(right: 4), child: Checkbox(value: picked.contains(n.id), onChanged: (_) => setState(() => picked.contains(n.id) ? picked.remove(n.id) : picked.add(n.id)))),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(13)), child: Icon(k.$1, size: 20, color: p.fg)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w700, fontSize: 14.5)),
            if (n.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(n.body, style: TextStyle(color: context.mutedText, fontSize: 13, height: 1.4))),
            const SizedBox(height: 4),
            Text(dTime.format(n.createdAt), style: TextStyle(color: context.mutedText, fontSize: 11.5)),
          ]),
        ),
        if (!n.read) Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle)),
      ]),
    );
    if (selecting) return tile;
    return Slidable(
      key: ValueKey(n.id),
      endActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.48, children: [
        SlidableAction(
          onPressed: (_) => s.markRead([n.id], !n.read),
          backgroundColor: const Color(0xFFE6DEFF),
          foregroundColor: C.purpleDark,
          icon: n.read ? Icons.mark_email_unread_outlined : Icons.done_all_rounded,
          label: n.read ? 'Unread' : 'Read',
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
        ),
        SlidableAction(
          onPressed: (_) => _delete(s, [n.id]),
          backgroundColor: C.red,
          foregroundColor: Colors.white,
          icon: Icons.delete_outline,
          label: 'Delete',
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
        ),
      ]),
      child: tile,
    );
  }
}
