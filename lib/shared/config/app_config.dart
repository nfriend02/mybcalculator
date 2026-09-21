import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide config from `.env` / Netlify env.
class AppConfig {
  static String get apiPrefix => '/api';

  static String get title =>
      dotenv.env['APP_TITLE'] ?? 'AI Smart Calculator';

  static String get description =>
      dotenv.env['APP_DESCRIPTION'] ??
      '음성·자연어로 계산, 환율, 날씨까지 한 번에.';

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

  static String? get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['Gemini_API_Key'];

  static bool get hasGemini =>
      geminiApiKey != null &&
      geminiApiKey!.isNotEmpty &&
      !geminiApiKey!.startsWith('your_');

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
