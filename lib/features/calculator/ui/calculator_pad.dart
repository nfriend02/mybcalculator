import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_theme.dart';
import '../model/calculator_controller.dart';

/// Classic calculator pad — wide pill keys, fixed aspect, no overflow.
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            // Fixed display height; FittedBox below prevents overflow.
            final displayH =
                math.min(110.0, math.max(80.0, constraints.maxHeight * 0.22));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: displayH,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    // FittedBox scales the whole readout so it never overflows.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            controller.expression.isEmpty
                                ? ' '
                                : controller.expression,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 12,
                              height: 1.2,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.display,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: gap),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, gridConstraints) {
                      const cols = 4;
                      const rows = 5;
                      const cellGap = 8.0;
                      // ~2× previous horizontal aspect (1.35 → 2.7): wide pills.
                      const cellAspect = 2.7; // width / height

                      final budgetW = gridConstraints.maxWidth;
                      final budgetH = gridConstraints.maxHeight;
                      final maxCellW =
                          (budgetW - cellGap * (cols - 1)) / cols;
                      final maxCellH =
                          (budgetH - cellGap * (rows - 1)) / rows;

                      // Prefer filling width; scale down uniformly if height is tight.
                      var cellW = maxCellW;
                      var cellH = cellW / cellAspect;
                      if (cellH > maxCellH) {
                        cellH = maxCellH;
                        cellW = cellH * cellAspect;
                      }

                      final gridW = cellW * cols + cellGap * (cols - 1);
                      final gridH = cellH * rows + cellGap * (rows - 1);
                      final keyFont = (cellH * 0.48).clamp(15.0, 24.0);

                      return Center(
                        child: SizedBox(
                          width: gridW,
                          height: gridH,
                          child: Column(
                            children: [
                              for (var r = 0; r < _rows.length; r++) ...[
                                if (r > 0) const SizedBox(height: cellGap),
                                SizedBox(
                                  height: cellH,
                                  child: Row(
                                    children: [
                                      for (var c = 0;
                                          c < _rows[r].length;
                                          c++) ...[
                                        if (c > 0)
                                          const SizedBox(width: cellGap),
                                        SizedBox(
                                          width: cellW,
                                          height: cellH,
                                          child: _CalcKey(
                                            label: _label(_rows[r][c]),
                                            token: _rows[r][c],
                                            fontSize: keyFont,
                                            onTap: () => controller.input(
                                              _rows[r][c] == 'back'
                                                  ? '⌫'
                                                  : _rows[r][c],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
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
    required this.fontSize,
  });

  final String label;
  final String token;
  final VoidCallback onTap;
  final double fontSize;

  bool get _isEquals => token == '=';
  bool get _isOp => '+-*/()'.contains(token) || token == 'C' || token == 'back';

  @override
  Widget build(BuildContext context) {
    final bg = _isEquals
        ? AppTheme.gold
        : _isOp
            ? AppTheme.keyOp
            : AppTheme.keyFace;
    final fg = _isEquals ? const Color(0xFF1A1208) : AppTheme.textPrimary;
    // Pill radius from height so wide buttons stay capsule-shaped, not circles.
    final radius = 999.0;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
