import 'package:flutter/material.dart';

/// Global notifier driving [MaterialApp.themeMode].
/// Persisted via [UserSettings.themeMode] in SQLite (0=system, 1=light, 2=dark).
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
