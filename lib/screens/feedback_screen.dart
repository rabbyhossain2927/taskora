import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sends a message straight to the app owner's email (through your server).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final name = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  final msg = TextEditingController();
  String kind = 'Feedback';
  bool sending = false, sent = false;

  Future<void> _send() async {
    if (msg.text.trim().isEmpty) {
      toast(context, 'Please write a message first.');
      return;
    }
    setState(() => sending = true);
    try {
      final v = await UpdateService.current();
      await Api.post('feedback.php', {'name': name.text.trim(), 'message': msg.text.trim(), 'kind': kind, 'appVersion': '${v.version} (${v.build})'});
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const Header('Send feedback'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: sent
                  ? FadeIn(
                      child: Column(children: [
                        const SizedBox(height: 40),
                        Container(width: 84, height: 84, decoration: const BoxDecoration(color: C.greenBg, shape: BoxShape.circle), child: const Icon(Icons.mark_email_read_outlined, color: C.green, size: 40)),
                        const SizedBox(height: 16),
                        const Text('Thank you!', style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Your message was sent. We read every one and reply by email when needed.', textAlign: TextAlign.center, style: TextStyle(color: context.mutedText, height: 1.5)),
                        const SizedBox(height: 20),
                        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                      ]),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Found a bug or have an idea? Tell us — it goes straight to the developer’s inbox.', style: TextStyle(color: context.mutedText, height: 1.5)),
                      const Label('Type'),
                      Segmented<String>(items: const [('Feedback', 'Feedback'), ('Bug', 'Problem'), ('Idea', 'Idea')], value: kind, onChanged: (v) => setState(() => kind = v)),
                      const Label('Your name'),
                      TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Your name')),
                      const Label('Message'),
                      TextField(controller: msg, minLines: 6, maxLines: 12, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Write your message…')),
                      const SizedBox(height: 8),
                      Text('We include your account email so we can reply.', style: TextStyle(color: context.mutedText, fontSize: 12)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: sending ? null : _send,
                        icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                        label: Text(sending ? 'Sending…' : 'Send'),
                      ),
                    ]),
            ),
          ]),
        ),
      );
}
