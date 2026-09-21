import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Builds [FirebaseOptions] from `.env` / Netlify environment variables.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final apiKey = dotenv.env['FIREBASE_API_KEY'];
    final appId = dotenv.env['FIREBASE_APP_ID'];
    final messagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'];
    final projectId = dotenv.env['FIREBASE_PROJECT_ID'];

    if (apiKey == null ||
        apiKey.isEmpty ||
        apiKey.startsWith('your_') ||
        appId == null ||
        messagingSenderId == null ||
        projectId == null) {
      throw StateError(
        'Firebase credentials missing. Copy .env.example → .env '
        'or set Netlify environment variables.',
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'],
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
      measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'],
    );
  }

  /// True when `.env` looks like real credentials (not placeholders).
  static bool get isConfigured {
    final key = dotenv.env['FIREBASE_API_KEY'];
    return key != null && key.isNotEmpty && !key.startsWith('your_');
  }
}
