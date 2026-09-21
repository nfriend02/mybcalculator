import '../schedule/schedule_item.dart' show parseFirestoreDate;

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.createdAt,
    this.category = 'general',
    this.status = 'active',
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'category': category,
        'status': status,
      };

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    return ExpenseRecord(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: map['category'] as String? ?? 'general',
      status: map['status'] as String? ?? 'active',
      createdAt: parseFirestoreDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}
