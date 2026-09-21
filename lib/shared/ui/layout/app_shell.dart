import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_theme.dart';
import '../../config/breakpoints.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.accent,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final String path;
  final Color accent;

  /// Visual variation key for each menu screen.
  final String variant;
}

/// Top tab menus (upload lives only in the desktop sidebar).
const kNavItems = <NavItem>[
  NavItem(
    label: '계산기',
    icon: Icons.calculate_rounded,
    path: '/',
    accent: AppTheme.gold,
    variant: 'calculator',
  ),
  NavItem(
    label: '환율',
    icon: Icons.currency_exchange_rounded,
    path: '/currency',
    accent: Color(0xFFC9A227),
    variant: 'currency',
  ),
  NavItem(
    label: '날씨',
    icon: Icons.wb_sunny_rounded,
    path: '/weather',
    accent: Color(0xFFD4B896),
    variant: 'weather',
  ),
  NavItem(
    label: '단위',
    icon: Icons.straighten_rounded,
    path: '/units',
    accent: Color(0xFFB8A48A),
    variant: 'units',
  ),
  NavItem(
    label: '알람',
    icon: Icons.alarm_rounded,
    path: '/alarm',
    accent: Color(0xFFE08A5A),
    variant: 'alarm',
  ),
  NavItem(
    label: '일정',
    icon: Icons.event_note_rounded,
    path: '/schedule',
    accent: Color(0xFFA8967A),
    variant: 'schedule',
  ),
  NavItem(
    label: '지출',
    icon: Icons.payments_rounded,
    path: '/expense',
    accent: Color(0xFFD4926A),
    variant: 'expense',
  ),
];

const kUploadNavItem = NavItem(
  label: '업로드',
  icon: Icons.cloud_upload_rounded,
  path: '/upload',
  accent: Color(0xFFBFA87A),
  variant: 'upload',
);

NavItem navItemForPath(String location) {
  if (location == kUploadNavItem.path ||
      location.startsWith('${kUploadNavItem.path}/')) {
    return kUploadNavItem;
  }
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

/// Desktop: logo-only left sidebar + tabs + content.
/// Mobile: logo row + horizontal tabs + content (no upload entry).
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
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: DecoratedBox(
        decoration: AppTheme.pageBackground(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = Breakpoints.isDesktop(constraints.maxWidth);

            // Upload is sidebar-only — leave the page on narrow layouts.
            if (!desktop &&
                (location == kUploadNavItem.path ||
                    location.startsWith('${kUploadNavItem.path}/'))) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/');
              });
            }

            final content = Material(
              type: MaterialType.transparency,
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LogoSidebar(location: location),
                        Expanded(
                          child: SafeArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _TabBar(location: location),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      4,
                                      24,
                                      16,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _MobileLogoBar(),
                          _TabBar(location: location, compact: true),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    ),
            );
            return content;
          },
        ),
      ),
    );
  }
}

/// Left sidebar: logo at top, upload button at bottom (desktop only).
class _LogoSidebar extends StatelessWidget {
  const _LogoSidebar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final uploadSelected = location == kUploadNavItem.path ||
        location.startsWith('${kUploadNavItem.path}/');

    return Container(
      width: 132,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 18, 10, 8),
              child: _BrandLogo(compact: true),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              child: Tooltip(
                message: kUploadNavItem.label,
                child: Material(
                  color: uploadSelected
                      ? kUploadNavItem.accent.withValues(alpha: 0.25)
                      : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => context.go(kUploadNavItem.path),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: uploadSelected
                              ? kUploadNavItem.accent
                              : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            kUploadNavItem.icon,
                            size: 22,
                            color: uploadSelected
                                ? kUploadNavItem.accent
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kUploadNavItem.label,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: uploadSelected
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLogoBar extends StatelessWidget {
  const _MobileLogoBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _BrandLogo(compact: false),
      ),
    );
  }
}

/// Calligraphy wordmark — 나의 만능 AI 비서 (no Sentul mark).
class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 118.0 : 56.0;
    return Semantics(
      label: '나의 만능 AI 비서',
      child: Image.asset(
        'assets/images/brand_logo.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _CalligraphyFallback(compact: compact),
      ),
    );
  }
}

/// Text fallback if the logo asset fails to load.
class _CalligraphyFallback extends StatelessWidget {
  const _CalligraphyFallback({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.nanumBrushScript(
      color: AppTheme.gold,
      height: 1.15,
      fontWeight: FontWeight.w600,
      fontSize: compact ? 28 : 32,
      shadows: [
        Shadow(
          color: AppTheme.gold.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (compact) {
      return Text(
        '나의\n만능 AI\n비서',
        textAlign: TextAlign.center,
        style: style,
      );
    }

    return Text(
      '나의 만능 AI 비서',
      style: style.copyWith(fontSize: 36),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.location, this.compact = false});

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 56 : 60,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kNavItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = kNavItems[i];
          final selected = item.path == '/'
              ? location == '/'
              : location == item.path || location.startsWith('${item.path}/');
          return _TabChip(
            item: item,
            selected: selected,
            index: i + 1,
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.item,
    required this.selected,
    required this.index,
  });

  final NavItem item;
  final bool selected;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? item.accent.withValues(alpha: 0.22)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? item.accent : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$index',
                style: GoogleFonts.notoSansKr(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? item.accent : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                item.icon,
                size: 16,
                color: selected ? item.accent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
