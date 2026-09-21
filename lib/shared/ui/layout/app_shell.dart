import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_theme.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.accent,
    required this.emoji,
  });

  final String label;
  final IconData icon;
  final String path;
  final Color accent;
  final String emoji;
}

const kNavItems = <NavItem>[
  NavItem(
    label: '홈',
    icon: Icons.home_rounded,
    path: '/',
    accent: AppTheme.mint,
    emoji: '🏠',
  ),
  NavItem(
    label: '계산기',
    icon: Icons.calculate_rounded,
    path: '/calculator',
    accent: AppTheme.peach,
    emoji: '🧮',
  ),
  NavItem(
    label: '환율',
    icon: Icons.currency_exchange_rounded,
    path: '/currency',
    accent: AppTheme.butter,
    emoji: '💱',
  ),
  NavItem(
    label: '날씨',
    icon: Icons.wb_sunny_rounded,
    path: '/weather',
    accent: AppTheme.sky,
    emoji: '🌤️',
  ),
  NavItem(
    label: '단위',
    icon: Icons.straighten_rounded,
    path: '/units',
    accent: AppTheme.lavender,
    emoji: '📏',
  ),
  NavItem(
    label: '알람',
    icon: Icons.alarm_rounded,
    path: '/alarm',
    accent: AppTheme.coral,
    emoji: '⏰',
  ),
  NavItem(
    label: '일정',
    icon: Icons.event_note_rounded,
    path: '/schedule',
    accent: AppTheme.mint,
    emoji: '📅',
  ),
  NavItem(
    label: '지출',
    icon: Icons.payments_rounded,
    path: '/expense',
    accent: AppTheme.peach,
    emoji: '💸',
  ),
  NavItem(
    label: '업로드',
    icon: Icons.cloud_upload_rounded,
    path: '/upload',
    accent: AppTheme.sky,
    emoji: '☁️',
  ),
];

NavItem? navItemForPath(String location) {
  for (final item in kNavItems) {
    if (item.path == '/') {
      if (location == '/') return item;
      continue;
    }
    if (location == item.path || location.startsWith('${item.path}/')) {
      return item;
    }
  }
  return kNavItems.first;
}

/// Bright pastel shell with **top tabs** (no sidebar).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final active = navItemForPath(location) ?? kNavItems.first;

    return DecoratedBox(
      decoration: AppTheme.pastelBackground(),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrandHeader(accent: active.accent),
              _TabStrip(location: location),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.55)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome, color: AppTheme.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Smart Calculator',
                  style: GoogleFonts.fredoka(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    color: AppTheme.ink,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideX(begin: -0.06, end: 0),
                Text(
                  '밝고 즐거운 계산 메이트',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppTheme.ink.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kNavItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = kNavItems[i];
          final selected = location == item.path ||
              (item.path != '/' && location.startsWith(item.path));
          return _TabChip(item: item, selected: selected);
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.item, required this.selected});
  final NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? item.accent
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? item.accent
                  : AppTheme.ink.withValues(alpha: 0.08),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: item.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
        );
  }
}
