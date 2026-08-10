import 'package:flutter/material.dart';

/// Brand tokens for SolarMitra.
///
/// Palette direction (ui-ux-pro-max design system): nature emerald trust-green
/// as the primary, with a solar-gold accent. Values are picked so that body
/// text holds >=4.5:1 contrast on their surfaces in both themes.
class AppColors {
  // ── Brand (constant across light/dark) ─────────────────────────────────────
  static const Color primary = Color(0xFF059669); // emerald-600 — CTA fills
  static const Color primaryDeep = Color(0xFF047857); // emerald-700 — small text
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF0B6B4F); // deep emerald accent
  static const Color secondarySoft = Color(0xFFD1FAE5); // emerald-100 container

  static const Color gold = Color(0xFFFBBF24); // solar-gold — decorative/glow
  static const Color goldDeep = Color(0xFFA16207); // solar-gold — AA text
  static const Color goldSoft = Color(0xFFFEF3C7); // solar-gold container

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFDE0DE);

  // ── Legacy aliases (light values) — retained so untouched references stay
  //    valid. Prefer AppColors.of(context) in new code.
  static const Color text = Color(0xFF06261F);
  static const Color tint = gold;
  static const Color foreground = text;
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = text;
  static const Color primaryForeground = onPrimary;
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFEDF5F1);
  static const Color mutedForeground = Color(0xFF3E5E54);
  static const Color accent = muted;
  static const Color accentForeground = text;
  static const Color destructive = error;
  static const Color destructiveForeground = onPrimary;
  static const Color successForeground = onPrimary;
  static const Color border = Color(0xFFD8EAE0);
  static const Color input = border;
  static const Color navy = Color(0xFF06261F);
  static const Color navyLight = Color(0xFF33524A);
  static const Color textSecondary = Color(0xFF3E5E54);
  static const Color surface = Color(0xFFF2F7F4);
  static const Color background = Color(0xFFF2F7F4);

  static const Color primaryContainer = primary;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color outlineVariant = border;
  static const Color onSurface = navy;
  static const Color surfaceVariant = muted;
  static const Color tertiary = goldDeep;
  static const Color tertiaryContainer = goldSoft;
  static const Color errorColor = error;
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = text;
  static const Color iconInactive = Color(0xFF7B918C);

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
  final Color primary; // emerald fills
  final Color primarySoft; // emerald tint containers
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
    background: Color(0xFFF2F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF5F1),
    onSurface: Color(0xFF06261F),
    onSurfaceMuted: Color(0xFF3E5E54),
    border: Color(0xFFD8EAE0),
    primary: Color(0xFF059669),
    primarySoft: Color(0xFFD1FAE5),
    onPrimary: Color(0xFFFFFFFF),
    gold: Color(0xFFFBBF24),
    goldSoft: Color(0xFFFEF3C7),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFDCFCE7),
    error: Color(0xFFDC2626),
  );

  static const SolarPalette dark = SolarPalette(
    background: Color(0xFF0B1914),
    surface: Color(0xFF12261F),
    surfaceMuted: Color(0xFF1A2E27),
    onSurface: Color(0xFFE3F0EB),
    onSurfaceMuted: Color(0xFFA9C2B8),
    border: Color(0xFF335048),
    primary: Color(0xFF34D399),
    primarySoft: Color(0xFF124232),
    onPrimary: Color(0xFF06372B),
    gold: Color(0xFFF5C542),
    goldSoft: Color(0xFF3D3217),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF123A22),
    error: Color(0xFFF87171),
  );
}