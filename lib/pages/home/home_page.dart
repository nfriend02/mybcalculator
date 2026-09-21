import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/calculator/model/calculator_controller.dart';
import '../../features/calculator/ui/calculator_pad.dart';
import '../../features/voice/domain/voice_recognition_service.dart';
import '../../shared/config/breakpoints.dart';

/// Main calculator workspace — NL left, keypad + history right (responsive).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _nl = TextEditingController();
  String? _error;

  static const _suggestions = [
    '팁 15% 포함해서 총액은?',
    '달러 120을 원화로',
    '시급 12,000원 · 주 20시간',
    '삼십 나누기 삼은?',
    '만원짜리 칼국수 세 그릇',
  ];

  @override
  void dispose() {
    _nl.dispose();
    super.dispose();
  }

  Future<void> _calculate({bool preferAi = false, String sourceHint = 'typed'}) async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final controller = context.read<CalculatorController>();
    setState(() => _error = null);
    try {
      final ok = await controller.applyNaturalLanguage(
        text,
        preferAi: preferAi,
        sourceHint: sourceHint,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = controller.lastError ??
              '계산 요청이 실패했습니다. 다시 시도해 주세요.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '계산 요청이 실패했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.desktopMin;

        final sentence = _SentencePanel(
          controller: _nl,
          error: _error ?? controller.lastError,
          note: controller.aiNote,
          busy: controller.aiBusy,
          suggestions: _suggestions,
          onSubmit: () => _calculate(),
          onVoiceSubmit: (transcript) async {
            _nl.text = transcript;
            _nl.selection =
                TextSelection.collapsed(offset: transcript.length);
            await _calculate(preferAi: true, sourceHint: 'voice');
          },
          onFileSubmit: (file) async {
            setState(() => _error = null);
            final calc = context.read<CalculatorController>();
            final hint = _nl.text.trim();
            final ok = await calc.applyFromFile(
              bytes: file.bytes,
              fileName: file.name,
              extension: file.extension,
              userHint: hint.isEmpty ? null : hint,
            );
            if (!mounted) return;
            if (ok) {
              final note = calc.aiNote ?? '${file.name} 분석 완료';
              _nl.text = note;
              _nl.selection = TextSelection.collapsed(offset: note.length);
            } else {
              setState(() {
                _error = calc.lastError ??
                    '파일 분석에 실패했습니다. 다시 시도해 주세요.';
              });
            }
          },
          onSuggestion: (s) {
            _nl.text = s;
            _calculate(preferAi: true, sourceHint: 'suggestion');
          },
          expandBody: wide,
        );
        final right = _KeypadHistoryColumn(calc: controller);

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: sentence),
              const SizedBox(width: 16),
              Expanded(flex: 9, child: right),
            ],
          );
        }

        return ListView(
          children: [
            sentence,
            const SizedBox(height: 14),
            SizedBox(height: 540, child: right),
          ],
        );
      },
    );
  }
}

class _PickedCalcFile {
  const _PickedCalcFile({
    required this.bytes,
    required this.name,
    this.extension,
  });

  final Uint8List bytes;
  final String name;
  final String? extension;
}

class _SentencePanel extends StatefulWidget {
  const _SentencePanel({
    required this.controller,
    required this.error,
    required this.note,
    required this.busy,
    required this.suggestions,
    required this.onSubmit,
    required this.onVoiceSubmit,
    required this.onFileSubmit,
    required this.onSuggestion,
    this.expandBody = true,
  });

  final TextEditingController controller;
  final String? error;
  final String? note;
  final bool busy;
  final List<String> suggestions;
  final VoidCallback onSubmit;
  final Future<void> Function(String transcript) onVoiceSubmit;
  final Future<void> Function(_PickedCalcFile file) onFileSubmit;
  final ValueChanged<String> onSuggestion;
  final bool expandBody;

  @override
  State<_SentencePanel> createState() => _SentencePanelState();
}

class _SentencePanelState extends State<_SentencePanel> {
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

