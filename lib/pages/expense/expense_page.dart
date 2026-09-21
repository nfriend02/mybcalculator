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
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _nl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();

    return FeatureScaffold(
      title: '지출 기록',
      subtitle: '합계 ₩${controller.total.toStringAsFixed(0)}',
      emoji: '💸',
      accent: const Color(0xFFD4926A),
      variant: FeatureVariant.stripe,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NlAssistInput(
            controller: _nl,
            hintText: '예) 커피 4,500원 썼어',
            busy: controller.busy,
            submitLabel: '지출 기록',
            busyLabel: '기록 중…',
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
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final a = double.tryParse(_amount.text) ?? 0;
                  if (_title.text.trim().isEmpty || a <= 0) return;
                  await controller.add(_title.text.trim(), a);
                  _title.clear();
                  _amount.clear();
                },
                child: const Text('기록'),
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
                  emptyMessage: '지출 내역이 없어요',
                  itemBuilder: (context, item, index) {
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
                      title: Text(item.title),
                      trailing: Text(
                        '₩${item.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
