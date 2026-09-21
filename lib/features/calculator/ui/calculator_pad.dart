import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../model/calculator_controller.dart';

class CalculatorPad extends StatelessWidget {
  const CalculatorPad({super.key, required this.controller});

  final CalculatorController controller;

  static const _rows = <List<String>>[
    ['C', 'back', '(', ')'],
    ['7', '8', '9', '/'],
    ['4', '5', '6', '*'],
    ['1', '2', '3', '-'],
    ['0', '.', '=', '+'],
  ];

  static String _label(String token) {
    return switch (token) {
      'back' => '⌫',
      '/' => '÷',
      '*' => '×',
      '-' => '−',
      _ => token,
    };
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder avoids Provider lookup failures inside nested builds.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.peach.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.peach.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    controller.expression.isEmpty ? ' ' : controller.expression,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.ink.withValues(alpha: 0.45),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      controller.display,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                children: [
                  for (final row in _rows)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final token in row)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: _CalcKey(
                                  label: _label(token),
                                  token: token,
                                  onTap: () => controller.input(
                                    token == 'back' ? '⌫' : token,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.label,
    required this.token,
    required this.onTap,
  });

  final String label;
  final String token;
  final VoidCallback onTap;

  Color get _bg {
    if (token == '=') return AppTheme.coral;
    if ('+-*/()'.contains(token)) return AppTheme.lavender;
    if (token == 'C' || token == 'back') return AppTheme.peach;
    return AppTheme.mint;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: token == '=' ? Colors.white : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
