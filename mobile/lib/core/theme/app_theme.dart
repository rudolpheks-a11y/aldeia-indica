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
    // Roles explícitos — ColorScheme.fromSeed sintetizaria tons que não
    // batem com as âncoras aprovadas (primary-700 / secondary-500), e essa
    // divergência vaza para Switch, Chip e cursor de TextField.
    const scheme = ColorScheme.light(
      primary: AppColors.primary700,
      onPrimary: AppColors.neutral0,
      secondary: AppColors.secondary500,
      onSecondary: AppColors.neutral900,
      error: AppColors.error900,
      onError: AppColors.neutral0,
      surface: AppColors.neutral0,
      onSurface: AppColors.neutral900,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
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
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary700, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error900, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary700
                  : AppColors.neutral0),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary200
                  : AppColors.neutral300),
        ),
        chipTheme: base.chipTheme.copyWith(
          selectedColor: AppColors.primary100,
          backgroundColor: AppColors.neutral50,
          labelStyle: const TextStyle(color: AppColors.neutral600),
          secondarySelectedColor: AppColors.primary100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: const BorderSide(color: AppColors.neutral300),
          ),
        ),
    );
  }
}
