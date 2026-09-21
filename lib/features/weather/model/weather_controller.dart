import 'package:flutter/foundation.dart';

import '../../../entities/calculation/calculation_record.dart';
import '../../../entities/weather/weather_snapshot.dart';
import '../../../shared/services/firestore_service.dart';
import '../../calculator/domain/gemini_calc_service.dart';
import '../domain/weather_service.dart';

/// Weather workspace — NL lookup + manual city fetch + history.
class WeatherController extends ChangeNotifier {
  WeatherController({
    FirestoreService? firestore,
    GeminiCalcService? gemini,
    WeatherService? weather,
  })  : _firestore = firestore,
        _gemini = gemini ?? GeminiCalcService(),
        _weather = weather ?? WeatherService();

  final FirestoreService? _firestore;
  final GeminiCalcService _gemini;
  final WeatherService _weather;

  final List<CalculationRecord> _history = [];
  final List<WeatherSnapshot> _results = [];

  String _cityText = '서울';
  String _expression = '';
  String _resultDisplay = '—';
  String? _aiNote;
  String? _lastError;
  bool _busy = false;
  bool _lookingUp = false;

  List<CalculationRecord> get history => List.unmodifiable(_history);
  List<WeatherSnapshot> get results => List.unmodifiable(_results);
  String get cityText => _cityText;
  String get expression => _expression;
  String get resultDisplay => _resultDisplay;
  String? get aiNote => _aiNote;
  String? get lastError => _lastError;
  bool get busy => _busy;
  bool get lookingUp => _lookingUp;

  void setCityText(String value) {
    _cityText = value;
    notifyListeners();
  }

  Future<void> lookupCity({bool addHistory = true}) async {
    final city = _cityText.trim();
    if (city.isEmpty) {
      _lastError = '도시 이름을 입력해 주세요.';
      notifyListeners();
      return;
    }
    await _applySnapshots(
      await _weather.fetchMany([city]),
      expression: '$city 날씨',
      addHistory: addHistory,
      source: 'weather',
    );
  }

