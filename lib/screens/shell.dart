import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/focus_service.dart';
import '../services/notify_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'focus_screen.dart';
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
    setState(() {
      tab = next;
      menuOpen = false;
    });
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

  void _add(Widget page) {
    setState(() => menuOpen = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page, fullscreenDialog: true));
  }

  void _haptic() {
    if (Prefs.instance.haptics) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), ProjectsScreen(), TodosScreen(), NotesScreen()];
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
          AnimatedBuilder(
            animation: fade,
            builder: (_, child) {
              final v = Curves.easeOutCubic.transform(fade.value);
              return Opacity(opacity: 0.35 + 0.65 * v, child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child));
            },
            child: IndexedStack(index: tab, children: pages),
          ),
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
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      setState(() => menuOpen = false);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
                    },
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
