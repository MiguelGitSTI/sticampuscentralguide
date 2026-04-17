import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sticampuscentralguide/theme/theme_provider.dart';
import 'package:sticampuscentralguide/utils/visitor_mode_provider.dart';
import 'package:sticampuscentralguide/firebase_options.dart';
import 'package:sticampuscentralguide/Screens/home_screen.dart';
import 'package:sticampuscentralguide/Screens/login_screen.dart';
import 'package:sticampuscentralguide/Widgets/loading_screen.dart';
import 'package:sticampuscentralguide/utils/notification_service.dart';
import 'package:sticampuscentralguide/utils/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize background service for persistent notifications
  await BackgroundService().initialize();
  await BackgroundService().registerDailyTask();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) => VisitorModeProvider()..load(),
        ),
      ],
      child: Consumer2<ThemeProvider, VisitorModeProvider>(
        builder: (context, themeProvider, visitorMode, child) {
          return MaterialApp(
            title: 'STI Campus Central Guide',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: const SplashWrapper(),
          );
        },
      ),
    );
  }
}

/// Wrapper that always shows splash screen first, then navigates based on auth state
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _showSplash = true;

  void _onSplashFinished() {
    if (!mounted || !_showSplash) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return LoadingScreen(onFinished: _onSplashFinished);
    }

    final visitorMode = context.watch<VisitorModeProvider>();
    if (!visitorMode.loaded) {
      return const _BootstrapLoadingScreen();
    }
    if (visitorMode.isVisitor) {
      return const HomeScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _BootstrapLoadingScreen();
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}
