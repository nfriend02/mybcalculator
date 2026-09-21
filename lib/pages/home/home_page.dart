import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/config/app_config.dart';
import '../../shared/ui/layout/app_shell.dart';
import '../../shared/ui/widgets/fun_feature_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.mint.withValues(alpha: 0.9),
                  AppTheme.sky.withValues(alpha: 0.55),
                  AppTheme.lavender.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConfig.title,
                  style: GoogleFonts.fredoka(
                    fontSize: 36,
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
                    fontSize: 15,
                    color: AppTheme.ink.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'by ${AppConfig.author}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppTheme.ink.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Text(
            '탭으로 바로 이동',
            style: GoogleFonts.fredoka(fontSize: 22),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          delegate: SliverChildListDelegate([
            for (final item in kNavItems.where((e) => e.path != '/'))
              FunFeatureButton(
                label: item.label,
                emoji: item.emoji,
                color: item.accent,
                onTap: () => context.go(item.path),
              ),
          ]),
        ),
      ],
    );
  }
}
