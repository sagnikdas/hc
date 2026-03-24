import 'dart:async';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/audio_handler.dart';
import 'core/lyrics_service.dart';
import 'core/analytics.dart';
import 'core/reminder_service.dart';
import 'core/referral_service.dart';
import 'data/models/cloud_stats.dart';
import 'data/models/entitlement.dart';
import 'features/play/play_screen.dart';

/// Notifies listeners when the audio handler is ready.
final audioHandlerNotifier = ValueNotifier<HanumanAudioHandler?>(null);
HanumanAudioHandler? get audioHandler => audioHandlerNotifier.value;

final lyricsService = LyricsService();

// Legacy globals kept as no-op placeholders so non-player modules still compile.
final entitlementNotifier = ValueNotifier<Entitlement>(Entitlement.free);
final cloudStatsNotifier = ValueNotifier<CloudStats?>(null);
final reminderService = NoOpReminderService();
final referralService = ReferralService();
final analyticsService = const NoOpAnalyticsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HanumanChalisaApp());
  unawaited(_initServices());
}

Future<void> _initServices() async {
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const PlayScreen(),
    );
  }
}
