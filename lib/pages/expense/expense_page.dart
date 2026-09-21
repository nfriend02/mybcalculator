import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/expense/model/expense_controller.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';
import '../../shared/ui/widgets/paged_list_view.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();

    return FeatureScaffold(
      title: '지출 기록',
      subtitle: '합계 ₩${controller.total.toStringAsFixed(0)}',
      emoji: '💸',
      accent: AppTheme.peach,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    hintText: '항목',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
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
                    fillColor: AppTheme.peach.withValues(alpha: 0.45),
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
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PagedListView(
                  items: controller.items,
                  emptyMessage: '지출 내역이 없어요',
                  itemBuilder: (context, item, index) {
                    return ListTile(
                      tileColor: Colors.white.withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.peach,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(item.title),
                      trailing: Text(
                        '₩${item.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
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
