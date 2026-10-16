import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
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

class ShellState extends State<Shell> with WidgetsBindingObserver {
  late int tab = Prefs.instance.startTab.clamp(0, 3);
  bool menuOpen = false;

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
  void go(int i) => setState(() {
        tab = i.clamp(0, 3);
        menuOpen = false;
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      UpdatePrompt.checkInBackground(context);
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) BackupService.runAutoBackups(context.read<Store>());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<Store>().syncQuietly();
      UpdatePrompt.checkInBackground(context);
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
            tab = 0;
          }
        });
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(children: [
          IndexedStack(index: tab, children: pages),
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
            bottom: 104 + MediaQuery.of(context).padding.bottom,
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
                      width: 62,
                      height: 62,
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
    return Container(
      height: 62,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF22222C) : Colors.white,
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: dark ? Colors.white10 : context.accent.withOpacity(0.10)),
        boxShadow: [BoxShadow(color: (dark ? Colors.black : context.accent).withOpacity(dark ? 0.4 : 0.12), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            flex: i == tab ? 5 : 3,
            child: Semantics(
              selected: i == tab,
              button: true,
              label: items[i].$3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(color: i == tab ? context.tint : Colors.transparent, borderRadius: BorderRadius.circular(25)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(i == tab ? items[i].$2 : items[i].$1, size: 22, color: i == tab ? context.accent : context.mutedText),
                    if (i == tab)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(items[i].$3,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.onTint)),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
