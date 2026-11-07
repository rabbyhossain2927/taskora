// ignore_for_file: deprecated_member_use
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Built-in English spell check for notes (works the same on phone and web).
/// Wrong words get a red wavy line drawn by the editor itself, so it always
/// sits exactly under the word.
class SpellCheck extends SpellCheckerService<Object> {
  SpellCheck() : super(language: 'en');

  static Set<String> _words = {};
  static bool on = true;

  /// Load the word list once (about 37,000 common English words).
  static Future<void> init({required bool enabled}) async {
    on = enabled;
    SpellCheckerServiceProvider.setNewCheckerService(SpellCheck());
    try {
      final txt = await rootBundle.loadString('assets/words.txt');
      _words = txt.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty).toSet();
    } catch (_) {}
  }

  static final _wordRe = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");
  static const _suffixes = ['s', 'es', 'ed', 'd', 'ing', 'ly', 'er', 'ers', 'est', 'ness', 'ment', 'ments', 'ful', 'less', 'able'];

  /// True when the word looks fine (known word, a simple ending on a known word,
  /// a name, an abbreviation, or something we can't judge).
  static bool ok(String raw) {
    var w = raw;
    final apo = w.indexOf("'");
    if (apo > 0) w = w.substring(0, apo); // don't -> don
    if (w.length < 3) return true;
    if (w.toUpperCase() == w) return true; // ABC, NASA
    final lower = w.toLowerCase();
    if (_words.contains(lower)) return true;
    if (w[0] != lower[0]) return true; // Capitalised: probably a name
    for (final s in _suffixes) {
      if (lower.length > s.length + 2 && lower.endsWith(s)) {
        final base = lower.substring(0, lower.length - s.length);
        if (_words.contains(base) || _words.contains('${base}e')) return true;
        // running -> run, stopped -> stop
        if (base.length > 2 && base[base.length - 1] == base[base.length - 2] && _words.contains(base.substring(0, base.length - 1))) return true;
        // tried -> try, happily -> happy
        if (base.endsWith('i') && _words.contains('${base.substring(0, base.length - 1)}y')) return true;
      }
    }
    return false;
  }

  @override
  List<TextSpan>? checkSpelling(String text, {LongPressGestureRecognizer Function(String)? customLongPressRecognizerOnWrongSpan}) {
    if (!on || _words.isEmpty || text.isEmpty) return null;
    final spans = <TextSpan>[];
    var last = 0, wrong = false;
    for (final m in _wordRe.allMatches(text)) {
      if (ok(m.group(0)!)) continue;
      wrong = true;
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.wavy, decorationColor: Color(0xFFE5484D), decorationThickness: 1.6),
      ));
      last = m.end;
    }
    if (!wrong) return null;
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
