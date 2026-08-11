// lib/services/app_settings.dart
//
// Lightweight app-wide settings. Light mode is the default; the theme toggle
// in Settings flips between light/dark for the current session.

import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void setDark(bool value) {
    if (_themeMode == (value ? ThemeMode.dark : ThemeMode.light)) return;
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
