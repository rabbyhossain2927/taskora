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

  /// Which sidebar page is open over the tabs on computers (null = a tab).
  final side = ValueNotifier<String?>(null);

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
  void go(int i) {
    final next = i.clamp(0, 3);
    if (next != tab) fade.forward(from: 0);
    if (_wide) contentNav.currentState?.popUntil((r) => r.isFirst);
    side.value = null;
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
    side.dispose();
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
  void open(Widget page, {bool modal = false, bool wide = false}) {
    setState(() => menuOpen = false);
    _nav.push(MaterialPageRoute(builder: (_) => page, fullscreenDialog: modal, settings: RouteSettings(name: wide ? 'wide' : null)));
  }

  void _add(Widget page) => open(page, modal: true);

  void _haptic() {
    if (Prefs.instance.haptics) HapticFeedback.selectionClick();
  }

  void _openFocus() {
    HapticFeedback.mediumImpact();
    if (_wide) return openSide('focus', const FocusScreen());
    open(const FocusScreen());
  }

  /// Computers: a sidebar page replaces whatever is open in the content area.
  void openSide(String key, Widget page) {
    contentNav.currentState?.popUntil((r) => r.isFirst);
    side.value = key;
    open(page, wide: true);
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
            for (final (w, max) in const [(HomeScreen(), double.infinity), (ProjectsScreen(), double.infinity), (TodosScreen(), double.infinity), (NotesScreen(), double.infinity)])
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
            ValueListenableBuilder<String?>(
              valueListenable: side,
              builder: (_, sd, __) => _Sidebar(
                full: full,
                tab: tab,
                side: sd,
                onTab: (i) {
                  _haptic();
                  go(i);
                },
                onSide: openSide,
                onFocus: _openFocus,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: NavigatorPopHandler(
                  onPop: () => contentNav.currentState?.maybePop(),
                  child: Navigator(
                    key: contentNav,
                    observers: [_SideObserver(side)],
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

/// Clears the sidebar highlight once you go back to the tabs.
class _SideObserver extends NavigatorObserver {
  final ValueNotifier<String?> side;
  _SideObserver(this.side);
  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute?.isFirst ?? false) side.value = null;
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

/// Sidebar for computers and tablets (web design): see-through white panel,
/// each item has its own pastel icon tile, the open page is a white pill.
class _Sidebar extends StatelessWidget {
  final bool full;
  final int tab;
  final String? side;
  final ValueChanged<int> onTab;
  final void Function(String key, Widget page) onSide;
  final VoidCallback onFocus;
  const _Sidebar({required this.full, required this.tab, required this.side, required this.onTab, required this.onSide, required this.onFocus});

  // key, label, icon, tile bg, icon colour
  static const _home = ('home', 'Home', Icons.home_rounded, Color(0xFFE9E6FF), Color(0xFF5B4FE0));
  static const _projects = ('projects', 'Projects', Icons.work_rounded, Color(0xFFFFE6F1), Color(0xFFC2306F));
  static const _todo = ('todo', 'To-do', Icons.check_circle_rounded, Color(0xFFDDF5E8), Color(0xFF1E7A50));
  static const _notes = ('notes', 'Notes', Icons.sticky_note_2_rounded, Color(0xFFFFF2D6), Color(0xFFA5650A));
  static const _stats = ('stats', 'Stats', Icons.insights_rounded, Color(0xFFE1EEFF), Color(0xFF2F5FD0));
  static const _cal = ('calendar', 'Calendar', Icons.calendar_month_rounded, Color(0xFFFFE6DE), Color(0xFFB8462E));
  static const _focus = ('focus', 'Focus', Icons.timer_rounded, Color(0xFFF2E4FF), Color(0xFF8236C9));
  static const _inbox = ('inbox', 'Notifications', Icons.notifications_rounded, Color(0xFFDDF4F7), Color(0xFF0B7A86));
  static const _bin = ('bin', 'Archive & Trash', Icons.inventory_2_rounded, Color(0xFFEEEEF3), Color(0xFF55556A));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final f = context.watch<FocusService>();
    final dark = context.isDark;
    final u = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final endToday = DateTime(now.year, now.month, now.day + 1);
    final due = s.todos.where((t) => !t.done && t.deadline != null && t.deadline!.isBefore(endToday)).length;
    final active = s.projects.where((p) => !p.done).length;
    final w = full ? 236.0 : 78.0;
    final cur = side ?? const ['home', 'projects', 'todo', 'notes'][tab];

    Widget item((String, String, IconData, Color, Color) d, VoidCallback onTap, {String badge = '', bool alert = false, String? hint}) =>
        _Item(full: full, data: d, selected: cur == d.$1, badge: badge, alert: alert, hint: hint, onTap: onTap);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: w,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111116) : Colors.white.withOpacity(0.72),
        border: Border(right: BorderSide(color: dark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.9))),
        boxShadow: dark ? null : const [BoxShadow(color: Color(0x0F7859DC), blurRadius: 30, offset: Offset(4, 0))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(full ? 20 : 0, 20, full ? 20 : 0, 16),
          child: Row(mainAxisAlignment: full ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            const Logo(size: 34),
            if (full) ...[
              const SizedBox(width: 10),
              const Text.rich(TextSpan(children: [TextSpan(text: 'Task'), TextSpan(text: 'Ora', style: TextStyle(color: Color(0xFF7054FB)))]),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ],
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            item(_home, () => onTab(0), hint: 'Alt+1'),
            item(_projects, () => onTab(1), badge: active > 0 ? '$active' : '', hint: 'Alt+2'),
            item(_todo, () => onTab(2), badge: due > 0 ? '$due' : '', alert: true, hint: 'Alt+3'),
            item(_notes, () => onTab(3), hint: 'Alt+4'),
            Padding(padding: EdgeInsets.symmetric(horizontal: full ? 20 : 16, vertical: 10), child: const Divider()),
            item(_stats, () => onSide('stats', const StatsScreen())),
            item(_cal, () => onSide('calendar', const CalendarScreen())),
            item(_focus, onFocus, badge: f.active ? FocusEngine.fmt(f.leftMs) : '', hint: 'Alt+F'),
            item(_inbox, () => onSide('inbox', const NotificationsScreen()), badge: s.unreadCount > 0 ? '${s.unreadCount}' : ''),
            item(_bin, () => onSide('bin', const BinScreen(trash: false))),
          ]),
        ),
        // Profile -> Account
        Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: dark ? Colors.white.withOpacity(0.05) : null,
                gradient: dark ? null : const LinearGradient(colors: [Color(0xFFFCE9FF), Color(0xFFE6F1FF)]),
                border: side == 'account' ? Border.all(color: const Color(0xFF7054FB), width: 1.5) : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSide('account', const ProfileScreen()),
                child: Padding(
                  padding: EdgeInsets.all(full ? 10 : 8),
                  child: Row(mainAxisAlignment: full ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                    const Avatar(size: 34, ring: false),
                    if (full) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u?.displayName ?? 'You', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(s.syncError != null ? 'Offline' : (s.syncing ? 'Syncing…' : 'Synced'),
                              style: TextStyle(fontSize: 11.5, color: s.syncError != null ? C.red : const Color(0xFF1E7A50))),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Item extends StatefulWidget {
  final bool full;
  final (String, String, IconData, Color, Color) data;
  final bool selected;
  final String badge;
  final bool alert;
  final String? hint;
  final VoidCallback onTap;
  const _Item({required this.full, required this.data, required this.selected, this.badge = '', this.alert = false, this.hint, required this.onTap});
  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final sel = widget.selected;
    final dark = context.isDark;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: sel ? null : (dark ? d.$5.withOpacity(0.18) : d.$4),
        gradient: sel ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [d.$5, d.$5.withOpacity(0.8)]) : null,
      ),
      child: Icon(d.$3, size: 17, color: sel ? Colors.white : (dark ? Color.lerp(d.$5, Colors.white, 0.4) : d.$5)),
    );
    final badge = widget.badge.isEmpty
        ? null
        : widget.alert && !sel
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(99)),
                child: Text(widget.badge, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB42318))),
              )
            : Text(widget.badge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.selInk));
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 42,
          margin: EdgeInsets.symmetric(horizontal: widget.full ? 12 : 14, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.full ? 8 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: sel ? context.selTint : (hover ? context.hoverTint : Colors.transparent),
            
          ),
          child: Row(mainAxisAlignment: widget.full ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            widget.full || badge == null ? tile : Badge(label: Text(widget.badge), backgroundColor: C.red, child: tile),
            if (widget.full) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(d.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 14, color: sel ? context.selInk : (dark ? null : const Color(0xFF4B4B5A)))),
              ),
              if (badge != null) badge,
            ],
          ]),
        ),
      ),
    );
    return widget.full ? item : Tooltip(message: widget.hint == null ? d.$2 : '${d.$2} (${widget.hint})', child: item);
  }
}
