import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/translations.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screens.dart';
import 'screens/focus_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'screens/update_screen.dart';
import 'services/focus_service.dart';
import 'services/notify_service.dart';
import 'services/prefs.dart';
import 'services/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On the website, right-click opens TaskOra's own menus instead of the browser's.
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase is used ONLY for Google / email sign-in. Data syncs with your own server (see Config.apiBase).
  await Prefs.init();
  try {
    await NotifyService.init();
  } catch (_) {}
  try {
    await FocusService.instance.init();
  } catch (_) {}
  NotifyService.onOpenUpdate = () => NotifyService.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const UpdateScreen()));
  NotifyService.onOpenFocus = () => NotifyService.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const FocusScreen()));
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: Prefs.instance),
      ChangeNotifierProvider.value(value: FocusService.instance),
      ChangeNotifierProvider(create: (_) => AuthState(), lazy: false),
    ],
    child: const TaskOraApp(),
  ));
}

/// Who is signed in. Listens to Firebase once for the whole app.
class AuthState extends ChangeNotifier {
  User? user;
  bool _gotUser = false, _splashDone = false;
  bool get ready => _gotUser && _splashDone;
  AuthState() {
    FirebaseAuth.instance.userChanges().listen((u) {
      user = u;
      _gotUser = true;
      notifyListeners();
    });
    // Show the splash for a moment so it doesn't flash.
    // Web already shows a loading screen from index.html, so no second splash there.
    Future.delayed(Duration(milliseconds: kIsWeb ? 0 : 1500), () {
      _splashDone = true;
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
      theme: buildTheme(t, Brightness.light, bgStyle: prefs.bgStyle),
      darkTheme: buildTheme(t, Brightness.dark, bgStyle: prefs.bgStyle),
      themeMode: prefs.mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      builder: (context, child) {
        // Archivo is a wide font: show all text a little smaller.
        final mq = MediaQuery.of(context);
        final scaled = MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear((mq.textScaler.scale(14) / 14) * 0.94)), child: child!);
        return user == null
            ? scaled
            : ChangeNotifierProvider<Store>(
                key: ValueKey(user.uid),
                create: (_) => Store(user.uid),
                child: scaled,
              );
      },
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
    final user = auth.user;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 1.03, end: 1.0).animate(a), child: child)),
      child: !auth.ready
          ? const SplashScreen(key: ValueKey('splash'))
          : user == null
              ? const WelcomeScreen(key: ValueKey('welcome'))
              : Shell(key: ValueKey(user.uid)),
    );
  }
}
