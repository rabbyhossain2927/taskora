import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../icons.dart';
import '../models.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'taxonomy_screen.dart';

/// Create or edit a project: colour, icon, money + platform fee, dates,
/// status, priority, category, and splitting it into to-dos.
class ProjectEditor extends StatefulWidget {
  final String? id;
  const ProjectEditor({super.key, this.id});
  @override
  State<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<ProjectEditor> {
  late Project p;
  late bool isNew;
  bool money = false;
  final title = TextEditingController(), desc = TextEditingController(), amount = TextEditingController(), task = TextEditingController(), customFee = TextEditingController();
  final splits = <String>[];

  @override
  void initState() {
    super.initState();
    final s = context.read<Store>();
    final existing = widget.id == null ? null : s.project(widget.id);
    isNew = existing == null;
    final prefs = Prefs.instance;
    p = existing != null
        ? Project.fromMap(existing.id, existing.toMap())
        : Project(
            id: newId(),
            start: DateTime.now(),
            currency: prefs.defaultCurrency,
            platform: FeePlatform.values.firstWhere((x) => x.name == prefs.defaultPlatform, orElse: () => FeePlatform.direct),
            category: s.projectCats.first.key,
            status: s.statuses.first.key,
          );
    title.text = p.title;
    desc.text = p.description;
    money = (p.amount ?? 0) > 0;
    if (money) amount.text = p.amount!.toStringAsFixed(p.amount! == p.amount!.roundToDouble() ? 0 : 2);
    customFee.text = p.customFee.toStringAsFixed(0);
  }

  Future<void> _save() async {
    p.title = title.text.trim();
    p.description = desc.text.trim();
    if (p.title.isEmpty) {
      toast(context, 'Give the project a name first.');
      return;
    }
    p.amount = money ? double.tryParse(amount.text.replaceAll(',', '')) : null;
    p.customFee = double.tryParse(customFee.text) ?? 15;
    if (p.done) p.status = 'complete';
    final s = context.read<Store>();
    final m = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await s.saveProject(p);
    for (final t in splits) {
      await s.saveTodo(Todo(id: newId(), title: t, projectId: p.id, deadline: p.deadline, priority: p.priority, category: s.todoCats.first.key, start: p.start));
    }
    if (splits.isNotEmpty) m.showSnackBar(SnackBar(content: Text('Project saved · ${splits.length} to-dos added')));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final c = pastel(p.color);
    final amt = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
    final pct = feePercent(p.platform, double.tryParse(customFee.text) ?? 15);
    final fee = amt * pct / 100;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Header(isNew ? 'New project' : 'Edit project'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              // Preview
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(26)),
                child: Row(children: [
                  GestureDetector(
                    onTap: () async {
                      final k = await pickIcon(context, current: p.icon, color: p.color);
                      if (k != null) setState(() => p.icon = k);
                    },
                    child: Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(19)), child: Icon(iconOf(p.icon), color: c.fg, size: 28)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: title,
                      autofocus: isNew,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.ink),
                      decoration: const InputDecoration(hintText: 'Project name', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              TextField(controller: desc, minLines: 2, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'What is this project about? (optional)')),

              Label('Colour', trailing: Text(c.name, style: TextStyle(color: c.fg, fontWeight: FontWeight.w800, fontSize: 12.5))),
              ColorDots(colors: [for (final x in pastels) x.bg], rings: [for (final x in pastels) x.fg], value: p.color, size: 32, onChanged: (i) => setState(() => p.color = i)),
              const Label('Icon'),
              IconQuickPick(value: p.icon, color: p.color, onChanged: (k) => setState(() => p.icon = k)),

              // Money
              const Label('Money'),
              Box(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.payments_outlined, color: C.green),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Add an amount', style: TextStyle(fontWeight: FontWeight.w700))),
                    Switch(value: money, onChanged: (v) => setState(() => money = v)),
                  ]),
                  if (money) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(
                        width: 104,
                        child: DropdownButtonFormField<String>(
                          value: currencySymbols.containsKey(p.currency) ? p.currency : 'USD',
                          isExpanded: true,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                          items: [for (final k in currencySymbols.keys) DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)))],
                          onChanged: (v) => setState(() => p.currency = v ?? 'USD'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(hintText: '0', prefixText: currencySymbols[p.currency]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Segmented<FeePlatform>(
                      items: const [(FeePlatform.direct, 'Direct'), (FeePlatform.fiverr, 'Fiverr'), (FeePlatform.upwork, 'Upwork'), (FeePlatform.custom, 'Custom')],
                      value: p.platform,
                      onChanged: (v) => setState(() => p.platform = v),
                    ),
                    if (p.platform == FeePlatform.custom) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customFee,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Platform fee', suffixText: '%'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _moneyLine(context, 'Amount', fmtMoney(amt, p.currency)),
                    _moneyLine(context, 'Fee (${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%)', '− ${fmtMoney(fee, p.currency)}', color: C.red),
                    const Divider(height: 18),
                    _moneyLine(context, 'You receive', fmtMoney(amt - fee, p.currency), bold: true, color: C.green),
                  ],
                ]),
              ),

              const Label('Dates & reminder'),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  DateRow(label: 'Start date', icon: Icons.play_circle_outline, value: p.start, onChanged: (d) => setState(() => p.start = d)),
                  const Divider(),
                  DateRow(label: 'Deadline', icon: Icons.flag_outlined, value: p.deadline, onChanged: (d) => setState(() => p.deadline = d)),
                  const Divider(),
                  DateRow(label: 'Reminder', icon: Icons.alarm, value: p.reminder, withTime: true, onChanged: (d) => setState(() => p.reminder = d)),
                  const Divider(),
                  const RowTile(icon: Icons.person_add_alt_1_outlined, color: 6, title: 'Assigned', subtitle: 'Invite teammates', trailing: SoonPill()),
                  const Divider(),
                  RowTile(
                    icon: Icons.task_alt,
                    color: 8,
                    title: 'Mark project as done',
                    trailing: Checkbox(value: p.done, onChanged: (v) => setState(() => p.done = v ?? false)),
                    onTap: () => setState(() => p.done = !p.done),
                  ),
                ]),
              ),

              Label('Status', trailing: _editLink(context, 'statuses')),
              TagPicker(tags: s.statuses, value: p.status, onChanged: (v) => setState(() => p.status = v)),
              const Label('Priority'),
              PriorityPicker(value: p.priority, onChanged: (v) => setState(() => p.priority = v)),
              Label('Category', trailing: _editLink(context, 'projectCats')),
              TagPicker(tags: s.projectCats, value: p.category, onChanged: (v) => setState(() => p.category = v)),

              if (isNew) ...[
                const Label('Split into tasks'),
                Box(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: Column(children: [
                    for (var i = 0; i < splits.length; i++)
                      Row(children: [
                        Icon(Icons.radio_button_unchecked, size: 20, color: c.fg),
                        const SizedBox(width: 10),
                        Expanded(child: Text(splits[i], style: const TextStyle(fontWeight: FontWeight.w600))),
                        IconButton(tooltip: 'Remove', icon: Icon(Icons.close_rounded, size: 18, color: context.mutedText), onPressed: () => setState(() => splits.removeAt(i))),
                      ]),
                    Row(children: [
                      Icon(Icons.add_rounded, color: context.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: task,
                          onSubmitted: (_) => _addSplit(),
                          decoration: const InputDecoration(hintText: 'Add a task (goes to To-do)', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                        ),
                      ),
                      TextButton(onPressed: _addSplit, child: const Text('Add')),
                    ]),
                  ]),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: FilledButton(
              onPressed: _save,
              child: Text(isNew ? (splits.isEmpty ? 'Create project' : 'Create project · ${splits.length} to-dos') : 'Save changes'),
            ),
          ),
        ]),
      ),
    );
  }

  void _addSplit() {
    final v = task.text.trim();
    if (v.isEmpty) return;
    setState(() => splits.add(v));
    task.clear();
  }

  Widget _editLink(BuildContext context, String field) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaxonomyScreen(initial: field))),
        child: Text('Edit', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 13)),
      );

  Widget _moneyLine(BuildContext context, String a, String b, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(color: bold ? null : context.mutedText, fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
          Text(b, style: TextStyle(fontWeight: FontWeight.w800, fontSize: bold ? 18 : 14, color: color)),
        ]),
      );
}
