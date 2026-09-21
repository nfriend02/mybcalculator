import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight multi-language support (ko / en / ja).
class LocaleController extends ChangeNotifier {
  LocaleController() {
    _load();
  }

  String _code = 'ko';
  String get code => _code;

  static const supported = ['ko', 'en', 'ja'];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString('locale') ?? 'ko';
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (!supported.contains(code)) return;
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    notifyListeners();
  }

  String t(String key) => _dict[_code]?[key] ?? _dict['en']?[key] ?? key;

  static const _dict = <String, Map<String, String>>{
    'ko': {
      'home': '홈',
      'calculator': '계산기',
      'currency': '환율',
      'weather': '날씨',
      'units': '단위',
      'alarm': '알람',
      'schedule': '일정',
      'expense': '지출',
      'upload': '업로드',
      'voice_hint': '마이크로 말해 보세요',
    },
    'en': {
      'home': 'Home',
      'calculator': 'Calculator',
      'currency': 'FX',
      'weather': 'Weather',
      'units': 'Units',
      'alarm': 'Alarm',
      'schedule': 'Schedule',
      'expense': 'Expense',
      'upload': 'Upload',
      'voice_hint': 'Tap the mic and speak',
    },
    'ja': {
      'home': 'ホーム',
      'calculator': '電卓',
      'currency': '為替',
      'weather': '天気',
      'units': '単位',
      'alarm': 'アラーム',
      'schedule': '予定',
      'expense': '支出',
      'upload': 'アップロード',
      'voice_hint': 'マイクで話してください',
    },
  };
}
