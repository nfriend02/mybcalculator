import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/currency/domain/currency_service.dart';
import '../../features/currency/model/currency_controller.dart';
import '../../features/voice/domain/voice_recognition_service.dart';
import '../../shared/config/breakpoints.dart';

/// FX workspace — NL left, convert panel + history right (mirrors calculator).
class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  final _nl = TextEditingController();
  String? _error;

  static const _suggestions = [
    '오늘 싱가포르달러 100달러면 얼마야?',
    '달러 120을 원화로',
    '엔화 1만 엔은 원으로?',
    '10만 원을 유로로 바꾸면?',
    '위안 500은 얼마?',
  ];

  @override
  void dispose() {
    _nl.dispose();
    super.dispose();
  }

  Future<void> _calculate({String sourceHint = 'typed'}) async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final controller = context.read<CurrencyController>();
    setState(() => _error = null);
    try {
      final ok = await controller.applyNaturalLanguage(
        text,
        sourceHint: sourceHint,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = controller.lastError ??
              '환율 계산 요청이 실패했습니다. 다시 시도해 주세요.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '환율 계산 요청이 실패했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CurrencyController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.desktopMin;

        final sentence = _FxSentencePanel(
          controller: _nl,
          error: _error ?? controller.lastError,
          note: controller.aiNote,
          busy: controller.busy,
          suggestions: _suggestions,
          onSubmit: () => _calculate(),
          onVoiceSubmit: (transcript) async {
            _nl.text = transcript;
            _nl.selection =
                TextSelection.collapsed(offset: transcript.length);
            await _calculate(sourceHint: 'voice');
          },
          onFileSubmit: (file) async {
            setState(() => _error = null);
            final fx = context.read<CurrencyController>();
            final hint = _nl.text.trim();
            final ok = await fx.applyFromFile(
              bytes: file.bytes,
              fileName: file.name,
              extension: file.extension,
              userHint: hint.isEmpty ? null : hint,
            );
            if (!mounted) return;
            if (ok) {
              final note = fx.aiNote ?? '${file.name} 분석 완료';
              _nl.text = note;
              _nl.selection = TextSelection.collapsed(offset: note.length);
            } else {
              setState(() {
                _error = fx.lastError ??
                    '파일 분석에 실패했습니다. 다시 시도해 주세요.';
              });
            }
          },
          onSuggestion: (s) {
            _nl.text = s;
            _calculate(sourceHint: 'suggestion');
          },
          expandBody: wide,
        );

        final right = _FxConvertHistoryColumn(fx: controller);

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
            SizedBox(height: 560, child: right),
          ],
        );
      },
    );
  }
}

class _PickedFxFile {
  const _PickedFxFile({
    required this.bytes,
    required this.name,
    this.extension,
  });

  final Uint8List bytes;
  final String name;
  final String? extension;
}

class _FxSentencePanel extends StatefulWidget {
  const _FxSentencePanel({
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
  final Future<void> Function(_PickedFxFile file) onFileSubmit;
  final ValueChanged<String> onSuggestion;
  final bool expandBody;

  @override
  State<_FxSentencePanel> createState() => _FxSentencePanelState();
}

class _FxSentencePanelState extends State<_FxSentencePanel> {
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
      final text = (raw ?? '').trim();
      if (text.isNotEmpty) {
        widget.controller.text = text;
        widget.controller.selection =
            TextSelection.collapsed(offset: text.length);
        await widget.onVoiceSubmit(text);
      }
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
        _PickedFxFile(
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
        hintText: '예) 오늘 싱가포르달러로 100달러면 얼마지?',
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
            '나의 AI 환율 계산기',
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
              _FxIconButton(
                icon: _listening ? Icons.mic : Icons.mic_none_rounded,
                tooltip: '음성으로 입력',
                active: _listening,
                onTap: _onMic,
              ),
              const SizedBox(width: 10),
              _FxIconButton(
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
            '외화 ↔ 원화를 일상 대화처럼 물어보세요.\n'
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
                _FxSuggestionPill(
                  label: s,
                  onTap: () => widget.onSuggestion(s),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: FilledButton.icon(
                onPressed: widget.busy ? null : widget.onSubmit,
                style: FilledButton.styleFrom(
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

class _FxIconButton extends StatelessWidget {
  const _FxIconButton({
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

class _FxSuggestionPill extends StatelessWidget {
  const _FxSuggestionPill({required this.label, required this.onTap});

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

class _FxConvertHistoryColumn extends StatelessWidget {
  const _FxConvertHistoryColumn({required this.fx});
  final CurrencyController fx;

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
                  '환율 계산',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _FxConvertPad(fx: fx)),
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
                        '지난 환율계산',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          fx.history.isEmpty ? null : () => fx.clearHistory(),
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
                Expanded(child: _FxHistoryPane(fx: fx)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FxConvertPad extends StatefulWidget {
  const _FxConvertPad({required this.fx});
  final CurrencyController fx;

  @override
  State<_FxConvertPad> createState() => _FxConvertPadState();
}

class _FxConvertPadState extends State<_FxConvertPad> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.fx.amountText);
    // Initial preview convert (no history spam).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.fx.convertManual(addHistory: false);
    });
  }

  @override
  void didUpdateWidget(covariant _FxConvertPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_amountCtrl.text != widget.fx.amountText &&
        !_amountCtrl.selection.isValid) {
      // keep user typing; only sync if controller changed amount externally
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({String? label}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.gold, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = widget.fx;
    final codes = CurrencyService.supportedCodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Result display (mirrors calculator output).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fx.expression.isEmpty ? ' ' : fx.expression,
                  maxLines: 2,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    height: 1.3,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fx.resultDisplay,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount input + from currency (KRW default).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(label: '금액'),
                        onChanged: (v) => fx.setAmountText(v),
                        onSubmitted: (_) =>
                            fx.convertManual(addHistory: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: fx.fromCode,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceElevated,
                        style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _fieldDecoration(label: '입력 통화'),
                        items: [
                          for (final c in codes)
                            DropdownMenuItem(
                              value: c,
                              child: Text(
                                CurrencyService.labelOf(c),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) fx.setFromCode(v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Output amount + to currency unit.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: InputDecorator(
                        decoration: _fieldDecoration(label: '환산 금액'),
                        child: Text(
                          fx.outputAmount.isEmpty ? '—' : fx.outputAmount,
                          style: GoogleFonts.notoSansKr(
                            color: AppTheme.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: fx.toCode,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceElevated,
                        style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _fieldDecoration(label: '출력 통화'),
                        items: [
                          for (final c in codes)
                            DropdownMenuItem(
                              value: c,
                              child: Text(
                                CurrencyService.labelOf(c),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) fx.setToCode(v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.85,
                    child: FilledButton(
                      onPressed: fx.converting
                          ? null
                          : () => fx.convertManual(addHistory: true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: Text(fx.converting ? '변환 중…' : '환율 변환'),
                    ),
                  ),
                ),
                if (fx.rateNote != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    fx.rateNote!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      height: 1.4,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FxHistoryPane extends StatelessWidget {
  const _FxHistoryPane({required this.fx});
  final CurrencyController fx;

  @override
  Widget build(BuildContext context) {
    final items = fx.history;
    if (items.isEmpty) {
      return CustomPaint(
        painter: _FxDashedBorderPainter(color: AppTheme.border),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                color: AppTheme.textMuted.withValues(alpha: 0.85),
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                '환율을 계산하면\n여기에 기록이 쌓입니다',
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

class _FxDashedBorderPainter extends CustomPainter {
  _FxDashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
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
  bool shouldRepaint(covariant _FxDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
