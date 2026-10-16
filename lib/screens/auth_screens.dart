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

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              const Logo(size: 84),
              const SizedBox(height: 28),
              RichText(
                text: TextSpan(style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15), children: [
                  const TextSpan(text: 'Projects, to-dos and notes.\n'),
                  TextSpan(text: 'All in one calm place.', style: TextStyle(color: context.accent)),
                ]),
              ),
              const SizedBox(height: 14),
              Text('Plan client work, split it into tasks, keep notes beside it — and sync it to every phone.', style: TextStyle(fontSize: 15, color: context.mutedText, height: 1.5)),
              const Spacer(),
              const _GoogleButton(),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: const StadiumBorder()),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
                child: const Text('Sign in with email', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: const Text('New here? Create an account'),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _GoogleButton extends StatefulWidget {
  const _GoogleButton();
  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
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
        icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.g_mobiledata_rounded, size: 30),
        label: const Text('Continue with Google'),
      );
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 24), children: [
            const Header(''),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 15, color: context.mutedText)),
                const SizedBox(height: 26),
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
  Widget build(BuildContext context) => _AuthScaffold(title: 'Welcome back', subtitle: 'Sign in to pick up where you left off.', children: [
        TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 12),
        TextField(
          controller: pass,
          obscureText: hide,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(tooltip: hide ? 'Show password' : 'Hide password', icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotScreen())), child: const Text('Forgot password?')),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : _go, child: Text(busy ? 'Signing in…' : 'Sign in')),
        const SizedBox(height: 14),
        const _GoogleButton(),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignUpScreen())), child: const Text('No account yet? Create one')),
      ]);
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  bool busy = false, agree = true;

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
  Widget build(BuildContext context) => _AuthScaffold(title: 'Create your account', subtitle: 'Free for 7 days. No card needed.', children: [
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password (6+ characters)', prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: agree,
          onChanged: (v) => setState(() => agree = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('I agree to the Terms and Privacy policy', style: TextStyle(fontSize: 13.5)),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : _go, child: Text(busy ? 'Creating…' : 'Create account')),
        const SizedBox(height: 14),
        const _GoogleButton(),
      ]);
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
