import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';

extension Ctx on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get surface => Theme.of(this).colorScheme.surface;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get mutedText => isDark ? const Color(0xFFA3A3B2) : C.muted;
  Store get store => read<Store>();
}

final dShort = DateFormat('d MMM');
final dLong = DateFormat('EEE, d MMM y');
final dTime = DateFormat('d MMM, h:mm a');

String fmtMoney(double v, String cur) {
  final f = NumberFormat.currency(name: cur, symbol: currencySymbols[cur] ?? '$cur ', decimalDigits: v == v.roundToDouble() ? 0 : 2);
  return f.format(v);
}

const currencySymbols = {
  'USD': r'$', 'EUR': '€', 'GBP': '£', 'BDT': '৳', 'INR': '₹', 'PKR': 'Rs ', 'AED': 'AED ', 'SAR': 'SAR ',
  'CAD': r'CA$', 'AUD': r'A$', 'JPY': '¥', 'CNY': 'CN¥', 'MYR': 'RM ', 'SGD': r'S$', 'TRY': '₺', 'NGN': '₦',
};

const priorityColors = [Color(0xFFD64545), Color(0xFFE08A1E), Color(0xFF2C6CB8), Color(0xFF8A8A99)];
Color priorityColor(int p) => priorityColors[(p - 1).clamp(0, 3)];

/// Rounded pastel square with an icon.
class IconTile extends StatelessWidget {
  final String icon;
  final int color;
  final double size;
  const IconTile({super.key, required this.icon, required this.color, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(iconOf(icon), color: p.fg, size: size * 0.5),
    );
  }
}

class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color? bg;
  final Color? fg;
  const RoundButton({super.key, required this.icon, this.onTap, this.tooltip = '', this.bg, this.fg});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: bg ?? context.surface,
          shape: CircleBorder(side: BorderSide(color: context.isDark ? Colors.white10 : C.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 21, color: fg)),
          ),
        ),
      );
}

/// Page header: round back button, big title, optional actions.
class Header extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool back;
  const Header(this.title, {super.key, this.actions = const [], this.back = true});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: Row(children: [
          if (back) ...[
            RoundButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Back', onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          ...actions.expand((a) => [const SizedBox(width: 8), a]),
        ]),
      );
}

/// White rounded card.
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.radius = 22});
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? context.surface,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class Label extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const Label(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.mutedText))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// A row inside a settings-style list.
class RowTile extends StatelessWidget {
  final IconData? icon;
  final int color;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const RowTile({super.key, this.icon, this.color = 0, required this.title, this.subtitle, this.value, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            if (icon != null) ...[
              Container(width: 34, height: 34, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: p.fg)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12.5, color: context.mutedText)),
              ]),
            ),
            if (value != null) Text(value!, style: TextStyle(fontSize: 13.5, color: context.mutedText, fontWeight: FontWeight.w600)),
            if (trailing != null) trailing! else if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.mutedText),
          ]),
        ),
      ),
    );
  }
}

/// Pastel chip used for statuses, categories and tags.
class TagChip extends StatelessWidget {
  final Tag tag;
  final bool selected;
  final VoidCallback? onTap;
  final bool small;
  const TagChip(this.tag, {super.key, this.selected = true, this.onTap, this.small = false});
  @override
  Widget build(BuildContext context) {
    final p = pastel(tag.color);
    return Material(
      color: selected ? p.bg : context.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.bg : (context.isDark ? Colors.white12 : C.line))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12, vertical: small ? 4 : 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(iconOf(tag.icon), size: small ? 13 : 16, color: selected ? p.fg : context.mutedText),
            SizedBox(width: small ? 4 : 6),
            Text(tag.label, style: TextStyle(fontSize: small ? 11.5 : 13, fontWeight: FontWeight.w700, color: selected ? p.fg : null)),
          ]),
        ),
      ),
    );
  }
}

class TagPicker extends StatelessWidget {
  final List<Tag> tags;
  final String value;
  final ValueChanged<String> onChanged;
  const TagPicker({super.key, required this.tags, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final t in tags) TagChip(t, selected: t.key == value, onTap: () => onChanged(t.key))],
      );
}

class PriorityPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const PriorityPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var p = 1; p <= 4; p++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: p < 4 ? 8 : 0),
                child: Material(
                  color: value == p ? priorityColor(p).withOpacity(0.14) : context.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: value == p ? priorityColor(p) : (context.isDark ? Colors.white12 : C.line))),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onChanged(p),
                    child: SizedBox(
                      height: 44,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.flag_rounded, size: 16, color: priorityColor(p)),
                        const SizedBox(width: 4),
                        Text('P$p', style: TextStyle(fontWeight: FontWeight.w800, color: priorityColor(p))),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

/// Segmented control.
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: context.isDark ? Colors.white10 : const Color(0xFFF1EEF8), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: it.$1 == value ? context.surface : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                  child: Text(it.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: it.$1 == value ? context.accent : context.mutedText)),
                ),
              ),
            ),
        ]),
      );
}

