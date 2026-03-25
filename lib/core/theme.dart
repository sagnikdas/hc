import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Sacred Manuscript Design System — Hanuman Chalisa App
// Palette: Deep Saffron (#ffb59a) · Celestial Gold (#e9c349) · Charcoal Embers (#131313)

const _primary = Color(0xFFFFB59A);
const _secondary = Color(0xFFE9C349);
const _tertiary = Color(0xFFFFBA38);
const _primaryContainer = Color(0xFFF95E14);

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
    primary: _primary,
    onPrimary: Color(0xFF5B1B00),
    primaryContainer: _primaryContainer,
    onPrimaryContainer: Color(0xFF4F1700),
    secondary: _secondary,
    onSecondary: Color(0xFF3C2F00),
    secondaryContainer: Color(0xFFAF8D11),
    onSecondaryContainer: Color(0xFF342800),
    tertiary: _tertiary,
    onTertiary: Color(0xFF432C00),
    tertiaryContainer: Color(0xFFC08600),
    onTertiaryContainer: Color(0xFF3A2600),
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
    foregroundColor: _primary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.notoSerif(fontSize: 20, color: _primary),
  ),
  scaffoldBackgroundColor: const Color(0xFF131313),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? const Color(0xFF131313) : null,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? _primary : null,
    ),
  ),
);

