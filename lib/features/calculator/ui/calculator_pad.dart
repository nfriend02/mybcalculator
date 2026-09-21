import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../model/calculator_controller.dart';

class CalculatorPad extends StatelessWidget {
  const CalculatorPad({super.key});

  static const _keys = [
    ['C', '⌫', '(', ')'],
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '－'],
    ['0', '.', '＝', '＋'],
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.peach.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                controller.expression.isEmpty ? ' ' : controller.expression,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppTheme.ink.withValues(alpha: 0.45),
                ),
              ),
              Text(
                controller.display,
                style: GoogleFonts.fredoka(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final row in _keys) ...[
          Expanded(
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _CalcKey(
                        label: key,
                        onTap: () => controller.input(key),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  Color get _bg {
    if (label == '＝') return AppTheme.coral;
    if ('＋－×÷()'.contains(label)) return AppTheme.lavender;
    if (label == 'C' || label == '⌫') return AppTheme.peach;
    return AppTheme.mint;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: label == '＝' ? Colors.white : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
