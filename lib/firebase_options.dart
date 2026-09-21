import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase options for the mybcalculator web app.
///
/// Client Firebase config is public by design. Values can still be overridden
/// via dotenv (`assets/config/app_config.env`) when present.
class DefaultFirebaseOptions {
  /// Built-in project config (used when dotenv is missing — e.g. Netlify
  /// blocking `.env` uploads).
  static const FirebaseOptions mybcalculator = FirebaseOptions(
    apiKey: 'AIzaSyCrgHjykWGeapUxwJswT9fNunUsZ6UGnS4',
    appId: '1:1054489668623:web:8c70be0c68283e9389877a',
    messagingSenderId: '1054489668623',
    projectId: 'mybcalculator',
    authDomain: 'mybcalculator.firebaseapp.com',
    storageBucket: 'mybcalculator.firebasestorage.app',
    measurementId: 'G-KHG6Q96FSG',
  );

  static FirebaseOptions get currentPlatform {
    final apiKey = dotenv.env['FIREBASE_API_KEY']?.trim();
    final appId = dotenv.env['FIREBASE_APP_ID']?.trim();
    final messagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID']?.trim();
    final projectId = dotenv.env['FIREBASE_PROJECT_ID']?.trim();

    final envReady = apiKey != null &&
        apiKey.isNotEmpty &&
        !apiKey.startsWith('your_') &&
        appId != null &&
        appId.isNotEmpty &&
        messagingSenderId != null &&
        messagingSenderId.isNotEmpty &&
        projectId != null &&
        projectId.isNotEmpty;

    if (!envReady) return mybcalculator;

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']?.trim().isNotEmpty == true
          ? dotenv.env['FIREBASE_AUTH_DOMAIN']!.trim()
          : mybcalculator.authDomain,
      storageBucket:
          dotenv.env['FIREBASE_STORAGE_BUCKET']?.trim().isNotEmpty == true
              ? dotenv.env['FIREBASE_STORAGE_BUCKET']!.trim()
              : mybcalculator.storageBucket,
      measurementId:
          dotenv.env['FIREBASE_MEASUREMENT_ID']?.trim().isNotEmpty == true
              ? dotenv.env['FIREBASE_MEASUREMENT_ID']!.trim()
              : mybcalculator.measurementId,
    );
  }

  /// Always true — built-in mybcalculator options are the fallback.
  static bool get isConfigured => true;
}
