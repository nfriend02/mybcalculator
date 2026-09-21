import 'package:flutter/foundation.dart';

import '../../../entities/expense/expense_record.dart';
import '../../../shared/services/firestore_service.dart';

class ExpenseController extends ChangeNotifier {
  ExpenseController({this._firestore});

  final FirestoreService? _firestore;
  final List<ExpenseRecord> _items = [];

  List<ExpenseRecord> get items => List.unmodifiable(_items);
  double get total => _items.fold(0, (s, e) => s + e.amount);

  Future<void> load() async {
    final fs = _firestore;
    if (fs == null) return;
    try {
      final rows = await fs.list(collectionPath: 'expenses', limit: 50);
      _items
        ..clear()
        ..addAll(rows.map(ExpenseRecord.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('Expense load: $e');
    }
  }

  Future<void> add(String title, double amount, {String category = 'general'}) async {
    final item = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      category: category,
      createdAt: DateTime.now(),
    );
    _items.insert(0, item);
    notifyListeners();
    final fs = _firestore;
    if (fs == null) return;
    try {
      await fs.create(collectionPath: 'expenses', data: item.toMap());
    } catch (e) {
      debugPrint('Expense add: $e');
    }
  }
}
