import 'package:flutter/foundation.dart';

import '../../../entities/calculation/calculation_record.dart';
import '../../../shared/services/firestore_service.dart';
import '../../calculator/domain/gemini_calc_service.dart';
import '../domain/unit_converter.dart';

/// Unit converter workspace — NL + manual convert + history.
class UnitController extends ChangeNotifier {
  UnitController({
    FirestoreService? firestore,
    GeminiCalcService? gemini,
  })  : _firestore = firestore,
        _gemini = gemini ?? GeminiCalcService();

  final FirestoreService? _firestore;
  final GeminiCalcService _gemini;

  final List<CalculationRecord> _history = [];

  String _mode = 'length';
  String _from = 'ft';
  String _to = 'm';
  String _amountText = '100';
  String _expression = '';
  String _resultDisplay = '—';
  String? _aiNote;
  String? _lastError;
  bool _busy = false;
  bool _converting = false;

  List<CalculationRecord> get history => List.unmodifiable(_history);
  String get mode => _mode;
  String get from => _from;
  String get to => _to;
  String get amountText => _amountText;
  String get expression => _expression;
  String get resultDisplay => _resultDisplay;
  String? get aiNote => _aiNote;
  String? get lastError => _lastError;
  bool get busy => _busy;
  bool get converting => _converting;

  List<String> get units => UnitConverter.unitsFor(_mode);

  void setAmountText(String value) {
    _amountText = value;
    notifyListeners();
  }

  void setMode(String mode) {
    if (mode == _mode) return;
    _mode = mode;
    final u = UnitConverter.unitsFor(mode);
    _from = u.first;
    _to = u.length > 1 ? u[1] : u.first;
    notifyListeners();
    convertManual(addHistory: false);
  }

  void setFrom(String unit) {
    final next = UnitConverter.canonicalize(unit);
    if (next == _from) return;
    _from = next;
    if (_to == _from) {
      final u = units;
      _to = u.firstWhere((x) => x != _from, orElse: () => _from);
    }
    notifyListeners();
    convertManual(addHistory: false);
  }

  void setTo(String unit) {
    final next = UnitConverter.canonicalize(unit);
    if (next == _to) return;
    _to = next;
    if (_from == _to) {
      final u = units;
      _from = u.firstWhere((x) => x != _to, orElse: () => _to);
    }
    notifyListeners();
    convertManual(addHistory: false);
  }

  Future<void> convertManual({bool addHistory = true}) async {
    final amount = double.tryParse(_amountText.replaceAll(',', '').trim());
    if (amount == null) {
      _lastError = '숫자를 입력해 주세요.';
      notifyListeners();
      return;
    }

    _converting = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = UnitConverter.convert(
        value: amount,
        from: _from,
        to: _to,
      );
      final pretty = UnitConverter.formatResult(result);
      _expression =
          '${UnitConverter.formatResult(amount)} ${UnitConverter.labelOf(_from)} → ${UnitConverter.labelOf(_to)}';
      _resultDisplay = '$pretty ${UnitConverter.labelOf(_to)}';
      _aiNote = _expression;
      _mode = UnitConverter.categoryOf(_from);

      if (addHistory) {
        await _persist(
          expression: _expression,
          result: _resultDisplay,
          source: 'unit',
        );
      }
    } catch (e, st) {
      debugPrint('convertManual(unit): $e\n$st');
      _lastError = '단위 변환에 실패했습니다.';
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
      final local = UnitConverter.tryParse(text);
      if (local != null) {
        _applyParsed(local);
        await _persist(
          expression: local.expression,
          result: local.resultText,
          source: sourceHint == 'voice' ? 'unit_voice' : 'unit_nl',
        );
        _aiNote = '로컬 단위 변환기로 계산했습니다.';
        return true;
      }

      // Gemini: ask for structured conversion, then verify locally if possible.
      final ai = await _gemini.calculate(
        '단위 변환만 수행하세요. JSON의 expression은 '
        '"<숫자> <from단위> → <to단위>" 형태, result는 최종 숫자만.\n'
        '지원: mm cm m km in ft yd mi / mg g kg t oz lb / '
        'ml L gal qt cup fl_oz / C F\n\n$text',
      );
      if (ai != null) {
        final retry = UnitConverter.tryParse(
          '${ai.expression} = ${ai.result}',
        );
        if (retry != null) {
          _applyParsed(retry);
          await _persist(
            expression: retry.expression,
            result: retry.resultText,
            source: 'unit_ai',
          );
          _aiNote = ai.explanation.isNotEmpty
              ? ai.explanation
              : 'AI로 단위를 해석한 뒤 변환했습니다.';
          return true;
        }

        _expression =
            ai.expression.isNotEmpty ? ai.expression : text;
        _resultDisplay = ai.result;
        _aiNote = ai.explanation.isNotEmpty ? ai.explanation : null;
        await _persist(
          expression: _expression,
          result: ai.result,
          source: 'unit_ai',
        );
        return true;
      }

      _lastError =
          '단위를 이해하지 못했습니다. 예: "100 feet가 몇 m인가요?"';
      return false;
    } catch (e, st) {
      debugPrint('applyNaturalLanguage(unit): $e\n$st');
      _lastError = '단위 변환 중 오류가 발생했습니다: $e';
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
          '파일의 측정값·단위를 찾아 단위 변환하세요. '
          'expression은 "숫자 from → to", result는 숫자만.',
        );
      final ai = await _gemini.calculateFromFile(
        bytes: bytes,
        fileName: fileName,
        extension: extension,
        userHint: hint.toString().trim(),
      );
      if (ai == null) {
        _lastError = '파일에서 단위를 찾지 못했습니다.';
        return false;
      }

      final parsed = UnitConverter.tryParse(
        '${ai.expression} ${ai.result}',
      );
      if (parsed != null) {
        _applyParsed(parsed);
        _aiNote = ai.explanation.isNotEmpty
            ? ai.explanation
            : '$fileName에서 단위를 읽어 변환했습니다.';
        await _persist(
          expression: parsed.expression,
          result: parsed.resultText,
          source: 'unit_file',
        );
        return true;
      }

      _expression = ai.expression.isNotEmpty ? ai.expression : fileName;
      _resultDisplay = ai.result;
      _aiNote = ai.explanation;
      await _persist(
        expression: _expression,
        result: ai.result,
        source: 'unit_file',
      );
      return true;
    } catch (e, st) {
      debugPrint('applyFromFile(unit): $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _applyParsed(UnitParseResult parsed) {
    _mode = parsed.mode;
    _from = parsed.from;
    _to = parsed.to;
    _amountText = UnitConverter.formatResult(parsed.value);
    _expression = parsed.expression;
    _resultDisplay = parsed.resultText;
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
      final unitRows = rows
          .map(CalculationRecord.fromMap)
          .where((r) => r.source.startsWith('unit'))
          .toList();
      _history
        ..clear()
        ..addAll(unitRows);
      notifyListeners();
    } catch (e) {
      debugPrint('loadHistory(unit): $e');
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
      debugPrint('Failed to save unit conversion: $e');
    }
  }

  @override
  void dispose() {
    _gemini.dispose();
    super.dispose();
  }
}
