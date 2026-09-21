import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/alarm/model/alarm_timer_controller.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<AlarmTimerController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('알람 / 타이머', style: GoogleFonts.fredoka(fontSize: 28)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.coral.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            timer.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(fontSize: 56),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final m in [1, 5, 10, 15, 30])
              ActionChip(
                label: Text('$m분'),
                onPressed: () => timer.setMinutes(m),
                backgroundColor: AppTheme.butter,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: timer.running ? null : timer.start,
                child: const Text('시작'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: timer.pause,
                child: const Text('일시정지'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: timer.reset,
                child: const Text('리셋'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
