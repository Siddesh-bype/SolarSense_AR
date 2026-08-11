import 'package:flutter/material.dart';

/// Brand tokens for SolarSense.
///
/// Palette matches solar-sense-ar/constants/colors.ts (commit d4da8e9):
/// solar-orange as the primary with slate neutrals. Values are picked so that
/// body text holds >=4.5:1 contrast on their surfaces in both themes.
class AppColors {
  // ── Brand (constant across light/dark) ─────────────────────────────────────
  static const Color primary = Color(0xFFF97316); // orange-500 — CTA fills
  static const Color primaryDeep = Color(0xFFC2410C); // orange-700 — small text
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF1E293B); // slate-800 accent
  static const Color secondarySoft = Color(0xFFE2E8F0); // slate-200 container

  static const Color gold = primary; // solar accent aligns to brand orange
  static const Color goldDeep = Color(0xFF7C2D12); // orange-900 — AA text
  static const Color goldSoft = Color(0xFFFFEDD5); // orange-100 container

  static const Color success = Color(0xFF22C55E);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEE2E2);

  // ── Legacy aliases (light values) — retained so untouched references stay
  //    valid. Prefer AppColors.of(context) in new code.
  static const Color text = Color(0xFF0F172A);
  static const Color tint = primary;
  static const Color foreground = text;
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = text;
  static const Color primaryForeground = onPrimary;
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFF8FAFC);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color accent = muted;
  static const Color accentForeground = secondary;
  static const Color destructive = error;
  static const Color destructiveForeground = onPrimary;
  static const Color successForeground = onPrimary;
  static const Color border = Color(0xFFE2E8F0);
  static const Color input = border;
  static const Color navy = Color(0xFF1E293B);
  static const Color navyLight = Color(0xFF334155);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color background = Color(0xFFFFFFFF);
  static const Color iconInactive = Color(0xFF94A3B8);

  static const Color primaryContainer = primary;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color outlineVariant = border;
  static const Color onSurface = navy;
  static const Color surfaceVariant = muted;
  static const Color tertiary = navyLight;
  static const Color tertiaryContainer = secondarySoft;
  static const Color errorColor = error;
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = text;

  /// Resolves the palette for the active brightness. New UI should read from
  /// this so light/dark stay consistent (the consts above are light-targeted).
  static SolarPalette of(BuildContext context) => SolarPalette.of(context);
}

/// Theme-aware semantic palette. Surfaces/text adapt to light/dark; brand
/// accents stay constant via [AppColors].
@immutable
class SolarPalette {
  final Color background; // scaffold
  final Color surface; // cards
  final Color surfaceMuted; // tinted containers / chips
  final Color onSurface; // primary ink
  final Color onSurfaceMuted; // secondary text
  final Color border; // hairline dividers / input strokes
  final Color primary; // orange fills
  final Color primarySoft; // orange tint containers
  final Color onPrimary;
  final Color gold; // decorative solar accent
  final Color goldSoft;
  final Color success;
  final Color successSoft;
  final Color error;

  const SolarPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.gold,
    required this.goldSoft,
    required this.success,
    required this.successSoft,
    required this.error,
  });

  static SolarPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const SolarPalette light = SolarPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF8FAFC),
    onSurface: Color(0xFF0F172A),
    onSurfaceMuted: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
    primary: Color(0xFFF97316),
    primarySoft: Color(0xFFFFEDD5),
    onPrimary: Color(0xFFFFFFFF),
    gold: Color(0xFFF97316),
    goldSoft: Color(0xFFFFEDD5),
    success: Color(0xFF22C55E),
    successSoft: Color(0xFFDCFCE7),
    error: Color(0xFFEF4444),
  );

  static const SolarPalette dark = SolarPalette(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceMuted: Color(0xFF263443),
    onSurface: Color(0xFFF1F5F9),
    onSurfaceMuted: Color(0xFF94A3B8),
    border: Color(0xFF334155),
    primary: Color(0xFFFB923C),
    primarySoft: Color(0xFF3B1A08),
    onPrimary: Color(0xFF431407),
    gold: Color(0xFFFB923C),
    goldSoft: Color(0xFF3B1A08),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF1A3A26),
    error: Color(0xFFF87171),
  );
}