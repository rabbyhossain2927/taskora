import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../screens/profile_screen.dart';

extension Ctx on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get tint => Theme.of(this).colorScheme.primaryContainer;
  Color get onTint => Theme.of(this).colorScheme.onPrimaryContainer;
  Color get surface => Theme.of(this).colorScheme.surface;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get mutedText => isDark ? const Color(0xFFA3A3B2) : C.muted;
  Store get store => read<Store>();
}

final dShort = DateFormat('d MMM');
final dLong = DateFormat('EEE, d MMM y');
final dTime = DateFormat('d MMM, h:mm a');

/// A deadline: "18 Oct", "18 Oct, 5:00 PM", or with the year when it isn't this year.
String fmtDue(DateTime d, {bool long = false}) {
  final hasTime = d.hour != 0 || d.minute != 0;
  final otherYear = d.year != DateTime.now().year;
  final date = DateFormat(long ? (otherYear ? 'EEE, d MMM y' : 'EEE, d MMM') : (otherYear ? 'd MMM y' : 'd MMM')).format(d);
  return hasTime ? '$date, ${DateFormat('h:mm a').format(d)}' : date;
}

/// Pick a deadline date, then an optional time. Returns null if cancelled.
Future<DateTime?> pickDeadline(BuildContext context, DateTime? current) async {
  final now = DateTime.now();
  final d = await showDatePicker(context: context, initialDate: current ?? now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 10), helpText: 'Deadline');
  if (d == null || !context.mounted) return null;
  final had = current != null && (current.hour != 0 || current.minute != 0);
  final t = await showTimePicker(context: context, helpText: 'Add a time (optional)', cancelText: 'No time', initialTime: had ? TimeOfDay.fromDateTime(current) : const TimeOfDay(hour: 17, minute: 0));
  return t == null ? d : DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// Date and time an item was made or changed: "Today, 9:41 AM", "Yesterday, …", "12 Oct 2026, …"
String fmtStamp(DateTime d) {
  final now = DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final t = DateFormat('h:mm a').format(d);
  if (day == today) return 'Today, $t';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $t';
  return '${DateFormat(d.year == now.year ? 'd MMM' : 'd MMM y').format(d)}, $t';
}

String fmtMoney(double v, String cur) {
  final f = NumberFormat.currency(name: cur, symbol: currencySymbols[cur] ?? '$cur ', decimalDigits: v == v.roundToDouble() ? 0 : 2);
  return f.format(v);
}

const currencySymbols = {
  'USD': r'$', 'EUR': '€', 'GBP': '£', 'BDT': '৳', 'INR': '₹', 'PKR': 'Rs ', 'AED': 'AED ', 'SAR': 'SAR ',
  'CAD': r'CA$', 'AUD': r'A$', 'JPY': '¥', 'CNY': 'CN¥', 'MYR': 'RM ', 'SGD': r'S$', 'TRY': '₺', 'NGN': '₦',
};

/// 1 Urgent · 2 High · 3 Medium · 4 Low · 5 None
const priorityNames = ['Urgent', 'High', 'Medium', 'Low', 'None'];
const priorityColors = [Color(0xFFE5484D), Color(0xFFF08C2E), Color(0xFF3E7BFA), Color(0xFF2EAD6B), Color(0xFF9A9AA8)];
Color priorityColor(int p) => priorityColors[(p - 1).clamp(0, 4)];
String priorityName(int p) => priorityNames[(p - 1).clamp(0, 4)];

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
        child: Pressable(
          scale: 0.9,
          child: Material(
          color: bg ?? context.surface,
          shape: CircleBorder(side: BorderSide(color: context.isDark ? Colors.white10 : C.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 21, color: fg)),
          ),
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
          Expanded(child: Text(title, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w700, letterSpacing: -0.3), overflow: TextOverflow.ellipsis)),
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
  Widget build(BuildContext context) {
    final m = Material(
      color: color ?? context.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    return onTap == null ? m : Pressable(child: m);
  }
}

/// Shrinks a little while pressed, then springs back.
class Pressable extends StatefulWidget {
  final Widget child;
  final double scale;
  const Pressable({super.key, required this.child, this.scale = 0.97});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => down = true),
        onPointerUp: (_) => setState(() => down = false),
        onPointerCancel: (_) => setState(() => down = false),
        child: AnimatedScale(
          scale: down ? widget.scale : 1,
          duration: Duration(milliseconds: down ? 90 : 220),
          curve: down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      );
}

