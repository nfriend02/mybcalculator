import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/schedule/model/schedule_controller.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';
import '../../shared/ui/widgets/nl_assist_input.dart';
import '../../shared/ui/widgets/paged_list_view.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _title = TextEditingController();
  final _nl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _nl.dispose();
    super.dispose();
  }

  Future<void> _applyNl() async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final controller = context.read<ScheduleController>();
    setState(() => _error = null);
    final ok = await controller.applyNaturalLanguage(text);
    if (!mounted) return;
    if (ok) {
      _nl.clear();
    } else {
      setState(() {
        _error = controller.lastError ?? '일정을 추가하지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleController>();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return FeatureScaffold(
      title: '일정 관리',
      subtitle: '말로 일정을 말하거나, 제목을 직접 추가',
      emoji: '📅',
      accent: const Color(0xFFA8967A),
      variant: FeatureVariant.soft,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NlAssistInput(
            controller: _nl,
            hintText: '예) 내일 오후 3시 팀 회의',
            busy: controller.busy,
            submitLabel: '일정 추가',
            busyLabel: '추가 중…',
            minLines: 2,
            maxLines: 3,
            onSubmit: _applyNl,
            onVoiceSubmit: (t) async {
              _nl.text = t;
              await _applyNl();
            },
            onFileSubmit: (file) async {
              setState(() => _error = null);
              final ok = await controller.applyFromFile(
                bytes: file.bytes,
                fileName: file.name,
                extension: file.extension,
                userHint: _nl.text.trim().isEmpty ? null : _nl.text.trim(),
              );
              if (!mounted) return;
              if (!ok) {
                setState(() {
                  _error = controller.lastError ?? '파일에서 일정을 찾지 못했어요.';
                });
              }
            },
          ),
          if (controller.note != null && _error == null) ...[
            const SizedBox(height: 6),
            Text(
              controller.note!,
              style: GoogleFonts.notoSansKr(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: GoogleFonts.notoSansKr(
                color: AppTheme.dangerText,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    hintText: '새 일정 제목 (직접 입력)',
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  if (_title.text.trim().isEmpty) return;
                  await controller.add(
                    _title.text.trim(),
                    DateTime.now().add(const Duration(hours: 1)),
                  );
                  _title.clear();
                },
                child: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Material(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PagedListView(
                  items: controller.items,
                  emptyMessage: '일정이 비어 있어요',
                  itemBuilder: (context, item, index) {
                    return ListTile(
                      tileColor: AppTheme.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFFA8967A).withValues(alpha: 0.35),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(item.title),
                      subtitle: Text(fmt.format(item.when)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
