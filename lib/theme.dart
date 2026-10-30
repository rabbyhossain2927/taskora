import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const purple = Color(0xFF5B5FEF);
  static const purpleDark = Color(0xFF4A4ED6);
  static const tint = Color(0xFFECEDFD);
  static const bg = Color(0xFFF6F6FA);
  static const ink = Color(0xFF16161D);
  static const muted = Color(0xFF6E6E7C);
  static const line = Color(0xFFECECF2);
  static const green = Color(0xFF1E8A5A);
  static const greenBg = Color(0xFFDDF3E8);
  static const red = Color(0xFFD64545);
  static const redBg = Color(0xFFFDE2E2);
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

/// App-wide colour themes. Everything else (tints, glow, nav) is derived from the accent.
class AppThemeOption {
  final String name;
  final Color accent;
  const AppThemeOption(this.name, this.accent);
  Color get tint => Color.lerp(accent, Colors.white, 0.88)!;
  Color get glow => Color.lerp(accent, Colors.white, 0.80)!;
  // Kept for older screens that read these
  Color get bg => C.bg;
}

const appThemes = <AppThemeOption>[
  AppThemeOption('Indigo Night', Color(0xFF5B5FEF)),
  AppThemeOption('Royal Violet', Color(0xFF7A5AF8)),
  AppThemeOption('Ocean Blue', Color(0xFF2F6FEB)),
  AppThemeOption('Sky Cyan', Color(0xFF0B9BD8)),
  AppThemeOption('Aqua Teal', Color(0xFF0E9384)),
  AppThemeOption('Emerald Green', Color(0xFF079455)),
  AppThemeOption('Lime Fresh', Color(0xFF5E9E0B)),
  AppThemeOption('Golden Amber', Color(0xFFD48806)),
  AppThemeOption('Sunset Orange', Color(0xFFE8590C)),
  AppThemeOption('Coral Peach', Color(0xFFEF6A5B)),
  AppThemeOption('Rose Pink', Color(0xFFDD2590)),
  AppThemeOption('Crimson Red', Color(0xFFD92D20)),
  AppThemeOption('Graphite', Color(0xFF3F3F4A)),
  AppThemeOption('Lavender Mist', Color(0xFF8B7CF6)),
  AppThemeOption('Plum', Color(0xFF9B3FB5)),
  AppThemeOption('Berry', Color(0xFFC0266D)),
  AppThemeOption('Mint', Color(0xFF12A97E)),
  AppThemeOption('Forest', Color(0xFF2F7D32)),
  AppThemeOption('Olive', Color(0xFF7A8B1E)),
  AppThemeOption('Copper', Color(0xFFB4572B)),
  AppThemeOption('Mocha', Color(0xFF8D5B3D)),
  AppThemeOption('Slate', Color(0xFF475569)),
  AppThemeOption('Midnight', Color(0xFF1E3A8A)),
  // Bright & light
  AppThemeOption('Bubblegum', Color(0xFFFF6FB5)),
  AppThemeOption('Flamingo', Color(0xFFF472B6)),
  AppThemeOption('Coral Pop', Color(0xFFFF6B6B)),
  AppThemeOption('Tangerine', Color(0xFFFF8A3D)),
  AppThemeOption('Sunshine', Color(0xFFF5B400)),
  AppThemeOption('Electric Lime', Color(0xFF7CC40F)),
  AppThemeOption('Peppermint', Color(0xFF2DD4A0)),
  AppThemeOption('Turquoise', Color(0xFF14C8C8)),
  AppThemeOption('Bright Sky', Color(0xFF38B6FF)),
  AppThemeOption('Azure', Color(0xFF3D8BFF)),
  AppThemeOption('Lilac Pop', Color(0xFFA78BFA)),
  AppThemeOption('Electric Violet', Color(0xFF8B5CF6)),
  AppThemeOption('Fuchsia', Color(0xFFE040FB)),
  AppThemeOption('Watermelon', Color(0xFFFF4D6D)),
];

/// Soft colours that match the current theme: the accent first, then
/// gentle neighbours around the colour wheel (for charts and stats).
List<Color> softPalette(Color accent, int n, {bool dark = false}) {
  final h = HSLColor.fromColor(accent);
  const steps = [0.0, 42.0, -38.0, 90.0, -80.0, 140.0, 190.0, -130.0];
  return [
    for (var i = 0; i < n; i++)
      HSLColor.fromAHSL(
        1,
        (h.hue + steps[i % steps.length] + 360) % 360,
        (h.saturation * 0.78).clamp(0.38, 0.72),
        dark ? 0.68 : (i == 0 ? h.lightness.clamp(0.48, 0.6) : 0.64),
      ).toColor(),
  ];
}

