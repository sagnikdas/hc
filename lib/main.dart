import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/audio_handler.dart';
import 'core/lyrics_service.dart';
import 'core/purchase_service.dart';
import 'core/reminder_service.dart';
import 'core/referral_service.dart';
import 'data/models/entitlement.dart';
import 'data/repositories/entitlement_repository.dart';
import 'features/play/play_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/profile/profile_screen.dart';

/// Notifies listeners when the audio handler is ready.
final audioHandlerNotifier = ValueNotifier<HanumanAudioHandler?>(null);
HanumanAudioHandler? get audioHandler => audioHandlerNotifier.value;

final lyricsService = LyricsService();

/// Current entitlement — updated after any purchase or restore.
final entitlementNotifier = ValueNotifier<Entitlement>(Entitlement.free);

/// Swap [NoOpPurchaseService] for [RevenueCatPurchaseService] before shipping.
/// Set the real API key via a --dart-define or environment config.
final PurchaseService purchaseService = NoOpPurchaseService();

/// Swap [NoOpReminderService] for [LocalReminderService] before shipping.
final ReminderService reminderService = NoOpReminderService();

final referralService = ReferralService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HanumanChalisaApp());
  _initServices();
}

Future<void> _initServices() async {
  // Restore saved entitlement immediately so the UI has correct state.
  try {
    final saved = await SqliteEntitlementRepository().get();
    entitlementNotifier.value = saved;
  } catch (e) {
    debugPrint('Entitlement restore failed: $e');
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

  try {
    await purchaseService.init(
      defaultTargetPlatform == TargetPlatform.iOS
          ? kRevenueCatApiKeyIos
          : kRevenueCatApiKeyAndroid,
    );
    // After SDK init, fetch the latest entitlement from the store and
    // reconcile with the locally-cached value. This handles the case where
    // a purchase completed in a previous session before the app could save it.
    final remote = await purchaseService.fetchEntitlement();
    if (remote.isActive) {
      final repo = SqliteEntitlementRepository();
      await repo.save(remote);
      entitlementNotifier.value = remote;
    }
  } catch (e) {
    debugPrint('PurchaseService init/sync failed: $e');
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
