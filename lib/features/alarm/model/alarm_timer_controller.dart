import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../calculator/domain/gemini_calc_service.dart';

class AlarmTimerController extends ChangeNotifier {
  AlarmTimerController({GeminiCalcService? gemini})
      : _gemini = gemini ?? GeminiCalcService();

  final GeminiCalcService _gemini;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _running = false;
  bool _busy = false;
  String? _note;
  String? _lastError;

  Duration get remaining => _remaining;
  bool get running => _running;
  bool get busy => _busy;
  String? get note => _note;
  String? get lastError => _lastError;

  String get label {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = _remaining.inHours.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void setMinutes(int minutes) {
    _timer?.cancel();
    _running = false;
    _remaining = Duration(minutes: minutes);
    notifyListeners();
  }

  void setDuration(Duration duration) {
    _timer?.cancel();
    _running = false;
    _remaining = duration;
    notifyListeners();
  }

  void start() {
    if (_remaining == Duration.zero) return;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 1) {
        _remaining = Duration.zero;
        _running = false;
        _timer?.cancel();
      } else {
        _remaining -= const Duration(seconds: 1);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _running = false;
    notifyListeners();
  }

  void reset() {
    pause();
    _remaining = Duration.zero;
    notifyListeners();
  }

  /// NL: "10분 타이머", "5분만 알람", "1시간 30분" …
  Future<bool> applyNaturalLanguage(String utterance, {bool autoStart = true}) async {
    final text = utterance.trim();
    if (text.isEmpty) return false;

    _busy = true;
    _note = null;
    _lastError = null;
    notifyListeners();

    try {
      final local = _parseDuration(text);
      if (local != null && local > Duration.zero) {
        setDuration(local);
        _note = '${_formatHuman(local)} 타이머로 설정했습니다.';
        if (autoStart) start();
        return true;
      }

      final ai = await _gemini.calculate(
        '알람/타이머 시간만 추출하세요. result는 총 초(숫자만). '
        '예: "10분" → 600, "1시간 30분" → 5400\n\n$text',
      );
      if (ai != null) {
        final seconds = int.tryParse(ai.result.replaceAll(RegExp(r'[^0-9]'), ''));
        if (seconds != null && seconds > 0) {
          setDuration(Duration(seconds: seconds));
          _note = ai.explanation.isNotEmpty
              ? ai.explanation
              : '${_formatHuman(Duration(seconds: seconds))} 타이머로 설정했습니다.';
          if (autoStart) start();
          return true;
        }
      }

      _lastError = '시간을 이해하지 못했어요. 예: "10분 타이머 맞춰줘"';
      return false;
    } catch (e, st) {
      debugPrint('alarm NL: $e\n$st');
      _lastError = '알람 설정 중 오류가 발생했습니다.';
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
            '${userHint ?? ''}\n파일에서 타이머/알람 시간을 찾아 result에 총 초(숫자만)를 넣으세요.',
      );
      if (ai == null) {
        _lastError = '파일에서 시간을 찾지 못했습니다.';
        return false;
      }
      final seconds = int.tryParse(ai.result.replaceAll(RegExp(r'[^0-9]'), ''));
      if (seconds == null || seconds <= 0) {
        _lastError = '파일에서 유효한 시간을 찾지 못했습니다.';
        return false;
      }
      setDuration(Duration(seconds: seconds));
      _note = ai.explanation.isNotEmpty
          ? ai.explanation
          : '$fileName → ${_formatHuman(Duration(seconds: seconds))}';
      start();
      return true;
    } catch (e, st) {
      debugPrint('alarm file: $e\n$st');
      _lastError = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static Duration? _parseDuration(String text) {
    final t = text.replaceAll(',', '').toLowerCase();
    var total = Duration.zero;
    var hit = false;

    final hour = RegExp(r'(\d+)\s*(시간|hours?|h)\b').firstMatch(t);
    if (hour != null) {
      total += Duration(hours: int.parse(hour.group(1)!));
      hit = true;
    }
    final min = RegExp(r'(\d+)\s*(분|minutes?|mins?|m)\b').firstMatch(t);
    if (min != null) {
      total += Duration(minutes: int.parse(min.group(1)!));
      hit = true;
    }
    final sec = RegExp(r'(\d+)\s*(초|seconds?|secs?|s)\b').firstMatch(t);
    if (sec != null) {
      total += Duration(seconds: int.parse(sec.group(1)!));
      hit = true;
    }

    // Bare number → minutes (e.g. "10" / "타이머 15")
    if (!hit) {
      final bare = RegExp(r'(?:타이머|알람|timer|alarm)?\s*(\d+)\s*$').firstMatch(t) ??
          RegExp(r'^(\d+)$').firstMatch(t.trim());
      if (bare != null) {
        total = Duration(minutes: int.parse(bare.group(1)!));
        hit = true;
      }
    }

    return hit ? total : null;
  }

  static String _formatHuman(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0 && m > 0) return '$h시간 $m분';
    if (h > 0) return '$h시간';
    if (m > 0 && s > 0) return '$m분 $s초';
    if (m > 0) return '$m분';
    return '$s초';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gemini.dispose();
    super.dispose();
  }
}
