import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/voice_recognition_service.dart';

class VoiceListenButton extends StatefulWidget {
  const VoiceListenButton({
    super.key,
    required this.onResult,
  });

  final Future<void> Function(VoiceParseResult result, String raw) onResult;

  @override
  State<VoiceListenButton> createState() => _VoiceListenButtonState();
}

class _VoiceListenButtonState extends State<VoiceListenButton> {
  final _service = VoiceRecognitionService();
  bool _listening = false;
  String _hint = '마이크로 말해 보세요';

  Future<void> _tap() async {
    setState(() {
      _listening = true;
      _hint = '듣는 중…';
    });
    final raw = await _service.listenOnce();
    if (!mounted) return;
    if (raw == null || raw.isEmpty) {
      setState(() {
        _listening = false;
        _hint = '인식되지 않았어요. 다시 시도!';
      });
      return;
    }
    final parsed = _service.parse(raw);
    await widget.onResult(parsed, raw);
    if (!mounted) return;
    setState(() {
      _listening = false;
      _hint = raw;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _listening ? null : _tap,
          icon: Icon(_listening ? Icons.hearing : Icons.mic_rounded),
          label: Text(_listening ? '듣는 중' : '음성으로 계산'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.coral,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _hint,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppTheme.ink.withValues(alpha: 0.55),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
