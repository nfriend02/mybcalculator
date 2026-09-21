import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/calculator/model/calculator_controller.dart';
import '../../features/calculator/ui/calculator_pad.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _nl = TextEditingController();

  @override
  void dispose() {
    _nl.dispose();
    super.dispose();
  }

  Future<void> _runNaturalLanguage(CalculatorController controller) async {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    await controller.applyNaturalLanguage(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();

    return FeatureScaffold(
      title: '스마트 계산기',
      subtitle: '버튼을 누르거나 문장으로 계산해 보세요',
      emoji: '🧮',
      accent: AppTheme.peach,
      scrollable: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final pad = CalculatorPad(controller: controller);
          final side = _SidePanel(
            controller: controller,
            nlController: _nl,
            onSubmit: () => _runNaturalLanguage(controller),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: pad),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(child: side),
                ),
              ],
            );
          }

          return ListView(
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.58).clamp(340.0, 520.0),
                child: pad,
              ),
              const SizedBox(height: 12),
              side,
            ],
          );
        },
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.controller,
    required this.nlController,
    required this.onSubmit,
  });

  final CalculatorController controller;
  final TextEditingController nlController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final history = controller.history;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.peach.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '자연어 계산',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nlController,
            decoration: InputDecoration(
              hintText: '예: 삼십 나누기 삼은?',
              filled: true,
              fillColor: AppTheme.peach.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onSubmit,
            child: const Text('계산하기'),
          ),
          const SizedBox(height: 16),
          Text(
            '최근 계산',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Text(
              '아직 계산 기록이 없어요',
              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
            )
          else
            ...history.take(8).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppTheme.mint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    title: Text(item.expression, maxLines: 1),
                    subtitle: Text('= ${item.result}'),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
