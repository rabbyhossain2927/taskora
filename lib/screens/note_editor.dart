import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../icons.dart';
import '../models.dart';
import '../services/file_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A note with tabs (like Google Docs). Each tab holds blocks:
/// text (size + bold), bullets, checklist, dropdown, link preview, image / file.
/// Saves automatically when you go back.
class NoteEditor extends StatefulWidget {
  final String? id;
  final String? sectionId;
  const NoteEditor({super.key, this.id, this.sectionId});
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late Note n;
  late bool isNew;
  bool deleted = false;
  bool uploading = false;
  int tab = 0;
  NoteBlock? focused;

  @override
  void initState() {
    super.initState();
    final s = context.read<Store>();
    final ex = widget.id == null ? null : s.notes.where((x) => x.id == widget.id).firstOrNull;
    isNew = ex == null;
    n = ex != null ? Note.fromMap(ex.id, ex.toMap()) : Note(id: newId(), sectionId: widget.sectionId);
  }

  NoteTab get cur => n.tabs[tab.clamp(0, n.tabs.length - 1)];

  bool get _empty => n.title.trim().isEmpty && n.allBlocks.every((b) => b.text.trim().isEmpty && b.body.trim().isEmpty && b.items.every((i) => i.title.trim().isEmpty) && b.file == null);

  void _saveOnExit() {
    if (deleted) return;
    if (isNew && _empty) return;
    for (final t in n.tabs) {
      for (final b in t.blocks) {
        b.items.removeWhere((i) => i.title.trim().isEmpty && b.items.length > 1);
      }
    }
    context.read<Store>().saveNote(n);
  }

  void _add(NoteBlock b) => setState(() {
        // Replace an empty first text block instead of stacking under it
        if (cur.blocks.length == 1 && cur.blocks.first.type == 'text' && cur.blocks.first.text.isEmpty && b.type != 'text') {
          cur.blocks
            ..clear()
            ..add(b);
        } else {
          cur.blocks.add(b);
        }
        focused = b;
      });

  Future<void> _addLink() async {
    final url = await askText(context, title: 'Add a link', hint: 'https://…');
    if (url == null || url.isEmpty) return;
    _add(NoteBlock(type: 'link', text: url.startsWith('http') ? url : 'https://$url'));
  }

