import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../calculator/domain/calculator_engine.dart';

enum VoiceIntent { calculate, currency, weather, money, unknown }

class VoiceParseResult {
  const VoiceParseResult({
    required this.intent,
    required this.raw,
    this.answer,
    this.city,
    this.amount,
    this.fromCurrency,
  });

  final VoiceIntent intent;
  final String raw;
  final String? answer;
  final String? city;
  final double? amount;
  final String? fromCurrency;
}

class VoiceRecognitionService {
  SpeechToText? _speech;
  bool _ready = false;
  bool _failed = false;

  bool get isAvailable => _ready;

  Future<bool> init() async {
    if (_failed) return false;
    if (_ready) return true;
    try {
      _speech ??= SpeechToText();
      _ready = await _speech!.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) => debugPrint('STT status: $s'),
      );
      if (!_ready) _failed = true;
      return _ready;
    } catch (e, st) {
      debugPrint('STT init failed: $e\n$st');
      _failed = true;
      return false;
    }
  }

  Future<String?> listenOnce({String localeId = 'ko_KR'}) async {
    if (kIsWeb) {
      // Web Speech API via speech_to_text is flaky; avoid blocking calculator UX.
      return null;
    }
    try {
      final ok = await init();
      if (!ok || _speech == null) return null;
      String? result;
      await _speech!.listen(
        onResult: (r) {
          if (r.finalResult) result = r.recognizedWords;
        },
        listenOptions: SpeechListenOptions(localeId: localeId),
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      await _speech!.stop();
      return result;
    } catch (e, st) {
      debugPrint('STT listen failed: $e\n$st');
      return null;
    }
  }

  VoiceParseResult parse(String utterance) {
    final t = utterance.trim();
    final lower = t.toLowerCase();

    if (lower.contains('날씨') || lower.contains('weather')) {
      final city =
          RegExp(r'([가-힣A-Za-z]+)(?:\s*날씨)').firstMatch(t)?.group(1) ?? '서울';
      return VoiceParseResult(intent: VoiceIntent.weather, raw: t, city: city);
    }

    if (lower.contains('달러') ||
        lower.contains('엔') ||
        lower.contains('유로') ||
        lower.contains('환율') ||
        lower.contains('한국돈')) {
      final amount = double.tryParse(
            RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t)?.group(1) ?? '',
          ) ??
          0;
      String? code;
      if (t.contains('달러') || lower.contains('usd')) code = 'USD';
      if (t.contains('엔') || lower.contains('jpy')) code = 'JPY';
      if (t.contains('유로') || lower.contains('eur')) code = 'EUR';
      return VoiceParseResult(
        intent: VoiceIntent.currency,
        raw: t,
        amount: amount,
        fromCurrency: code ?? 'USD',
      );
    }

    final calc = KoreanMathParser.tryParse(t);
    if (calc != null) {
      return VoiceParseResult(
        intent: VoiceIntent.calculate,
        raw: t,
        answer: calc,
      );
    }

    return VoiceParseResult(intent: VoiceIntent.unknown, raw: t);
  }
}
