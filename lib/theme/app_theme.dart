import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF00D4AA);
  static const Color primaryDark = Color(0xFF00A884);
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color bullish = Color(0xFF00D4AA);
  static const Color bearish = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFB347);
  static const Color cardBorder = Color(0xFF30363D);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          surface: surface,
          background: background,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.inter(color: textSecondary),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: cardBorder, width: 1),
          ),
          elevation: 0,
        ),
      );
}
