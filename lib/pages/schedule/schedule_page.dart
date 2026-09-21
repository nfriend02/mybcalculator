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
  final Set<String> _selected = {};
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

  Future<void> _addManual() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final controller = context.read<ScheduleController>();
    await controller.add(
      title,
      DateTime.now().add(const Duration(hours: 1)),
    );
    if (!mounted) return;
    _title.clear();
    setState(() => _error = null);
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final controller = context.read<ScheduleController>();
    final ids = _selected.toList();
    await controller.removeByIds(ids);
    if (!mounted) return;
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleController>();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final selectedCount = _selected
        .where((id) => controller.items.any((e) => e.id == id))
        .length;

    return FeatureScaffold(
      title: '일정 관리',
      subtitle: '말로 일정을 말하거나, 제목을 직접 추가',
      emoji: '📅',
      accent: const Color(0xFFA8967A),
      variant: FeatureVariant.soft,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NlAssistInput(
            controller: _nl,
            hintText: '예) 내일 오후 3시 팀 회의',
            busy: controller.busy,
            submitLabel: '일정 추가',
            busyLabel: '추가 중…',
            minLines: 1,
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
                  onSubmitted: (_) => _addManual(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addManual,
                child: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '기록 ${controller.items.length}개',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: selectedCount == 0 ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(
                  selectedCount == 0
                      ? '기록 삭제'
                      : '기록 삭제 ($selectedCount)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: PagedListView(
                items: controller.items,
                shrinkWrap: true,
                emptyMessage: '일정이 비어 있어요',
                itemBuilder: (context, item, index) {
                  final checked = _selected.contains(item.id);
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
                    title: Text(
                      item.title,
                      style: GoogleFonts.notoSansKr(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      fmt.format(item.when),
                      style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Checkbox(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(item.id);
                          } else {
                            _selected.remove(item.id);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (checked) {
                          _selected.remove(item.id);
                        } else {
                          _selected.add(item.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