  Future<bool> applyNaturalLanguage(
    String utterance, {
    String sourceHint = 'typed',
  }) async {
    final text = utterance.trim();
    if (text.isEmpty) return false;

    _busy = true;
    _aiNote = null;
    _lastError = null;
    notifyListeners();

    try {
      var cities = WeatherService.extractCities(text);

      // Gemini fallback: ask for city list JSON when local parse finds none.
      if (cities.isEmpty) {
        final ai = await _gemini.calculate(
          '다음 문장에서 날씨를 묻고 있는 도시 이름만 쉼표로 나열하세요. '
          '다른 말은 금지. 도시가 없으면 "서울"만 출력.\n\n$text',
          requireNumericResult: false,
        );
        if (ai != null) {
          final raw = ai.result.isNotEmpty ? ai.result : ai.expression;
          cities = raw
              .split(RegExp(r'[,/|·]|그리고|와|과'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s != '0')
              .toList();
          // Also try extracting from explanation/expression text.
          if (cities.isEmpty) {
            cities = WeatherService.extractCities(
              '${ai.expression} ${ai.explanation} ${ai.result}',
            );
          }
        }
      }

      if (cities.isEmpty) {
        cities = ['서울'];
        _aiNote = '도시를 찾지 못해 서울 날씨를 보여 드립니다.';
      }

      if (cities.length == 1) {
        _cityText = cities.first;
      }

      final snaps = await _weather.fetchMany(cities);
      final ok = await _applySnapshots(
        snaps,
        expression: text,
        addHistory: true,
        source: sourceHint == 'voice' ? 'weather_voice' : 'weather_nl',
      );
      if (_aiNote == null && snaps.any((s) => s.ok)) {
        _aiNote = snaps.map((s) => s.summaryLine).join('\n');
      }
      return ok;
    } catch (e, st) {
      debugPrint('applyNaturalLanguage(weather): $e\n$st');
      _lastError = '날씨 조회 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> applyFromFile({
    required Uint8List bytes,
    required String fileName,
    String? extension,
    String? userHint,
  }) async {
    _busy = true;
    _aiNote = null;
    _lastError = null;
    notifyListeners();

    try {
      final hint = StringBuffer()
        ..writeln((userHint ?? '').trim())
        ..writeln(
          '파일에서 도시·여행지·장소 이름을 찾아 result에 도시명을 쉼표로 나열하세요. '
          '날씨 숫자는 추측하지 마세요.',
        );
      final ai = await _gemini.calculateFromFile(
        bytes: bytes,
        fileName: fileName,
        extension: extension,
        userHint: hint.toString().trim(),
        requireNumericResult: false,
      );
      if (ai == null) {
        _lastError = '파일에서 도시를 찾지 못했습니다. 다시 시도해 주세요.';
        return false;
      }

      final blob = '${ai.result} ${ai.expression} ${ai.explanation}';
      var cities = WeatherService.extractCities(blob);
      if (cities.isEmpty) {
        cities = blob
            .split(RegExp(r'[,/|·\n]'))
            .map((s) => s.trim())
            .where((s) => s.length >= 2 && s.length <= 40)
            .take(5)
            .toList();
      }
      if (cities.isEmpty) {
        _lastError = '파일에서 도시 이름을 찾지 못했습니다.';
        return false;
      }

      final snaps = await _weather.fetchMany(cities);
      _aiNote = ai.explanation.isNotEmpty
          ? ai.explanation
          : '$fileName에서 도시를 읽어 날씨를 조회했습니다.';
      return await _applySnapshots(
        snaps,
        expression: fileName,
        addHistory: true,
        source: 'weather_file',
      );
    } catch (e, st) {
      debugPrint('applyFromFile(weather): $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _applySnapshots(
    List<WeatherSnapshot> snaps, {
    required String expression,
    required bool addHistory,
    required String source,
  }) async {
    _lookingUp = true;
    _lastError = null;
    notifyListeners();

    try {
      if (snaps.isEmpty) {
        _lastError = '날씨 결과를 가져오지 못했습니다.';
        return false;
      }

      _results
        ..clear()
        ..addAll(snaps);

      final okSnaps = snaps.where((s) => s.ok).toList();
      final failSnaps = snaps.where((s) => !s.ok).toList();

      _expression = expression;
      if (okSnaps.length == 1) {
        final s = okSnaps.first;
        _resultDisplay = '${s.temperatureC.toStringAsFixed(1)}°C';
        _cityText = s.city;
      } else if (okSnaps.isNotEmpty) {
        _resultDisplay = okSnaps
            .map((s) => '${s.city} ${s.temperatureC.toStringAsFixed(0)}°')
            .join(' · ');
      } else {
        _resultDisplay = '조회 실패';
      }

      if (failSnaps.isNotEmpty && okSnaps.isEmpty) {
        _lastError = failSnaps.first.description;
      }

      final detail = snaps.map((s) => s.summaryLine).join('\n');
      _aiNote = detail;

      if (addHistory) {
        await _persist(
          expression: expression.length > 80
              ? '${expression.substring(0, 80)}…'
              : expression,
          result: detail.replaceAll('\n', ' | '),
          source: source,
        );
      }
      return okSnaps.isNotEmpty;
    } finally {
      _lookingUp = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    final fs = _firestore;
    if (fs == null) return;
    try {
      final rows = await fs.list(collectionPath: 'calculations', limit: 80);
      final weatherRows = rows
          .map(CalculationRecord.fromMap)
          .where((r) => r.source.startsWith('weather'))
          .toList();
      _history
        ..clear()
        ..addAll(weatherRows);
      notifyListeners();
    } catch (e) {
      debugPrint('loadHistory(weather): $e');
    }
  }

  Future<void> _persist({
    required String expression,
    required String result,
    required String source,
  }) async {
    final record = CalculationRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      expression: expression,
      result: result,
      createdAt: DateTime.now(),
      source: source,
    );
    _history.insert(0, record);

    final fs = _firestore;
    if (fs == null) return;
    try {
      await fs.create(collectionPath: 'calculations', data: record.toMap());
    } catch (e) {
      debugPrint('Failed to save weather lookup: $e');
    }
  }

  @override
  void dispose() {
    _gemini.dispose();
    _weather.dispose();
    super.dispose();
  }
}
