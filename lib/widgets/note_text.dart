import 'package:flutter/material.dart';

/// Line styles in a note. They are stored as small marks at the start of a
/// line (so copying the text keeps them readable):
///   "# "  heading      "## " subheading      "-# " small text
///   "• "  bullet point (flat, so you can select and copy all of them)
///   **bold** inside a line
const lineMarks = {'h1': '# ', 'h2': '## ', 'small': '-# ', 'normal': ''};
const bulletMark = '• ';

/// Splits a line into (style mark, bullet?, rest).
(String, bool, String) parseLine(String line) {
  var style = 'normal';
  var rest = line;
  if (rest.startsWith('## ')) {
    style = 'h2';
    rest = rest.substring(3);
  } else if (rest.startsWith('# ')) {
    style = 'h1';
    rest = rest.substring(2);
  } else if (rest.startsWith('-# ')) {
    style = 'small';
    rest = rest.substring(3);
  }
  final bullet = rest.startsWith(bulletMark);
  if (bullet) rest = rest.substring(bulletMark.length);
  return (style, bullet, rest);
}

/// A text controller that shows headings, small text, bullets and bold,
/// and keeps bullet lists going when you press Enter.
class NoteTextController extends TextEditingController {
  Color? ink;
  Color accent;
  Color muted;
  double baseSize;
  bool baseBold;
  String _last;
  bool _busy = false;

  NoteTextController({required String text, this.ink, required this.accent, required this.muted, this.baseSize = 15, this.baseBold = false})
      : _last = text,
        super(text: text) {
    addListener(_onEdit);
  }

  static const _hidden = TextStyle(fontSize: 0.1, color: Colors.transparent, letterSpacing: 0, height: 1);

