import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screens.dart';
import 'screens/shell.dart';
import 'screens/update_screen.dart';
import 'services/notify_service.dart';
import 'services/prefs.dart';
import 'services/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase is used ONLY for Google / email sign-in. Data syncs with your own server (see Config.apiBase).
  await Prefs.init();
  try {
    await NotifyService.init();
  } catch (_) {}
  NotifyService.onOpenUpdate = () => NotifyService.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const UpdateScreen()));
  runApp(ChangeNotifierProvider.value(value: Prefs.instance, child: const TaskOraApp()));
}

class TaskOraApp extends StatelessWidget {
  const TaskOraApp({super.key});
  static final _authChanges = FirebaseAuth.instance.userChanges();
  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<Prefs>();
    final t = appThemes[prefs.themeIndex.clamp(0, appThemes.length - 1)];
    // The Store sits above MaterialApp so every pushed page can read it.
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting && !snap.hasData;
        final user = snap.data;
        final app = MaterialApp(
          title: 'TaskOra',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotifyService.navigatorKey,
          theme: buildTheme(t, Brightness.light),
          darkTheme: buildTheme(t, Brightness.dark),
          themeMode: prefs.mode,
          home: waiting
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : user == null
                  ? const WelcomeScreen()
                  : Shell(key: ValueKey(user.uid)),
        );
        if (user == null) return app;
        return ChangeNotifierProvider<Store>(
          key: ValueKey(user.uid),
          create: (_) => Store(user.uid),
          child: app,
        );
      },
    );
  }
}
