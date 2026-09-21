import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide config from `.env` / Netlify env.
class AppConfig {
  static String get apiPrefix => '/api';

  static String get title =>
      dotenv.env['APP_TITLE'] ?? '센툴 AI Calculator';

  static String get description =>
      dotenv.env['APP_DESCRIPTION'] ??
      '말로 풀고 식으로 확인하는 AI 계산기.';

  static String get author =>
      dotenv.env['APP_AUTHOR'] ?? 'MyBranch Team';

  static String get iconUrl =>
      dotenv.env['APP_ICON_URL'] ?? '/icons/Icon-512.png';

  static String get githubBranchUrl =>
      dotenv.env['GITHUB_BRANCH_URL'] ?? '';

  static String get netlifySiteUrl =>
      dotenv.env['NETLIFY_SITE_URL'] ?? '';

  static String? get openWeatherApiKey =>
      dotenv.env['OPENWEATHER_API_KEY'];

  static String? get exchangeRateApiKey =>
      dotenv.env['EXCHANGE_RATE_API_KEY'];

  static String? get geminiApiKey {
    final raw =
        dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['Gemini_API_Key'];
    if (raw == null) return null;
    // Strip wrapping quotes that often sneak into Windows .env files.
    final cleaned = raw.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  static bool get hasGemini {
    final key = geminiApiKey;
    return key != null &&
        key.isNotEmpty &&
        !key.startsWith('your_') &&
        key.length >= 20;
  }

  /// Preferred Gemini model; overridable via `.env`.
  static String get geminiModel =>
      dotenv.env['GEMINI_MODEL']?.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '') ??
      'gemini-flash-latest';

  /// Portfolio upload checklist fields (≤200 chars description).
  static Map<String, String> uploadChecklistMeta() {
    final desc = description.length > 200
        ? '${description.substring(0, 197)}...'
        : description;
    return {
      'title': title,
      'description': desc,
      'author': author,
      'iconUrl': iconUrl,
      'githubBranchUrl': githubBranchUrl,
      'netlifySiteUrl': netlifySiteUrl,
    };
  }
}
