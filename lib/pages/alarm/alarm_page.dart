import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/alarm/model/alarm_timer_controller.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';
import '../../shared/ui/widgets/nl_assist_input.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  final _nl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nl.dispose();
    super.dispose();
  }

  Future<void> _applyNl() async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final timer = context.read<AlarmTimerController>();
    setState(() => _error = null);
    final ok = await timer.applyNaturalLanguage(text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = timer.lastError ?? '알람을 설정하지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<AlarmTimerController>();

    return FeatureScaffold(
      title: '알람 / 타이머',
      subtitle: '시간 설정 · 시작 · 일시정지 · 정지 · 리셋',
      emoji: '⏰',
      accent: const Color(0xFFE08A5A),
      variant: FeatureVariant.stripe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NlAssistInput(
            controller: _nl,
            hintText: '예) 10분 타이머 / 시작 / 일시정지 / 정지 / 리셋',
            busy: timer.busy,
            submitLabel: '실행',
            busyLabel: '처리 중…',
            onSubmit: _applyNl,
            onVoiceSubmit: (t) async {
              _nl.text = t;
              await _applyNl();
            },
            onFileSubmit: (file) async {
              setState(() => _error = null);
              final ok = await timer.applyFromFile(
                bytes: file.bytes,
                fileName: file.name,
                extension: file.extension,
                userHint: _nl.text.trim().isEmpty ? null : _nl.text.trim(),
              );
              if (!mounted) return;
              if (!ok) {
                setState(() {
                  _error = timer.lastError ?? '파일에서 시간을 찾지 못했어요.';
                });
              }
            },
          ),
          if (timer.note != null && _error == null) ...[
            const SizedBox(height: 8),
            Text(
              timer.note!,
              style: GoogleFonts.notoSansKr(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.notoSansKr(
                color: AppTheme.dangerText,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.coral.withValues(alpha: 0.55),
                  AppTheme.peach.withValues(alpha: 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              timer.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(fontSize: 56),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final m in [1, 5, 10, 15, 30])
                Material(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () => timer.setMinutes(m),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        '$m분',
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: timer.running ? null : timer.start,
                  child: const Text('시작'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: timer.pause,
                  child: const Text('일시정지'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: timer.pause,
                  child: const Text('정지'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: timer.reset,
                  child: const Text('리셋'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
