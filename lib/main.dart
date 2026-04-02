import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/audio_handler.dart';
import 'core/font_scale_notifier.dart';
import 'core/lyrics_service.dart';
import 'core/notification_service.dart';
import 'core/app_secrets.dart';
import 'data/repositories/app_repository.dart';
import 'features/auth/auth_gate.dart';

final audioHandlerNotifier = ValueNotifier<HanumanAudioHandler?>(null);
HanumanAudioHandler? get audioHandler => audioHandlerNotifier.value;

/// True while PlayScreen is mounted. Used by MainShell to show/hide
/// the mini-player without duplicating the screen.
final isPlayScreenOpen = ValueNotifier<bool>(false);

final lyricsService = LyricsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);

  // Load theme + font scale before the first frame so there is no
  // dark-flash on launch when the user has saved a different theme.
  try {
    final settings = await AppRepository.instance.getSettings();
    themeModeNotifier.value = ThemeMode.values[settings.themeMode.clamp(0, 2)];
    fontScaleNotifier.value = settings.fontScale.clamp(0.8, 1.4);
  } catch (e) {
    debugPrint('Pre-launch settings load failed: $e');
  }

  runApp(const HanumanChalisaApp());
  unawaited(_initServices());
}

Future<void> _initServices() async {
  // Init notifications (timezone data, plugin registration).
  try {
    await NotificationService.init();
    await NotificationService.consumeNotificationLaunchNavigation();
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

  // Flush any completions that failed to sync in a previous session.
  unawaited(AppRepository.instance.flushPendingSyncs());

  // Re-flush whenever the user signs in.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      unawaited(AppRepository.instance.flushPendingSyncs());
    }
  });

  // Apply notification schedule (settings already loaded pre-launch).
  try {
    final settings = await AppRepository.instance.getSettings();
    unawaited(NotificationService.applyReminderSchedule(settings));
  } catch (e) {
    debugPrint('Notification schedule init failed: $e');
  }
}

class HanumanChalisaApp extends StatelessWidget {
  const HanumanChalisaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Hanuman Chalisa',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: ValueListenableBuilder<double>(
            valueListenable: fontScaleNotifier,
            builder: (context, scale, _) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  // Flutter deprecates `textScaleFactor` in favor of `textScaler`.
                  textScaler: TextScaler.linear(scale),
                ),
                child: const AuthGate(),
              );
            },
          ),
        );
      },
    );
  }
}
