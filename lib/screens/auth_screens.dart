import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 76});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(size * 0.32)),
        child: CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 76;
    c.save();
    c.translate(15 * u, 15 * u);
    c.scale(u * 46 / 48);
    final w = Paint()..color = Colors.white;
    c.drawLine(const Offset(16, 34), const Offset(30, 14), Paint()..color = Colors.white.withOpacity(0.85)..strokeWidth = 12..strokeCap = StrokeCap.round);
    c.drawCircle(const Offset(13, 14), 7, w);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 4, 20, 18), const Radius.circular(6)), Paint()..color = const Color(0xFFE6DEFF));
    c.drawCircle(const Offset(15, 35), 10, w);
    c.drawCircle(const Offset(35, 35), 7, Paint()..color = const Color(0xFFCDBEFF));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Logo(size: 34),
        const SizedBox(width: 10),
        Text.rich(TextSpan(children: [const TextSpan(text: 'Task'), TextSpan(text: 'Ora', style: TextStyle(color: context.accent))]),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      ]);
}

/// First screen: what the app is, then Get started / Sign in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final a = context.accent;
    Widget mini(IconData icon, int color, String title, String sub) {
      final p = pastel(color);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: p.fg)),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(sub, style: TextStyle(fontSize: 11, color: context.mutedText)),
          ]),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const FadeIn(child: Align(alignment: Alignment.centerLeft, child: _Wordmark())),
            const SizedBox(height: 28),
            FadeIn(
              index: 1,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: context.tint, borderRadius: BorderRadius.circular(28)),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: a.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))]),
                    child: Column(children: [
                      Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.folder_rounded, color: Colors.white, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Product Launch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text('12 of 20 done', style: TextStyle(fontSize: 12, color: context.mutedText)),
                          ]),
                        ),
                        Text('60%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: a)),
                      ]),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 0.6),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: v, minHeight: 6, color: a, backgroundColor: context.tint)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    mini(Icons.check_rounded, 8, 'Tasks', '8 linked'),
                    const SizedBox(width: 10),
                    mini(Icons.description_outlined, 4, 'Notes', '4 linked'),
                    const SizedBox(width: 10),
                    mini(Icons.calendar_month_outlined, 12, 'Events', '3 linked'),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 32),
            FadeIn(
              index: 2,
              child: Text.rich(
                TextSpan(children: [const TextSpan(text: 'Everything you do,\n'), TextSpan(text: 'connected.', style: TextStyle(color: a))]),
                style: const TextStyle(fontSize: 31, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.8),
              ),
            ),
            const SizedBox(height: 12),
            FadeIn(
              index: 3,
              child: Text('Projects, tasks, notes and your calendar in one calm place. Link anything to anything and see the whole picture.',
                  style: TextStyle(fontSize: 14.5, height: 1.55, color: context.mutedText)),
            ),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 22, height: 6, decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 6),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: a.withOpacity(0.25), borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 6),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: a.withOpacity(0.25), borderRadius: BorderRadius.circular(6))),
            ]),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Get started'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18)]),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Already have an account? ', style: TextStyle(color: context.mutedText)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
                child: Text('Sign in', style: TextStyle(color: a, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(2, 2, s.width - 4, s.height - 4);
    Paint p(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.18;
    c.drawArc(r, -0.35, -1.45, false, p(const Color(0xFFEA4335)));
    c.drawArc(r, -1.8, -1.5, false, p(const Color(0xFFFBBC05)));
    c.drawArc(r, 2.98, -1.6, false, p(const Color(0xFF34A853)));
    c.drawArc(r, 1.38, -1.73, false, p(const Color(0xFF4285F4)));
    c.drawLine(Offset(s.width / 2, s.height / 2), Offset(s.width - 2, s.height / 2), p(const Color(0xFF4285F4)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleButton extends StatefulWidget {
  final String label;
  const _GoogleButton({this.label = 'Continue with Google'});
  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: context.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await AuthService.signInWithGoogle();
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                } catch (e) {
                  if (context.mounted) toast(context, AuthService.friendly(e));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const _GoogleMark(),
          const SizedBox(width: 10),
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Or extends StatelessWidget {
  final String text;
  const _Or(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(text, style: TextStyle(color: context.mutedText, fontSize: 12.5))),
          const Expanded(child: Divider()),
        ]),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 12, left: 2),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool logo;
  final List<Widget> children;
  const _AuthScaffold({required this.title, required this.subtitle, required this.children, this.logo = false});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 24), children: [
            const Header(''),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (logo) const Padding(padding: EdgeInsets.only(bottom: 18), child: Align(alignment: Alignment.centerLeft, child: Logo(size: 52))),
                FadeIn(child: Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5))),
                const SizedBox(height: 6),
                FadeIn(index: 1, child: Text(subtitle, style: TextStyle(fontSize: 14.5, height: 1.5, color: context.mutedText))),
                const SizedBox(height: 22),
                ...children,
              ]),
            ),
          ]),
        ),
      );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false, hide = true;

  Future<void> _go() async {
    setState(() => busy = true);
    try {
      await AuthService.signInWithEmail(email.text, pass.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) toast(context, AuthService.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        logo: true,
        title: 'Welcome back',
        subtitle: 'Sign in and your work syncs across all your phones automatically.',
        children: [
          const _GoogleButton(),
          const _Or('or use email'),
          const _FieldLabel('Email'),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(hintText: 'you@example.com')),
          const _FieldLabel('Password'),
          TextField(
            controller: pass,
            obscureText: hide,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              hintText: '••••••••',
              suffixIcon: IconButton(tooltip: hide ? 'Show password' : 'Hide password', icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotScreen())), child: const Text('Forgot password?')),
          ),
          const SizedBox(height: 4),
          FilledButton(onPressed: busy ? null : _go, child: Text(busy ? 'Signing in…' : 'Sign in')),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('New to TaskOra? ', style: TextStyle(color: context.mutedText)),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
              child: Text('Create account', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  bool busy = false, agree = true, hide = true;

  int get _strength {
    final p = pass.text;
    var n = 0;
    if (p.length >= 8) n++;
    if (RegExp(r'[0-9]').hasMatch(p)) n++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) n++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) n++;
    return p.isEmpty ? 0 : n.clamp(1, 4);
  }

  Future<void> _go() async {
    if (name.text.trim().isEmpty) {
      toast(context, 'Please add your name.');
      return;
    }
    if (!agree) {
      toast(context, 'Please accept the terms to continue.');
      return;
    }
    setState(() => busy = true);
    try {
      await AuthService.signUp(name.text, email.text, pass.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) toast(context, AuthService.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _strength;
    const colors = [Color(0xFFE5484D), Color(0xFFF08C2E), Color(0xFF3E7BFA), Color(0xFF2EAD6B)];
    const hints = ['Too short. Use at least 8 characters.', 'Okay. Add a number to make it stronger.', 'Good. Add a symbol to make it strong.', 'Strong password.'];
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'Free forever. Your projects, to-dos and notes sync on every phone you sign in to.',
      children: [
        const _GoogleButton(label: 'Sign up with Google'),
        const _Or('or'),
        const _FieldLabel('Your name'),
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Alex Rahman')),
        const _FieldLabel('Email'),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'you@example.com')),
        const _FieldLabel('Password'),
        TextField(
          controller: pass,
          obscureText: hide,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'At least 8 characters',
            suffixIcon: IconButton(tooltip: hide ? 'Show password' : 'Hide password', icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide)),
          ),
        ),
        if (st > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(color: i < st ? colors[st - 1] : (context.isDark ? Colors.white12 : const Color(0xFFE8E8EE)), borderRadius: BorderRadius.circular(4)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(hints[st - 1], style: TextStyle(fontSize: 12, color: colors[st - 1], fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => agree = !agree),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: agree ? context.accent : Colors.transparent, borderRadius: BorderRadius.circular(7), border: Border.all(color: context.accent, width: 2)),
                child: agree ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('I agree to the Terms and Privacy Policy', style: TextStyle(fontSize: 13.5))),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : _go, child: Text(busy ? 'Creating…' : 'Create account')),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Already have an account? ', style: TextStyle(color: context.mutedText)),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
            child: Text('Sign in', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
          ),
        ]),
      ],
    );
  }
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final email = TextEditingController();
  bool sent = false;
  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: sent ? 'Check your email' : 'Reset password',
        subtitle: sent ? 'We sent a reset link to ${email.text.trim()}.' : 'Enter your email and we’ll send you a reset link.',
        children: [
          if (!sent) ...[
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  await AuthService.resetPassword(email.text);
                  setState(() => sent = true);
                } catch (e) {
                  if (context.mounted) toast(context, AuthService.friendly(e));
                }
              },
              child: const Text('Send reset link'),
            ),
          ] else ...[
            Container(
              height: 120,
              decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.mark_email_read_outlined, size: 54, color: C.green),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to sign in')),
          ],
        ],
      );
}
