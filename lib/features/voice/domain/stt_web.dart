import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Chrome uses webkitSpeechRecognition; release-mode SpeechRecognition can break.
@JS('webkitSpeechRecognition')
extension type _WebkitSpeechRecognition._(web.SpeechRecognition _)
    implements web.SpeechRecognition {
  external factory _WebkitSpeechRecognition();
}

web.SpeechRecognition? _active;
bool _discardActiveResult = false;

bool get _supported =>
    web.window.hasProperty('SpeechRecognition'.toJS).toDart ||
    web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

Future<bool> webEnsureMicPermission() async {
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    final tracks = stream.getTracks().toDart;
    for (final track in tracks) {
      track.stop();
    }
    return true;
  } catch (e) {
    debugPrint('web mic permission failed: $e');
    return false;
  }
}

Future<String?> webListenOnce({
  String localeId = 'ko-KR',
  Duration listenFor = const Duration(seconds: 12),
  void Function(String partial)? onPartial,
}) async {
  if (!_supported) {
    debugPrint('Web SpeechRecognition not supported in this browser');
    return null;
  }

  final micOk = await webEnsureMicPermission();
  if (!micOk) return null;

  await webStopListening();

  final lang = localeId.contains('_')
      ? localeId.replaceAll('_', '-')
      : localeId;

  late final web.SpeechRecognition recog;
  try {
    if (web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart) {
      recog = _WebkitSpeechRecognition();
    } else {
      recog = web.SpeechRecognition();
    }
  } catch (e) {
    debugPrint('SpeechRecognition create failed: $e');
    return null;
  }

  _active = recog;
  recog.lang = lang;
  recog.interimResults = true;
  recog.continuous = true;
  recog.maxAlternatives = 1;

  final completer = Completer<String?>();
  var latest = '';
  Timer? silenceTimer;
  Timer? maxTimer;

  void finish([String? value]) {
    silenceTimer?.cancel();
    maxTimer?.cancel();
    final discard = _discardActiveResult;
    _discardActiveResult = false;
    if (!completer.isCompleted) {
      if (discard) {
        completer.complete(null);
      } else {
        final out = (value ?? latest).trim();
        completer.complete(out.isEmpty ? null : out);
      }
    }
    try {
      recog.stop();
    } catch (_) {}
    if (identical(_active, recog)) _active = null;
  }

  void bumpSilenceWatch() {
    silenceTimer?.cancel();
    // After we have some text, stop ~1.8s after last result.
    if (latest.isEmpty) return;
    silenceTimer = Timer(const Duration(milliseconds: 1800), () {
      finish(latest);
    });
  }

  recog.onresult = (web.SpeechRecognitionEvent event) {
    final buf = StringBuffer();
    final results = event.results;
    for (var i = 0; i < results.length; i++) {
      final result = results.item(i);
      if (result.length == 0) continue;
      buf.write(result.item(0).transcript);
    }
    latest = buf.toString().trim();
    if (latest.isNotEmpty) {
      onPartial?.call(latest);
      bumpSilenceWatch();
    }
  }.toJS;

  recog.onerror = (web.SpeechRecognitionErrorEvent event) {
    debugPrint('web STT error: ${event.error}');
    // 'no-speech' / 'aborted' → still return whatever we have
    finish(latest.isEmpty ? null : latest);
  }.toJS;

  recog.onend = (web.Event _) {
    finish(latest.isEmpty ? null : latest);
  }.toJS;

  try {
    recog.start();
  } catch (e) {
    debugPrint('web STT start failed: $e');
    return null;
  }

  maxTimer = Timer(listenFor, () => finish(latest.isEmpty ? null : latest));

  return completer.future.timeout(
    listenFor + const Duration(seconds: 3),
    onTimeout: () {
      finish(latest.isEmpty ? null : latest);
      return latest.isEmpty ? null : latest;
    },
  );
}

Future<void> webStopListening({bool discardResult = false}) async {
  if (discardResult) _discardActiveResult = true;
  final active = _active;
  _active = null;
  if (active == null) return;
  try {
    active.abort();
  } catch (_) {
    try {
      active.stop();
    } catch (_) {}
  }
}
