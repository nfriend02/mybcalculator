import 'dart:async';

/// Stub for non-web platforms.
Future<bool> webEnsureMicPermission() async => false;

Future<String?> webListenOnce({
  String localeId = 'ko-KR',
  Duration listenFor = const Duration(seconds: 12),
  void Function(String partial)? onPartial,
}) async =>
    null;

Future<void> webStopListening({bool discardResult = false}) async {}
