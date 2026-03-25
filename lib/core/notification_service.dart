import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notification IDs: morning 100–106, evening 200–206, Tue/Sat 300–301
  static const _morningBaseId = 100;
  static const _eveningBaseId = 200;
  static const _sacredDayBaseId = 300;

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  static Future<bool> requestPermissions() async {
    bool granted = false;

    // Android 13+
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notifGranted =
          await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      granted = notifGranted;
    }

    // iOS
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

  /// Schedules 7 days of morning + evening reminders and Tue/Sat priority
  /// notifications. Safe to call on every app launch — cancels old ones first.
  static Future<void> scheduleDailyReminders() async {
    if (!_initialized) await init();
    await _cancelReminders();

    final rng = Random.secure();
    final now = tz.TZDateTime.now(tz.local);

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      final weekday = day.weekday; // 1=Mon … 7=Sun; Tue=2, Sat=6

      // Morning: random minute in [330, 510) = 5:30 AM to 8:30 AM
      final morningMinute = 330 + rng.nextInt(181);
      final morningTime = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        morningMinute ~/ 60,
        morningMinute % 60,
      );
      if (morningTime.isAfter(now)) {
        await _schedule(
          id: _morningBaseId + dayOffset,
          title: _morningTitle(weekday),
          body: 'Begin your morning recitation of Hanuman Chalisa.',
          scheduledDate: morningTime,
          priority: weekday == DateTime.tuesday || weekday == DateTime.saturday
              ? Priority.high
              : Priority.defaultPriority,
          importance: weekday == DateTime.tuesday || weekday == DateTime.saturday
              ? Importance.high
              : Importance.defaultImportance,
        );
      }

      // Evening: random minute in [1140, 1320) = 7:00 PM to 10:00 PM
      final eveningMinute = 1140 + rng.nextInt(181);
      final eveningTime = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        eveningMinute ~/ 60,
        eveningMinute % 60,
      );
      if (eveningTime.isAfter(now)) {
        await _schedule(
          id: _eveningBaseId + dayOffset,
          title: _eveningTitle(weekday),
          body: 'Complete your evening Hanuman Chalisa before the day ends.',
          scheduledDate: eveningTime,
          priority: weekday == DateTime.tuesday || weekday == DateTime.saturday
              ? Priority.high
              : Priority.defaultPriority,
          importance: weekday == DateTime.tuesday || weekday == DateTime.saturday
              ? Importance.high
              : Importance.defaultImportance,
        );
      }
    }

    debugPrint('NotificationService: scheduled 7-day reminders');
  }

  static String _morningTitle(int weekday) {
    if (weekday == DateTime.tuesday) return '🙏 Mangalvaar Vishesh — Jai Hanuman!';
    if (weekday == DateTime.saturday) return '🙏 Shanivar Vishesh — Jai Hanuman!';
    return 'Good morning — Begin your paath';
  }

  static String _eveningTitle(int weekday) {
    if (weekday == DateTime.tuesday) return '🙏 Mangalvaar evening paath awaits';
    if (weekday == DateTime.saturday) return '🙏 Shanivar evening — complete your vow';
    return 'Evening paath — Hanuman Chalisa';
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    Priority priority = Priority.defaultPriority,
    Importance importance = Importance.defaultImportance,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      importance == Importance.high ? 'hc_sacred_days' : 'hc_reminders',
      importance == Importance.high
          ? 'Sacred Day Reminders'
          : 'Hanuman Chalisa Reminders',
      channelDescription: 'Daily devotional reminders',
      importance: importance,
      priority: priority,
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
    );
  }

  // ── Cancellation ──────────────────────────────────────────────────────────

  static Future<void> _cancelReminders() async {
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(_morningBaseId + i);
      await _plugin.cancel(_eveningBaseId + i);
    }
    await _plugin.cancel(_sacredDayBaseId);
    await _plugin.cancel(_sacredDayBaseId + 1);
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
