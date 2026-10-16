import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'note_editor.dart';
import 'notes_screen.dart';
import 'project_editor.dart';
import 'projects_screen.dart';
import 'stats_screen.dart';
import 'todo_editor.dart';
import 'todos_screen.dart';
import 'update_screen.dart';

/// The five tabs with the floating pill nav and the + button.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with WidgetsBindingObserver {
  late int tab = Prefs.instance.startTab.clamp(0, 4);
  bool menuOpen = false;

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
  void go(int i) => setState(() => tab = i);

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

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), ProjectsScreen(), StatsScreen(), TodosScreen(), NotesScreen()];
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
          if (menuOpen)
            Positioned.fill(
              child: GestureDetector(onTap: () => setState(() => menuOpen = false), child: Container(color: Colors.black.withOpacity(0.35))),
            ),
          if (menuOpen)
            Positioned(
              right: 20,
              bottom: 110,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _AddItem('Project', Icons.work_outline, 0, () => _add(const ProjectEditor())),
                const SizedBox(height: 10),
                _AddItem('To-do', Icons.check_circle_outline, 8, () => _add(const TodoEditor())),
                const SizedBox(height: 10),
                _AddItem('Note', Icons.sticky_note_2_outlined, 6, () => _add(const NoteEditor())),
              ]),
            ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Expanded(child: _PillNav(tab: tab, onTap: (i) {
                if (Prefs.instance.haptics) HapticFeedback.selectionClick();
                setState(() {
                  tab = i;
                  menuOpen = false;
                });
              })),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: menuOpen ? 'Close' : 'Add new',
                child: GestureDetector(
                  onTap: () => setState(() => menuOpen = !menuOpen),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(color: menuOpen ? const Color(0xFF1A1A1F) : context.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: context.accent.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))]),
                    child: AnimatedRotation(turns: menuOpen ? 0.125 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.add_rounded, color: Colors.white, size: 30)),
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
  final VoidCallback onTap;
  const _AddItem(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
        color: context.surface,
        shape: const StadiumBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 12),
              IconTileRaw(icon: icon, color: color),
            ]),
          ),
        ),
      );
}

class IconTileRaw extends StatelessWidget {
  final IconData icon;
  final int color;
  const IconTileRaw({super.key, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return Container(width: 38, height: 38, decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle), child: Icon(icon, size: 20, color: p.fg));
  }
}

class _PillNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _PillNav({required this.tab, required this.onTap});
  static const items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.work_outline, Icons.work_rounded, 'Projects'),
    (Icons.insights_outlined, Icons.insights_rounded, 'Stats'),
    (Icons.check_circle_outline, Icons.check_circle_rounded, 'To-do'),
    (Icons.sticky_note_2_outlined, Icons.sticky_note_2_rounded, 'Notes'),
  ];
  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF26262E) : const Color(0xFF1A1A1F),
          borderRadius: BorderRadius.circular(31),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == tab,
                button: true,
                label: items[i].$3,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: i == tab ? Colors.white : Colors.transparent, shape: BoxShape.circle),
                      child: Icon(i == tab ? items[i].$2 : items[i].$1, color: i == tab ? const Color(0xFF1A1A1F) : Colors.white70, size: 23),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}