/// A number that counts up when it appears or changes.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  const AnimatedCount(this.value, {super.key, this.style, this.suffix = ''});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}$suffix', style: style),
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
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: context.mutedText))),
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
    return AnimatedScale(
      scale: selected ? 1 : 0.97,
      duration: const Duration(milliseconds: 200),
      child: Material(
      animationDuration: const Duration(milliseconds: 220),
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
    ),
    );
  }
}

class TagPicker extends StatelessWidget {
  final List<Tag> tags;
  final String value;
  final ValueChanged<String> onChanged;
  /// When set, shows a "+ Other" chip that asks for a new name.
  final Future<void> Function(String name)? onAdd;
  const TagPicker({super.key, required this.tags, required this.value, required this.onChanged, this.onAdd});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in tags) TagChip(t, selected: t.key == value, onTap: () => onChanged(t.key)),
          if (onAdd != null)
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16, color: context.accent),
              label: Text('Other', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.accent)),
              onPressed: () async {
                final name = await askText(context, title: 'New category', hint: 'e.g. Freelance');
                if (name != null && name.isNotEmpty) await onAdd!(name);
              },
            ),
        ],
      );
}

/// Adds a category to a list in the Store and returns its key.
Future<String> addCategory(Store s, String field, String name) async {
  final list = List<Tag>.of(field == 'projectCats' ? s.projectCats : s.todoCats);
  final key = 'c${DateTime.now().millisecondsSinceEpoch}';
  list.add(Tag(key, name, (list.length * 3) % pastels.length, 'label'));
  await s.saveTaxonomy(field, list);
  return key;
}

class PriorityPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const PriorityPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var p = 1; p <= 5; p++)
            Material(
              color: value == p ? priorityColor(p).withOpacity(0.13) : context.surface,
              shape: StadiumBorder(side: BorderSide(color: value == p ? priorityColor(p) : (context.isDark ? Colors.white12 : C.line))),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(p == 5 ? Icons.outlined_flag_rounded : Icons.flag_rounded, size: 15, color: priorityColor(p)),
                    const SizedBox(width: 5),
                    Text(priorityName(p), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value == p ? priorityColor(p) : null)),
                  ]),
                ),
              ),
            ),
        ],
      );
}

/// Small coloured flag + name, e.g. "High".
class PriorityBadge extends StatelessWidget {
  final int p;
  final bool showNone;
  const PriorityBadge(this.p, {super.key, this.showNone = false});
  @override
  Widget build(BuildContext context) {
    if (p >= 5 && !showNone) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(p >= 5 ? Icons.outlined_flag_rounded : Icons.flag_rounded, size: 13, color: priorityColor(p)),
      const SizedBox(width: 3),
      Text(priorityName(p), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: priorityColor(p))),
    ]);
  }
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
                  child: Text(it.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: it.$1 == value ? context.accent : context.mutedText)),
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
  /// Date first, then an optional time (cancel the clock to keep just the date).
  final bool optionalTime;
  final ValueChanged<DateTime?> onChanged;
  const DateRow({super.key, required this.label, required this.icon, required this.value, required this.onChanged, this.withTime = false, this.optionalTime = false});
  @override
  Widget build(BuildContext context) => RowTile(
        icon: icon,
        color: 12,
        title: label,
        value: value == null ? 'Not set' : (optionalTime ? fmtDue(value!, long: true) : (withTime ? dTime : dLong).format(value!)),
        trailing: value == null
            ? null
            : IconButton(tooltip: 'Clear', icon: Icon(Icons.close_rounded, size: 18, color: context.mutedText), onPressed: () => onChanged(null)),
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 10));
          if (d == null) return;
          if (optionalTime && context.mounted) {
            final had = value != null && (value!.hour != 0 || value!.minute != 0);
            final t = await showTimePicker(context: context, helpText: 'Add a time (optional)', cancelText: 'No time', initialTime: had ? TimeOfDay.fromDateTime(value!) : const TimeOfDay(hour: 17, minute: 0));
            onChanged(t == null ? d : DateTime(d.year, d.month, d.day, t.hour, t.minute));
            return;
          }
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
            Text('Choose an icon', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
        child: const Text('Soon', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.amber)),
      );
}


// ---------------- avatar / profile ----------------

class Avatar extends StatelessWidget {
  final double size;
  final bool ring;
  const Avatar({super.key, this.size = 44, this.ring = true});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName?.trim().isNotEmpty ?? false) ? u!.displayName! : (u?.email ?? 'You');
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    final pic = u?.photoURL;
    final inner = CircleAvatar(
      radius: size / 2 - (ring ? size * 0.09 : 0),
      backgroundColor: context.tint,
      foregroundImage: pic != null ? NetworkImage(pic) : null,
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.w700, color: context.onTint, fontSize: size * 0.3)),
    );
    if (!ring) return inner;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.045),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [context.accent, context.accent.withOpacity(0.35), context.accent])),
      child: Container(
        padding: EdgeInsets.all(size * 0.04),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).canvasColor),
        child: inner,
      ),
    );
  }
}

