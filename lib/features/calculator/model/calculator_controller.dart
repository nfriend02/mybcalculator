import 'package:flutter/foundation.dart';

import '../../../entities/calculation/calculation_record.dart';
import '../../../shared/services/firestore_service.dart';
import '../domain/calculator_engine.dart';

class CalculatorController extends ChangeNotifier {
  CalculatorController({this._firestore}) : _engine = CalculatorEngine();

  final FirestoreService? _firestore;
  final CalculatorEngine _engine;
  final List<CalculationRecord> _history = [];
  bool _saving = false;

  String get display => _engine.display;
  String get expression => _engine.expression;
  List<CalculationRecord> get history => List.unmodifiable(_history);
  bool get saving => _saving;

  void clear() {
    _engine.clear();
    notifyListeners();
  }

  void input(String token) {
    _engine.input(token);
    if (token == '=' || token == '＝') {
      // Fire-and-forget persistence; never block UI on Firestore.
      _persist(_engine.expression, _engine.display, source: 'manual');
    }
    notifyListeners();
  }

  Future<void> applyNaturalLanguage(String utterance) async {
    final result = KoreanMathParser.tryParse(utterance);
    if (result == null) {
      _engine.setExpression(utterance);
      notifyListeners();
      return;
    }
    _engine.setExpression('$utterance = $result');
    await _persist(utterance, result, source: 'voice');
    notifyListeners();
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
}