/// Background styles drawn behind every page.
const bgStyles = <(String, String)>[
  ('glow', 'Soft glow'),
  ('aurora', 'Aurora'),
  ('mesh', 'Mesh'),
  ('silk', 'Silk lines'),
  ('waves', 'Waves'),
  ('grain', 'Grain'),
  ('paper', 'Paper'),
  ('grid', 'Grid'),
  ('dots', 'Dots'),
  ('plain', 'Plain'),
];

/// Text sizes (Archivo is wide, so everything is a touch smaller).
class T {
  static const display = 24.0;
  static const title = 20.0;
  static const heading = 16.0;
  static const body = 14.0;
  static const small = 12.5;
  static const tiny = 11.0;
}

ThemeData buildTheme(AppThemeOption t, Brightness b, {String bgStyle = 'glow'}) {
  final dark = b == Brightness.dark;
  final surface = dark ? const Color(0xFF1B1B23) : Colors.white;
  final ink = dark ? const Color(0xFFEDEDF3) : C.ink;
  final muted = dark ? const Color(0xFFA0A0B0) : C.muted;
  final scheme = ColorScheme.fromSeed(seedColor: t.accent, brightness: b).copyWith(
    primary: t.accent,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    primaryContainer: dark ? Color.lerp(t.accent, Colors.black, 0.55) : t.tint,
    onPrimaryContainer: dark ? Colors.white : Color.lerp(t.accent, Colors.black, 0.25),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final text = GoogleFonts.archivoTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
  final snack = dark ? Color.lerp(t.accent, Colors.black, 0.35)! : Color.lerp(t.accent, Colors.black, 0.18)!;
  return base.copyWith(
    // Pages are transparent; AppBackground paints the colour + style behind each page.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: dark ? const Color(0xFF111117) : C.bg,
    textTheme: text,
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: BackgroundPageTransitionsBuilder(t, dark, bgStyle),
    }),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: snack,
      elevation: 6,
      contentTextStyle: GoogleFonts.archivo(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13.5),
      actionTextColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF22222B) : Colors.white,
      hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: dark ? Colors.white12 : C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: dark ? Colors.white12 : C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFDCDCE6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 13.5))),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogTheme(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    popupMenuTheme: PopupMenuThemeData(color: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder(), side: BorderSide(color: dark ? Colors.white12 : C.line)),
    dividerTheme: DividerThemeData(color: dark ? Colors.white10 : const Color(0xFFF0F0F5), space: 1, thickness: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : null),
    ),
  );
}

