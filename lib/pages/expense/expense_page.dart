import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/expense/model/expense_controller.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';
import '../../shared/ui/widgets/nl_assist_input.dart';
import '../../shared/ui/widgets/paged_list_view.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _nl = TextEditingController();
  final Set<String> _selected = {};
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _nl.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll('원', '');
    return double.tryParse(cleaned);
  }

  Future<void> _applyNl() async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final controller = context.read<ExpenseController>();
    setState(() => _error = null);
    final ok = await controller.applyNaturalLanguage(text);
    if (!mounted) return;
    if (ok) {
      _nl.clear();
    } else {
      setState(() {
        _error = controller.lastError ?? '지출을 기록하지 못했어요.';
      });
    }
  }

  Future<void> _addManual() async {
    final title = _title.text.trim();
    final amount = _parseAmount(_amount.text) ?? 0;
    if (title.isEmpty || amount <= 0) {
      setState(() {
        _error = '항목과 금액을 입력해 주세요. 예: 커피 / 4500';
      });
      return;
    }
    final controller = context.read<ExpenseController>();
    await controller.add(title, amount);
    if (!mounted) return;
    _title.clear();
    _amount.clear();
    setState(() => _error = null);
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final controller = context.read<ExpenseController>();
    final ids = _selected.toList();
    await controller.removeByIds(ids);
    if (!mounted) return;
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final firebaseReady = context.watch<bool>();
    final selectedCount = _selected
        .where((id) => controller.items.any((e) => e.id == id))
        .length;

    return FeatureScaffold(
      title: '지출 기록',
      subtitle: firebaseReady
          ? '합계 ₩${controller.total.toStringAsFixed(0)} · Firebase 동기화'
          : '합계 ₩${controller.total.toStringAsFixed(0)} · 오프라인',
      emoji: '💸',
      accent: const Color(0xFFD4926A),
      variant: FeatureVariant.stripe,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NlAssistInput(
            controller: _nl,
            hintText: '예) 커피 4,500원 썼어',
            busy: controller.busy,
            submitLabel: '지출 기록',
            busyLabel: '기록 중…',
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
                  _error = controller.lastError ?? '파일에서 지출을 찾지 못했어요.';
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
                flex: 2,
                child: TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    hintText: '항목',
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '금액',
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
                child: const Text('기록'),
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
                emptyMessage: '지출 내역이 없어요',
                itemBuilder: (context, item, index) {
                  final checked = _selected.contains(item.id);
                  return ListTile(
                    tileColor: AppTheme.panel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFFD4926A).withValues(alpha: 0.35),
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
                      '₩${item.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w700,
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
