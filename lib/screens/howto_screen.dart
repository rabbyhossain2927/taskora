import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A short, friendly guide to every part of the app.
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const sections = <(IconData, int, String, List<String>)>[
    (Icons.home_outlined, 0, 'Home', [
      'See what is due today, your progress ring and the next 7 days.',
      'Search finds any project, to-do, sub-task, note or tag.',
      'The calendar icon shows deadlines by day. The bell shows your notifications.',
      'Tap Stats to see your week, month and year. Tap Focus to start a timer.',
    ]),
    (Icons.add_rounded, 12, 'The + button', [
      'Tap + to add a project, a to-do or a note.',
      'Press and hold + to start a Focus session straight away.',
    ]),
    (Icons.work_outline_rounded, 0, 'Projects', [
      'Add a colour, an icon, a cover photo and an amount. Fiverr (20%) and Upwork (10%) fees are worked out for you.',
      'Swipe a project to the right to mark it complete. Swipe left to delete.',
      'Completed projects move into the “Completed” dropdown at the bottom.',
      'Press and hold a project for quick options: complete, edit, add a task, change status or priority.',
      'Inside a project, tap any box (status, category, dates, priority) to change it. Attach files up to 30 MB.',
    ]),
    (Icons.check_circle_outline_rounded, 8, 'To-dos', [
      'Tap the circle to finish a to-do. Swipe right for done, left to delete.',
      'Tap the arrow on the right to see its sub-tasks and tick them off.',
      'Press and hold for options, or choose “Select several” to change or delete many at once.',
      'Priorities: Urgent, High, Medium, Low or None. Pick “Other” to make your own category.',
    ]),
    (Icons.sticky_note_2_outlined, 6, 'Notes', [
      'Group notes in folders. A folder can be shown on Home.',
      'Add tabs inside a note, like Google Docs. Hold a tab to rename or move it.',
      'Use the toolbar for text size, bold, bullet points, checklists, dropdowns, links, images and PDFs.',
      'Links turn into preview cards. Press and hold a note to pin, move or delete it.',
    ]),
    (Icons.cloud_sync_outlined, 10, 'Sync & backup', [
      'Everything is saved on your phone first and synced to the server automatically.',
      'Pull down on any page to sync right now.',
      'Turn on automatic backups to Google Drive and phone storage in Backup & sync.',
      'Deleted something by mistake? Tap Undo in the bar at the bottom.',
    ]),
    (Icons.palette_outlined, 2, 'Make it yours', [
      'Profile → Theme: pick one of 13 colours, a background style, and light or dark mode.',
      'Profile → Preferences: defaults, tags, statuses and categories.',
    ]),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const Header('How to use'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < sections.length; i++)
                  FadeIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Box(
                        padding: EdgeInsets.zero,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: i == 0,
                            shape: const RoundedRectangleBorder(),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: pastel(sections[i].$2).bg, borderRadius: BorderRadius.circular(11)),
                              child: Icon(sections[i].$1, size: 19, color: pastel(sections[i].$2).fg),
                            ),
                            title: Text(sections[i].$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            children: [
                              for (final line in sections[i].$4)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Padding(padding: const EdgeInsets.only(top: 7, right: 10), child: Icon(Icons.circle, size: 6, color: context.accent)),
                                    Expanded(child: Text(line, style: const TextStyle(height: 1.5, fontSize: 14))),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      );
}