/// Paints the page background (colour + style) under every page, so page
/// transitions stay clean even though Scaffolds are transparent.
class BackgroundPageTransitionsBuilder extends PageTransitionsBuilder {
  final AppThemeOption t;
  final bool dark;
  final String style;
  const BackgroundPageTransitionsBuilder(this.t, this.dark, this.style);
  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final inA = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outA = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final fromBottom = route.fullscreenDialog;
    return SlideTransition(
      position: Tween(begin: fromBottom ? const Offset(0, 0.10) : const Offset(0.12, 0), end: Offset.zero).animate(inA),
      child: FadeTransition(
        opacity: inA,
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.05, 0)).animate(outA),
          // Pages opened on top get a readable width on big screens.
          child: AppBackground(t: t, dark: dark, style: style, constrain: !route.isFirst, child: child),
        ),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  final AppThemeOption t;
  final bool dark;
  final String style;
  final Widget child;
  final bool constrain;
  const AppBackground({super.key, required this.t, required this.dark, required this.style, required this.child, this.constrain = false});
  @override
  Widget build(BuildContext context) {
    final base = dark ? const Color(0xFF111117) : C.bg;
    final wide = constrain && MediaQuery.sizeOf(context).width >= 1000;
    // Computers, light, "Soft glow": the pastel pink / blue / mint wash from the web design.
    if (!dark && style == 'glow' && MediaQuery.sizeOf(context).width >= 700) {
      final inner = wide ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: child)) : child;
      RadialGradient g(Alignment at, double r, Color c, double stop) => RadialGradient(center: at, radius: r, colors: [c, c.withOpacity(0)], stops: [0, stop]);
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF8F7FF)),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: g(Alignment.topLeft, 1.3, const Color(0xFFFCE9FF), 0.62)),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: g(Alignment.topRight, 1.1, const Color(0xFFDFF0FF), 0.58)),
            child: DecoratedBox(decoration: BoxDecoration(gradient: g(const Alignment(0.4, 1), 1.2, const Color(0xFFE2FBEF), 0.6)), child: inner),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: base),
      child: CustomPaint(
        painter: _BgPainter(t.accent, dark, style),
        child: wide ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: child)) : child,
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final Color accent;
  final bool dark;
  final String style;
  _BgPainter(this.accent, this.dark, this.style);
  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'plain') return;
    // Soft colour glow at the top
    final glowH = size.height * 0.42;
    final rect = Rect.fromLTWH(0, 0, size.width, glowH);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withOpacity(dark ? 0.22 : 0.16), accent.withOpacity(0)],
        ).createShader(rect),
    );
    canvas.drawCircle(Offset(size.width * 0.9, 0), size.width * 0.5,
        Paint()..shader = RadialGradient(colors: [accent.withOpacity(dark ? 0.18 : 0.12), accent.withOpacity(0)]).createShader(Rect.fromCircle(center: Offset(size.width * 0.9, 0), radius: size.width * 0.5)));
    final rnd = math.Random(7);
    if (style == 'aurora') {
      final hues = [accent, HSLColor.fromColor(accent).withHue((HSLColor.fromColor(accent).hue + 40) % 360).toColor(), HSLColor.fromColor(accent).withHue((HSLColor.fromColor(accent).hue + 320) % 360).toColor()];
      for (var i = 0; i < 3; i++) {
        final c = Offset(size.width * [0.1, 0.6, 1.0][i], size.height * [0.05, 0.18, 0.02][i]);
        final r = size.width * [0.55, 0.45, 0.5][i];
        canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [hues[i].withOpacity(dark ? 0.22 : 0.16), hues[i].withOpacity(0)]).createShader(Rect.fromCircle(center: c, radius: r)));
      }
    } else if (style == 'mesh') {
      final hue = HSLColor.fromColor(accent);
      for (var i = 0; i < 5; i++) {
        final c = Offset(size.width * rnd.nextDouble(), size.height * (0.05 + 0.45 * rnd.nextDouble()));
        final r = size.width * (0.25 + 0.2 * rnd.nextDouble());
        final col = hue.withHue((hue.hue + i * 28) % 360).toColor();
        canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [col.withOpacity(dark ? 0.16 : 0.11), col.withOpacity(0)]).createShader(Rect.fromCircle(center: c, radius: r)));
      }
    } else if (style == 'waves') {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withOpacity(dark ? 0.12 : 0.09);
      for (var i = 0; i < 10; i++) {
        final path = Path();
        final y0 = 30.0 + i * 26;
        path.moveTo(0, y0);
        for (double x = 0; x <= size.width; x += 8) {
          path.lineTo(x, y0 + math.sin(x / 38 + i * 0.6) * 9);
        }
        canvas.drawPath(path, p);
      }
    } else if (style == 'grain') {
      final p = Paint()..color = (dark ? Colors.white : Colors.black).withOpacity(dark ? 0.05 : 0.035);
      for (var i = 0; i < 2600; i++) {
        canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), 0.7, p);
      }
    } else if (style == 'paper') {
      final p = Paint()
        ..color = accent.withOpacity(dark ? 0.08 : 0.06)
        ..strokeWidth = 1;
      for (double y = 28; y < size.height; y += 28) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
      canvas.drawLine(const Offset(36, 0), Offset(36, size.height), Paint()..color = const Color(0xFFE5484D).withOpacity(dark ? 0.12 : 0.10));
    } else if (style == 'grid') {
      final p = Paint()
        ..color = accent.withOpacity(dark ? 0.08 : 0.06)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (double y = 0; y < size.height; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    } else if (style == 'silk') {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withOpacity(dark ? 0.10 : 0.08);
      for (var i = 0; i < 14; i++) {
        final path = Path();
        final y0 = 40.0 + i * 22;
        path.moveTo(0, y0);
        path.cubicTo(size.width * 0.3, y0 - 60, size.width * 0.6, y0 + 70, size.width, y0 - 10);
        canvas.drawPath(path, p);
      }
    } else if (style == 'dots') {
      final p = Paint()..color = accent.withOpacity(dark ? 0.12 : 0.09);
      for (double y = 18; y < glowH + 80; y += 22) {
        for (double x = 14; x < size.width; x += 22) {
          canvas.drawCircle(Offset(x, y), 1.4 * (1 - y / (glowH + 120)).clamp(0.2, 1.0), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter o) => o.accent != accent || o.dark != dark || o.style != style;
}
