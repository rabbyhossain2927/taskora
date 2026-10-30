import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

class Sticker {
  final String emoji, name, how;
  final int color;
  final double progress; // 0..1
  const Sticker(this.emoji, this.name, this.how, this.color, this.progress);
  bool get earned => progress >= 1;
}

/// All stickers with progress (earned when progress reaches 1).
List<Sticker> stickersOf(Store s) {
  final done = s.todos.where((t) => t.done && t.completedAt != null).toList();
  final streak = streakOf(s);
    double r(num a, num b) => (a / b).clamp(0, 1).toDouble();
    final early = done.where((t) => t.completedAt!.hour < 9).length;
    final night = done.where((t) => t.completedAt!.hour >= 22).length;
  return [
      Sticker('🚀', 'Lift-off', 'Create your first project', 0, r(s.projects.length, 1)),
      Sticker('✅', 'Getting going', 'Finish 10 to-dos', 8, r(done.length, 10)),
      Sticker('🏆', 'Half-century', 'Finish 50 to-dos', 6, r(done.length, 50)),
      Sticker('🔥', 'On fire', 'Keep a 3-day streak', 4, r(streak, 3)),
      Sticker('🌋', 'Unstoppable', 'Keep a 7-day streak', 2, r(streak, 7)),
      Sticker('📝', 'Note taker', 'Write 10 notes', 12, r(s.notes.length, 10)),
      Sticker('💸', 'Getting paid', 'Add money to a project', 9, r(s.projects.where((p) => (p.amount ?? 0) > 0).length, 1)),
      Sticker('🌅', 'Early bird', 'Finish 5 to-dos before 9 am', 5, r(early, 5)),
      Sticker('🦉', 'Night owl', 'Finish 5 to-dos after 10 pm', 14, r(night, 5)),
      Sticker('🗂️', 'Organiser', 'Make 3 note sections', 10, r(s.sections.length, 3)),
      Sticker('🎯', 'Closer', 'Complete 3 projects', 13, r(s.projects.where((p) => p.done).length, 3)),
      Sticker('🧩', 'Breaker-down', 'Add 10 sub-tasks', 1, r(s.todos.fold<int>(0, (a, t) => a + t.subtasks.length), 10)),
    ];
}

/// XP level (same maths as the sticker book).
int levelOf(Store s) {
  final done = s.todos.where((t) => t.done && t.completedAt != null).length;
  final xp = done * 10 + s.projects.length * 25 + s.notes.length * 5 + s.projects.where((p) => p.done).length * 50;
  return (math.sqrt(xp / 50)).floor() + 1;
}

/// Achievements: streak flame, XP level and a sticker book.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});
  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  late final AnimationController flame = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Store>();
    final done = s.todos.where((t) => t.done && t.completedAt != null).toList();
    final streak = streakOf(s);
    final xp = done.length * 10 + s.projects.length * 25 + s.notes.length * 5 + s.projects.where((p) => p.done).length * 50;
    final level = (math.sqrt(xp / 50)).floor() + 1;
    final thisLevel = 50 * (level - 1) * (level - 1), nextLevel = 50 * level * level;
    final stickers = stickersOf(s);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doneDays = done.map((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day)).toSet();
    const warm = Color(0xFFFFF9EE);

    return Scaffold(
      backgroundColor: context.isDark ? null : warm,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          const Header('Achievements'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFB347), Color(0xFFFF7A59)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(children: [
                  AnimatedBuilder(
                    animation: flame,
                    builder: (_, __) => Transform.scale(scale: 1 + flame.value * 0.12, child: Transform.rotate(angle: (flame.value - 0.5) * 0.12, child: const Text('🔥', style: TextStyle(fontSize: 64)))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$streak', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: Colors.white, height: 1)),
                      const Text('day streak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(streak == 0 ? 'Finish a to-do today to light it up!' : 'Keep it going — finish one today.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Box(
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (var i = 6; i >= 0; i--)
                    Builder(builder: (_) {
                      final d = today.subtract(Duration(days: i));
                      final lit = doneDays.contains(d);
                      return Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: lit ? const Color(0xFFFFE2C2) : (context.isDark ? Colors.white10 : const Color(0xFFF4F1EA)), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(lit ? '🔥' : '·', style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(height: 4),
                        Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: i == 0 ? const Color(0xFFFF7A59) : context.mutedText)),
                      ]);
                    }),
                ]),
              ),
              const SizedBox(height: 12),
              Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Level $level', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('$xp / $nextLevel XP', style: TextStyle(color: context.mutedText, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: ((xp - thisLevel) / (nextLevel - thisLevel)).clamp(0, 1).toDouble(), minHeight: 14, color: const Color(0xFFFF9F43), backgroundColor: const Color(0xFFFFEBD3)),
                  ),
                  const SizedBox(height: 8),
                  Text('+10 per to-do · +25 per project · +50 when a project is done', style: TextStyle(fontSize: 12, color: context.mutedText)),
                ]),
              ),
              Label('Sticker book · ${stickers.where((x) => x.earned).length}/${stickers.length}'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [
                  for (var i = 0; i < stickers.length; i++) _stickerTile(context, stickers[i], i),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stickerTile(BuildContext context, Sticker st, int i) {
    final c = pastel(st.color);
    final angle = [-0.06, 0.04, -0.02, 0.05, -0.04, 0.03][i % 6];
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(st.emoji, style: TextStyle(fontSize: 72, color: st.earned ? null : Colors.black.withOpacity(0.3))),
            const SizedBox(height: 8),
            Text(st.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(st.how, style: TextStyle(color: context.mutedText)),
            const SizedBox(height: 14),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: st.progress, minHeight: 10, color: c.fg, backgroundColor: c.bg)),
            const SizedBox(height: 6),
            Text(st.earned ? 'Earned! 🎉' : '${(st.progress * 100).round()}% there', style: TextStyle(fontWeight: FontWeight.w700, color: c.fg)),
          ]),
        ),
      ),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          decoration: BoxDecoration(
            color: st.earned ? c.bg : (context.isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: st.earned ? Colors.white : C.line, width: 3),
            boxShadow: st.earned ? [BoxShadow(color: c.fg.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 6))] : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(alignment: Alignment.center, children: [
                if (!st.earned) CircularProgressIndicator(value: st.progress, strokeWidth: 4, color: c.fg, backgroundColor: c.bg),
                Opacity(opacity: st.earned ? 1 : 0.35, child: Text(st.emoji, style: const TextStyle(fontSize: 30))),
              ]),
            ),
            const SizedBox(height: 6),
            Text(st.name, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: st.earned ? c.fg : context.mutedText)),
          ]),
        ),
      ),
    );
  }
}
