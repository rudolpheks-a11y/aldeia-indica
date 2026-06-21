import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  /// Corpo e interface em Inter; títulos/destaques em Poppins.
  static TextTheme _buildTextTheme(TextTheme base) {
    final body = GoogleFonts.interTextTheme(base);
    return body.copyWith(
      displayLarge: GoogleFonts.poppins(textStyle: body.displayLarge, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.poppins(textStyle: body.displayMedium, fontWeight: FontWeight.w700),
      displaySmall: GoogleFonts.poppins(textStyle: body.displaySmall, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.poppins(textStyle: body.headlineLarge, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.poppins(textStyle: body.headlineMedium, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(textStyle: body.headlineSmall, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.poppins(textStyle: body.titleLarge, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
        textTheme: _buildTextTheme(base.textTheme),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
    );
  }
}
