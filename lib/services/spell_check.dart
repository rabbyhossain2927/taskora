// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A grammar problem found by LanguageTool in the open note.
class GrammarIssue {
  final String text; // the words that are wrong
  final String message;
  final List<String> fixes;
  const GrammarIssue(this.text, this.message, this.fixes);
}

/// What's wrong at a spot in the text, and how to fix it.
class TextIssue {
  final int start, length;
  final String word;
  final bool grammar;
  final String message;
  final List<String> fixes;
  const TextIssue(this.start, this.length, this.word, this.grammar, this.message, this.fixes);
}

/// Built-in spell check (on the device) + grammar check (LanguageTool) for notes.
/// Mistakes are drawn by the editor itself — bold, with a wavy line exactly
/// under the words: red for spelling, blue for grammar.
class SpellCheck extends SpellCheckerService<Object> {
  SpellCheck() : super(language: 'en');

  static Map<String, int> _rank = {}; // word -> how common (0 = most common)
  static final Set<String> _mine = {}; // "Add to dictionary"
  static final Set<String> _ignored = {}; // "Ignore" (this session)
  static List<GrammarIssue> grammar = [];
  static bool on = true;

  /// Bumped when marks change (grammar results, a word added) so editors redraw.
  static final changed = ValueNotifier<int>(0);

  static Future<void> init({required bool enabled}) async {
    on = enabled;
    SpellCheckerServiceProvider.setNewCheckerService(SpellCheck());
    try {
      final p = await SharedPreferences.getInstance();
      _mine.addAll(p.getStringList('myWords') ?? const []);
    } catch (_) {}
    try {
      final txt = await rootBundle.loadString('assets/words.txt');
      final list = txt.split('\n');
      final m = <String, int>{};
      for (var i = 0; i < list.length; i++) {
        final w = list[i].trim();
        if (w.isNotEmpty) m.putIfAbsent(w, () => i);
      }
      _rank = m;
      changed.value++;
    } catch (_) {}
  }

