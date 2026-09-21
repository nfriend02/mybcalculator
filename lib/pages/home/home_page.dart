import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/config/app_config.dart';
import '../../shared/ui/widgets/fun_feature_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.title,
                style: GoogleFonts.fredoka(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              )
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    end: const Offset(1, 1),
                  ),
              const SizedBox(height: 8),
              Text(
                AppConfig.description,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: AppTheme.ink.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'by ${AppConfig.author}',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppTheme.ink.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '무엇을 도와드릴까요?',
                style: GoogleFonts.fredoka(fontSize: 22),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          delegate: SliverChildListDelegate([
            FunFeatureButton(
              label: '계산기',
              emoji: '🧮',
              color: AppTheme.peach,
              onTap: () => context.go('/calculator'),
            ),
            FunFeatureButton(
              label: '환율',
              emoji: '💱',
              color: AppTheme.butter,
              onTap: () => context.go('/currency'),
            ),
            FunFeatureButton(
              label: '날씨',
              emoji: '🌤️',
              color: AppTheme.sky,
              onTap: () => context.go('/weather'),
            ),
            FunFeatureButton(
              label: '단위 변환',
              emoji: '📏',
              color: AppTheme.lavender,
              onTap: () => context.go('/units'),
            ),
            FunFeatureButton(
              label: '알람/타이머',
              emoji: '⏰',
              color: AppTheme.coral.withValues(alpha: 0.7),
              onTap: () => context.go('/alarm'),
            ),
            FunFeatureButton(
              label: '일정',
              emoji: '📅',
              color: AppTheme.mint,
              onTap: () => context.go('/schedule'),
            ),
            FunFeatureButton(
              label: '지출',
              emoji: '💸',
              color: AppTheme.peach,
              onTap: () => context.go('/expense'),
            ),
            FunFeatureButton(
              label: '업로드',
              emoji: '☁️',
              color: AppTheme.sky,
              onTap: () => context.go('/upload'),
            ),
          ]),
        ),
      ],
    );
  }
}
