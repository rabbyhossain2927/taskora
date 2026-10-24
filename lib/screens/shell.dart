import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/focus_service.dart';
import '../services/notify_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth_screens.dart' show Logo;
import 'bin_screen.dart';
import 'calendar_screen.dart';
import 'focus_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'stats_screen.dart';
import 'home_screen.dart';
import 'note_editor.dart';
import 'notes_screen.dart';
import 'project_editor.dart';
import 'projects_screen.dart';
import 'todo_editor.dart';
import 'todos_screen.dart';
import 'update_screen.dart';

/// The four tabs with the floating nav pill and the + button.
/// Tap + for Project / To-do / Note. Hold + to start Focus.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int tab = Prefs.instance.startTab.clamp(0, 3);
  late final AnimationController fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 360), value: 1);
  bool menuOpen = false;

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
  void go(int i) {
    final next = i.clamp(0, 3);
    if (next != tab) fade.forward(from: 0);
    if (_wide) contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      tab = next;
      menuOpen = false;
    });
    tabN.value = next;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Android 13+ only shows notifications after you allow them.
      try {
        await NotifyService.requestPermission();
      } catch (_) {}
      if (!mounted) return;
      UpdatePrompt.checkInBackground(context);
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) BackupService.runAutoBackups(context.read<Store>());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    fade.dispose();
    tabN.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      context.read<Store>().syncQuietly();
      context.read<Store>().checkReminders();
      FocusService.instance.refresh();
      UpdatePrompt.checkInBackground(context);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Save to the phone right away in case the app is closed.
      context.read<Store>().flush();
    }
  }

  /// Pages open inside the content area on computers (the sidebar stays).
  final contentNav = GlobalKey<NavigatorState>();
  late final tabN = ValueNotifier<int>(tab);
  bool _wide = false;

  NavigatorState get _nav => (_wide ? contentNav.currentState : null) ?? Navigator.of(context);

  /// Opens a page: inside the content area on computers, full screen on phones.
  void open(Widget page, {bool modal = false}) {
    setState(() => menuOpen = false);
    _nav.push(MaterialPageRoute(builder: (_) => page, fullscreenDialog: modal));
  }

  void _add(Widget page) => open(page, modal: true);

  void _haptic() {
    if (Prefs.instance.haptics) HapticFeedback.selectionClick();
  }

  void _openFocus() {
    HapticFeedback.mediumImpact();
    open(const FocusScreen());
  }

  Widget _tabs() => ValueListenableBuilder<int>(
        valueListenable: tabN,
        builder: (_, t, __) => AnimatedBuilder(
          animation: fade,
          builder: (_, child) {
            final v = Curves.easeOutCubic.transform(fade.value);
            return Opacity(opacity: 0.35 + 0.65 * v, child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child));
          },
          child: IndexedStack(index: t, children: [
            for (final (w, max) in const [(HomeScreen(), 1240.0), (ProjectsScreen(), 1320.0), (TodosScreen(), 920.0), (NotesScreen(), 1320.0)])
              // Computers: keep each page at a comfortable width, centred.
              _wide ? Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: w)) : w,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _wide = c.maxWidth >= 700;
      return _wide ? _desktop(c.maxWidth) : _phone();
    });
  }

  // ---------------- computers & tablets ----------------
  Widget _desktop(double width) {
    final full = width >= 1100;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, alt: true): () => _add(const TodoEditor()),
        const SingleActivator(LogicalKeyboardKey.keyP, alt: true): () => _add(const ProjectEditor()),
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () => _add(const NoteEditor()),
        const SingleActivator(LogicalKeyboardKey.keyF, alt: true): _openFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => open(const SearchScreen()),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => open(const SearchScreen()),
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => go(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => go(1),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => go(2),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => go(3),
        const SingleActivator(LogicalKeyboardKey.escape): () => contentNav.currentState?.maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(children: [
            _Sidebar(
              full: full,
              tab: tab,
              onTab: (i) {
                _haptic();
                go(i);
              },
              onAdd: _add,
              onOpen: open,
              onFocus: _openFocus,
            ),
            Expanded(
              child: ClipRect(
                child: NavigatorPopHandler(
                  onPop: () => contentNav.currentState?.maybePop(),
                  child: Navigator(
                    key: contentNav,
                    onGenerateRoute: (_) => PageRouteBuilder(pageBuilder: (_, __, ___) => _tabs(), transitionDuration: Duration.zero),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------- phones ----------------
  Widget _phone() {
    return PopScope(
      canPop: tab == 0 && !menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (menuOpen) {
            menuOpen = false;
          } else {
            go(0);
          }
        });
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(children: [
          _tabs(),
          IgnorePointer(
            ignoring: !menuOpen,
            child: AnimatedOpacity(
              opacity: menuOpen ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: GestureDetector(onTap: () => setState(() => menuOpen = false), child: Container(color: Colors.black.withOpacity(0.28))),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 112 + MediaQuery.of(context).padding.bottom,
            child: IgnorePointer(
              ignoring: !menuOpen,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _AddItem('Project', Icons.work_outline_rounded, 0, menuOpen, 2, () => _add(const ProjectEditor())),
                const SizedBox(height: 10),
                _AddItem('To-do', Icons.check_circle_outline_rounded, 8, menuOpen, 1, () => _add(const TodoEditor())),
                const SizedBox(height: 10),
                _AddItem('Note', Icons.sticky_note_2_outlined, 6, menuOpen, 0, () => _add(const NoteEditor())),
              ]),
            ),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: _NavPill(tab: tab, onTap: (i) {
                  _haptic();
                  go(i);
                }),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Tap to add · hold for Focus',
                child: Semantics(
                  button: true,
                  label: menuOpen ? 'Close' : 'Add new. Long press for Focus.',
                  child: GestureDetector(
                    onTap: () {
                      _haptic();
                      setState(() => menuOpen = !menuOpen);
                    },
                    onLongPress: _openFocus,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color.lerp(context.accent, Colors.white, 0.18)!, context.accent],
                        ),
                        boxShadow: [BoxShadow(color: context.accent.withOpacity(0.38), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: AnimatedRotation(
                        turns: menuOpen ? 0.125 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AddItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final int color;
  final bool open;
  final int order;
  final VoidCallback onTap;
  const _AddItem(this.label, this.icon, this.color, this.open, this.order, this.onTap);
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return AnimatedSlide(
      offset: open ? Offset.zero : const Offset(0, 0.6),
      duration: Duration(milliseconds: 200 + order * 40),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: Duration(milliseconds: 160 + order * 40),
        child: Material(
          color: context.surface,
          shape: const StadiumBorder(),
          elevation: 3,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(width: 12),
                Container(width: 36, height: 36, decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle), child: Icon(icon, size: 19, color: p.fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill bar; the selected tab is a pill in the theme colour with its
/// icon and name, and it slides between tabs.
class _NavPill extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _NavPill({required this.tab, required this.onTap});
  static const items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.work_outline_rounded, Icons.work_rounded, 'Projects'),
    (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'To-do'),
    (Icons.sticky_note_2_outlined, Icons.sticky_note_2_rounded, 'Notes'),
  ];
  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final a = context.accent;
    final bar = dark ? const Color(0xFF1E1E27) : Colors.white;
    final idle = dark ? const Color(0xFFA0A0B0) : const Color(0xFF8A8A99);
    const pad = 6.0;
    const curve = Curves.easeOutCubic;
    const dur = Duration(milliseconds: 320);
    return Container(
      height: 66,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(33),
        border: Border.all(color: dark ? Colors.white10 : const Color(0xFFEDEDF3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(dark ? 0.35 : 0.07), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: a.withOpacity(dark ? 0.10 : 0.08), blurRadius: 30, offset: const Offset(0, 6)),
        ],
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final selW = w * 0.40;
        final otherW = (w - selW) / (items.length - 1);
        double leftOf(int i) => i <= tab ? i * otherW : selW + (i - 1) * otherW;
        return Stack(children: [
          // Sliding light pill
          AnimatedPositioned(
            duration: dur,
            curve: curve,
            left: leftOf(tab),
            top: 0,
            bottom: 0,
            width: selW,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(a, Colors.white, 0.14)!, a]),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [BoxShadow(color: a.withOpacity(0.32), blurRadius: 12, offset: const Offset(0, 4))],
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: dur,
                curve: curve,
                width: i == tab ? selW : otherW,
                child: Semantics(
                  selected: i == tab,
                  button: true,
                  label: items[i].$3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: ClipRect(
                      child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (ch, an) => ScaleTransition(scale: an, child: ch),
                          child: Icon(
                            i == tab ? items[i].$2 : items[i].$1,
                            key: ValueKey('$i-${i == tab}'),
                            size: 23,
                            color: i == tab ? Colors.white : idle,
                          ),
                        ),
                        AnimatedSize(
                          duration: dur,
                          curve: curve,
                          child: i == tab
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(items[i].$3,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ]),
                    ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Sidebar for computers and tablets: same look as the phone nav pill.
class _Sidebar extends StatelessWidget {
  final bool full;
  final int tab;
  final ValueChanged<int> onTab;
  final void Function(Widget page) onAdd;
  final void Function(Widget page, {bool modal}) onOpen;
  final VoidCallback onFocus;
  const _Sidebar({required this.full, required this.tab, required this.onTab, required this.onAdd, required this.onOpen, required this.onFocus});

  static const tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home', 'Alt+1'),
    (Icons.work_outline_rounded, Icons.work_rounded, 'Projects', 'Alt+2'),
    (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'To-do', 'Alt+3'),
    (Icons.sticky_note_2_outlined, Icons.sticky_note_2_rounded, 'Notes', 'Alt+4'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final f = context.watch<FocusService>();
    final dark = context.isDark;
    final a = context.accent;
    final u = FirebaseAuth.instance.currentUser;
    final w = full ? 236.0 : 78.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: w,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E27) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: dark ? Colors.white10 : const Color(0xFFEDEDF3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(dark ? 0.35 : 0.06), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: a.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(full ? 18 : 0, 18, full ? 18 : 0, 14),
          child: Row(mainAxisAlignment: full ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            const Logo(size: 36),
            if (full) ...[
              const SizedBox(width: 10),
              const Text('TaskOra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
            ],
          ]),
        ),
        // + New
        Padding(
          padding: EdgeInsets.symmetric(horizontal: full ? 14 : 12),
          child: PopupMenuButton<int>(
            tooltip: 'New project, to-do or note',
            offset: const Offset(0, 56),
            onSelected: (v) {
              if (v == 0) onAdd(const ProjectEditor());
              if (v == 1) onAdd(const TodoEditor());
              if (v == 2) onAdd(const NoteEditor());
              if (v == 3) onFocus();
            },
            itemBuilder: (_) => [
              _menu(0, Icons.work_outline_rounded, 'Project', 'Alt+P', 0),
              _menu(1, Icons.check_circle_outline_rounded, 'To-do', 'Alt+T', 8),
              _menu(2, Icons.sticky_note_2_outlined, 'Note', 'Alt+N', 6),
              const PopupMenuDivider(),
              _menu(3, Icons.timer_outlined, 'Start focus', 'Alt+F', 12),
            ],
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(a, Colors.white, 0.18)!, a]),
                boxShadow: [BoxShadow(color: a.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                if (full) ...[
                  const SizedBox(width: 6),
                  const Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < tabs.length; i++)
          _Item(full: full, icon: i == tab ? tabs[i].$2 : tabs[i].$1, label: tabs[i].$3, hint: tabs[i].$4, selected: i == tab, onTap: () => onTab(i)),
        Padding(padding: EdgeInsets.symmetric(horizontal: full ? 20 : 16, vertical: 10), child: const Divider()),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _Item(full: full, icon: Icons.insights_rounded, label: 'Stats', onTap: () => onOpen(const StatsScreen())),
            _Item(full: full, icon: Icons.calendar_month_outlined, label: 'Calendar', onTap: () => onOpen(const CalendarScreen())),
            _Item(
              full: full,
              icon: f.active ? Icons.timer_rounded : Icons.timer_outlined,
              label: f.active ? 'Focus · ${FocusEngine.fmt(f.leftMs)}' : 'Focus',
              hint: 'Alt+F',
              onTap: onFocus,
            ),
            _Item(full: full, icon: Icons.notifications_none_rounded, label: 'Notifications', badge: s.unreadCount, onTap: () => onOpen(const NotificationsScreen())),
            _Item(full: full, icon: Icons.search_rounded, label: 'Search', hint: 'Ctrl+K', onTap: () => onOpen(const SearchScreen())),
            _Item(full: full, icon: Icons.archive_outlined, label: 'Archive', onTap: () => onOpen(const BinScreen(trash: false))),
            _Item(full: full, icon: Icons.delete_outline_rounded, label: 'Trash', onTap: () => onOpen(const BinScreen(trash: true))),
          ]),
        ),
        // Profile
        Padding(
          padding: const EdgeInsets.all(10),
          child: Material(
            color: dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF6F6FA),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onOpen(const ProfileScreen()),
              child: Padding(
                padding: EdgeInsets.all(full ? 10 : 8),
                child: Row(mainAxisAlignment: full ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                  Stack(children: [
                    const Avatar(size: 36, ring: false),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.syncError != null ? C.red : (s.hasPendingWrites ? const Color(0xFFD48806) : C.green),
                          border: Border.all(color: dark ? const Color(0xFF1E1E27) : Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ]),
                  if (full) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u?.displayName ?? 'You', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text(s.syncError != null ? 'Offline' : (s.syncing ? 'Syncing…' : 'Synced'), style: TextStyle(fontSize: 11.5, color: context.mutedText)),
                      ]),
                    ),
                    Icon(Icons.settings_outlined, size: 18, color: context.mutedText),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  PopupMenuItem<int> _menu(int v, IconData icon, String label, String hint, int color) {
    final p = pastel(color);
    return PopupMenuItem(
      value: v,
      child: Builder(
        builder: (context) => Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 17, color: p.fg)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(hint, style: TextStyle(fontSize: 11.5, color: context.mutedText)),
        ]),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  final bool full;
  final IconData icon;
  final String label;
  final String? hint;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _Item({required this.full, required this.icon, required this.label, this.hint, this.selected = false, this.badge = 0, required this.onTap});
  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final a = context.accent;
    final sel = widget.selected;
    final idle = context.isDark ? const Color(0xFFA0A0B0) : const Color(0xFF6E6E7C);
    final icon = Badge(
      isLabelVisible: widget.badge > 0,
      label: Text('${widget.badge}'),
      backgroundColor: C.red,
      child: Icon(widget.icon, size: 22, color: sel ? Colors.white : (hover ? a : idle)),
    );
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 46,
          margin: EdgeInsets.symmetric(horizontal: widget.full ? 12 : 14, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.full ? 14 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: sel ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(a, Colors.white, 0.14)!, a]) : null,
            color: sel ? null : (hover ? a.withOpacity(context.isDark ? 0.14 : 0.08) : Colors.transparent),
            boxShadow: sel ? [BoxShadow(color: a.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Row(mainAxisAlignment: widget.full ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            icon,
            if (widget.full) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 14, color: sel ? Colors.white : (hover ? a : null))),
              ),
              if (widget.hint != null && hover && !sel) Text(widget.hint!, style: TextStyle(fontSize: 11, color: context.mutedText)),
            ],
          ]),
        ),
      ),
    );
    return widget.full ? item : Tooltip(message: widget.hint == null ? widget.label : '${widget.label} (${widget.hint})', child: item);
  }
}
