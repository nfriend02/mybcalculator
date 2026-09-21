import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/theme/app_theme.dart';
import 'firebase_options.dart';

/// Entry point — Firebase init, dotenv, routing.
///
/// Developer Guidelines: every branch app exposes `main.dart` (or `index.js`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer non-dotfile config — Netlify CDN often blocks `/.env` / `/assets/.env`.
  for (final path in const [
    'assets/config/app_config.env',
    'assets/config/app.env',
    '.env',
  ]) {
    try {
      await dotenv.load(fileName: path, isOptional: true);
      if (dotenv.env.isNotEmpty) break;
    } catch (e, st) {
      debugPrint('dotenv load ($path) skipped: $e\n$st');
    }
  }

  var firebaseReady = false;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (Firebase.apps.isNotEmpty) {
      final existing = Firebase.app();
      final sameProject = existing.options.projectId == options.projectId;
      if (!sameProject) {
        await existing.delete();
      }
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    firebaseReady = true;
    debugPrint('Firebase ready: ${options.projectId}');
  } catch (e, st) {
    debugPrint('Firebase init skipped/failed: $e\n$st');
  }

  runApp(SmartCalculatorRoot(firebaseReady: firebaseReady));
}

class SmartCalculatorRoot extends StatelessWidget {
  const SmartCalculatorRoot({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final bootstrap = AppBootstrap(firebaseReady: firebaseReady);
    final router = bootstrap.createRouter();

    return MultiProvider(
      providers: bootstrap.providers(),
      child: MaterialApp.router(
        title: '센툴 AI Calculator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
