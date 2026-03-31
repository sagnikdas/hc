import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../data/models/user_settings.dart';
import 'reminder_navigation.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Payload on scheduled paath reminders; tap opens [PlayScreen] from [MainShell].
  static const paathReminderPayload = 'hc_paath_reminder';

  /// Widget tests: skip plugin / timezone scheduling.
  @visibleForTesting
  static Future<void> Function(UserSettings)? applyReminderScheduleForTest;
  @visibleForTesting
  static Future<void> Function()? cancelRemindersForTest;
  @visibleForTesting
  static Future<void> Function()? consumeLaunchNavigationForTest;

  // Notification IDs: morning 100–106, evening 200–206
  static const _morningBaseId = 100;
  static const _eveningBaseId = 200;

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (info.identifier.isNotEmpty) {
        try {
          tz.setLocalLocation(tz.getLocation(info.identifier));
        } catch (e) {
          debugPrint(
            'NotificationService: timezone id not in database: '
            '${info.identifier} ($e)',
          );
        }
      }
    } catch (e, st) {
      // Without this, tz.local defaults to UTC and alarms fire at the wrong
      // wall-clock time on real devices (especially outside UTC).
      debugPrint('NotificationService: failed to read device timezone: $e\n$st');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType !=
        NotificationResponseType.selectedNotification) {
      return;
    }
    if (response.payload != paathReminderPayload) return;
    bumpReminderNotificationTap();
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  static Future<bool> requestPermissions() async {
    bool granted = false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notifGranted =
          await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      granted = notifGranted;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return granted;
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Cancels existing reminder IDs and schedules up to 7 days ahead from
  /// [settings]. No-op when [UserSettings.reminderNotificationsEnabled] is false.
  static Future<void> applyReminderSchedule(UserSettings settings) async {
    final stub = applyReminderScheduleForTest;
    if (stub != null) {
      await stub(settings);
      return;
    }
    if (!_initialized) await init();
    await _cancelReminders();

    if (!settings.reminderNotificationsEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final morningH = settings.reminderMorningMinutes ~/ 60;
    final morningM = settings.reminderMorningMinutes % 60;
    final eveningH = settings.reminderEveningMinutes ~/ 60;
    final eveningM = settings.reminderEveningMinutes % 60;

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      final weekday = day.weekday;
      final isSacredDay =
          weekday == DateTime.tuesday || weekday == DateTime.saturday;
      final useVishesh =
          settings.sacredDayNotificationsEnabled && isSacredDay;

      final morningTime = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        morningH,
        morningM,
      );
      if (morningTime.isAfter(now)) {
        await _schedule(
          id: _morningBaseId + dayOffset,
          title: _morningTitle(weekday, useVishesh),
          body: 'Begin your morning recitation of Hanuman Chalisa.',
          scheduledDate: morningTime,
          highImportance: useVishesh,
        );
      }

      final eveningTime = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        eveningH,
        eveningM,
      );
      if (eveningTime.isAfter(now)) {
        await _schedule(
          id: _eveningBaseId + dayOffset,
          title: _eveningTitle(weekday, useVishesh),
          body: 'Complete your evening Hanuman Chalisa before the day ends.',
          scheduledDate: eveningTime,
          highImportance: useVishesh,
        );
      }
    }

    debugPrint('NotificationService: applied reminder schedule from settings');
  }

  /// If the app was cold-started by tapping a paath reminder, consume the
  /// event once so [MainShell] can open the player.
  static Future<void> consumeNotificationLaunchNavigation() async {
    final stub = consumeLaunchNavigationForTest;
    if (stub != null) {
      await stub();
      return;
    }
    if (!_initialized) await init();
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (!(details?.didNotificationLaunchApp ?? false)) return;
      final payload = details!.notificationResponse?.payload;
      if (payload != paathReminderPayload) return;
      bumpReminderNotificationTap();
    } catch (e, st) {
      debugPrint('NotificationService: launch details: $e\n$st');
    }
  }

  static String _morningTitle(int weekday, bool vishesh) {
    if (!vishesh) return 'Good morning — Begin your paath';
    if (weekday == DateTime.tuesday) return '🙏 Mangalvaar Vishesh — Jai Hanuman!';
    if (weekday == DateTime.saturday) return '🙏 Shanivar Vishesh — Jai Hanuman!';
    return 'Good morning — Begin your paath';
  }

  static String _eveningTitle(int weekday, bool vishesh) {
    if (!vishesh) return 'Evening paath — Hanuman Chalisa';
    if (weekday == DateTime.tuesday) return '🙏 Mangalvaar evening paath awaits';
    if (weekday == DateTime.saturday) {
      return '🙏 Shanivar evening — complete your vow';
    }
    return 'Evening paath — Hanuman Chalisa';
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required bool highImportance,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      highImportance ? 'hc_sacred_days' : 'hc_reminders',
      highImportance ? 'Sacred Day Reminders' : 'Hanuman Chalisa Reminders',
      channelDescription: 'Daily devotional reminders',
      importance:
          highImportance ? Importance.high : Importance.defaultImportance,
      priority: highImportance ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: paathReminderPayload,
    );
  }

  // ── Cancellation ──────────────────────────────────────────────────────────

  static Future<void> _cancelReminders() async {
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(_morningBaseId + i);
      await _plugin.cancel(_eveningBaseId + i);
    }
  }

  static Future<void> cancelReminders() async {
    final stub = cancelRemindersForTest;
    if (stub != null) {
      await stub();
      return;
    }
    if (!_initialized) await init();
    await _cancelReminders();
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
