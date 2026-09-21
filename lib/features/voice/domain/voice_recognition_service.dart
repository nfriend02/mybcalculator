import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../calculator/domain/calculator_engine.dart';
import 'stt_web_stub.dart' if (dart.library.html) 'stt_web.dart' as web_stt;

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

/// Browser / device speech-to-text → Korean text for Gemini calc.
class VoiceRecognitionService {
  SpeechToText? _speech;
  bool _ready = false;
  bool _failed = false;
  bool _listening = false;

  bool get isAvailable => kIsWeb ? true : _ready;
  bool get isListening => _listening;

  Future<bool> init() async {
    if (kIsWeb) return true;
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

  /// Capture one utterance (Korean). Chrome web uses native Web Speech API.
  Future<String?> listenOnce({
    String localeId = 'ko_KR',
    Duration listenFor = const Duration(seconds: 12),
    void Function(String partial)? onPartial,
  }) async {
    _listening = true;
    try {
      if (kIsWeb) {
        return await web_stt.webListenOnce(
          localeId: localeId.replaceAll('_', '-'),
          listenFor: listenFor,
          onPartial: onPartial,
        );
      }

      final ok = await init();
      if (!ok || _speech == null) return null;

      if (_speech!.isListening) {
        await _speech!.stop();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      final completer = Completer<String?>();
      var latest = '';

      await _speech!.listen(
        onResult: (r) {
          final words = r.recognizedWords.trim();
          if (words.isNotEmpty) {
            latest = words;
            onPartial?.call(latest);
          }
          if (r.finalResult && !completer.isCompleted) {
            completer.complete(latest.isEmpty ? null : latest);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );

      final result = await completer.future.timeout(
        listenFor + const Duration(seconds: 2),
        onTimeout: () => latest.isEmpty ? null : latest,
      );

      if (_speech!.isListening) {
        await _speech!.stop();
      }
      // Prefer last partial if "final" never arrived.
      if (result != null && result.isNotEmpty) return result;
      return latest.isEmpty ? null : latest;
    } catch (e, st) {
      debugPrint('STT listen failed: $e\n$st');
      try {
        await _speech?.stop();
      } catch (_) {}
      return null;
    } finally {
      _listening = false;
    }
  }

  Future<void> cancel({bool discardResult = true}) async {
    _listening = false;
    if (kIsWeb) {
      await web_stt.webStopListening(discardResult: discardResult);
      return;
    }
    try {
      await _speech?.cancel();
    } catch (_) {}
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
