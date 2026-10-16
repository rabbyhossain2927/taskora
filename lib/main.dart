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
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: Prefs.instance),
      ChangeNotifierProvider(create: (_) => AuthState(), lazy: false),
    ],
    child: const TaskOraApp(),
  ));
}

/// Who is signed in. Listens to Firebase once for the whole app.
class AuthState extends ChangeNotifier {
  User? user;
  bool ready = false;
  AuthState() {
    FirebaseAuth.instance.userChanges().listen((u) {
      user = u;
      ready = true;
      notifyListeners();
    });
  }
}

class TaskOraApp extends StatelessWidget {
  const TaskOraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<Prefs>();
    final user = context.watch<AuthState>().user;
    final t = appThemes[prefs.themeIndex.clamp(0, appThemes.length - 1)];
    // MaterialApp is built once and never replaced (replacing it froze the
    // screen after sign-in). The Store is added around the navigator through
    // `builder`, so every page can read it.
    return MaterialApp(
      title: 'TaskOra',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotifyService.navigatorKey,
      theme: buildTheme(t, Brightness.light),
      darkTheme: buildTheme(t, Brightness.dark),
      themeMode: prefs.mode,
      builder: (context, child) => user == null
          ? child!
          : ChangeNotifierProvider<Store>(
              key: ValueKey(user.uid),
              create: (_) => Store(user.uid),
              child: child!,
            ),
      home: const AuthGate(),
    );
  }
}

/// The first page: loading, Welcome, or the app — and it updates live.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = auth.user;
    if (user == null) return const WelcomeScreen();
    return Shell(key: ValueKey(user.uid));
  }
}
