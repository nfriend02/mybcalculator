import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bright pastel theme — playful, logo-forward.
class AppTheme {
  static const Color mint = Color(0xFFB8E8D4);
  static const Color peach = Color(0xFFFFD6C9);
  static const Color lavender = Color(0xFFE0D4FF);
  static const Color butter = Color(0xFFFFF0B3);
  static const Color sky = Color(0xFFC5E8FF);
  static const Color coral = Color(0xFFFF8F8F);
  static const Color ink = Color(0xFF2D3436);
  static const Color softWhite = Color(0xFFFFFBF7);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: coral,
        secondary: Color(0xFF7EC8E3),
        tertiary: Color(0xFFB39DDB),
        surface: softWhite,
        onPrimary: Colors.white,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: softWhite,
    );

    return base.copyWith(
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static BoxDecoration pastelBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF5F0),
          Color(0xFFE8F8F5),
          Color(0xFFF3EEFF),
          Color(0xFFFFF8E7),
        ],
      ),
    );
  }
}
