import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kBrand = Color(0xFF2EACEB);

/// Bottom padding for scrollable page content so the floating curved nav bar
/// (which the body extends behind) never hides the last item.
const double kNavInset = 96;

/// Soft card shadow used instead of borders on list items / cards.
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
];

const AppBarTheme _brandAppBar = AppBarTheme(
  backgroundColor: kBrand,
  foregroundColor: Colors.white,
  elevation: 0,
  scrolledUnderElevation: 0,
  centerTitle: false,
  systemOverlayStyle: SystemUiOverlayStyle.light,
  titleTextStyle: TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  ),
  iconTheme: IconThemeData(color: Colors.white),
);

const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF5AC6F0), Color(0xFF2EACEB), Color(0xFF1A93D6)],
);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
  ).copyWith(primary: kBrand);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3F7FB),
    appBarTheme: _brandAppBar,
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.dark,
  ).copyWith(primary: kBrand);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0C1922),
    appBarTheme: _brandAppBar,
    cardTheme: const CardThemeData(
      color: Color(0xFF13232E),
      elevation: 0,
    ),
  );
}
