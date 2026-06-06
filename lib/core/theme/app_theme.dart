import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary     = Color(0xFFB57BFF);
  static const Color primaryDeep = Color(0xFF7C3AED);
  static const Color accent      = Color(0xFFFF6B9D);
  static const Color bgDeep      = Color(0xFF0A0714);
  static const Color bgCard      = Color(0xFF16102A);
  static const Color bgCardLight = Color(0xFF1E1740);
  static const Color textPrimary = Color(0xFFF0EBFF);
  static const Color textSub     = Color(0xFF9B8EC4);
  static const Color border      = Color(0xFF2D2456);

  static const Color menstrual  = Color(0xFFFF6B6B);
  static const Color follicular = Color(0xFF4ECDC4);
  static const Color ovulation  = Color(0xFFFFD93D);
  static const Color luteal     = Color(0xFFB57BFF);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgCard,
        background: bgDeep,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: primaryDeep.withOpacity(0.4),
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.plusJakartaSans(fontSize: 11, color: textSub),
        ),
      ),
      cardTheme: CardTheme(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSub),
        hintStyle: TextStyle(color: textSub.withOpacity(0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 15,
          ),
        ),
      ),
    );
  }
}