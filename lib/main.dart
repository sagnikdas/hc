import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/audio_handler.dart';
import 'core/lyrics_service.dart';
import 'core/notification_service.dart';
import 'core/app_secrets.dart';
import 'features/auth/auth_gate.dart';

final audioHandlerNotifier = ValueNotifier<HanumanAudioHandler?>(null);
HanumanAudioHandler? get audioHandler => audioHandlerNotifier.value;

final lyricsService = LyricsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  runApp(const HanumanChalisaApp());
  unawaited(_initServices());
}

Future<void> _initServices() async {
  // Init notifications (timezone data, plugin registration).
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  try {
    audioHandlerNotifier.value = await initAudioHandler();
  } catch (e) {
    debugPrint('AudioService init failed: $e');
  }

  try {
    await lyricsService.load();
    debugPrint('LyricsService loaded ${lyricsService.lines.length} lines');
  } catch (e, st) {
    debugPrint('LyricsService load failed: $e\n$st');
  }
}

class HanumanChalisaApp extends StatelessWidget {
  const HanumanChalisaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hanuman Chalisa',
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}
