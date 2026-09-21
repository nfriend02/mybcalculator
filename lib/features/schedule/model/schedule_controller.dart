import 'package:flutter/foundation.dart';

import '../../../entities/schedule/schedule_item.dart';
import '../../../shared/services/firestore_service.dart';
import '../../calculator/domain/gemini_calc_service.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController({
    FirestoreService? firestore,
    GeminiCalcService? gemini,
  })  : _firestore = firestore,
        _gemini = gemini ?? GeminiCalcService();

  final FirestoreService? _firestore;
  final GeminiCalcService _gemini;
  final List<ScheduleItem> _items = [];
  bool _busy = false;
  String? _note;
  String? _lastError;

  List<ScheduleItem> get items => List.unmodifiable(_items);
  bool get busy => _busy;
  String? get note => _note;
  String? get lastError => _lastError;

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

  /// NL: "내일 오후 3시 회의", "오늘 저녁 회식" …
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
        _note = '"${local.$1}" 일정을 추가했습니다.';
        return true;
      }

      final ai = await _gemini.calculate(
        '일정 추가. JSON result는 "제목|ISO8601일시" 한 줄만.\n'
        '지금: ${DateTime.now().toIso8601String()}\n\n$text',
        requireNumericResult: false,
      );
      if (ai != null) {
        final parsed = _parseAiResult(ai.result, ai.expression, text);
        if (parsed != null) {
          await add(parsed.$1, parsed.$2);
          _note = ai.explanation.isNotEmpty
              ? ai.explanation
              : '"${parsed.$1}" 일정을 추가했습니다.';
          return true;
        }
      }

      // Fallback: whole text as title, +1 hour.
      await add(text, DateTime.now().add(const Duration(hours: 1)));
      _note = '제목만으로 일정을 추가했습니다 (1시간 후).';
      return true;
    } catch (e, st) {
      debugPrint('schedule NL: $e\n$st');
      _lastError = '일정 추가 중 오류가 발생했습니다.';
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
            '${userHint ?? ''}\n파일의 일정/미팅을 찾아 result에 "제목|ISO8601" 형식으로.',
        requireNumericResult: false,
      );
      if (ai == null) {
        _lastError = '파일에서 일정을 찾지 못했습니다.';
        return false;
      }
      final parsed = _parseAiResult(ai.result, ai.expression, fileName);
      if (parsed == null) {
        _lastError = '파일에서 일정 제목을 찾지 못했습니다.';
        return false;
      }
      await add(parsed.$1, parsed.$2);
      _note = ai.explanation.isNotEmpty
          ? ai.explanation
          : '$fileName에서 "${parsed.$1}" 일정을 추가했습니다.';
      return true;
    } catch (e, st) {
      debugPrint('schedule file: $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Returns null when there is no clear schedule signal — let Gemini handle.
  static (String, DateTime)? _parseLocal(String text) {
    final hasTimeSignal = RegExp(
      r'내일|모레|오늘|오전|오후|아침|저녁|밤|\d{1,2}\s*시|am|pm',
      caseSensitive: false,
    ).hasMatch(text);
    final hasIntent = RegExp(r'일정|회의|미팅|약속|스케줄|등록|추가').hasMatch(text);
    if (!hasTimeSignal && !hasIntent) return null;

    final now = DateTime.now();
    var when = now.add(const Duration(hours: 1));
    var title = text;

    if (text.contains('내일')) {
      when = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1, hours: 9));
      title = text.replaceAll('내일', '').trim();
    } else if (text.contains('모레')) {
      when = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 2, hours: 9));
      title = text.replaceAll('모레', '').trim();
    } else if (text.contains('오늘')) {
      when = DateTime(now.year, now.month, now.day, now.hour + 1);
      title = text.replaceAll('오늘', '').trim();
    }

    final ampm = RegExp(
      r'(오전|오후|am|pm)?\s*(\d{1,2})\s*시\s*(\d{1,2})?\s*분?',
      caseSensitive: false,
    ).firstMatch(text);
    if (ampm != null) {
      var hour = int.parse(ampm.group(2)!);
      final minute = int.tryParse(ampm.group(3) ?? '') ?? 0;
      final period = (ampm.group(1) ?? '').toLowerCase();
      if (period.contains('오후') || period == 'pm') {
        if (hour < 12) hour += 12;
      } else if (period.contains('오전') || period == 'am') {
        if (hour == 12) hour = 0;
      }
      when = DateTime(when.year, when.month, when.day, hour, minute);
      title = title.replaceAll(ampm.group(0)!, '').trim();
    }

    title = title
        .replaceAll(RegExp(r'일정|추가|등록|잡아|넣어|해줘|해주세요|미팅|회의|약속'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) title = text;
    return (title, when);
  }

  static (String, DateTime)? _parseAiResult(
    String result,
    String expression,
    String fallbackTitle,
  ) {
    final raw = result.contains('|') ? result : expression;
    final parts = raw.split('|');
    if (parts.length >= 2) {
      final title = parts[0].trim();
      final when = DateTime.tryParse(parts[1].trim());
      if (title.isNotEmpty && when != null) return (title, when);
    }
    final iso = DateTime.tryParse(result.trim());
    if (iso != null) {
      return (fallbackTitle, iso);
    }
    if (result.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(result.trim())) {
      return (
        result.trim(),
        DateTime.now().add(const Duration(hours: 1)),
      );
    }
    return null;
  }

  @override
  void dispose() {
    _gemini.dispose();
    super.dispose();
  }
}
