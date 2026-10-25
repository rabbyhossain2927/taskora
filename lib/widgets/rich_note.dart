import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../models.dart';
import '../services/file_service.dart';

/// Rich note text (headings, small text, bold, bullets with proper indent,
/// checklists and images placed where the cursor is), stored as a Quill
/// document in NoteBlock.body. NoteBlock.text keeps a plain copy with light
/// marks ("# ", "## ", "-# ", "• ", "**bold**") for previews and search.

/// Old plain text with marks -> rich document.
List<Map<String, dynamic>> marksToDelta(String text) {
  final ops = <Map<String, dynamic>>[];
  final lines = text.split('\n');
  for (final raw in lines) {
    var line = raw;
    Map<String, dynamic>? block;
    var small = false;
    if (line.startsWith('## ')) {
      block = {'header': 2};
      line = line.substring(3);
    } else if (line.startsWith('# ')) {
      block = {'header': 1};
      line = line.substring(2);
    } else if (line.startsWith('-# ')) {
      small = true;
      line = line.substring(3);
    }
    if (line.startsWith('• ')) {
      block = {...?block, 'list': 'bullet'};
      line = line.substring(2);
    } else if (line.startsWith('☐ ') || line.startsWith('☑ ')) {
      block = {...?block, 'list': line.startsWith('☑') ? 'checked' : 'unchecked'};
      line = line.substring(2);
    }
    // **bold** pieces
    var i = 0;
    while (i < line.length) {
      final a = line.indexOf('**', i);
      final b = a < 0 ? -1 : line.indexOf('**', a + 2);
      if (a < 0 || b < 0) {
        _push(ops, line.substring(i), small: small);
        break;
      }
      if (a > i) _push(ops, line.substring(i, a), small: small);
      _push(ops, line.substring(a + 2, b), small: small, bold: true);
      i = b + 2;
    }
    ops.add({'insert': '\n', if (block != null) 'attributes': block});
  }
  return ops;
}

void _push(List<Map<String, dynamic>> ops, String s, {bool small = false, bool bold = false}) {
  if (s.isEmpty) return;
  final attrs = <String, dynamic>{if (small) 'small': true, if (bold) 'bold': true};
  ops.add({'insert': s, if (attrs.isNotEmpty) 'attributes': attrs});
}

/// Rich document -> plain text with marks (for cards, previews, search).
String deltaToMarks(List<dynamic> ops) {
  final out = <String>[];
  final cur = StringBuffer();
  var smallLine = false;
  for (final o in ops) {
    if (o is! Map) continue;
    final ins = o['insert'];
    final attrs = (o['attributes'] as Map?) ?? const {};
    if (ins is! String) continue; // images etc.
    final parts = ins.split('\n');
    for (var k = 0; k < parts.length; k++) {
      final piece = parts[k];
      if (piece.isNotEmpty) {
        if (attrs['small'] == true) smallLine = true;
        cur.write(attrs['bold'] == true && piece.trim().isNotEmpty ? '**$piece**' : piece);
      }
      if (k < parts.length - 1) {
        // end of a line: the line's own attributes sit on this "\n"
        final h = attrs['header'];
        final list = attrs['list'];
        final prefix = '${h == 1 ? '# ' : h != null ? '## ' : (smallLine ? '-# ' : '')}'
            '${list == 'bullet' ? '• ' : list == 'checked' ? '☑ ' : list == 'unchecked' ? '☐ ' : list == 'ordered' ? '• ' : ''}';
        out.add('$prefix$cur');
        cur.clear();
        smallLine = false;
      }
    }
  }
  if (cur.isNotEmpty) out.add(cur.toString());
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

/// First image URL inside a rich document (for note cards).
String? firstImageIn(String body) {
  if (!body.contains('"image"')) return null;
  try {
    for (final o in jsonDecode(body) as List) {
      final ins = (o as Map)['insert'];
      if (ins is Map && ins['image'] is String) return ins['image'] as String;
    }
  } catch (_) {}
  return null;
}

Document docOf(NoteBlock b) {
  if (b.body.isNotEmpty) {
    try {
      final ops = jsonDecode(b.body) as List;
      if (ops.isNotEmpty) return Document.fromJson(ops);
    } catch (_) {}
  }
  return Document.fromJson(marksToDelta(b.text));
}

/// Text sizes that match the rest of TaskOra.
DefaultStyles noteStyles(BuildContext context, Color? ink, Color accent, Color muted) {
  final base = DefaultStyles.getInstance(context);
  final color = ink ?? Theme.of(context).colorScheme.onSurface;
  TextStyle t(double size, {FontWeight w = FontWeight.w400, double h = 1.55, double ls = 0}) =>
      TextStyle(fontSize: size, height: h, fontWeight: w, color: color, letterSpacing: ls, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily);
  DefaultTextBlockStyle block(TextStyle s, double top, double bottom) => DefaultTextBlockStyle(s, HorizontalSpacing.zero, VerticalSpacing(top, bottom), VerticalSpacing.zero, null);
  return base.merge(DefaultStyles(
    h1: block(t(22, w: FontWeight.w700, h: 1.35, ls: -0.3), 12, 4),
    h2: block(t(18, w: FontWeight.w700, h: 1.4, ls: -0.2), 10, 2),
    h3: block(t(16, w: FontWeight.w700, h: 1.4), 8, 2),
    paragraph: block(t(15), 0, 0),
    leading: block(t(15), 0, 0),
    placeHolder: block(t(15).copyWith(color: muted), 0, 0),
    small: TextStyle(fontSize: 12.5, color: ink?.withOpacity(0.7) ?? muted),
    bold: const TextStyle(fontWeight: FontWeight.w700),
    link: TextStyle(color: accent, decoration: TextDecoration.underline),
  ));
}

/// Bullets in the same colour, font and weight as the text.
Widget? noteBullet(Node node, LeadingConfigurations config, TextStyle text) {
  if (config.attribute != Attribute.ul) return null;
  return QuillEditorBulletPoint(
    style: text.copyWith(fontSize: config.style?.fontSize ?? text.fontSize, fontWeight: FontWeight.w400),
    width: config.width ?? 28,
    padding: config.padding ?? 0,
  );
}

/// Shows images inside the note text. Tap opens the full image.
class NoteImageEmbed extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;
  @override
  bool get expanded => false;
  @override
  Widget build(BuildContext context, QuillController controller, Embed node, bool readOnly, bool inline, TextStyle textStyle) {
    final url = node.value.data.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => FileService.open(Attachment(id: '', name: 'image', mime: 'image/*', size: 0, url: url)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (c, w, p) => p == null ? w : const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => Container(
                height: 90,
                alignment: Alignment.center,
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
