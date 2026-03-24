import 'package:flutter/material.dart';

const _saffron = Color(0xFFFF6F00);
const _deepSaffron = Color(0xFFE65100);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _saffron,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: _saffron,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _deepSaffron,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: _deepSaffron,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
);
