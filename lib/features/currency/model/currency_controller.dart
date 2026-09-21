import 'package:flutter/foundation.dart';

import '../../../entities/calculation/calculation_record.dart';
import '../../../shared/services/firestore_service.dart';
import '../../calculator/domain/fx_money_parser.dart';
import '../../calculator/domain/gemini_calc_service.dart';
import '../domain/currency_service.dart';

/// FX workspace state — NL / manual convert + history (currency tab).
class CurrencyController extends ChangeNotifier {
  CurrencyController({
    FirestoreService? firestore,
    GeminiCalcService? gemini,
    CurrencyService? currency,
  })  : _firestore = firestore,
        _gemini = gemini ?? GeminiCalcService(),
        _currency = currency ?? CurrencyService();

  final FirestoreService? _firestore;
  final GeminiCalcService _gemini;
  final CurrencyService _currency;

  final List<CalculationRecord> _history = [];

  String _fromCode = 'KRW';
  String _toCode = 'USD';
  String _amountText = '100';
  String _expression = '';
  String _resultDisplay = '0';
  String _outputAmount = '';
  String? _rateNote;
  String? _aiNote;
  String? _lastError;
  bool _busy = false;
  bool _converting = false;

  List<CalculationRecord> get history => List.unmodifiable(_history);
  String get fromCode => _fromCode;
  String get toCode => _toCode;
  String get amountText => _amountText;
  String get expression => _expression;
  String get resultDisplay => _resultDisplay;
  String get outputAmount => _outputAmount;
  String? get rateNote => _rateNote;
  String? get aiNote => _aiNote;
  String? get lastError => _lastError;
  bool get busy => _busy;
  bool get converting => _converting;

  CurrencyService get service => _currency;

  void setAmountText(String value) {
    _amountText = value;
    notifyListeners();
  }

  void setFromCode(String code) {
    final next = code.toUpperCase();
    if (next == _fromCode) return;
    _fromCode = next;
    if (_fromCode == _toCode) {
      _toCode = _fromCode == 'KRW' ? 'USD' : 'KRW';
    } else if (_fromCode != 'KRW' && _toCode != 'KRW') {
      // Prefer foreign → KRW when picking a foreign source.
      _toCode = 'KRW';
    }
    notifyListeners();
    convertManual(addHistory: false);
  }

  void setToCode(String code) {
    final next = code.toUpperCase();
    if (next == _toCode) return;
    _toCode = next;
    if (_toCode == _fromCode) {
      _fromCode = _toCode == 'KRW' ? 'USD' : 'KRW';
    }
    notifyListeners();
    convertManual(addHistory: false);
  }