/// A tappable date/time row. Long-press clears it.
class DateRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final bool withTime;
  final ValueChanged<DateTime?> onChanged;
  const DateRow({super.key, required this.label, required this.icon, required this.value, required this.onChanged, this.withTime = false});
  @override
  Widget build(BuildContext context) => RowTile(
        icon: icon,
        color: 12,
        title: label,
        value: value == null ? 'Not set' : (withTime ? dTime : dLong).format(value!),
        trailing: value == null
            ? null
            : IconButton(tooltip: 'Clear', icon: Icon(Icons.close_rounded, size: 18, color: context.mutedText), onPressed: () => onChanged(null)),
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 10));
          if (d == null) return;
          if (!withTime || !context.mounted) {
            onChanged(d);
            return;
          }
          final t = await showTimePicker(context: context, initialTime: value != null ? TimeOfDay.fromDateTime(value!) : const TimeOfDay(hour: 9, minute: 0));
          onChanged(DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0));
        },
      );
}

/// Row of colour dots.
class ColorDots extends StatelessWidget {
  final List<Color> colors;
  final List<Color>? rings;
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const ColorDots({super.key, required this.colors, this.rings, required this.value, required this.onChanged, this.size = 34});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < colors.length; i++)
            Semantics(
              button: true,
              selected: i == value,
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    border: Border.all(color: i == value ? context.accent : (rings?[i] ?? C.line), width: i == value ? 2.5 : 1),
                  ),
                  child: i == value ? Icon(Icons.check_rounded, size: size * 0.5, color: rings?[i] ?? C.ink) : null,
                ),
              ),
            ),
        ],
      );
}

/// Full icon library in a sheet. Returns the chosen icon name.
Future<String?> pickIcon(BuildContext context, {String? current, int color = 0}) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IconSheet(current: current, color: color),
    );

class _IconSheet extends StatefulWidget {
  final String? current;
  final int color;
  const _IconSheet({this.current, this.color = 0});
  @override
  State<_IconSheet> createState() => _IconSheetState();
}

class _IconSheetState extends State<_IconSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final p = pastel(widget.color);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(children: [
            Text('Choose an icon', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('$iconCount icons', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search icons', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
            for (final g in iconGroups)
              if (g.icons.keys.any((k) => k.contains(q) || g.name.toLowerCase().contains(q))) ...[
                Label(g.name),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in g.icons.entries)
                    if (q.isEmpty || e.key.contains(q) || g.name.toLowerCase().contains(q))
                      Tooltip(
                        message: e.key,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, e.key),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: e.key == widget.current ? p.bg : (context.isDark ? Colors.white10 : C.bg),
                              borderRadius: BorderRadius.circular(14),
                              border: e.key == widget.current ? Border.all(color: p.fg, width: 2) : null,
                            ),
                            child: Icon(e.value, color: e.key == widget.current ? p.fg : null),
                          ),
                        ),
                      ),
                ]),
              ],
          ]),
        ),
      ]),
    );
  }
}

/// The 8 quick icons + "Browse all" link used on create screens.
class IconQuickPick extends StatelessWidget {
  final String value;
  final int color;
  final List<String> quick;
  final ValueChanged<String> onChanged;
  const IconQuickPick({super.key, required this.value, required this.color, required this.onChanged, this.quick = const ['work', 'code', 'palette', 'campaign', 'money', 'school', 'home', 'rocket']});
  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    final shown = quick.contains(value) ? quick : [value, ...quick.take(7)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in shown)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(k),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: k == value ? p.bg : context.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: k == value ? p.fg : C.line, width: k == value ? 2 : 1)),
              child: Icon(iconOf(k), size: 21, color: k == value ? p.fg : context.mutedText),
            ),
          ),
      ]),
      TextButton.icon(
        onPressed: () async {
          final k = await pickIcon(context, current: value, color: color);
          if (k != null) onChanged(k);
        },
        icon: const Icon(Icons.apps_rounded, size: 18),
        label: Text('Browse $iconCount icons'),
      ),
    ]);
  }
}

// ---------------- sync + undo ----------------

/// Pull down to sync, on any page.
class SyncRefresh extends StatelessWidget {
  final Widget child;
  const SyncRefresh({super.key, required this.child});
  @override
  Widget build(BuildContext context) => RefreshIndicator(
        color: context.accent,
        edgeOffset: 8,
        // Works inside board columns too, not only the page's own list.
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        onRefresh: () => syncNow(context),
        child: child,
      );
}

Future<void> syncNow(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  final store = context.read<Store>();
  m.hideCurrentSnackBar();
  try {
    await store.sync();
    m.showSnackBar(const SnackBar(content: Row(children: [Icon(Icons.cloud_done_rounded, color: Color(0xFFA6F0C6)), SizedBox(width: 10), Text('Synced · everything is up to date')]), duration: Duration(seconds: 2)));
  } catch (_) {
    m.showSnackBar(const SnackBar(content: Row(children: [Icon(Icons.cloud_off_rounded, color: Color(0xFFFFC7D9)), SizedBox(width: 10), Expanded(child: Text('Offline · changes are saved and will sync later'))])));
  }
}

/// Shows "Deleted" with an Undo button for 5 seconds.
void showUndo(BuildContext context, String message, Future<void> Function() undo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: 'Undo', onPressed: () => undo()),
  ));
}

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const EmptyState({super.key, required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
        child: Column(children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 32, color: context.accent)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, height: 1.5)),
        ]),
      );
}

/// Square checkbox in the brand style.
class CheckDot extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  const CheckDot({super.key, required this.value, required this.onTap, this.color, this.size = 24});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    return Semantics(
      checked: value,
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(color: value ? c : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: c, width: 2)),
            child: value ? Icon(Icons.check_rounded, size: size * 0.66, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}

/// "Soon" pill for features that are not ready yet.
class SoonPill extends StatelessWidget {
  const SoonPill({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(10)),
        child: const Text('Soon', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.amber)),
      );
}
