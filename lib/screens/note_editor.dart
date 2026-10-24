import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../icons.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/file_service.dart';
import '../services/prefs.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rich_note.dart';

/// A note with tabs (like Google Docs). The main text is rich: headings,
/// small text, bold, bullets (with proper indent), checklists and images
/// placed where your cursor is. Extra blocks: dropdown, link preview, file.
/// Saves while you type, when you leave, and when the app is closed.
class NoteEditor extends StatefulWidget {
  final String? id;
  final String? sectionId;
  const NoteEditor({super.key, this.id, this.sectionId});
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> with WidgetsBindingObserver {
  late Note n;
  late bool isNew;
  late final Store store;
  bool deleted = false;
  String? uploading; // "Uploading 2 of 5…"
  int tab = 0;
  NoteBlock? focused; // the rich text block you were last typing in
  final _ctrls = <NoteBlock, QuillController>{};
  final _nodes = <NoteBlock, FocusNode>{};
  final _scrolls = <NoteBlock, ScrollController>{};
  final _subs = <StreamSubscription>[];
  Timer? _debounce;
  String _lastSaved = '';
  bool _savedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = context.read<Store>();
    final ex = widget.id == null ? null : store.notes.where((x) => x.id == widget.id).firstOrNull;
    isNew = ex == null;
    n = ex != null ? Note.fromMap(ex.id, ex.toMap()) : Note(id: newId(), sectionId: widget.sectionId);
    _migrate();
    // Open the tab you were last working in.
    if (!isNew) tab = Prefs.instance.noteTab(n.id).clamp(0, n.tabs.length - 1);
    _lastSaved = isNew ? '' : jsonEncode({...n.toMap(), 'updatedAt': null});
  }

