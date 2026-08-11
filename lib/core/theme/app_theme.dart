import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Design tokens + Material 3 theme for SolarSense.
///
/// Palette: solar-orange primary with slate truth-tone neutrals (matches
/// solar-sense-ar/constants/colors.ts).
/// Typography: Inter (display + body), with tight-tracked bold heads.
class AppTheme {
  // ── Color schemes ──────────────────────────────────────────────────────────
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF97316),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFEDD5),
    onPrimaryContainer: Color(0xFF7C2D12),
    secondary: Color(0xFF1E293B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE2E8F0),
    onSecondaryContainer: Color(0xFF0F172A),
    tertiary: Color(0xFF334155),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE2E8F0),
    onTertiaryContainer: Color(0xFF1E293B),
    error: Color(0xFFEF4444),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFE2E8F0),
    surfaceContainerHighest: Color(0xFFCBD5E1),
    onSurfaceVariant: Color(0xFF64748B),
    outline: Color(0xFF94A3B8),
    outlineVariant: Color(0xFFE2E8F0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1E293B),
    inversePrimary: Color(0xFFFDBA74),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFB923C),
    onPrimary: Color(0xFF431407),
    primaryContainer: Color(0xFF7C2D12),
    onPrimaryContainer: Color(0xFFFFEDD5),
    secondary: Color(0xFF94A3B8),
    onSecondary: Color(0xFF0F172A),
    secondaryContainer: Color(0xFF1E293B),
    onSecondaryContainer: Color(0xFFCBD5E1),
    tertiary: Color(0xFFCBD5E1),
    onTertiary: Color(0xFF0F172A),
    tertiaryContainer: Color(0xFF334155),
    onTertiaryContainer: Color(0xFFF1F5F9),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFECACA),
    surface: Color(0xFF1E293B),
    onSurface: Color(0xFFF1F5F9),
    surfaceContainerLowest: Color(0xFF0F172A),
    surfaceContainerLow: Color(0xFF1E293B),
    surfaceContainer: Color(0xFF273443),
    surfaceContainerHigh: Color(0xFF334155),
    surfaceContainerHighest: Color(0xFF3F4C5F),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF64748B),
    outlineVariant: Color(0xFF334155),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFF1F5F9),
    inversePrimary: Color(0xFFC2410C),
  );

  static ThemeData get light => _build(_lightScheme, SolarPalette.light);
  static ThemeData get dark => _build(_darkScheme, SolarPalette.dark);

  static ThemeData _build(ColorScheme scheme, SolarPalette p) {
    final baseText = GoogleFonts.interTextTheme(
      Typography.material2021().black,
    );

    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1.0),
      displayMedium: GoogleFonts.inter(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8),
      displaySmall: GoogleFonts.inter(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineLarge: GoogleFonts.inter(fontSize: 22, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: GoogleFonts.inter(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      headlineSmall: GoogleFonts.inter(fontSize: 18, height: 1.35, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.inter(fontSize: 17, height: 1.3, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.inter(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.inter(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.inter(fontSize: 12, height: 1.4, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(fontSize: 15, height: 1.2, fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.inter(fontSize: 13, height: 1.2, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.inter(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.4),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final radius = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
        systemOverlayStyle: scheme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: radius,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.border, width: 1.5),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: radius,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: p.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary,
        disabledColor: p.surfaceMuted,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        elevation: 0,
      ),

      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.inversePrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: ThemeData.light().inputDecorationTheme.copyWith(
              filled: true,
              fillColor: p.surface,
            ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primarySoft,
        selectionHandleColor: p.primary,
      ),
    );
  }
}