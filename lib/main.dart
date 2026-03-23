import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/audio_handler.dart';
import 'core/lyrics_service.dart';
import 'features/play/play_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/profile/profile_screen.dart';

/// Notifies listeners when the audio handler is ready.
final audioHandlerNotifier = ValueNotifier<HanumanAudioHandler?>(null);
HanumanAudioHandler? get audioHandler => audioHandlerNotifier.value;

final lyricsService = LyricsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HanumanChalisaApp());
  _initServices();
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
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _screens = [
    PlayScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.play_circle_outline), label: 'Play'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Progress'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