  TextStyle styleFor(String style) => switch (style) {
        'h1' => TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: ink),
        'h2' => TextStyle(fontSize: 18, height: 1.4, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: ink),
        'small' => TextStyle(fontSize: 12.5, height: 1.5, color: ink?.withOpacity(0.7) ?? muted),
        _ => TextStyle(fontSize: baseSize, height: 1.55, color: ink, fontWeight: baseBold ? FontWeight.w700 : FontWeight.w400),
      };

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final (st, bullet, rest) = parseLine(line);
      final ls = styleFor(st);
      final markLen = lineMarks[st]!.length;
      if (markLen > 0) spans.add(TextSpan(text: line.substring(0, markLen), style: _hidden));
      if (bullet) spans.add(TextSpan(text: bulletMark, style: ls.copyWith(color: accent, fontWeight: FontWeight.w900)));
      _inline(rest, ls, spans);
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: ls));
    }
    return TextSpan(style: style, children: spans);
  }

  /// **bold** inside a line (the stars are hidden).
  void _inline(String s, TextStyle ls, List<InlineSpan> out) {
    var i = 0;
    while (i < s.length) {
      final a = s.indexOf('**', i);
      final b = a < 0 ? -1 : s.indexOf('**', a + 2);
      if (a < 0 || b < 0) {
        out.add(TextSpan(text: s.substring(i), style: ls));
        return;
      }
      if (a > i) out.add(TextSpan(text: s.substring(i, a), style: ls));
      out.add(const TextSpan(text: '**', style: _hidden));
      out.add(TextSpan(text: s.substring(a + 2, b), style: ls.copyWith(fontWeight: FontWeight.w700)));
      out.add(const TextSpan(text: '**', style: _hidden));
      i = b + 2;
    }
  }

  /// Enter on a bullet line starts a new bullet; Enter on an empty bullet ends the list.
  void _onEdit() {
    if (_busy) return;
    final now = text;
    final before = _last;
    _last = now;
    final sel = selection;
    if (now.length != before.length + 1 || !sel.isCollapsed || sel.baseOffset < 1) return;
    final at = sel.baseOffset;
    if (now[at - 1] != '\n') return;
    if (now.substring(0, at - 1) + now.substring(at) != before) return;
    final lineStart = at < 2 ? 0 : now.lastIndexOf('\n', at - 2) + 1;
    final prev = now.substring(lineStart, at - 1);
    final (st, bullet, rest) = parseLine(prev);
    if (!bullet) return;
    _busy = true;
    if (rest.trim().isEmpty) {
      // Empty bullet + Enter: remove the bullet and stay on that line.
      final cleaned = now.substring(0, lineStart) + now.substring(at);
      value = TextEditingValue(text: cleaned, selection: TextSelection.collapsed(offset: lineStart));
    } else {
      final mark = st == 'small' ? '-# ' : '';
      final ins = '$mark$bulletMark';
      value = TextEditingValue(text: now.substring(0, at) + ins + now.substring(at), selection: TextSelection.collapsed(offset: at + ins.length));
    }
    _last = text;
    _busy = false;
  }

  (int, int) _lineRange() {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final s0 = sel.start.clamp(0, text.length);
    final start = s0 == 0 ? 0 : text.lastIndexOf('\n', s0 - 1) + 1;
    var end = text.indexOf('\n', sel.end.clamp(0, text.length));
    if (end < 0) end = text.length;
    return (start, end);
  }

  void _replaceLines(String Function(String line) f) {
    final (start, end) = _lineRange();
    final lines = text.substring(start, end).split('\n');
    final newPart = lines.map(f).join('\n');
    final cursorFromEnd = text.length - (selection.isValid ? selection.end : text.length);
    final next = text.substring(0, start) + newPart + text.substring(end);
    _busy = true;
    value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: (next.length - cursorFromEnd).clamp(0, next.length)));
    _last = text;
    _busy = false;
  }

  /// Style of the line the cursor is on.
  String get currentStyle {
    final (start, end) = _lineRange();
    return parseLine(text.substring(start, end).split('\n').first).$1;
  }

  bool get currentBullet {
    final (start, end) = _lineRange();
    return parseLine(text.substring(start, end).split('\n').first).$2;
  }

  /// Heading / subheading / normal / small for the selected line(s) only.
  void setLineStyle(String style) => _replaceLines((l) {
        final (_, bullet, rest) = parseLine(l);
        return '${lineMarks[style]}${bullet ? bulletMark : ''}$rest';
      });

  /// Turns bullets on or off for the selected line(s).
  void toggleBullets() {
    final on = !currentBullet;
    _replaceLines((l) {
      final (st, _, rest) = parseLine(l);
      return '${lineMarks[st]}${on ? bulletMark : ''}$rest';
    });
  }

  /// Bold the selected words (or the whole line if nothing is selected).
  void toggleBold() {
    var sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    if (sel.isCollapsed) {
      final (start, end) = _lineRange();
      final line = text.substring(start, end);
      final (st, bullet, rest) = parseLine(line);
      final prefix = '${lineMarks[st]}${bullet ? bulletMark : ''}';
      final isBold = rest.startsWith('**') && rest.endsWith('**') && rest.length >= 4;
      final inner = isBold ? rest.substring(2, rest.length - 2) : rest.replaceAll('**', '');
      if (inner.isEmpty) return;
      _replaceLines((_) => isBold ? '$prefix$inner' : '$prefix**$inner**');
      return;
    }
    final a = sel.start, b = sel.end;
    final wrapped = a >= 2 && b + 2 <= text.length && text.substring(a - 2, a) == '**' && text.substring(b, b + 2) == '**';
    _busy = true;
    if (wrapped) {
      value = TextEditingValue(text: text.substring(0, a - 2) + text.substring(a, b) + text.substring(b + 2), selection: TextSelection(baseOffset: a - 2, extentOffset: b - 2));
    } else {
      final mid = text.substring(a, b).replaceAll('**', '');
      value = TextEditingValue(text: '${text.substring(0, a)}**$mid**${text.substring(b)}', selection: TextSelection(baseOffset: a + 2, extentOffset: a + 2 + mid.length));
    }
    _last = text;
    _busy = false;
  }

  @override
  void dispose() {
    removeListener(_onEdit);
    super.dispose();
  }
}