  Future<void> _addFile({bool image = false}) async {
    setState(() => uploading = true);
    try {
      final a = await FileService.pickAndUpload(imagesOnly: image);
      if (a != null) _add(NoteBlock(type: 'file', file: a));
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _styleFocused({String? size, bool toggleBold = false}) {
    final b = focused;
    if (b == null || b.type != 'text') {
      toast(context, 'Tap into a text block first');
      return;
    }
    setState(() {
      if (size != null) b.size = size;
      if (toggleBold) b.bold = !b.bold;
    });
  }

  Future<void> _tabMenu(int i) async {
    await showActions(context, title: n.tabs[i].title, items: [
      ActionItem(Icons.edit_outlined, 'Rename tab', () async {
        final t = await askText(context, title: 'Rename tab', initial: n.tabs[i].title);
        if (t != null && t.isNotEmpty) setState(() => n.tabs[i].title = t);
      }),
      if (i > 0) ActionItem(Icons.arrow_back_rounded, 'Move left', () => setState(() {
            n.tabs.insert(i - 1, n.tabs.removeAt(i));
            tab = i - 1;
          })),
      if (i < n.tabs.length - 1) ActionItem(Icons.arrow_forward_rounded, 'Move right', () => setState(() {
            n.tabs.insert(i + 1, n.tabs.removeAt(i));
            tab = i + 1;
          })),
      if (n.tabs.length > 1)
        ActionItem(Icons.delete_outline_rounded, 'Delete tab', () {
          final removed = n.tabs[i];
          setState(() {
            n.tabs.removeAt(i);
            tab = (tab >= n.tabs.length) ? n.tabs.length - 1 : tab;
          });
          showUndo(context, 'Tab “${removed.title}” deleted', () async => setState(() => n.tabs.insert(i, removed)));
        }, danger: true),
    ]);
  }

  Future<void> _style() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (context, set) {
        void upd(VoidCallback f) {
          setState(f);
          set(() {});
        }

        final store = context.read<Store>();
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

  @override
  Widget build(BuildContext context) {
    final plain = n.color == 0;
    final bg = context.isDark && plain ? null : noteColor(n.color);
    final ink = context.isDark && plain ? null : C.ink;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveOnExit();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [
            Header('', actions: [
              RoundButton(icon: n.pinned ? Icons.push_pin : Icons.push_pin_outlined, tooltip: n.pinned ? 'Unpin' : 'Pin', onTap: () => setState(() => n.pinned = !n.pinned)),
              RoundButton(icon: Icons.palette_outlined, tooltip: 'Colour, icon, folder, tags', onTap: _style),
              if (!isNew)
                RoundButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onTap: () async {
                    deleted = true;
                    final s = context.read<Store>();
                    final m = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final undo = await s.deleteDocs('notes', [n.id]);
                    m.showSnackBar(SnackBar(content: const Text('Note deleted'), duration: const Duration(seconds: 5), action: SnackBarAction(label: 'Undo', onPressed: () => undo())));
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
                  },
                  child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(context.isDark && plain ? 0.08 : 0.75), borderRadius: BorderRadius.circular(13)), child: Icon(iconOf(n.icon), color: context.accent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: n.title,
                    autofocus: isNew,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => n.title = v,
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
                      child: ChoiceChip(
                        avatar: Icon(Icons.description_outlined, size: 15, color: i == tab ? context.onTint : context.mutedText),
                        label: Text(n.tabs[i].title),
                        selected: i == tab,
                        onSelected: (_) => setState(() {
                          tab = i;
                          focused = null;
                        }),
                      ),
                    ),
                  ),
                ActionChip(
                  avatar: Icon(Icons.add_rounded, size: 16, color: context.accent),
                  label: const Text('Tab'),
                  onPressed: () => setState(() {
                    n.tabs.add(NoteTab(id: newId(), title: 'Tab ${n.tabs.length + 1}'));
                    tab = n.tabs.length - 1;
                  }),
                ),
              ]),
            ),
            // ---------- blocks ----------
            Expanded(
              child: ListView(
                key: ValueKey('tab-${cur.id}'),
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
                children: [
                  for (var i = 0; i < cur.blocks.length; i++) _block(cur.blocks[i], i, ink),
                  if (uploading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                  const SizedBox(height: 12),
                  Text('Edited ${dTime.format(n.updatedAt)} · hold a tab to rename it', style: TextStyle(fontSize: 11.5, color: (ink ?? context.mutedText).withOpacity(0.55))),
                ],
              ),
            ),
            // ---------- toolbar ----------
            Container(
              decoration: BoxDecoration(color: context.surface, border: Border(top: BorderSide(color: context.isDark ? Colors.white10 : C.line))),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  PopupMenuButton<String>(
                    tooltip: 'Text size',
                    icon: const Icon(Icons.format_size_rounded),
                    onSelected: (v) => _styleFocused(size: v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'h', child: Text('Heading', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                      PopupMenuItem(value: 'l', child: Text('Large', style: TextStyle(fontSize: 17))),
                      PopupMenuItem(value: 'm', child: Text('Normal', style: TextStyle(fontSize: 14.5))),
                      PopupMenuItem(value: 's', child: Text('Small', style: TextStyle(fontSize: 12.5))),
                    ],
                  ),
                  IconButton(tooltip: 'Bold', icon: Icon(Icons.format_bold_rounded, color: focused?.bold == true ? context.accent : null), onPressed: () => _styleFocused(toggleBold: true)),
                  const SizedBox(height: 24, child: VerticalDivider()),
                  IconButton(tooltip: 'Text', icon: const Icon(Icons.notes_rounded), onPressed: () => _add(NoteBlock())),
                  IconButton(tooltip: 'Bullet list', icon: const Icon(Icons.format_list_bulleted_rounded), onPressed: () => _add(NoteBlock(type: 'bullets', items: [SubTask('')]))),
                  IconButton(tooltip: 'Checklist', icon: const Icon(Icons.checklist_rounded), onPressed: () => _add(NoteBlock(type: 'check', items: [SubTask('')]))),
                  IconButton(tooltip: 'Dropdown', icon: const Icon(Icons.arrow_drop_down_circle_outlined), onPressed: () => _add(NoteBlock(type: 'dropdown'))),
                  IconButton(tooltip: 'Link', icon: const Icon(Icons.link_rounded), onPressed: _addLink),
                  IconButton(tooltip: 'Image', icon: const Icon(Icons.image_outlined), onPressed: uploading ? null : () => _addFile(image: true)),
                  IconButton(tooltip: 'File or PDF', icon: const Icon(Icons.attach_file_rounded), onPressed: uploading ? null : () => _addFile()),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static const _bare = InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6));

  TextStyle _textStyle(NoteBlock b, Color? ink) {
    final size = switch (b.size) { 'h' => 21.0, 'l' => 17.5, 's' => 12.5, _ => 15.0 };
    return TextStyle(fontSize: size, height: 1.5, color: ink, fontWeight: b.bold || b.size == 'h' ? FontWeight.w700 : FontWeight.w400);
  }

  Widget _blockMenu(int i) => PopupMenuButton<String>(
        tooltip: 'Block options',
        icon: Icon(Icons.more_horiz, size: 20, color: context.mutedText),
        onSelected: (v) => setState(() {
          final bl = cur.blocks;
          if (v == 'up' && i > 0) bl.insert(i - 1, bl.removeAt(i));
          if (v == 'down' && i < bl.length - 1) bl.insert(i + 1, bl.removeAt(i));
          if (v == 'delete') {
            final removed = bl.removeAt(i);
            if (bl.isEmpty) bl.add(NoteBlock());
            showUndo(context, 'Block deleted', () async => setState(() => bl.insert(i.clamp(0, bl.length), removed)));
          }
        }),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'up', child: Text('Move up')),
          PopupMenuItem(value: 'down', child: Text('Move down')),
          PopupMenuItem(value: 'delete', child: Text('Delete block')),
        ],
      );

  Widget _card({required Widget child, required NoteBlock b}) => Container(
        key: ObjectKey(b),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
        decoration: BoxDecoration(color: (context.isDark && n.color == 0 ? Colors.white : Colors.white).withOpacity(context.isDark && n.color == 0 ? 0.05 : 0.55), borderRadius: BorderRadius.circular(18)),
        child: child,
      );

  Widget _listBlock(NoteBlock b, int i, Color? ink, {required bool checks}) => _card(
        b: b,
        child: Column(children: [
          for (var j = 0; j < b.items.length; j++)
            Row(key: ObjectKey(b.items[j]), children: [
              if (checks)
                Checkbox(value: b.items[j].done, onChanged: (v) => setState(() => b.items[j].done = v ?? false))
              else
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 12, 0), child: Icon(Icons.circle, size: 7, color: ink ?? Theme.of(context).colorScheme.onSurface)),
              Expanded(
                child: TextFormField(
                  initialValue: b.items[j].title,
                  autofocus: b.items[j].title.isEmpty && focused == b,
                  onChanged: (v) => b.items[j].title = v,
                  onFieldSubmitted: (_) => setState(() => b.items.insert(j + 1, SubTask(''))),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: ink, fontSize: 15, decoration: checks && b.items[j].done ? TextDecoration.lineThrough : null),
                  decoration: _bare.copyWith(hintText: checks ? 'List item' : 'Bullet point'),
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.close_rounded, size: 17),
                onPressed: () => setState(() {
                  b.items.removeAt(j);
                  if (b.items.isEmpty) cur.blocks.remove(b);
                }),
              ),
            ]),
          Row(children: [
            TextButton.icon(onPressed: () => setState(() => b.items.add(SubTask(''))), icon: const Icon(Icons.add, size: 18), label: Text(checks ? 'Add item' : 'Add point')),
            const Spacer(),
            _blockMenu(i),
          ]),
        ]),
      );

  Widget _block(NoteBlock b, int i, Color? ink) {
    switch (b.type) {
      case 'check':
        return _listBlock(b, i, ink, checks: true);
      case 'bullets':
        return _listBlock(b, i, ink, checks: false);
      case 'dropdown':
        return _card(
          b: b,
          child: Column(children: [
            Row(children: [
              IconButton(
                tooltip: b.open ? 'Collapse' : 'Expand',
                onPressed: () => setState(() => b.open = !b.open),
                icon: AnimatedRotation(turns: b.open ? 0.25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.arrow_right_rounded, size: 28)),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: b.text,
                  onChanged: (v) => b.text = v,
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
                        onChanged: (v) => b.body = v,
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
          margin: const EdgeInsets.only(top: 10),
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
          margin: const EdgeInsets.only(top: 10),
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
        return Focus(
          key: ObjectKey(b),
          onFocusChange: (has) {
            if (has) setState(() => focused = b);
          },
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                initialValue: b.text,
                onChanged: (v) => b.text = v,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: _textStyle(b, ink),
                decoration: _bare.copyWith(hintText: i == 0 ? 'Start writing…' : (b.size == 'h' ? 'Heading' : 'Text')),
              ),
            ),
            if (cur.blocks.length > 1) _blockMenu(i),
          ]),
        );
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
