import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Sacred Manuscript Design System — Hanuman Chalisa App
// Dark palette:  Deep Saffron (#ffb59a) · Vibrant Orange (#FF9500) · Charcoal Embers (#131313)
// Light palette: Deep Saffron (#a83900) · Burnt Orange (#CC5200) · Warm White (#fff8f5)

// ── Dark palette ───────────────────────────────────────────────────────────────
const _darkPrimary = Color(0xFFFFB59A);
const _darkSecondary = Color(0xFFFF9500);
const _darkTertiary = Color(0xFFFFA726);
const _darkPrimaryContainer = Color(0xFFF95E14);

// ── Light palette ──────────────────────────────────────────────────────────────
const _lightPrimary = Color(0xFFA83900);
const _lightSecondary = Color(0xFFCC5200);
const _lightTertiary = Color(0xFFD97000);
const _lightPrimaryContainer = Color(0xFFFFDBCC);

final _textTheme = TextTheme(
  displayLarge: GoogleFonts.notoSerif(fontSize: 57),
  displayMedium: GoogleFonts.notoSerif(fontSize: 45),
  displaySmall: GoogleFonts.notoSerif(fontSize: 36),
  headlineLarge: GoogleFonts.notoSerif(fontSize: 32),
  headlineMedium: GoogleFonts.notoSerif(fontSize: 28),
  headlineSmall: GoogleFonts.notoSerif(fontSize: 24),
  titleLarge: GoogleFonts.notoSerif(fontSize: 22),
  titleMedium: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w500),
  titleSmall: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500),
  bodyLarge: GoogleFonts.manrope(fontSize: 16),
  bodyMedium: GoogleFonts.manrope(fontSize: 14),
  bodySmall: GoogleFonts.manrope(fontSize: 12),
  labelLarge: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500),
  labelMedium: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500),
  labelSmall: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: _darkPrimary,
    onPrimary: Color(0xFF5B1B00),
    primaryContainer: _darkPrimaryContainer,
    onPrimaryContainer: Color(0xFF4F1700),
    secondary: _darkSecondary,
    onSecondary: Color(0xFF5D2E00),
    secondaryContainer: Color(0xFFE07040),
    onSecondaryContainer: Color(0xFF3D1600),
    tertiary: _darkTertiary,
    onTertiary: Color(0xFF5D3300),
    tertiaryContainer: Color(0xFFF0925D),
    onTertiaryContainer: Color(0xFF471E00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: Color(0xFF131313),
    onSurface: Color(0xFFE5E2E1),
    onSurfaceVariant: Color(0xFFE3BEB5),
    outline: Color(0xFFAA8981),
    outlineVariant: Color(0xFF5A413A),
    surfaceContainerLowest: Color(0xFF0E0E0E),
    surfaceContainerLow: Color(0xFF1C1B1B),
    surfaceContainer: Color(0xFF201F1F),
    surfaceContainerHigh: Color(0xFF2A2A2A),
    surfaceContainerHighest: Color(0xFF353534),
    inverseSurface: Color(0xFFE5E2E1),
    inversePrimary: Color(0xFFA83900),
  ),
  textTheme: _textTheme,
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF131313),
    foregroundColor: _darkPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.notoSerif(fontSize: 20, color: _darkPrimary),
  ),
  scaffoldBackgroundColor: const Color(0xFF131313),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? const Color(0xFF131313) : null,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? _darkPrimary : null,
    ),
  ),
);

final lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: _lightPrimary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: _lightPrimaryContainer,
    onPrimaryContainer: Color(0xFF370E00),
    secondary: _lightSecondary,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDCC8),
    onSecondaryContainer: Color(0xFF4A1800),
    tertiary: _lightTertiary,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE1C9),
    onTertiaryContainer: Color(0xFF5D2600),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFF8F5),
    onSurface: Color(0xFF201210),
    onSurfaceVariant: Color(0xFF5D3E38),
    outline: Color(0xFF8D6E63),
    outlineVariant: Color(0xFFD7BFB8),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7EDE8),
    surfaceContainer: Color(0xFFF1E5DF),
    surfaceContainerHigh: Color(0xFFEADBD4),
    surfaceContainerHighest: Color(0xFFE4D4CD),
    inverseSurface: Color(0xFF35302E),
    inversePrimary: Color(0xFFFFB59A),
  ),
  textTheme: _textTheme,
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFFFF8F5),
    foregroundColor: _lightPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.notoSerif(fontSize: 20, color: _lightPrimary),
  ),
  scaffoldBackgroundColor: const Color(0xFFFFF8F5),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? const Color(0xFFFFFFFF) : null,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? _lightPrimary : null,
    ),
  ),
);
