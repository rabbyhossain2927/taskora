import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';

/// Shown for a moment while the app starts: logo, name and a small loading bar.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final a = context.accent;
    // Web: same light screen as index.html while sign-in loads, so it looks like one splash.
    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F7FF),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Logo(size: 92),
            SizedBox(height: 20),
            Text.rich(TextSpan(children: [TextSpan(text: 'Task'), TextSpan(text: 'Ora', style: TextStyle(color: Color(0xFF7054FB)))]),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: Color(0xFF16161D))),
            SizedBox(height: 4),
            Text('Projects · To-dos · Notes', style: TextStyle(fontSize: 13.5, color: Color(0xFF6A6A7A))),
            SizedBox(height: 28),
            SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 4, color: Color(0xFF7054FB), backgroundColor: Color(0xFFE6E1FF))),
          ]),
        ),
      );
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(a, Colors.white, 0.12)!, Color.lerp(a, Colors.black, 0.18)!]),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: 0.8 + 0.2 * v, child: child)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 12))]),
                child: const Logo(size: 96),
              ),
              const SizedBox(height: 20),
              const Text('TaskOra', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
              const SizedBox(height: 4),
              const Text('Projects · To-dos · Notes', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(minHeight: 4, color: Colors.white, backgroundColor: Colors.white24),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
