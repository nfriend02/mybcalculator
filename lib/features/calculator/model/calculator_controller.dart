import 'package:flutter/foundation.dart';

import '../../../entities/calculation/calculation_record.dart';
import '../../../shared/services/firestore_service.dart';
import '../../currency/domain/currency_service.dart';
import '../domain/calculator_engine.dart';
import '../domain/fx_money_parser.dart';
import '../domain/gemini_calc_service.dart';

class CalculatorController extends ChangeNotifier {
  CalculatorController({
    FirestoreService? firestore,
    GeminiCalcService? gemini,
    CurrencyService? currency,
  })  : _firestore = firestore,
        _gemini = gemini ?? GeminiCalcService(),
        _currency = currency ?? CurrencyService(),
        _engine = CalculatorEngine();

  final FirestoreService? _firestore;
  final GeminiCalcService _gemini;
  final CurrencyService _currency;
  final CalculatorEngine _engine;
  final List<CalculationRecord> _history = [];
  bool _saving = false;
  bool _aiBusy = false;
  String? _aiNote;
  String? _lastError;

  String get display => _engine.display;
  String get expression => _engine.expression;
  bool get hasError => _engine.hasError;
  List<CalculationRecord> get history => List.unmodifiable(_history);
  bool get saving => _saving;
  bool get aiBusy => _aiBusy;
  String? get aiNote => _aiNote;
  String? get lastError => _lastError;

  void clear() {
    _engine.clear();
    _aiNote = null;
    _lastError = null;
    notifyListeners();
  }

