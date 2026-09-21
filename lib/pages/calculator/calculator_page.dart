import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/calculator/model/calculator_controller.dart';
import '../../features/calculator/ui/calculator_pad.dart';
import '../../features/voice/domain/voice_recognition_service.dart';
import '../../features/voice/ui/voice_listen_button.dart';
import '../../shared/ui/widgets/paged_list_view.dart';

class CalculatorPage extends StatelessWidget {
  const CalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = const CalculatorPad();
        final side = _HistoryAndVoice(controller: controller);

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: pad),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: side),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 3, child: pad),
            const SizedBox(height: 12),
            Expanded(flex: 2, child: side),
          ],
        );
      },
    );
  }
}

class _HistoryAndVoice extends StatelessWidget {
  const _HistoryAndVoice({required this.controller});
  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('음성 · 자연어', style: GoogleFonts.fredoka(fontSize: 20)),
        const SizedBox(height: 8),
        VoiceListenButton(
          onResult: (result, raw) async {
            switch (result.intent) {
              case VoiceIntent.calculate:
              case VoiceIntent.money:
                await controller.applyNaturalLanguage(raw);
              case VoiceIntent.currency:
                await controller.applyNaturalLanguage(
                  '${result.amount} ${result.fromCurrency} → KRW 변환은 환율 탭에서!',
                );
              case VoiceIntent.weather:
                await controller.applyNaturalLanguage(
                  '${result.city} 날씨는 날씨 탭에서 확인해요!',
                );
              case VoiceIntent.unknown:
                await controller.applyNaturalLanguage(raw);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          '예: "삼십 나누기 삼은?", "만원짜리 칼국수 세 그릇"',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppTheme.ink.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 16),
        Text('최근 계산', style: GoogleFonts.fredoka(fontSize: 18)),
        const SizedBox(height: 8),
        Expanded(
          child: PagedListView(
            items: controller.history,
            itemBuilder: (context, item, index) {
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: Colors.white.withValues(alpha: 0.75),
                title: Text(item.expression, maxLines: 1),
                subtitle: Text('= ${item.result} · ${item.source}'),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.mint,
                  child: Text('${index + 1}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
