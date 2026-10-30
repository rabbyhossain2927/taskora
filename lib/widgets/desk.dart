import 'package:flutter/material.dart';
import '../theme.dart';
import 'common.dart';

/// Shared pieces for the computer (web) layouts, matching the web design.
bool deskWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 1000;

const deskInk = Color(0xFF16161D);
const deskLink = Color(0xFF4A4ED6);
const deskLine = Color(0xFFF1F0F8);

/// Page title + subtitle on the left, controls on the right.
class DeskHead extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const DeskHead(this.title, {super.key, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: context.mutedText))),
          ]),
        ),
        ...actions.expand((a) => [const SizedBox(width: 12), a]),
      ]);
}

/// White card with the soft violet shadow.
class DeskCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const DeskCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18), this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: softCard(18, color ?? context.surface),
        child: child,
      );
}

/// Card heading.
class DeskH extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const DeskH(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))), if (trailing != null) trailing!]),
      );
}

/// White segmented switch (Week / Month / Year …).
class DeskSeg<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const DeskSeg({super.key, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0F281E6E), blurRadius: 2, offset: Offset(0, 1))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final it in items)
            DeskHover(
              onTap: () => onChanged(it.$1),
              radius: 9,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 34,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: it.$1 == value ? (context.isDark ? Colors.white12 : context.selTint) : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: Text(it.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: it.$1 == value ? context.selInk : context.mutedText)),
              ),
            ),
        ]),
      );
}

/// Rounded button: primary (theme colour), soft (lavender) or white.
class DeskBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String kind; // primary | soft | white | danger
  final double height;
  const DeskBtn(this.label, {super.key, this.icon, this.onTap, this.kind = 'soft', this.height = 40});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      'primary' => (context.accent, Colors.white),
      'white' => (context.surface, context.selInk),
      'danger' => (const Color(0xFFFDE2E2), const Color(0xFFB42318)),
      _ => (context.isDark ? Colors.white12 : context.softFill, context.isDark ? Colors.white : context.selInk),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        hoverColor: kind == 'primary' ? Colors.white.withOpacity(0.10) : context.accent.withOpacity(0.06),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: kind == 'primary' ? BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: context.accent.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 5))]) : null,
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Small rounded label.
Widget deskChip(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );

/// Filter chip ("All · 11").
class DeskFilter extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const DeskFilter(this.label, {super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => DeskHover(
        onTap: onTap,
        radius: 99,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? context.accent : context.surface,
            borderRadius: BorderRadius.circular(99),
            boxShadow: on ? [BoxShadow(color: context.accent.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))] : const [BoxShadow(color: Color(0x0F281E6E), blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : (context.isDark ? Colors.white70 : const Color(0xFF4B4B5A)))),
        ),
      );
}

/// Soft hover: a light lavender wash and a pointer cursor, no jumping.
class DeskHover extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final double radius;
  final EdgeInsets padding;
  final bool wash;
  const DeskHover({super.key, required this.child, this.onTap, this.onSecondaryTap, this.radius = 12, this.padding = EdgeInsets.zero, this.wash = false});
  @override
  State<DeskHover> createState() => _DeskHoverState();
}

class _DeskHoverState extends State<DeskHover> {
  bool h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => h = true),
        onExit: (_) => setState(() => h = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onSecondaryTap: widget.onSecondaryTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.wash && h ? (context.isDark ? Colors.white.withOpacity(0.04) : context.hoverTint) : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
            child: AnimatedSlide(duration: const Duration(milliseconds: 160), curve: Curves.easeOut, offset: !widget.wash && h && widget.onTap != null ? const Offset(0, -0.01) : Offset.zero, child: widget.child),
          ),
        ),
      );
}

/// Thin progress bar.
Widget deskBar(double v, Color c, {double h = 6}) => ClipRRect(
      borderRadius: BorderRadius.circular(h / 2),
      child: LinearProgressIndicator(value: v.clamp(0.0, 1.0), minHeight: h, color: c, backgroundColor: const Color(0xFFECEBFA)),
    );

/// Page wrapper: padding + scroll.
class DeskScroll extends StatelessWidget {
  final List<Widget> children;
  const DeskScroll({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(28, 22, 28, 28), children: children),
        ),
      );
}

/// Toggle row for settings panels.
class DeskSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;
  const DeskSwitch(this.label, this.value, this.onChanged, {super.key, this.last = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: deskLine))),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))), Switch(value: value, onChanged: onChanged)]),
      );
}

/// Pastel used for categories / kinds by index.
Pastel deskPastel(int i) => pastel(i);

/// Computers: open an editor (to-do, project…) in a popup with a close (×)
/// button in the corner. Phones: open it as a normal page.
Future<void> openEditor(BuildContext context, Widget editor) {
  if (!isDesktop(context)) return Navigator.push(context, MaterialPageRoute(builder: (_) => editor));
  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (d) {
      final size = MediaQuery.sizeOf(d);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Theme.of(d).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720, maxHeight: size.height * 0.88),
          child: SizedBox(
            width: 720,
            height: size.height * 0.88,
            child: Stack(children: [
              // Its own navigator, so "Save" (which goes back) closes just the popup.
              Positioned.fill(
                child: NoBack(
                  child: Navigator(
                    onGenerateRoute: (_) => PageRouteBuilder(pageBuilder: (_, __, ___) => editor, transitionDuration: Duration.zero),
                    observers: [_CloseOnEmpty(d)],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Tooltip(
                  message: 'Close',
                  child: Material(
                    color: Theme.of(d).brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : context.softFill,
                    shape: const CircleBorder(),
                    child: InkWell(customBorder: const CircleBorder(), onTap: () => Navigator.of(d).pop(), child: const SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 20))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

/// When the editor inside the popup goes back (after Save / Delete), close the popup.
class _CloseOnEmpty extends NavigatorObserver {
  final BuildContext dialog;
  _CloseOnEmpty(this.dialog);
  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute == null) WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(dialog).pop());
  }
}
