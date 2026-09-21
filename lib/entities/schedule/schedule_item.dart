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
      when: DateTime.tryParse(map['when'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }
}
