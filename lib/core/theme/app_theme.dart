import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.onSurface),
        titleTextStyle: TextStyle(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.w800),
        titleMedium: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        titleSmall: GoogleFonts.manrope(color: AppColors.onSurface, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryContainer,
          side: const BorderSide(color: AppColors.primaryContainer, width: 1.5),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
