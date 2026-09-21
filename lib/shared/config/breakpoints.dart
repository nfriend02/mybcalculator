/// Shared breakpoints for responsive layout rules.
abstract final class Breakpoints {
  /// Mobile: ≤768px — top nav row + content below.
  static const double mobileMax = 768;

  /// Desktop: ≥769px — left sidebar + right content.
  static const double desktopMin = 769;

  static bool isMobile(double width) => width <= mobileMax;
  static bool isDesktop(double width) => width >= desktopMin;
}

/// Page-unit scroll (10 items per page).
abstract final class PaginationRules {
  static const int pageSize = 10;
}
