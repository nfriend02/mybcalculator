import 'package:flutter/foundation.dart';

import '../../../entities/expense/expense_record.dart';
import '../../../shared/services/firestore_service.dart';
import '../../calculator/domain/calculator_engine.dart';
import '../../calculator/domain/gemini_calc_service.dart';

class ExpenseController extends ChangeNotifier {
  ExpenseController({
    FirestoreService? firestore,
    GeminiCalcService? gemini,
  })  : _firestore = firestore,
        _gemini = gemini ?? GeminiCalcService();

  final FirestoreService? _firestore;
  final GeminiCalcService _gemini;
  final List<ExpenseRecord> _items = [];
  bool _busy = false;
  String? _note;
  String? _lastError;
  int _loadToken = 0;

  List<ExpenseRecord> get items => List.unmodifiable(_items);
  double get total => _items.fold(0, (s, e) => s + e.amount);
  bool get busy => _busy;
  String? get note => _note;
  String? get lastError => _lastError;

  Future<void> load() async {
    final fs = _firestore;
    if (fs == null) return;
    final token = ++_loadToken;
    try {
      final rows = await fs.list(collectionPath: 'expenses', limit: 50);
      if (token != _loadToken) return;
      final remote = rows.map(ExpenseRecord.fromMap).toList();
      final remoteIds = remote.map((e) => e.id).toSet();
      final pendingLocal =
          _items.where((e) => e.id.isNotEmpty && !remoteIds.contains(e.id));
      _items
        ..clear()
        ..addAll(pendingLocal)
        ..addAll(remote);
      notifyListeners();
    } catch (e) {
      debugPrint('Expense load: $e');
    }
  }