  /// Older notes: plain text blocks and bullet blocks become rich text.
  void _migrate() {
    for (final t in n.tabs) {
      for (var i = 0; i < t.blocks.length; i++) {
        final b = t.blocks[i];
        if (b.type == 'text') {
          final mark = switch (b.size) { 'h' => '# ', 'l' => '## ', 's' => '-# ', _ => '' };
          final text = mark.isEmpty ? b.text : b.text.split('\n').map((l) => l.isEmpty ? l : '$mark$l').join('\n');
          final ops = marksToDelta(b.bold ? text.split('\n').map((l) => l.trim().isEmpty ? l : '**$l**').join('\n') : text);
          t.blocks[i] = NoteBlock(type: 'doc', text: deltaToMarks(ops), body: jsonEncode(ops));
        } else if (b.type == 'bullets') {
          final text = b.items.map((x) => '• ${x.title}').join('\n');
          final ops = marksToDelta(text);
          t.blocks[i] = NoteBlock(type: 'doc', text: text, body: jsonEncode(ops));
        }
      }
      if (!t.blocks.any((b) => b.type == 'doc')) t.blocks.insert(0, NoteBlock(type: 'doc'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _nodes.values) {
      f.dispose();
    }
    for (final s in _scrolls.values) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Closing or leaving the app saves what you typed right away.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _save(final_: false);
      store.flush();
    }
  }

  NoteTab get cur => n.tabs[tab.clamp(0, n.tabs.length - 1)];

  bool get _empty =>
      n.title.trim().isEmpty &&
      n.allBlocks.every((b) => b.text.trim().isEmpty && !b.body.contains('"image"') && (b.type == 'doc' || b.body.trim().isEmpty) && b.items.every((i) => i.title.trim().isEmpty) && b.file == null);

  /// Called on every change: saves a moment after you stop typing.
  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () => _save(final_: false));
  }

  void _save({required bool final_}) {
    _debounce?.cancel();
    if (deleted) return;
    if (isNew && !_savedOnce && _empty) return;
    if (final_) {
      for (final t in n.tabs) {
        for (final b in t.blocks) {
          b.items.removeWhere((i) => i.title.trim().isEmpty && b.items.length > 1);
        }
      }
    }
    final now = jsonEncode({...n.toMap(), 'updatedAt': null});
    if (now == _lastSaved) return;
    _lastSaved = now;
    _savedOnce = true;
    store.saveNote(n);
  }

  void _setTab(int i) {
    setState(() {
      tab = i;
      focused = null;
    });
    if (!isNew || _savedOnce) Prefs.instance.setNoteTab(n.id, i);
  }

  // ---------------- rich text ----------------
  QuillController _ctrlFor(NoteBlock b) => _ctrls.putIfAbsent(b, () {
        final c = QuillController(document: docOf(b), selection: const TextSelection.collapsed(offset: 0));
        _subs.add(c.document.changes.listen((_) {
          final ops = c.document.toDelta().toJson();
          b.body = jsonEncode(ops);
          b.text = deltaToMarks(ops);
          _changed();
        }));
        // Keep the toolbar (undo, styles) up to date.
        c.addListener(() {
          if (mounted && focused == b) setState(() {});
        });
        return c;
      });

  FocusNode _nodeFor(NoteBlock b) => _nodes.putIfAbsent(b, () {
        final f = FocusNode();
        f.addListener(() {
          if (f.hasFocus && focused != b && mounted) setState(() => focused = b);
        });
        return f;
      });

  /// The rich text block the toolbar acts on.
  NoteBlock _targetBlock() {
    final b = focused;
    if (b != null && cur.blocks.contains(b) && b.type == 'doc') return b;
    return cur.blocks.lastWhere((x) => x.type == 'doc');
  }

  QuillController? get _focusedCtrl => focused == null ? null : _ctrls[focused!];

  Map<String, Attribute> get _style => _focusedCtrl?.getSelectionStyle().attributes ?? const {};
  int? get _header => _style[Attribute.header.key]?.value as int?;
  String? get _list => _style[Attribute.list.key]?.value as String?;
  bool get _small => _style.containsKey(Attribute.small.key);
  bool get _bold => _style.containsKey(Attribute.bold.key);

  /// Selected text, or the whole line the cursor is on.
  (int, int) _lineRange(QuillController c) {
    final sel = c.selection;
    if (!sel.isCollapsed) return (sel.start, sel.end - sel.start);
    final res = c.document.queryChild(sel.baseOffset);
    final node = res.node;
    if (node == null) return (sel.baseOffset, 0);
    return (node.documentOffset, (node.length - 1).clamp(0, 1 << 30));
  }

  void _apply(void Function(QuillController c) f) {
    final b = _targetBlock();
    final c = _ctrlFor(b);
    HapticFeedback.selectionClick();
    f(c);
    if (focused != b) setState(() => focused = b);
    _nodes[b]?.requestFocus();
  }

  void _lineStyle(String style) => _apply((c) {
        final (start, len) = _lineRange(c);
        final h = c.getSelectionStyle().attributes[Attribute.header.key]?.value;
        // clear first
        c.formatText(start, len, Attribute.clone(Attribute.small, null));
        if (style == 'h1') {
          c.formatSelection(h == 1 ? Attribute.clone(Attribute.header, null) : Attribute.h1);
        } else if (style == 'h2') {
          c.formatSelection(h == 2 ? Attribute.clone(Attribute.header, null) : Attribute.h2);
        } else {
          c.formatSelection(Attribute.clone(Attribute.header, null));
          if (style == 'small' && len > 0) c.formatText(start, len, Attribute.small);
        }
      });

  void _toggleBold() => _apply((c) {
        final on = c.getSelectionStyle().attributes.containsKey(Attribute.bold.key);
        final (start, len) = _lineRange(c);
        if (len == 0) {
          c.formatSelection(on ? Attribute.clone(Attribute.bold, null) : Attribute.bold);
        } else {
          c.formatText(start, len, on ? Attribute.clone(Attribute.bold, null) : Attribute.bold);
        }
      });

  void _toggleList(Attribute on) => _apply((c) {
        final v = c.getSelectionStyle().attributes[Attribute.list.key]?.value;
        final isOn = on == Attribute.ul ? v == 'bullet' : (v == 'checked' || v == 'unchecked');
        c.formatSelection(isOn ? Attribute.clone(Attribute.list, null) : on);
      });

  /// Tap on empty space: put the cursor at the end of the text.
  void _focusEnd() {
    final b = cur.blocks.lastWhere((x) => x.type == 'doc');
    setState(() => focused = b);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _ctrls[b];
      if (c != null) c.updateSelection(TextSelection.collapsed(offset: c.document.length - 1), ChangeSource.local);
      _nodes[b]?.requestFocus();
    });
  }

  /// Images go right where the cursor is. You can pick several at once.
  Future<void> _addImages() async {
    final b = _targetBlock();
    final c = _ctrlFor(b);
    final at = c.selection.isValid ? c.selection.baseOffset.clamp(0, c.document.length - 1) : c.document.length - 1;
    try {
      final files = await FileService.pickAndUploadMany(
        imagesOnly: true,
        onProgress: (d, t) {
          if (mounted) setState(() => uploading = t <= 1 ? 'Uploading image…' : 'Uploading ${d + 1 > t ? t : d + 1} of $t…');
        },
      );
      if (files.isEmpty || !mounted) return;
      var pos = at;
      for (final f in files) {
        c.replaceText(pos, 0, BlockEmbed.image(f.url), null);
        pos += 1;
      }
      c.updateSelection(TextSelection.collapsed(offset: pos.clamp(0, c.document.length - 1)), ChangeSource.local);
      setState(() => focused = b);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => uploading = null);
    }
  }

  /// Other blocks (file, link, dropdown) go after the text you're in.
  void _add(NoteBlock nb) {
    setState(() {
      final b = _targetBlock();
      final i = cur.blocks.indexOf(b);
      cur.blocks.insert(i + 1, nb);
      // Keep a text block after it so you can keep typing.
      if (i + 2 >= cur.blocks.length || cur.blocks[i + 2].type != 'doc') cur.blocks.insert(i + 2, NoteBlock(type: 'doc'));
    });
    _changed();
  }

  Future<void> _addLink() async {
    final url = await askText(context, title: 'Add a link', hint: 'https://…');
    if (url == null || url.isEmpty) return;
    _add(NoteBlock(type: 'link', text: url.startsWith('http') ? url : 'https://$url'));
  }

  Future<void> _addFiles() async {
    try {
      final files = await FileService.pickAndUploadMany(
        onProgress: (d, t) {
          if (mounted) setState(() => uploading = t <= 1 ? 'Uploading file…' : 'Uploading ${d + 1 > t ? t : d + 1} of $t…');
        },
      );
      for (final f in files.reversed) {
        _add(NoteBlock(type: 'file', file: f));
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => uploading = null);
    }
  }

  Future<void> _tabMenu(int i) async {
    await showActions(context, title: n.tabs[i].title, items: [
      ActionItem(Icons.edit_outlined, 'Rename tab', () async {
        final t = await askText(context, title: 'Rename tab', initial: n.tabs[i].title);
        if (t != null && t.isNotEmpty) setState(() => n.tabs[i].title = t);
        _changed();
      }),
      if (i > 0)
        ActionItem(Icons.arrow_back_rounded, 'Move left', () {
          setState(() {
            n.tabs.insert(i - 1, n.tabs.removeAt(i));
          });
          _setTab(i - 1);
          _changed();
        }),
      if (i < n.tabs.length - 1)
        ActionItem(Icons.arrow_forward_rounded, 'Move right', () {
          setState(() {
            n.tabs.insert(i + 1, n.tabs.removeAt(i));
          });
          _setTab(i + 1);
          _changed();
        }),
      if (n.tabs.length > 1)
        ActionItem(Icons.delete_outline_rounded, 'Delete tab', () {
          final removed = n.tabs[i];
          setState(() => n.tabs.removeAt(i));
          _setTab(tab >= n.tabs.length ? n.tabs.length - 1 : tab);
          _changed();
          showUndo(context, 'Tab “${removed.title}” deleted', () async {
            setState(() => n.tabs.insert(i, removed));
            _changed();
          });
        }, danger: true),
    ]);
  }

  Future<void> _styleSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (context, set) {
        void upd(VoidCallback f) {
          setState(f);
          set(() {});
          _changed();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Style', style: TextStyle(fontSize: T.heading, fontWeight: FontWeight.w700)),
              Label('Colour · ${noteColors.length}'),
              ColorDots(colors: noteColors, value: n.color, size: 30, onChanged: (i) => upd(() => n.color = i)),
              const Label('Icon'),
              IconQuickPick(value: n.icon, color: 0, quick: const ['note', 'lightbulb', 'checklist', 'book', 'star', 'heart', 'cart', 'flag'], onChanged: (k) => upd(() => n.icon = k)),
              const Label('Folder'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('No folder'), selected: n.sectionId == null, onSelected: (_) => upd(() => n.sectionId = null)),
                for (final sec in store.sections) ChoiceChip(label: Text(sec.title), selected: n.sectionId == sec.id, onSelected: (_) => upd(() => n.sectionId = sec.id)),
              ]),
              const Label('Tags'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in store.tags)
                  FilterChip(
                    label: Text('#$t'),
                    selected: n.tags.contains(t),
                    onSelected: (v) => upd(() {
                      if (v) {
                        n.tags.add(t);
                      } else {
                        n.tags.remove(t);
                      }
                    }),
                  ),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  void _unfocus(PointerDownEvent _) => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    final plain = n.color == 0;
    final bg = context.isDark && plain ? null : noteColor(n.color);
    final ink = context.isDark && plain ? null : C.ink;
    final muted = (ink ?? context.mutedText).withOpacity(0.6);
    final fc = _focusedCtrl;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save(final_: true);
      },
      child: Scaffold(
        backgroundColor: bg,
        body: CallbackShortcuts(
          // Keyboard shortcuts on computers (Ctrl+B, Ctrl+Z and Ctrl+Y work too)
          bindings: {
            const SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true): () => _lineStyle('h1'),
            const SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true): () => _lineStyle('h2'),
            const SingleActivator(LogicalKeyboardKey.digit0, control: true, alt: true): () => _lineStyle('normal'),
            const SingleActivator(LogicalKeyboardKey.digit9, control: true, alt: true): () => _lineStyle('small'),
            const SingleActivator(LogicalKeyboardKey.digit8, control: true, shift: true): () => _toggleList(Attribute.ul),
          },
          child: SafeArea(
            child: Column(children: [
              Header('', actions: [
                RoundButton(
                    icon: n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    tooltip: n.pinned ? 'Unpin' : 'Pin',
                    onTap: () {
                      setState(() => n.pinned = !n.pinned);
                      _changed();
                    }),
                RoundButton(icon: Icons.palette_outlined, tooltip: 'Colour, icon, folder, tags', onTap: _styleSheet),
                if (!isNew || _savedOnce)
                  RoundButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Move to Trash',
                    onTap: () async {
                      deleted = true;
                      final m = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      final undo = await store.deleteDocs('notes', [n.id]);
                      m.showSnackBar(SnackBar(content: const Text('Note moved to Trash'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
                    },
                  ),
              ]),
              // ---------- title ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
                child: Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final k = await pickIcon(context, current: n.icon);
                      if (k != null) setState(() => n.icon = k);
                      _changed();
                    },
                    child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(context.isDark && plain ? 0.08 : 0.75), borderRadius: BorderRadius.circular(13)), child: Icon(iconOf(n.icon), color: context.accent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: n.title,
                      autofocus: isNew,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) {
                        n.title = v;
                        _changed();
                      },
                      onTapOutside: _unfocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _focusEnd(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: ink),
                      decoration: _bare.copyWith(hintText: 'Title'),
                    ),
                  ),
                ]),
              ),
              // ---------- tabs ----------
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
                  for (var i = 0; i < n.tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onLongPress: () => _tabMenu(i),
                        onSecondaryTap: () => _tabMenu(i),
                        child: ChoiceChip(
                          avatar: Icon(Icons.description_outlined, size: 15, color: i == tab ? context.onTint : context.mutedText),
                          label: Text(n.tabs[i].title),
                          selected: i == tab,
                          onSelected: (_) => _setTab(i),
                        ),
                      ),
                    ),
                  ActionChip(
                    avatar: Icon(Icons.add_rounded, size: 16, color: context.accent),
                    label: const Text('Tab'),
                    onPressed: () {
                      setState(() => n.tabs.add(NoteTab(id: newId(), title: 'Tab ${n.tabs.length + 1}', blocks: [NoteBlock(type: 'doc')])));
                      _setTab(n.tabs.length - 1);
                      _changed();
                    },
                  ),
                ]),
              ),
              // ---------- blocks ----------
              Expanded(
                child: ListView(
                  key: ValueKey('tab-${cur.id}'),
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                  children: [
                    for (var i = 0; i < cur.blocks.length; i++) _block(cur.blocks[i], i, ink, muted),
                    if (uploading != null)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text(uploading!, style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    // Empty space below the text: tap to keep writing.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focusEnd,
                      child: SizedBox(
                        height: 260,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text('Created ${fmtStamp(n.createdAt)}  ·  Edited ${fmtStamp(n.updatedAt)}', style: TextStyle(fontSize: 11.5, color: muted)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ---------- toolbar ----------
              TextFieldTapRegion(
                child: Container(
                  decoration: BoxDecoration(color: context.surface, border: Border(top: BorderSide(color: context.isDark ? Colors.white10 : C.line))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(children: [
                      IconButton(tooltip: 'Undo', icon: const Icon(Icons.undo_rounded), onPressed: fc != null && fc.hasUndo ? () => _apply((c) => c.undo()) : null),
                      IconButton(tooltip: 'Redo', icon: const Icon(Icons.redo_rounded), onPressed: fc != null && fc.hasRedo ? () => _apply((c) => c.redo()) : null),
                      const SizedBox(height: 24, child: VerticalDivider()),
                      _styleBtn('h1', 'H1', 'Heading', _header == 1),
                      _styleBtn('h2', 'H2', 'Subheading', _header == 2),
                      _styleBtn('normal', 'Aa', 'Normal text', fc != null && _header == null && !_small),
                      _styleBtn('small', 'aa', 'Small text', _small, small: true),
                      _toggle(Icons.format_bold_rounded, 'Bold', _bold, _toggleBold),
                      _toggle(Icons.format_list_bulleted_rounded, 'Bullet points', _list == 'bullet', () => _toggleList(Attribute.ul)),
                      _toggle(Icons.checklist_rounded, 'Checklist', _list == 'checked' || _list == 'unchecked', () => _toggleList(Attribute.unchecked)),
                      const SizedBox(height: 24, child: VerticalDivider()),
                      IconButton(tooltip: 'Images (at the cursor)', icon: const Icon(Icons.image_outlined), onPressed: uploading != null ? null : _addImages),
                      IconButton(tooltip: 'Files or PDFs', icon: const Icon(Icons.attach_file_rounded), onPressed: uploading != null ? null : _addFiles),
                      IconButton(tooltip: 'Link', icon: const Icon(Icons.link_rounded), onPressed: _addLink),
                      IconButton(tooltip: 'Dropdown', icon: const Icon(Icons.arrow_drop_down_circle_outlined), onPressed: () => _add(NoteBlock(type: 'dropdown'))),
                      if (!kIsWeb) IconButton(tooltip: 'Hide keyboard', icon: const Icon(Icons.keyboard_hide_outlined), onPressed: () => FocusManager.instance.primaryFocus?.unfocus()),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _toggle(IconData icon, String tip, bool on, VoidCallback onTap) => IconButton(
        tooltip: tip,
        isSelected: on,
        style: IconButton.styleFrom(backgroundColor: on ? context.tint : null),
        selectedIcon: Icon(icon, color: context.onTint),
        icon: Icon(icon),
        onPressed: onTap,
      );

  Widget _styleBtn(String style, String text, String tip, bool on, {bool small = false}) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _lineStyle(style),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: on ? context.tint : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Text(text, style: TextStyle(fontWeight: style.startsWith('h') ? FontWeight.w800 : FontWeight.w600, fontSize: small ? 12 : 15, color: on ? context.onTint : null)),
        ),
      ),
    );
  }

  static const _bare = InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6));

  Widget _blockMenu(int i) => PopupMenuButton<String>(
        tooltip: 'Block options',
        icon: Icon(Icons.more_horiz, size: 20, color: context.mutedText),
        onSelected: (v) {
          setState(() {
            final bl = cur.blocks;
            if (v == 'up' && i > 0) bl.insert(i - 1, bl.removeAt(i));
            if (v == 'down' && i < bl.length - 1) bl.insert(i + 1, bl.removeAt(i));
            if (v == 'delete') {
              final removed = bl.removeAt(i);
              if (!bl.any((b) => b.type == 'doc')) bl.add(NoteBlock(type: 'doc'));
              showUndo(context, 'Block deleted', () async {
                setState(() => bl.insert(i.clamp(0, bl.length), removed));
                _changed();
              });
            }
          });
          _changed();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'up', child: Text('Move up')),
          PopupMenuItem(value: 'down', child: Text('Move down')),
          PopupMenuItem(value: 'delete', child: Text('Delete block')),
        ],
      );

  Widget _card({required Widget child, required NoteBlock b}) => Container(
        key: ObjectKey(b),
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(context.isDark && n.color == 0 ? 0.05 : 0.55), borderRadius: BorderRadius.circular(18)),
        child: child,
      );

  /// Older checklist blocks (new checklists live inside the text).
  Widget _checkBlock(NoteBlock b, int i, Color? ink) => _card(
        b: b,
        child: Column(children: [
          for (var j = 0; j < b.items.length; j++)
            Row(key: ObjectKey(b.items[j]), children: [
              Checkbox(
                  value: b.items[j].done,
                  onChanged: (v) {
                    setState(() => b.items[j].done = v ?? false);
                    _changed();
                  }),
              Expanded(
                child: TextFormField(
                  initialValue: b.items[j].title,
                  autofocus: b.items[j].title.isEmpty && j > 0,
                  onChanged: (v) {
                    b.items[j].title = v;
                    _changed();
                  },
                  onTapOutside: _unfocus,
                  onFieldSubmitted: (_) => setState(() => b.items.insert(j + 1, SubTask(''))),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: ink, fontSize: 15, decoration: b.items[j].done ? TextDecoration.lineThrough : null),
                  decoration: _bare.copyWith(hintText: 'List item'),
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.close_rounded, size: 17),
                onPressed: () {
                  setState(() {
                    b.items.removeAt(j);
                    if (b.items.isEmpty) cur.blocks.remove(b);
                  });
                  _changed();
                },
              ),
            ]),
          Row(children: [
            TextButton.icon(onPressed: () => setState(() => b.items.add(SubTask(''))), icon: const Icon(Icons.add, size: 18), label: const Text('Add item')),
            const Spacer(),
            _blockMenu(i),
          ]),
        ]),
      );

  Widget _block(NoteBlock b, int i, Color? ink, Color muted) {
    switch (b.type) {
      case 'doc':
        final c = _ctrlFor(b);
        final firstDoc = cur.blocks.indexWhere((x) => x.type == 'doc') == i;
        return TapRegion(
          key: ObjectKey(b),
          groupId: EditableText,
          onTapOutside: (_) => _nodes[b]?.unfocus(),
          child: QuillEditor(
            controller: c,
            focusNode: _nodeFor(b),
            scrollController: _scrolls.putIfAbsent(b, ScrollController.new),
            configurations: QuillEditorConfigurations(
              scrollable: false,
              expands: false,
              autoFocus: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              placeholder: firstDoc ? 'Start writing…' : 'Text',
              customStyles: noteStyles(context, ink, context.accent, muted),
              embedBuilders: [NoteImageEmbed()],
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        );
      case 'check':
        return _checkBlock(b, i, ink);
      case 'dropdown':
        return _card(
          b: b,
          child: Column(children: [
            Row(children: [
              IconButton(
                tooltip: b.open ? 'Collapse' : 'Expand',
                onPressed: () {
                  setState(() => b.open = !b.open);
                  _changed();
                },
                icon: AnimatedRotation(turns: b.open ? 0.25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.arrow_right_rounded, size: 28)),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: b.text,
                  onChanged: (v) {
                    b.text = v;
                    _changed();
                  },
                  onTapOutside: _unfocus,
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  decoration: _bare.copyWith(hintText: 'Dropdown title'),
                ),
              ),
              _blockMenu(i),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: b.open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(48, 0, 12, 6),
                      child: TextFormField(
                        initialValue: b.body,
                        onChanged: (v) {
                          b.body = v;
                          _changed();
                        },
                        onTapOutside: _unfocus,
                        maxLines: null,
                        style: TextStyle(color: ink, height: 1.5),
                        decoration: _bare.copyWith(hintText: 'Hidden content…'),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        );
      case 'link':
        return Container(
          key: ObjectKey(b),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: LinkPreview(url: b.text)),
            _blockMenu(i),
          ]),
        );
      case 'file':
        final f = b.file;
        if (f == null) return SizedBox(key: ObjectKey(b));
        return Container(
          key: ObjectKey(b),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: f.isImage
                  ? GestureDetector(
                      onTap: () => FileService.open(f),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          f.url,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, w, p) => p == null ? w : const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                          errorBuilder: (_, __, ___) => _fileTile(f),
                        ),
                      ),
                    )
                  : _fileTile(f),
            ),
            _blockMenu(i),
          ]),
        );
      default:
        return SizedBox(key: ObjectKey(b));
    }
  }

  Widget _fileTile(Attachment f) => Material(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => FileService.open(f),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(12)), child: Icon(f.isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, color: context.onTint)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${f.sizeLabel} · tap to open', style: TextStyle(fontSize: 12, color: context.mutedText)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// A link shown as a card with the page's title, description and image.