  Future<void> convertManual({bool addHistory = true}) async {
    final amount = _parseAmount(_amountText);
    if (amount == null) {
      _lastError = '금액을 숫자로 입력해 주세요.';
      notifyListeners();
      return;
    }

    _converting = true;
    _lastError = null;
    notifyListeners();

    try {
      final snap = await _currency.snapshot();
      final converted = await _currency.convert(
        amount: amount,
        from: _fromCode,
        to: _toCode,
      );
      final fromLabel = CurrencyService.labelOf(_fromCode);
      final toLabel = CurrencyService.labelOf(_toCode);
      final fromPretty = _fmt(amount, code: _fromCode);
      final toPretty = _fmt(converted, code: _toCode);

      _expression = '$fromPretty $fromLabel → $toLabel';
      _resultDisplay = toPretty;
      _outputAmount = toPretty;
      _rateNote = _buildRateNote(snap, _fromCode, _toCode);
      _aiNote = _rateNote;

      if (addHistory) {
        await _persist(
          _expression,
          '$toPretty ${CurrencyService.unitOf(_toCode)}',
          source: 'currency',
        );
      }
    } catch (e, st) {
      debugPrint('convertManual: $e\n$st');
      _lastError = '환율 변환에 실패했습니다. 잠시 후 다시 시도해 주세요.';
    } finally {
      _converting = false;
      notifyListeners();
    }
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
      // 1) Local FX parse (foreign amounts → KRW).
      final fx = await FxMoneyParser.tryParse(text, currency: _currency);
      if (fx != null) {
        _fromCode = fx.usedCodes.length == 1 ? fx.usedCodes.first : _fromCode;
        if (_fromCode != 'KRW') _toCode = 'KRW';
        _expression = fx.breakdown.isNotEmpty
            ? fx.breakdown.join(' + ')
            : text;
        _resultDisplay = fx.krwTotal;
        _outputAmount = fx.krwTotal;
        // Keep input amount as original FX amount when a single code was used.
        if (fx.usedCodes.length == 1) {
          final code = fx.usedCodes.first;
          final hit = RegExp(
            r'(\d+(?:\.\d+)?)',
          ).firstMatch(text.replaceAll(',', ''));
          if (hit != null) _amountText = hit.group(1)!;
          _fromCode = code;
          _toCode = 'KRW';
        } else {
          _fromCode = 'KRW';
          _amountText = fx.krwTotal;
        }
        _rateNote = fx.rateNoteText;
        _aiNote = [
          if (fx.breakdown.isNotEmpty) fx.breakdown.join(' · '),
          fx.rateNoteText,
        ].where((s) => s.trim().isNotEmpty).join('\n');
        await _persist(_expression, '${fx.krwTotal}원', source: 'currency_nl');
        return true;
      }

      // 2) Gemini with live FX table injected.
      final prompt = await FxMoneyParser.rewriteToKrwPrompt(
        text,
        currency: _currency,
      );
      final fxPrompt = StringBuffer()
        ..writeln(prompt)
        ..writeln()
        ..writeln(
          '이 질문은 환율 환산입니다. 외화↔원화 양방향을 지원합니다. '
          'result는 최종 금액 숫자만, explanation에 적용 환율을 적으세요.',
        );
      final ai = await _gemini.calculate(fxPrompt.toString());
      if (ai != null) {
        _expression =
            ai.expression.isNotEmpty ? ai.expression : text;
        _resultDisplay = ai.result;
        _outputAmount = ai.result;
        _aiNote = ai.explanation.isNotEmpty
            ? ai.explanation
            : (ai.steps.isNotEmpty ? ai.steps.join(' · ') : null);
        await _persist(
          _expression,
          ai.result,
          source: sourceHint == 'voice' ? 'currency_voice' : 'currency_ai',
        );
        return true;
      }

      _lastError =
          'AI 환율 계산에 실패했습니다. API 키를 확인하거나 잠시 후 다시 시도해 주세요.';
      return false;
    } catch (e, st) {
      debugPrint('applyNaturalLanguage(fx): $e\n$st');
      _lastError = '환율 계산 중 오류가 발생했습니다: $e';
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
        ..writeln('환율·외화·원화 환산이 필요하면 적용 환율을 explanation에 포함하세요.');
      final ai = await _gemini.calculateFromFile(
        bytes: bytes,
        fileName: fileName,
        extension: extension,
        userHint: hint.toString().trim(),
      );
      if (ai != null) {
        _expression =
            ai.expression.isNotEmpty ? ai.expression : fileName;
        _resultDisplay = ai.result;
        _outputAmount = ai.result;
        _aiNote = ai.explanation.isNotEmpty
            ? ai.explanation
            : '파일 분석 완료';
        await _persist(_expression, ai.result, source: 'currency_file');
        return true;
      }
      _lastError = '파일 분석·환율 계산에 실패했습니다. 다시 시도해 주세요.';
      return false;
    } catch (e, st) {
      debugPrint('applyFromFile(fx): $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
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
      final fxRows = rows
          .map(CalculationRecord.fromMap)
          .where((r) => r.source.startsWith('currency'))
          .toList();
      _history
        ..clear()
        ..addAll(fxRows);
      notifyListeners();
    } catch (e) {
      debugPrint('loadHistory(fx): $e');
    }
  }

  String? _buildRateNote(FxRateSnapshot snap, String from, String to) {
    final notes = <String>[];
    for (final code in {from, to}) {
      if (code == 'KRW') continue;
      final rate = snap.rates[code];
      if (rate == null) continue;
      notes.add(
        CurrencyService.rateAppliedMessage(code, rate, label: snap.label),
      );
    }
    if (notes.isEmpty) return '${snap.label} 기준';
    return notes.join('\n');
  }

  static double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static String _fmt(double n, {required String code}) {
    final isKrw = code == 'KRW';
    final isYenLike = code == 'JPY' || code == 'KRW';
    if (isYenLike || (isKrw && n.abs() >= 1)) {
      final i = n.round();
      return i.toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          );
    }
    if (n.abs() >= 100) {
      return n.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          );
    }
    return n.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
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
    try {
      await fs.create(collectionPath: 'calculations', data: record.toMap());
    } catch (e) {
      debugPrint('Failed to save fx calculation: $e');
    }
  }

  @override
  void dispose() {
    _gemini.dispose();
    _currency.dispose();
    super.dispose();
  }
}
