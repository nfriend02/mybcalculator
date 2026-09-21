import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sentul dark theme — deep espresso + warm gold.
class AppTheme {
  static const Color bg = Color(0xFF0C0B0A);
  static const Color surface = Color(0xFF151311);
  static const Color surfaceElevated = Color(0xFF1C1916);
  static const Color panel = Color(0xFF1A1714);
  static const Color border = Color(0xFF2E2924);
  static const Color gold = Color(0xFFD4A054);
  static const Color goldDeep = Color(0xFFB8843A);
  static const Color textPrimary = Color(0xFFF4EFE6);
  static const Color textSecondary = Color(0xFFA3998D);
  static const Color textMuted = Color(0xFF6F675E);
  static const Color dangerBg = Color(0xFF3A2220);
  static const Color dangerBorder = Color(0xFF6B3A36);
  static const Color dangerText = Color(0xFFE8B4AE);
  static const Color keyFace = Color(0xFF24201C);
  static const Color keyOp = Color(0xFF2C2823);

  // Legacy aliases (secondary feature pages)
  static const Color ink = textPrimary;
  static const Color coral = gold;
  static const Color mint = Color(0xFF2A322C);
  static const Color peach = Color(0xFF322820);
  static const Color lavender = Color(0xFF2A2630);
  static const Color butter = Color(0xFF322C20);
  static const Color sky = Color(0xFF222830);
  static const Color softWhite = surface;

  static ThemeData light() => dark();

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldDeep,
        surface: surface,
        onPrimary: Color(0xFF1A1208),
        onSurface: textPrimary,
        error: Color(0xFFE57373),
      ),
    );

    final text = GoogleFonts.notoSansKrTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF1A1208),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.notoSansKr(
          color: textSecondary,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerColor: border,
    );
  }

  static BoxDecoration pastelBackground() => pageBackground();

  static BoxDecoration pageBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF100E0C),
          Color(0xFF0C0B0A),
          Color(0xFF0A0908),
        ],
      ),
    );
  }

  static BoxDecoration panelDecoration({bool emphasize = false}) {
    return BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: emphasize ? gold.withValues(alpha: 0.45) : border,
      ),
    );
  }
}