class LinkPreview extends StatelessWidget {
  final String url;
  const LinkPreview({super.key, required this.url});

  static final _cache = <String, Future<(String, String, String)>>{};

  static Future<(String, String, String)> _fetch(String url) async {
    if (kIsWeb) {
      // Browsers can't read other websites, so your server fetches the preview.
      try {
        final j = await Api.post('preview.php', {'url': url});
        return ((j['title'] ?? '').toString(), (j['description'] ?? '').toString(), (j['image'] ?? '').toString());
      } catch (_) {
        return ('', '', '');
      }
    }
    try {
      final r = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0 TaskOra'}).timeout(const Duration(seconds: 8));
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);
      String meta(String prop) {
        final m = RegExp('<meta[^>]+(?:property|name)=["\']$prop["\'][^>]*content=["\']([^"\']*)["\']', caseSensitive: false).firstMatch(html) ??
            RegExp('<meta[^>]+content=["\']([^"\']*)["\'][^>]*(?:property|name)=["\']$prop["\']', caseSensitive: false).firstMatch(html);
        return m?.group(1)?.trim() ?? '';
      }

      var title = meta('og:title');
      if (title.isEmpty) title = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false).firstMatch(html)?.group(1)?.trim() ?? '';
      var desc = meta('og:description');
      if (desc.isEmpty) desc = meta('description');
      var img = meta('og:image');
      if (img.isNotEmpty && img.startsWith('/')) img = Uri.parse(url).resolve(img).toString();
      String unescape(String s) => s.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');
      return (unescape(title), unescape(desc), img);
    } catch (_) {
      return ('', '', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
    return FutureBuilder<(String, String, String)>(
      future: _cache.putIfAbsent(url, () => _fetch(url)),
      builder: (context, snap) {
        final d = snap.data;
        return Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (d != null && d.$3.isNotEmpty)
                SizedBox(height: 130, child: Image.network(d.$3, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.public_rounded, size: 18, color: context.onTint)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d == null ? 'Loading preview…' : (d.$1.isEmpty ? host : d.$1), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (d != null && d.$2.isNotEmpty) Text(d.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.mutedText)),
                      Text(host, style: TextStyle(fontSize: 11.5, color: context.accent, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
