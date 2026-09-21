import 'package:flutter_test/flutter_test.dart';
import 'package:mybcalculator/features/expense/model/expense_controller.dart';
import 'package:mybcalculator/features/schedule/model/schedule_controller.dart';

void main() {
  group('ScheduleController', () {
    test('add inserts item locally without firestore', () async {
      final c = ScheduleController(firestore: null);
      await c.add('팀 회의', DateTime(2026, 9, 22, 15));
      expect(c.items, hasLength(1));
      expect(c.items.first.title, '팀 회의');
    });

    test('removeByIds deletes selected items', () async {
      final c = ScheduleController(firestore: null);
      await c.add('A', DateTime.now());
      await c.add('B', DateTime.now());
      final id = c.items.first.id;
      await c.removeByIds([id]);
      expect(c.items, hasLength(1));
      expect(c.items.first.title, 'A');
    });

    test('NL adds schedule immediately', () async {
      final c = ScheduleController(firestore: null);
      final ok = await c.applyNaturalLanguage('내일 오후 3시 팀 회의');
      expect(ok, isTrue);
      expect(c.items, isNotEmpty);
    });
  });

  group('ExpenseController', () {
    test('add inserts item locally without firestore', () async {
      final c = ExpenseController(firestore: null);
      await c.add('커피', 4500);
      expect(c.items, hasLength(1));
      expect(c.total, 4500);
    });

    test('removeByIds deletes selected items', () async {
      final c = ExpenseController(firestore: null);
      await c.add('커피', 4500);
      await c.add('점심', 12000);
      final id = c.items.first.id;
      await c.removeByIds([id]);
      expect(c.items, hasLength(1));
      expect(c.total, 4500);
    });

    test('NL parses amount with comma', () async {
      final c = ExpenseController(firestore: null);
      final ok = await c.applyNaturalLanguage('커피 4,500원 썼어');
      expect(ok, isTrue);
      expect(c.items.first.amount, 4500);
    });
  });
}