    // Second click while listening → stop early without submitting.
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
              '음성을 인식하지 못했어요. Chrome 주소창 마이크 권한을 허용하고, '
              '말하는 동안 마이크 아이콘이 켜져 있는지 확인해 주세요.',
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
          // images (Gemini Vision)
          'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic', 'heif',
          // documents
          'pdf',
          'txt', 'md', 'csv', 'json', 'log',
          // office
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
        _PickedCalcFile(
          bytes: bytes,
          name: file.name,
          extension: file.extension,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      maxLines: widget.expandBody ? null : 6,
      minLines: widget.expandBody ? null : 5,
      expands: widget.expandBody,
      textAlignVertical: TextAlignVertical.top,
      style: GoogleFonts.notoSansKr(
        color: AppTheme.textPrimary,
        height: 1.5,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: '예) 오늘 점심에 갈비탕 만이천원 2그릇, 아이스 아메리카노 2000원짜리 2개를 친구와 먹었으면?',
        hintStyle: GoogleFonts.notoSansKr(
          color: const Color(0xFF5A544C),
          height: 1.5,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '나의 만능 AI 계산기',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InputIconButton(
                icon: _listening ? Icons.mic : Icons.mic_none_rounded,
                tooltip: '음성으로 입력',
                active: _listening,
                onTap: _onMic,
              ),
              const SizedBox(width: 10),
              _InputIconButton(
                icon: Icons.upload_file_rounded,
                tooltip: '파일로 입력',
                active: _pickingFile,
                onTap: _onUpload,
              ),
              const SizedBox(width: 12),
              Text(
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
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'AI에게 일상 대화처럼 계산을 시켜보세요.\n'
            '문장·음성·파일(이미지·PDF·TXT·DOCX·PPTX) 모두 가능해요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.expandBody) Expanded(child: field) else field,
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.suggestions)
                _SuggestionPill(
                  label: s,
                  onTap: () => widget.onSuggestion(s),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              // 30% narrower than full width.
              widthFactor: 0.7,
              child: FilledButton.icon(
                onPressed: widget.busy ? null : widget.onSubmit,
                style: FilledButton.styleFrom(
                  // Theme vertical padding 14 → 50% taller.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 21,
                  ),
                  minimumSize: const Size(0, 66),
                  textStyle: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                icon: widget.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.subdirectory_arrow_left_rounded,
                        size: 22,
                      ),
                label: Text(widget.busy ? 'AI 계산 중…' : '계산하기'),
              ),
            ),
          ),
          if (widget.note != null && widget.error == null) ...[
            const SizedBox(height: 12),
            Text(
              widget.note!,
              style: GoogleFonts.notoSansKr(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (widget.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.dangerText,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: GoogleFonts.notoSansKr(
                        color: AppTheme.dangerText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  const _InputIconButton({
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppTheme.gold : AppTheme.border,
              ),
            ),
            child: Icon(
              icon,
              color: active ? AppTheme.gold : AppTheme.textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  const _SuggestionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadHistoryColumn extends StatelessWidget {
  const _KeypadHistoryColumn({required this.calc});
  final CalculatorController calc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '키패드',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: CalculatorPad(controller: calc)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '지난 계산',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: calc.history.isEmpty
                          ? null
                          : () => calc.clearHistory(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.gold,
                        disabledForegroundColor:
                            AppTheme.textMuted.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '기록삭제',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(child: _HistoryPane(calc: calc)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({required this.calc});
  final CalculatorController calc;

  @override
  Widget build(BuildContext context) {
    final items = calc.history;
    if (items.isEmpty) {
      return CustomPaint(
        painter: _DashedBorderPainter(color: AppTheme.border),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mouse_outlined,
                color: AppTheme.textMuted.withValues(alpha: 0.85),
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                '계산을 실행하면\n여기에 기록이 쌓입니다',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length.clamp(0, 20),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.expression,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '= ${item.result}',
                style: GoogleFonts.notoSansKr(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          const Radius.circular(14),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
