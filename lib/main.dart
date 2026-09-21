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

  await dotenv.load(fileName: '.env');

  var firebaseReady = false;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
    } catch (e, st) {
      debugPrint('Firebase init skipped/failed: $e\n$st');
    }
  } else {
    debugPrint(
      'Firebase credentials not configured — running in offline demo mode.',
    );
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
        title: 'AI Smart Calculator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
