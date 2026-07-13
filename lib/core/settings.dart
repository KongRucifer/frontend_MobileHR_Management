import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage.dart';

// ---- Theme ----
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier()
      : super(Storage.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light);

  void toggle() {
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    Storage.setThemeMode(isDark ? 'light' : 'dark');
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

// ---- Language ----
class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super(Storage.lang);

  void set(String lang) {
    state = lang;
    Storage.setLang(lang);
  }

  void toggle() => set(state == 'lo' ? 'en' : 'lo');
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, String>((ref) => LocaleNotifier());
