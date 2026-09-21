import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.when,
    this.note = '',
    this.status = 'active',
  });

  final String id;
  final String title;
  final DateTime when;
  final String note;
  final String status;

  Map<String, dynamic> toMap() => {
        'title': title,
        'when': when.toIso8601String(),
        'note': note,
        'status': status,
      };

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      when: parseFirestoreDate(map['when']) ?? DateTime.now(),
      note: map['note'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }
}

DateTime? parseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