/// Round avatar that opens Profile. Shown at the top of every main page.
class ProfileButton extends StatelessWidget {
  final double size;
  const ProfileButton({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Profile',
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Avatar(size: size),
        ),
      );
}

/// Title row for the main tabs: big title, optional actions, profile avatar.
class MainHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const MainHeader(this.title, {super.key, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: T.display, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: T.small, color: context.mutedText)),
            ]),
          ),
          ...actions.expand((a) => [a, const SizedBox(width: 8)]),
          const ProfileButton(),
        ]),
      );
}

// ---------------- animation ----------------

/// Fades and slides its child in once. Use `index` to stagger lists.
class FadeIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double dy;
  const FadeIn({super.key, required this.child, this.index = 0, this.dy = 14});
  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10)) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Interval(delay / (380 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: c)),
      child: child,
    );
  }
}

/// Progress ring that animates to its value.
class AnimatedRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? center;
  const AnimatedRing({super.key, required this.value, this.size = 72, this.stroke = 7, required this.color, required this.track, this.center});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: v, strokeWidth: stroke, color: color, backgroundColor: track, strokeCap: StrokeCap.round)),
            if (center != null) Padding(padding: EdgeInsets.all(stroke + 4), child: FittedBox(child: center)),
          ]),
        ),
      );
}

/// Gently pulses (used for the greeting sun/moon).
class Breathing extends StatefulWidget {
  final Widget child;
  const Breathing({super.key, required this.child});
  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) => Transform.rotate(angle: (c.value - 0.5) * 0.18, child: Transform.scale(scale: 1 + c.value * 0.06, child: child)),
        child: widget.child,
      );
}

// ---------------- menus ----------------

class ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const ActionItem(this.icon, this.label, this.onTap, {this.danger = false});
}

/// Long-press menu as a bottom sheet.
Future<void> showActions(BuildContext context, {required String title, String? subtitle, required List<ActionItem> items}) =>
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: T.heading, fontWeight: FontWeight.w700)),
                if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: T.small, color: ctx.mutedText)),
              ]),
            ),
            for (final it in items)
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(it.icon, color: it.danger ? C.red : ctx.accent, size: 21),
                title: Text(it.label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: it.danger ? C.red : null)),
                onTap: () {
                  Navigator.pop(ctx);
                  it.onTap();
                },
              ),
          ]),
        ),
      ),
    );

/// Pick one option from a list (bottom sheet). Returns the chosen value.
Future<V?> pickOne<V>(BuildContext context, {required String title, required List<(V, String)> options, V? current, List<IconData>? icons}) =>
    showModalBottomSheet<V>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text(title, style: const TextStyle(fontSize: T.heading, fontWeight: FontWeight.w700))),
            for (var i = 0; i < options.length; i++)
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                selected: options[i].$1 == current,
                selectedTileColor: ctx.tint,
                leading: icons != null && i < icons.length ? Icon(icons[i], size: 20) : null,
                title: Text(options[i].$2, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                trailing: options[i].$1 == current ? Icon(Icons.check_rounded, color: ctx.accent) : null,
                onTap: () => Navigator.pop(ctx, options[i].$1),
              ),
          ]),
        ),
      ),
    );

/// A settings row whose value opens a dropdown menu.
class DropdownTile<V> extends StatelessWidget {
  final IconData? icon;
  final int color;
  final String title;
  final String? subtitle;
  final V value;
  final List<(V, String)> options;
  final ValueChanged<V> onChanged;
  const DropdownTile({super.key, this.icon, this.color = 0, required this.title, this.subtitle, required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final label = options.where((o) => o.$1 == value).map((o) => o.$2).firstOrNull ?? options.first.$2;
    return RowTile(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      trailing: PopupMenuButton<V>(
        initialValue: value,
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (_) => [for (final o in options) PopupMenuItem<V>(value: o.$1, height: 42, child: Text(o.$2, style: const TextStyle(fontSize: 14)))],
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.onTint)),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.onTint),
          ]),
        ),
      ),
    );
  }
}

/// Ask for a line of text.
Future<String?> askText(BuildContext context, {required String title, String initial = '', String hint = '', bool number = false}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: T.heading, fontWeight: FontWeight.w700)),
      content: TextField(controller: c, autofocus: true, keyboardType: number ? TextInputType.number : null, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: hint), onSubmitted: (v) => Navigator.pop(d, v.trim())),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Save'))],
    ),
  );
}
