import 'package:flutter/foundation.dart';

import '../../../entities/schedule/schedule_item.dart';
import '../../../shared/services/firestore_service.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController({this._firestore});

  final FirestoreService? _firestore;
  final List<ScheduleItem> _items = [];

  List<ScheduleItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final fs = _firestore;
    if (fs == null) return;
    try {
      final rows = await fs.list(collectionPath: 'schedules', limit: 50);
      _items
        ..clear()
        ..addAll(rows.map(ScheduleItem.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('Schedule load: $e');
    }
  }

  Future<void> add(String title, DateTime when, {String note = ''}) async {
    final item = ScheduleItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      when: when,
      note: note,
    );
    _items.insert(0, item);
    notifyListeners();
    final fs = _firestore;
    if (fs == null) return;
    try {
      await fs.create(collectionPath: 'schedules', data: item.toMap());
    } catch (e) {
      debugPrint('Schedule add: $e');
    }
  }
}
