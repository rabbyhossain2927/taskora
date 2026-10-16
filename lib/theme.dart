import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const purple = Color(0xFF6A3FF5);
  static const purpleDark = Color(0xFF5B3FD0);
  static const tint = Color(0xFFEFEAFE);
  static const bg = Color(0xFFF8F7FC);
  static const ink = Color(0xFF1A1A1F);
  static const muted = Color(0xFF6B6B7A);
  static const line = Color(0xFFEEEBF7);
  static const green = Color(0xFF23845A);
  static const greenBg = Color(0xFFD7F2E3);
  static const red = Color(0xFFB03466);
  static const redBg = Color(0xFFFFD9E6);
  static const amber = Color(0xFF7F6100);
  static const amberBg = Color(0xFFFFF2C2);
}

/// A soft background with a matching strong colour for icons and text.
class Pastel {
  final String name;
  final Color bg;
  final Color fg;
  const Pastel(this.name, this.bg, this.fg);
}

/// 20 pastel pairs for projects, statuses and categories.
const pastels = <Pastel>[
  Pastel('Lavender', Color(0xFFE6DEFF), Color(0xFF5B3FD0)),
  Pastel('Lilac', Color(0xFFF1DDFB), Color(0xFF8A3BB0)),
  Pastel('Rose', Color(0xFFFFD9E6), Color(0xFFB03466)),
  Pastel('Blush', Color(0xFFFFE1DA), Color(0xFFB0463A)),
  Pastel('Peach', Color(0xFFFFE4CC), Color(0xFFB0601C)),
  Pastel('Apricot', Color(0xFFFFEBC7), Color(0xFF9A6A00)),
  Pastel('Butter', Color(0xFFFFF2C2), Color(0xFF7F6100)),
  Pastel('Lime', Color(0xFFEAF5C8), Color(0xFF5C7A12)),
  Pastel('Mint', Color(0xFFD7F2E3), Color(0xFF23845A)),
  Pastel('Sage', Color(0xFFDDEBDF), Color(0xFF3E6B4A)),
  Pastel('Teal', Color(0xFFCDF1EC), Color(0xFF1A7F72)),
  Pastel('Aqua', Color(0xFFCFEFF7), Color(0xFF16788F)),
  Pastel('Sky', Color(0xFFD6EAFF), Color(0xFF2C6CB8)),
  Pastel('Periwinkle', Color(0xFFDDE3FF), Color(0xFF3F55C4)),
  Pastel('Iris', Color(0xFFE3DCFA), Color(0xFF4E3AA8)),
  Pastel('Mauve', Color(0xFFEFDDEB), Color(0xFF8C3F7A)),
  Pastel('Sand', Color(0xFFF2E8DA), Color(0xFF7A5A33)),
  Pastel('Clay', Color(0xFFF3DED5), Color(0xFF8F4E35)),
  Pastel('Stone', Color(0xFFE7E5E0), Color(0xFF55524A)),
  Pastel('Graphite', Color(0xFFDCDCE3), Color(0xFF2E2E3A)),
];

Pastel pastel(int i) => pastels[i.clamp(0, pastels.length - 1)];

/// 32 note backgrounds (index 0 is plain white).
const noteColors = <Color>[
  Color(0xFFFFFFFF), Color(0xFFF6F2FF), Color(0xFFEDE6FF), Color(0xFFE3DCFA),
  Color(0xFFF8EAFD), Color(0xFFF1DDFB), Color(0xFFFFEEF4), Color(0xFFFFD9E6),
  Color(0xFFFFEDE8), Color(0xFFFFE1DA), Color(0xFFFFF0E2), Color(0xFFFFE4CC),
  Color(0xFFFFF5DD), Color(0xFFFFEBC7), Color(0xFFFFF8D9), Color(0xFFFFF2C2),
  Color(0xFFF4FADF), Color(0xFFEAF5C8), Color(0xFFE6F7EE), Color(0xFFD7F2E3),
  Color(0xFFE8F2EA), Color(0xFFDDEBDF), Color(0xFFE0F7F3), Color(0xFFCDF1EC),
  Color(0xFFE2F5FA), Color(0xFFCFEFF7), Color(0xFFE6F1FF), Color(0xFFD6EAFF),
  Color(0xFFF7F0E6), Color(0xFFF2E8DA), Color(0xFFF1F0EC), Color(0xFFE7E5E0),
];

Color noteColor(int i) => noteColors[i.clamp(0, noteColors.length - 1)];

/// App-wide themes: an accent colour plus a background wash.
class AppThemeOption {
  final String name;
  final Color accent;
  final Color bg;
  final Color tint;
  const AppThemeOption(this.name, this.accent, this.bg, this.tint);
}

const appThemes = <AppThemeOption>[
  AppThemeOption('TaskOra', Color(0xFF6A3FF5), Color(0xFFF8F7FC), Color(0xFFEFEAFE)),
  AppThemeOption('Rose', Color(0xFFC2416F), Color(0xFFFFF6F8), Color(0xFFFFE3EC)),
  AppThemeOption('Peach', Color(0xFFD06A2A), Color(0xFFFFF8F2), Color(0xFFFFE9D6)),
  AppThemeOption('Butter', Color(0xFFA27C00), Color(0xFFFFFCF0), Color(0xFFFFF2C2)),
  AppThemeOption('Mint', Color(0xFF23845A), Color(0xFFF4FBF7), Color(0xFFDDF4E7)),
  AppThemeOption('Teal', Color(0xFF1A7F72), Color(0xFFF2FBFA), Color(0xFFD6F3EF)),
  AppThemeOption('Sky', Color(0xFF2C6CB8), Color(0xFFF4F8FF), Color(0xFFDDEBFF)),
  AppThemeOption('Graphite', Color(0xFF2E2E3A), Color(0xFFF6F6F8), Color(0xFFE6E6EC)),
];

ThemeData buildTheme(AppThemeOption t, Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF121216) : t.bg;
  final surface = dark ? const Color(0xFF1E1E24) : Colors.white;
  final ink = dark ? const Color(0xFFF2F2F6) : C.ink;
  final scheme = ColorScheme.fromSeed(seedColor: t.accent, brightness: b).copyWith(
    primary: t.accent,
    surface: surface,
    onSurface: ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink),
    appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A1A1F),
      contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
      actionTextColor: const Color(0xFFCDBEFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF26262E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE4E0F2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE4E0F2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: t.accent, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30)))),
    dividerTheme: DividerThemeData(color: dark ? Colors.white10 : const Color(0xFFF1EEF8), space: 1),
  );
}