  Future<void> add(
    String title,
    double amount, {
    String category = 'general',
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || amount <= 0) return;
    _loadToken++;
    final item = ExpenseRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_items.length}',
      title: trimmed,
      amount: amount,
      category: category,
      createdAt: DateTime.now(),
    );
    _items.insert(0, item);
    _lastError = null;
    notifyListeners();
    final fs = _firestore;
    if (fs == null) return;
    try {
      await fs.create(
        collectionPath: 'expenses',
        data: item.toMap(),
        docId: item.id,
      );
    } catch (e) {
      debugPrint('Expense add: $e');
      _lastError =
          '로컬에는 저장됐지만 Firebase 동기화에 실패했습니다. Firestore 규칙/DB를 확인하세요.';
      notifyListeners();
    }
  }

  Future<void> removeByIds(Iterable<String> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    _items.removeWhere((e) => idSet.contains(e.id));
    notifyListeners();
    final fs = _firestore;
    if (fs == null) return;
    for (final id in idSet) {
      try {
        await fs.softDelete(collectionPath: 'expenses', docId: id);
      } catch (e) {
        debugPrint('Expense remove $id: $e');
      }
    }
  }

  /// NL: "커피 4500원", "점심에 만이천원 썼어" …
  Future<bool> applyNaturalLanguage(String utterance) async {
    final text = utterance.trim();
    if (text.isEmpty) return false;

    _busy = true;
    _note = null;
    _lastError = null;
    notifyListeners();

    try {
      final local = _parseLocal(text);
      if (local != null) {
        await add(local.$1, local.$2);
        _note =
            '${local.$1} ₩${local.$2.toStringAsFixed(0)} 지출을 기록했습니다.';
        return true;
      }

      final ai = await _gemini.calculate(
        '지출 기록. result는 "항목|금액숫자" 한 줄만 (콤마 없이).\n'
        '만이천=12000, 오천=5000.\n\n$text',
        requireNumericResult: false,
      );
      if (ai != null) {
        final parsed = _parseAi(ai.result, ai.expression, text);
        if (parsed != null) {
          await add(parsed.$1, parsed.$2);
          _note = ai.explanation.isNotEmpty
              ? ai.explanation
              : '${parsed.$1} ₩${parsed.$2.toStringAsFixed(0)} 기록.';
          return true;
        }
      }

      _lastError = '지출을 이해하지 못했어요. 예: "커피 4,500원"';
      return false;
    } catch (e, st) {
      debugPrint('expense NL: $e\n$st');
      _lastError = '지출 기록 중 오류가 발생했습니다.';
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
    _note = null;
    _lastError = null;
    notifyListeners();

    try {
      final ai = await _gemini.calculateFromFile(
        bytes: bytes,
        fileName: fileName,
        extension: extension,
        userHint:
            '${userHint ?? ''}\n영수증/내역에서 지출을 찾아 result에 "항목|금액" 형식.',
        requireNumericResult: false,
      );
      if (ai == null) {
        _lastError = '파일에서 지출을 찾지 못했습니다.';
        return false;
      }
      final parsed = _parseAi(ai.result, ai.expression, fileName);
      if (parsed == null) {
        _lastError = '파일에서 금액/항목을 찾지 못했습니다.';
        return false;
      }
      await add(parsed.$1, parsed.$2);
      _note = ai.explanation.isNotEmpty
          ? ai.explanation
          : '$fileName → ${parsed.$1} ₩${parsed.$2.toStringAsFixed(0)}';
      return true;
    } catch (e, st) {
      debugPrint('expense file: $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static (String, double)? _parseLocal(String text) {
    final cleaned = text.replaceAll(',', '');

    // Prefer full money token via KoreanMathParser (만이천원 → 12000).
    final moneyMatch = RegExp(
      r'([가-힣A-Za-z\s]+?)?\s*'
      r'((?:[일이삼사오육칠팔구십백천만억\d]+)\s*원|\d+(?:\.\d+)?\s*원?)',
    ).firstMatch(cleaned);
    if (moneyMatch != null) {
      final token = moneyMatch.group(2)!.replaceAll(RegExp(r'\s+'), '');
      final amount = KoreanMathParser.parseMoneyAmount(
            token.endsWith('원') ? token.replaceAll('원', '') : token,
          ) ??
          double.tryParse(token.replaceAll('원', ''));
      if (amount != null && amount > 0) {
        var title = (moneyMatch.group(1) ?? '').trim();
        title = title
            .replaceAll(RegExp(r'썼어|썼다|지출|결제|내역|기록|에'), '')
            .trim();
        if (title.isEmpty) {
          // "커피 만이천원" style — title before money
          final before = cleaned.substring(0, moneyMatch.start).trim();
          title = before
              .replaceAll(RegExp(r'썼어|썼다|지출|결제|에|을|를'), '')
              .trim();
        }
        if (title.isEmpty) title = '지출';
        return (title, amount);
      }
    }

    final titleFirst = RegExp(
      r'([가-힣A-Za-z\s]+?)\s*(\d+(?:\.\d+)?)\s*원?',
    ).firstMatch(cleaned);
    if (titleFirst != null) {
      final title = titleFirst
          .group(1)!
          .replaceAll(RegExp(r'썼어|썼다|지출|결제|에|을|를'), '')
          .trim();
      final amount = double.tryParse(titleFirst.group(2)!);
      if (title.isNotEmpty && amount != null && amount > 0) {
        return (title, amount);
      }
    }
    return null;
  }

  static (String, double)? _parseAi(
    String result,
    String expression,
    String fallbackTitle,
  ) {
    final raw = result.contains('|') ? result : expression;
    final parts = raw.split('|');
    if (parts.length >= 2) {
      final title = parts[0].trim();
      final amount = double.tryParse(
        parts[1].replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      if (title.isNotEmpty && amount != null && amount > 0) {
        return (title, amount);
      }
    }
    final amountOnly = double.tryParse(
      result.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    if (amountOnly != null && amountOnly > 0) {
      return (fallbackTitle, amountOnly);
    }
    return null;
  }

  @override
  void dispose() {
    _gemini.dispose();
    super.dispose();
  }
}
