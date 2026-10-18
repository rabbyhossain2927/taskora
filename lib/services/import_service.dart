import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import 'store.dart';

/// Turns Word (.docx), Google Docs (downloaded as .docx or .odt),
/// OpenDocument (.odt), Markdown and plain text files into notes.
/// Headings, bullet lists and bold text are kept.
class ImportService {
  static const extensions = ['docx', 'odt', 'txt', 'md', 'markdown', 'text', 'rtf', 'doc'];

  /// Lets you pick one or more files; returns how many notes were made.
  static Future<int> pickAndImport(Store store, {String? folderId}) async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: extensions, withData: false);
    if (r == null) return 0;
    var made = 0;
    final failed = <String>[];
    for (final f in r.files) {
      try {
        final bytes = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
        if (bytes == null) throw 'Could not read the file';
        final text = toNoteText(f.name, bytes);
        final title = f.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        await store.saveNote(Note(
          id: newId(),
          title: title,
          sectionId: folderId,
          icon: 'description',
          tabs: [NoteTab(id: 't1', title: 'Main', blocks: [NoteBlock(text: text.trim())])],
        ));
        made++;
      } catch (e) {
        failed.add('${f.name}: $e');
      }
    }
    if (made == 0 && failed.isNotEmpty) throw failed.join('\n');
    return made;
  }

  static String toNoteText(String name, List<int> bytes) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'docx':
        return _docx(bytes);
      case 'odt':
        return _odt(bytes);
      case 'doc':
        throw 'Old .doc files can’t be read. Open it in Word or Google Docs and save as .docx.';
      case 'rtf':
        return _rtf(utf8.decode(bytes, allowMalformed: true));
      case 'md':
      case 'markdown':
        return _markdown(utf8.decode(bytes, allowMalformed: true));
      default:
        return utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n');
    }
  }

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
        final code = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
        return code == null ? '' : String.fromCharCode(code);
      })
      .replaceAll('&amp;', '&');

  static String _file(List<int> zip, String path) {
    final a = ZipDecoder().decodeBytes(zip);
    final f = a.findFile(path);
    if (f == null) throw 'This file doesn’t look like a document.';
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  /// Word / Google Docs (.docx)
  static String _docx(List<int> bytes) {
    final xml = _file(bytes, 'word/document.xml');
    final out = <String>[];
    for (final p in RegExp(r'<w:p[ >][\s\S]*?</w:p>').allMatches(xml)) {
      final para = p[0]!;
      final style = RegExp(r'<w:pStyle w:val="([^"]+)"').firstMatch(para)?[1]?.toLowerCase() ?? '';
      final list = para.contains('<w:numPr>');
      final buf = StringBuffer();
      for (final r in RegExp(r'<w:r[ >][\s\S]*?</w:r>').allMatches(para)) {
        final run = r[0]!;
        final bold = RegExp(r'<w:b(\s*/>|\s+w:val="(1|true|on)"\s*/>)').hasMatch(run);
        final t = StringBuffer();
        for (final piece in RegExp(r'<w:t(?:\s[^>]*)?>([\s\S]*?)</w:t>|<w:tab/>|<w:br/>').allMatches(run)) {
          final m = piece[0]!;
          if (m == '<w:tab/>') {
            t.write('    ');
          } else if (m == '<w:br/>') {
            t.write('\n');
          } else {
            t.write(_unescape(piece[1] ?? ''));
          }
        }
        final txt = t.toString();
        if (txt.isEmpty) continue;
        buf.write(bold && txt.trim().isNotEmpty ? '**${txt.trim()}**${txt.endsWith(' ') ? ' ' : ''}' : txt);
      }
      var line = buf.toString().replaceAll('****', '');
      final plainLine = line.replaceAll('**', '');
      if (style == 'title' || style == 'heading1') {
        line = '# $plainLine';
      } else if (style.startsWith('heading') || style == 'subtitle') {
        line = '## $plainLine';
      } else if (list || style.contains('list')) {
        line = '• $line';
      }
      out.add(line);
    }
    return _tidy(out);
  }

  /// OpenDocument (.odt)
  static String _odt(List<int> bytes) {
    final xml = _file(bytes, 'content.xml');
    final body = RegExp(r'<office:text[^>]*>([\s\S]*)</office:text>').firstMatch(xml)?[1] ?? xml;
    final out = <String>[];
    String strip(String s) => _unescape(s.replaceAll(RegExp(r'<text:tab/>'), '    ').replaceAll(RegExp(r'<text:line-break/>'), '\n').replaceAll(RegExp(r'<[^>]+>'), ''));
    for (final m in RegExp(r'<text:list-item>([\s\S]*?)</text:list-item>|<text:h([^>]*)>([\s\S]*?)</text:h>|<text:p[^>]*/>|<text:p[^>]*>([\s\S]*?)</text:p>').allMatches(body)) {
      if (m[1] != null) {
        for (final p in RegExp(r'<text:p[^>]*>([\s\S]*?)</text:p>').allMatches(m[1]!)) {
          out.add('• ${strip(p[1]!)}');
        }
      } else if (m[3] != null) {
        final level = int.tryParse(RegExp(r'outline-level="(\d)"').firstMatch(m[2] ?? '')?[1] ?? '1') ?? 1;
        out.add('${level <= 1 ? '# ' : '## '}${strip(m[3]!)}');
      } else {
        out.add(strip(m[4] ?? ''));
      }
    }
    return _tidy(out);
  }

  static String _markdown(String s) => s
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((l) {
        final t = l.trimLeft();
        if (RegExp(r'^#{3,6} ').hasMatch(t)) return '## ${t.replaceFirst(RegExp(r'^#+ '), '')}';
        if (RegExp(r'^[-*+] (\[[ xX]\] )?').hasMatch(t)) return '• ${t.replaceFirst(RegExp(r'^[-*+] (\[[ xX]\] )?'), '')}';
        return l.replaceAll('__', '**');
      })
      .join('\n');

  /// Very simple RTF: keeps the words, drops the formatting codes.
  static String _rtf(String s) {
    var t = s.replaceAll(RegExp(r'\\par[d]?\b'), '\n').replaceAll(RegExp(r"\\'([0-9a-fA-F]{2})"), '');
    t = t.replaceAll(RegExp(r'\{\\\*[^{}]*\}'), '').replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '').replaceAll(RegExp(r'[{}]'), '');
    return _tidy(t.split('\n').map((l) => l.trim()).toList());
  }

  /// No more than one empty line in a row.
  static String _tidy(List<String> lines) {
    final out = <String>[];
    for (final l in lines) {
      if (l.trim().isEmpty && (out.isEmpty || out.last.trim().isEmpty)) continue;
      out.add(l.trimRight());
    }
    return out.join('\n');
  }
}
