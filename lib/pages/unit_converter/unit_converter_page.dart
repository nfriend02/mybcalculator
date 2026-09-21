import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/unit_converter/domain/unit_converter.dart';
import '../../features/unit_converter/model/unit_controller.dart';
import '../../features/voice/domain/voice_recognition_service.dart';
import '../../shared/config/breakpoints.dart';

/// Unit converter workspace — NL left, convert + history right.
class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  final _nl = TextEditingController();
  String? _error;

  static const _suggestions = [
    '100 feet가 몇 m인가요?',
    '5 kg는 몇 파운드?',
    '화씨 68도는 섭씨로',
    '2 마일을 킬로미터로',
    '500 ml는 몇 컵?',
  ];

  @override
  void dispose() {
    _nl.dispose();
    super.dispose();
  }

  Future<void> _convertNl({String sourceHint = 'typed'}) async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final controller = context.read<UnitController>();
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
              '단위 변환에 실패했습니다. 다시 시도해 주세요.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '단위 변환에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UnitController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.desktopMin;

        final sentence = _UnitSentencePanel(
          controller: _nl,
          error: _error ?? controller.lastError,
          note: controller.aiNote,
          busy: controller.busy,
          suggestions: _suggestions,
          onSubmit: () => _convertNl(),
          onVoiceSubmit: (transcript) async {
            _nl.text = transcript;
            _nl.selection =
                TextSelection.collapsed(offset: transcript.length);
            await _convertNl(sourceHint: 'voice');
          },
          onFileSubmit: (file) async {
            setState(() => _error = null);
            final units = context.read<UnitController>();
            final hint = _nl.text.trim();
            final ok = await units.applyFromFile(
              bytes: file.bytes,
              fileName: file.name,
              extension: file.extension,
              userHint: hint.isEmpty ? null : hint,
            );
            if (!mounted) return;
            if (ok) {
              final note = units.aiNote ?? '${file.name} 분석 완료';
              _nl.text = note;
              _nl.selection = TextSelection.collapsed(offset: note.length);
            } else {
              setState(() {
                _error = units.lastError ??
                    '파일 분석에 실패했습니다. 다시 시도해 주세요.';
              });
            }
          },
          onSuggestion: (s) {
            _nl.text = s;
            _convertNl(sourceHint: 'suggestion');
          },
          expandBody: wide,
        );

        final right = _UnitConvertHistoryColumn(units: controller);

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

class _PickedUnitFile {
  const _PickedUnitFile({
    required this.bytes,
    required this.name,
    this.extension,
  });

  final Uint8List bytes;
  final String name;
  final String? extension;
}

class _UnitSentencePanel extends StatefulWidget {
  const _UnitSentencePanel({
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
  final Future<void> Function(_PickedUnitFile file) onFileSubmit;
  final ValueChanged<String> onSuggestion;
  final bool expandBody;

  @override
  State<_UnitSentencePanel> createState() => _UnitSentencePanelState();
}

class _UnitSentencePanelState extends State<_UnitSentencePanel> {
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
        _PickedUnitFile(
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
        hintText: '예) 100 feet가 몇 m인가요?',
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
            '나의 AI 단위 계산기',
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
              _UnitIconButton(
                icon: _listening ? Icons.mic : Icons.mic_none_rounded,
                tooltip: '음성으로 입력',
                active: _listening,
                onTap: _onMic,
              ),
              const SizedBox(width: 10),
              _UnitIconButton(
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
            '길이·무게·부피·온도를 일상 문장으로 바꿔 보세요.\n'
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
                _UnitSuggestionPill(
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
                label: Text(widget.busy ? '변환 중…' : '단위 변환하기'),
              ),
            ),
          ),
          if (widget.note != null && widget.error == null) ...[
            const SizedBox(height: 12),
            Text(
              widget.note!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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

class _UnitIconButton extends StatelessWidget {
  const _UnitIconButton({
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

class _UnitSuggestionPill extends StatelessWidget {
  const _UnitSuggestionPill({required this.label, required this.onTap});

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

class _UnitConvertHistoryColumn extends StatelessWidget {
  const _UnitConvertHistoryColumn({required this.units});
  final UnitController units;

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
                  '단위 변환',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _UnitLookupPad(units: units)),
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
                        '지난 단위 조회',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: units.history.isEmpty
                          ? null
                          : () => units.clearHistory(),
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
                Expanded(child: _UnitHistoryPane(units: units)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitLookupPad extends StatefulWidget {
  const _UnitLookupPad({required this.units});
  final UnitController units;

  @override
  State<_UnitLookupPad> createState() => _UnitLookupPadState();
}

class _UnitLookupPadState extends State<_UnitLookupPad> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.units.amountText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.units.convertManual(addHistory: false);
    });
  }

  @override
  void didUpdateWidget(covariant _UnitLookupPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.units.amountText != _amountCtrl.text &&
        !FocusScope.of(context).hasFocus) {
      _amountCtrl.text = widget.units.amountText;
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
    final u = widget.units;
    final unitList = u.units;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  u.expression.isEmpty ? ' ' : u.expression,
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
                  u.resultDisplay,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '단위 조회',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    for (final m in UnitConverter.modes)
                      ButtonSegment(
                        value: m,
                        label: Text(
                          UnitConverter.modeLabel(m),
                          style: GoogleFonts.notoSansKr(fontSize: 12),
                        ),
                      ),
                  ],
                  selected: {u.mode},
                  onSelectionChanged: (s) => u.setMode(s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.gold.withValues(alpha: 0.25);
                      }
                      return AppTheme.surfaceElevated;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration(label: '값'),
                  onChanged: u.setAmountText,
                  onSubmitted: (_) => u.convertManual(addHistory: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: unitList.contains(u.from) ? u.from : unitList.first,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceElevated,
                        style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _fieldDecoration(label: 'From'),
                        items: [
                          for (final code in unitList)
                            DropdownMenuItem(
                              value: code,
                              child: Text(
                                UnitConverter.labelOf(code),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) u.setFrom(v);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.gold,
                      ),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: unitList.contains(u.to) ? u.to : unitList.first,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceElevated,
                        style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _fieldDecoration(label: 'To'),
                        items: [
                          for (final code in unitList)
                            DropdownMenuItem(
                              value: code,
                              child: Text(
                                UnitConverter.labelOf(code),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) u.setTo(v);
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
                      onPressed: u.converting
                          ? null
                          : () => u.convertManual(addHistory: true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: Text(u.converting ? '변환 중…' : '변환'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitHistoryPane extends StatelessWidget {
  const _UnitHistoryPane({required this.units});
  final UnitController units;

  @override
  Widget build(BuildContext context) {
    final items = units.history;
    if (items.isEmpty) {
      return CustomPaint(
        painter: _UnitDashedBorderPainter(color: AppTheme.border),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.straighten_rounded,
                color: AppTheme.textMuted.withValues(alpha: 0.85),
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                '단위를 변환하면\n여기에 기록이 쌓입니다',
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

class _UnitDashedBorderPainter extends CustomPainter {
  _UnitDashedBorderPainter({required this.color});
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
  bool shouldRepaint(covariant _UnitDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
