import 'dart:async';

import 'package:flutter/foundation.dart';

class AlarmTimerController extends ChangeNotifier {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _running = false;

  Duration get remaining => _remaining;
  bool get running => _running;

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
