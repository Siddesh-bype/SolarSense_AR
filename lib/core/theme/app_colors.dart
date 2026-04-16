import 'package:flutter/material.dart';

class AppColors {
  // Matching solar-sense-ar/constants/colors.ts
  static const Color text = Color(0xFF0F172A);
  static const Color tint = Color(0xFFF97316);

  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF0F172A);

  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF0F172A);

  static const Color primary = Color(0xFFF97316);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF1E293B);
  static const Color secondaryForeground = Color(0xFFFFFFFF);

  static const Color muted = Color(0xFFF8FAFC);
  static const Color mutedForeground = Color(0xFF64748B);

  static const Color accent = Color(0xFFF8FAFC);
  static const Color accentForeground = Color(0xFF1E293B);

  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF22C55E);
  static const Color successForeground = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0);
  static const Color input = Color(0xFFE2E8F0);

  static const Color navy = Color(0xFF1E293B);
  static const Color navyLight = Color(0xFF334155);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color surface = Color(0xFFF8FAFC);

  // Backward compatibility for existing screens that haven't been completely rewritten
  static const Color primaryContainer = primary;
  static const Color surfaceContainerLowest = background;
  static const Color outlineVariant = border;
  static const Color onSurface = navy;
  static const Color surfaceVariant = muted;
  static const Color tertiary = navyLight;
  static const Color tertiaryContainer = navyLight;
  
  // Legacy aliases
  static const Color error = Color(0xFFEF4444);
  static const Color cardBackground = background;
  static const Color textPrimary = navy;
  static const Color iconInactive = textSecondary;
}