  static Future<void> addWord(String w) async {
    _mine.add(w.toLowerCase());
    changed.value++;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('myWords', _mine.toList());
    } catch (_) {}
  }

  static void ignore(String w) {
    _ignored.add(w.toLowerCase());
    grammar = grammar.where((g) => g.text != w).toList();
    changed.value++;
  }

  static bool _known(String w) => _rank.containsKey(w) || _mine.contains(w);

  static final _wordRe = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");
  static const _suffixes = ['s', 'es', 'ed', 'd', 'ing', 'ly', 'er', 'ers', 'est', 'ness', 'ment', 'ments', 'ful', 'less', 'able'];

  /// True when the word looks fine (known word, a simple ending on a known word,
  /// a name, an abbreviation, or something we can't judge).
  static bool ok(String raw) {
    if (_rank.isEmpty) return true;
    var w = raw;
    final apo = w.indexOf("'");
    if (apo > 0) w = w.substring(0, apo); // don't -> don
    if (w.length < 3) return true;
    if (w.toUpperCase() == w) return true; // ABC, NASA
    final lower = w.toLowerCase();
    if (_known(lower) || _ignored.contains(lower)) return true;
    if (w[0] != lower[0]) return true; // Capitalised: probably a name
    for (final s in _suffixes) {
      if (lower.length > s.length + 2 && lower.endsWith(s)) {
        final base = lower.substring(0, lower.length - s.length);
        if (_known(base) || _known('${base}e')) return true;
        if (base.length > 2 && base[base.length - 1] == base[base.length - 2] && _known(base.substring(0, base.length - 1))) return true;
        if (base.endsWith('i') && _known('${base.substring(0, base.length - 1)}y')) return true;
      }
    }
    return false;
  }

  static const _abc = 'abcdefghijklmnopqrstuvwxyz';
  static Set<String> _edits(String w) {
    final out = <String>{};
    for (var i = 0; i <= w.length; i++) {
      final a = w.substring(0, i), b = w.substring(i);
      if (b.isNotEmpty) out.add(a + b.substring(1)); // delete
      if (b.length > 1) out.add(a + b[1] + b[0] + b.substring(2)); // swap
      for (final c in _abc.split('')) {
        if (b.isNotEmpty) out.add(a + c + b.substring(1)); // replace
        out.add(a + c + b); // insert
      }
    }
    return out;
  }

  /// Up to 4 likely right spellings, most common first.
  static List<String> suggest(String word) {
    final lower = word.toLowerCase();
    final e1 = _edits(lower);
    var found = e1.where(_rank.containsKey).toList();
    if (found.length < 4 && lower.length <= 9) {
      final more = <String>{};
      for (final e in e1) {
        for (final e2 in _edits(e)) {
          if (_rank.containsKey(e2)) more.add(e2);
        }
      }
      found = {...found, ...more}.toList();
    }
    found.sort((a, b) => _rank[a]!.compareTo(_rank[b]!));
    final cap = word.isNotEmpty && word[0] != lower[0];
    return [for (final f in found.take(4)) cap ? f[0].toUpperCase() + f.substring(1) : f];
  }

  /// The mistake under the caret (offset into the whole text), if any.
  static TextIssue? issueAt(String text, int offset) {
    if (!on) return null;
    for (final g in grammar) {
      var i = text.indexOf(g.text);
      while (i >= 0) {
        if (offset >= i && offset <= i + g.text.length) return TextIssue(i, g.text.length, g.text, true, g.message, g.fixes);
        i = text.indexOf(g.text, i + 1);
      }
    }
    for (final m in _wordRe.allMatches(text)) {
      if (m.start > offset) break;
      if (offset <= m.end && !ok(m.group(0)!)) {
        return TextIssue(m.start, m.end - m.start, m.group(0)!, false, 'Spelling', suggest(m.group(0)!));
      }
    }
    return null;
  }

  // ---------------- grammar (LanguageTool) ----------------
  static Timer? _timer;
  static String _lastChecked = '';

  /// Check grammar a moment after typing stops.
  static void checkGrammarSoon(String text) {
    if (!on) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () => _checkGrammar(text));
  }

  static Future<void> _checkGrammar(String text) async {
    final t = text.length > 15000 ? text.substring(0, 15000) : text;
    if (t.trim().length < 8 || t == _lastChecked) return;
    _lastChecked = t;
    try {
      final r = await http.post(
        Uri.parse('https://api.languagetool.org/v2/check'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
        body: {'text': t, 'language': 'en-US', 'enabledOnly': 'false'},
      ).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return;
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final out = <GrammarIssue>[];
      for (final x in (m['matches'] as List? ?? const [])) {
        final rule = (x['rule'] as Map?) ?? const {};
        if (rule['issueType'] == 'misspelling') continue; // spelling is done on the device
        final off = (x['offset'] as num).toInt(), len = (x['length'] as num).toInt();
        if (off < 0 || off + len > t.length || len == 0) continue;
        final words = t.substring(off, off + len);
        if (words.trim().isEmpty || _ignored.contains(words.toLowerCase())) continue;
        final fixes = [for (final f in (x['replacements'] as List? ?? const []).take(4)) (f['value'] ?? '').toString()].where((s) => s.isNotEmpty).toList();
        out.add(GrammarIssue(words, (x['shortMessage'] as String?)?.isNotEmpty == true ? x['shortMessage'] : (x['message'] ?? 'Grammar'), fixes));
      }
      grammar = out;
      changed.value++;
    } catch (_) {
      // No internet or the service is busy: just skip grammar this time.
    }
  }

  static void clearGrammar() {
    grammar = [];
    _lastChecked = '';
    changed.value++;
  }

  static const _spellStyle = TextStyle(
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Color(0xFFE5484D),
    decorationThickness: 1.8,
  );
  static const _grammarStyle = TextStyle(
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Color(0xFF3E7BFA),
    decorationThickness: 1.8,
  );

  @override
  List<TextSpan>? checkSpelling(String text, {LongPressGestureRecognizer Function(String)? customLongPressRecognizerOnWrongSpan}) {
    if (!on || text.isEmpty) return null;
    final marks = <(int, int, bool)>[]; // start, end, grammar?
    for (final g in grammar) {
      var i = text.indexOf(g.text);
      while (i >= 0) {
        marks.add((i, i + g.text.length, true));
        i = text.indexOf(g.text, i + g.text.length);
      }
    }
    if (_rank.isNotEmpty) {
      for (final m in _wordRe.allMatches(text)) {
        if (!ok(m.group(0)!)) marks.add((m.start, m.end, false));
      }
    }
    if (marks.isEmpty) return null;
    marks.sort((a, b) => a.$1.compareTo(b.$1));
    final spans = <TextSpan>[];
    var last = 0;
    for (final mk in marks) {
      if (mk.$1 < last) continue; // overlaps the previous mark
      if (mk.$1 > last) spans.add(TextSpan(text: text.substring(last, mk.$1)));
      spans.add(TextSpan(text: text.substring(mk.$1, mk.$2), style: mk.$3 ? _grammarStyle : _spellStyle));
      last = mk.$2;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  void toggleChecker() => on = !on;
  @override
  bool isServiceActive() => on;
  @override
  void dispose({bool onlyPartial = false}) {}
  @override
  void setNewLanguageState({required String language}) {}
  @override
  void updateCustomLanguageIfExist({required Object languageIdentifier}) {}
  @override
  void addCustomLanguage({required Object languageIdentifier}) {}
}
