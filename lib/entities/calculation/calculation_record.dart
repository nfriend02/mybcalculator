class CalculationRecord {
  const CalculationRecord({
    required this.id,
    required this.expression,
    required this.result,
    required this.createdAt,
    this.status = 'active',
    this.source = 'manual',
  });

  final String id;
  final String expression;
  final String result;
  final DateTime createdAt;
  final String status;
  final String source;

  Map<String, dynamic> toMap() => {
        'expression': expression,
        'result': result,
        'status': status,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CalculationRecord.fromMap(Map<String, dynamic> map) {
    return CalculationRecord(
      id: map['id'] as String? ?? '',
      expression: map['expression'] as String? ?? '',
      result: map['result'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      source: map['source'] as String? ?? 'manual',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
