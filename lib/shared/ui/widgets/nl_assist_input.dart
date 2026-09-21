import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_theme.dart';
import '../../../features/voice/domain/voice_recognition_service.dart';

class PickedAssistFile {
  const PickedAssistFile({
    required this.bytes,
    required this.name,
    this.extension,
  });

  final Uint8List bytes;
  final String name;
  final String? extension;
}

/// Voice + file buttons above a natural-language text field + submit.
class NlAssistInput extends StatefulWidget {
  const NlAssistInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSubmit,
    required this.onVoiceSubmit,
    required this.onFileSubmit,
    this.busy = false,
    this.submitLabel = '적용하기',
    this.busyLabel = '처리 중…',
    this.minLines = 2,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;
  final Future<void> Function(String transcript) onVoiceSubmit;
  final Future<void> Function(PickedAssistFile file) onFileSubmit;
  final bool busy;
  final String submitLabel;
  final String busyLabel;
  final int minLines;
  final int maxLines;

  @override
  State<NlAssistInput> createState() => _NlAssistInputState();
}

class _NlAssistInputState extends State<NlAssistInput> {
  final _voice = VoiceRecognitionService();
  bool _listening = false;
  bool _pickingFile = false;
  bool _discardVoice = false;

  @override
  void dispose() {
    _discardVoice = true;
    unawaited(_voice.cancel(discardResult: true));
    super.dispose();
  }

  Future<void> _onMic() async {
    if (widget.busy) return;
    if (_listening) {
      _discardVoice = true;
      await _voice.cancel(discardResult: true);
      if (mounted) setState(() => _listening = false);
      return;
    }

    _discardVoice = false;
    setState(() => _listening = true);
    try {
      final raw = await _voice.listenOnce(
        onPartial: (partial) {
          if (!mounted || _discardVoice) return;
          widget.controller.text = partial;
          widget.controller.selection =
              TextSelection.collapsed(offset: partial.length);
        },
      );
      if (!mounted || _discardVoice) return;
      if (raw == null || raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '음성을 인식하지 못했어요. Chrome 마이크 권한을 확인해 주세요.',
            ),
          ),
        );
        return;
      }
      widget.controller.text = raw;
      widget.controller.selection =
          TextSelection.collapsed(offset: raw.length);
      await widget.onVoiceSubmit(raw);
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _onUpload() async {
    if (_pickingFile || widget.busy) return;
    setState(() => _pickingFile = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic', 'heif',
          'pdf',
          'txt', 'md', 'csv', 'json', 'log',
          'doc', 'docx', 'ppt', 'pptx',
        ],
      );
      if (!mounted) return;
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 내용을 읽지 못했어요.')),
        );
        return;
      }

      await widget.onFileSubmit(
        PickedAssistFile(
          bytes: bytes,
          name: file.name,
          extension: file.extension,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _AssistIconButton(
              icon: _listening ? Icons.mic : Icons.mic_none_rounded,
              tooltip: '음성으로 입력',
              active: _listening,
              onTap: _onMic,
            ),
            const SizedBox(width: 10),
            _AssistIconButton(
              icon: Icons.upload_file_rounded,
              tooltip: '파일로 입력',
              active: _pickingFile,
              onTap: _onUpload,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _listening
                    ? '듣고 있어요… 다시 누르면 종료'
                    : _pickingFile
                        ? '파일 선택 중…'
                        : '음성 · 파일로도 입력할 수 있어요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.controller,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          enabled: !widget.busy,
          style: GoogleFonts.notoSansKr(
            color: AppTheme.textPrimary,
            height: 1.45,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.notoSansKr(
              color: const Color(0xFF5A544C),
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppTheme.surfaceElevated,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.gold, width: 1.4),
            ),
          ),
          onSubmitted: (_) {
            if (!widget.busy) widget.onSubmit();
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: widget.busy ? null : widget.onSubmit,
            icon: widget.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.subdirectory_arrow_left_rounded, size: 18),
            label: Text(widget.busy ? widget.busyLabel : widget.submitLabel),
          ),
        ),
      ],
    );
  }
}

class _AssistIconButton extends StatelessWidget {
  const _AssistIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppTheme.gold.withValues(alpha: 0.25)
            : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppTheme.gold : AppTheme.border,
              ),
            ),
            child: Icon(
              icon,
              color: active ? AppTheme.gold : AppTheme.textPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
