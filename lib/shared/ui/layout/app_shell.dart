import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/breakpoints.dart';
import '../../../app/theme/app_theme.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.accent,
    this.emoji = '',
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

/// Responsive shell:
/// - Desktop (≥769): left sidebar + right content
/// - Mobile (≤768): top horizontal menu + content below
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = Breakpoints.isMobile(constraints.maxWidth);
        return DecoratedBox(
          decoration: AppTheme.pastelBackground(),
          child: mobile
              ? _MobileShell(child: child)
              : _DesktopShell(child: child),
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Row(
      children: [
        SizedBox(
          width: 240,
          child: Material(
            color: Colors.white.withValues(alpha: 0.55),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: _BrandLogo(compact: false),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final item in kNavItems)
                          _DesktopNavTile(
                            item: item,
                            selected: location == item.path ||
                                (item.path != '/' &&
                                    location.startsWith(item.path)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'MyBranch · Portfolio',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppTheme.ink.withValues(alpha: 0.45),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _BrandLogo(compact: true),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: kNavItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = kNavItems[i];
                final selected = location == item.path ||
                    (item.path != '/' && location.startsWith(item.path));
                return _MobileNavChip(item: item, selected: selected);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'AI Smart\nCalculator',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.fredoka(
            fontSize: compact ? 28 : 34,
            height: 1.05,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: -0.12, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 4),
        Text(
          '밝고 즐거운 계산 메이트 ✨',
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppTheme.ink.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _DesktopNavTile extends StatefulWidget {
  const _DesktopNavTile({required this.item, required this.selected});
  final NavItem item;
  final bool selected;

  @override
  State<_DesktopNavTile> createState() => _DesktopNavTileState();
}

class _DesktopNavTileState extends State<_DesktopNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: widget.selected || _hover
                ? widget.item.accent.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: Icon(widget.item.icon, color: AppTheme.ink),
            title: Text(
              '${widget.item.emoji} ${widget.item.label}',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
            selected: widget.selected,
            onTap: () => context.go(widget.item.path),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavChip extends StatelessWidget {
  const _MobileNavChip({required this.item, required this.selected});
  final NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.path),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? item.accent
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? item.accent
                : AppTheme.ink.withValues(alpha: 0.08),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: item.accent.withValues(alpha: 0.35),
                    blurRadius: 10,
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
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          duration: 250.ms,
        );
  }
}