  /// Clear on-screen calculation history only (does not touch Firestore).
  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
  }

  void input(String token) {
    _engine.input(token);
    _aiNote = null;
    _lastError = null;
    if (token == '=' || token == '＝') {
      _persist(_engine.expression, _engine.display, source: 'manual');
    }
    notifyListeners();
  }

  /// Natural language / voice transcript → Gemini (local parse optional).
  Future<bool> applyNaturalLanguage(
    String utterance, {
    bool preferAi = false,
    String sourceHint = 'voice',
  }) async {
    final text = utterance.trim();
    if (text.isEmpty) return false;

    _aiBusy = true;
    _aiNote = null;
    _lastError = null;
    notifyListeners();

    try {
      // 1) Foreign currency → KRW (with rate footnotes).
      final fx = await FxMoneyParser.tryParse(text, currency: _currency);
      if (fx != null) {
        final label = fx.breakdown.isNotEmpty
            ? '${fx.breakdown.join(' + ')} = ${fx.krwTotal}원'
            : text;
        _engine.setResult(expression: label, result: fx.krwTotal);
        _aiNote = [
          if (fx.breakdown.isNotEmpty) fx.breakdown.join(' · '),
          fx.rateNoteText,
        ].where((s) => s.trim().isNotEmpty).join('\n');
        await _persist(label, fx.krwTotal, source: 'fx');
        return true;
      }

      // 2) Fast local KRW parse (skip when preferAi and no simple local hit needed).
      if (!preferAi) {
        final local = KoreanMathParser.tryParse(text);
        if (local != null) {
          _engine.setResult(expression: text, result: local);
          _aiNote = '로컬 파서로 계산했습니다';
          await _persist(text, local, source: 'local');
          return true;
        }
      } else {
        // Voice: still try local KRW before Gemini for speed.
        final local = KoreanMathParser.tryParse(text);
        if (local != null && !FxMoneyParser.mentionsForeignCurrency(text)) {
          _engine.setResult(expression: text, result: local);
          _aiNote = '로컬 파서로 계산했습니다';
          await _persist(text, local, source: 'local');
          return true;
        }
      }

      // 3) Gemini — inject today's FX rates when foreign currency is mentioned.
      final prompt = await FxMoneyParser.rewriteToKrwPrompt(
        text,
        currency: _currency,
      );
      final ai = await _gemini.calculate(prompt);
      if (ai != null) {
        _applyAi(ai, fallbackExpression: text);
        if (FxMoneyParser.mentionsForeignCurrency(text)) {
          final snap = await _currency.snapshot();
          final notes = <String>[];
          for (final code in CurrencyService.foreignCodes) {
            if (RegExp(_fxMentionRe(code)).hasMatch(text)) {
              final rate = snap.rates[code];
              if (rate != null) {
                notes.add(
                  CurrencyService.rateAppliedMessage(
                    code,
                    rate,
                    label: snap.label,
                  ),
                );
              }
            }
          }
          if (notes.isNotEmpty) {
            _aiNote = [
              if (_aiNote != null && _aiNote!.isNotEmpty) _aiNote!,
              ...notes,
            ].join('\n');
          }
        }
        await _persist(
          ai.expression.isNotEmpty ? ai.expression : text,
          ai.result,
          source: sourceHint.isNotEmpty ? sourceHint : ai.source,
        );
        return true;
      }

      _engine.setExpression(text);
      _lastError =
          'AI 계산에 실패했습니다. Gemini API 키(.env의 GEMINI_API_KEY)를 확인하거나 잠시 후 다시 시도해 주세요.';
      return false;
    } catch (e, st) {
      debugPrint('applyNaturalLanguage: $e\n$st');
      _engine.setExpression(text);
      _lastError = '계산 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _aiBusy = false;
      notifyListeners();
    }
  }

  String _fxMentionRe(String code) {
    return switch (code) {
      'USD' => r'미국\s*달러|달러|USD|불',
      'JPY' => r'일본\s*엔|엔화|\d\s*엔|만\s*엔|JPY',
      'SGD' => r'싱가포르\s*달러|싱가폴\s*달러|SGD',
      'CNY' => r'중국\s*위안|위안화|위안|인민폐|CNY',
      'EUR' => r'유럽\s*유로|유로|EUR',
      'GBP' => r'영국\s*파운드|파운드|GBP',
      'FRF' => r'프랑스\s*프랑|프랑|FRF',
      'TWD' => r'대만\s*달러|TWD',
      'CAD' => r'캐나다\s*달러|CAD',
      'AUD' => r'호주\s*달러|AUD',
      _ => code,
    };
  }

  /// Image / PDF / Office / text file → Gemini Vision or text extract + Gemini.
  Future<bool> applyFromFile({
    required Uint8List bytes,
    required String fileName,
    String? extension,
    String? userHint,
  }) async {
    _aiBusy = true;
    _aiNote = null;
    _lastError = null;
    notifyListeners();

    try {
      final ai = await _gemini.calculateFromFile(
        bytes: bytes,
        fileName: fileName,
        extension: extension,
        userHint: userHint,
      );
      if (ai != null) {
        final preview = (ai.extractedText ?? userHint ?? fileName).trim();
        _applyAi(ai, fallbackExpression: fileName);
        if (preview.isNotEmpty && (ai.extractedText?.isNotEmpty ?? false)) {
          _aiNote = [
            if (ai.explanation.isNotEmpty) ai.explanation,
            '파일 요약: ${preview.length > 160 ? '${preview.substring(0, 160)}…' : preview}',
          ].where((s) => s.isNotEmpty).join('\n');
        }
        await _persist(
          ai.expression.isNotEmpty ? ai.expression : fileName,
          ai.result,
          source: ai.source,
        );
        return true;
      }

      _lastError = '파일 분석·계산에 실패했습니다. 다시 시도해 주세요.';
      return false;
    } catch (e, st) {
      debugPrint('applyFromFile: $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _aiBusy = false;
      notifyListeners();
    }
  }

  void _applyAi(
    GeminiCalcResult ai, {
    required String fallbackExpression,
  }) {
    final label = ai.summary.isNotEmpty
        ? '${ai.summary} = ${ai.result}'
        : '${ai.expression.isNotEmpty ? ai.expression : fallbackExpression} = ${ai.result}';
    _engine.setResult(expression: label, result: ai.result);
    _aiNote = ai.explanation.isNotEmpty
        ? ai.explanation
        : (ai.steps.isNotEmpty ? ai.steps.join(' · ') : null);
  }

  Future<void> _persist(
    String expression,
    String result, {
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
    _saving = true;
    notifyListeners();
    try {
      await fs.create(
        collectionPath: 'calculations',
        data: record.toMap(),
      );
    } catch (e) {
      debugPrint('Failed to save calculation: $e');
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    final fs = _firestore;
    if (fs == null) return;
    try {
      final rows = await fs.list(collectionPath: 'calculations', limit: 50);
      _history
        ..clear()
        ..addAll(rows.map(CalculationRecord.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('loadHistory: $e');
    }
  }

  @override
  void dispose() {
    _gemini.dispose();
    _currency.dispose();
    super.dispose();
  }
}
