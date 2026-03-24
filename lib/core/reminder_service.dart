import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ── Timing constants ──────────────────────────────────────────────────────────

/// Default morning reminder time (within the 5:30–8:30 AM devotion window).
const kMorningHour = 7;
const kMorningMinute = 0;

/// Default evening reminder time (within the 7:00–10:00 PM devotion window).
const kEveningHour = 20;
const kEveningMinute = 0;

/// Notification ID ranges: morning = 10–16, evening = 17–23 (one per weekday).
const _kMorningBase = 10;
const _kEveningBase = 17;

// ── Interface ─────────────────────────────────────────────────────────────────

abstract interface class ReminderService {
  /// One-time SDK setup — call at app start before [scheduleAll].
  /// Returns whether the user granted notification permission.
  Future<bool> init();

  /// Schedules (or re-schedules) all 14 weekly reminders:
  /// one morning + one evening notification per weekday, with Tuesday and
  /// Saturday carrying higher-importance devotional copy.
  Future<void> scheduleAll({
    int morningHour = kMorningHour,
    int morningMinute = kMorningMinute,
    int eveningHour = kEveningHour,
    int eveningMinute = kEveningMinute,
  });

  /// Cancels all pending reminder notifications.
  Future<void> cancelAll();
}

// ── No-op (tests / unsupported platforms) ────────────────────────────────────

class NoOpReminderService implements ReminderService {
  const NoOpReminderService();

  @override
  Future<bool> init() async => false;

  @override
  Future<void> scheduleAll({
    int morningHour = kMorningHour,
    int morningMinute = kMorningMinute,
    int eveningHour = kEveningHour,
    int eveningMinute = kEveningMinute,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

// ── Live implementation ───────────────────────────────────────────────────────

/// Platform setup required before this works:
/// - Android: add SCHEDULE_EXACT_ALARM permission + notification channel in
///   AndroidManifest.xml; set android:icon in the manifest.
/// - iOS: add UNUserNotificationCenter delegate in AppDelegate.swift.
class LocalReminderService implements ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<bool> init() async {
    tz_data.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }

    return false;
  }

  @override
  Future<void> scheduleAll({
    int morningHour = kMorningHour,
    int morningMinute = kMorningMinute,
    int eveningHour = kEveningHour,
    int eveningMinute = kEveningMinute,
  }) async {
    await cancelAll();
    _setLocalTimezone();

    for (var weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++) {
      await _schedule(
        id: _kMorningBase + (weekday - 1),
        weekday: weekday,
        hour: morningHour,
        minute: morningMinute,
        title: _title(weekday, isMorning: true),
        body: _body(weekday, isMorning: true),
        importance: _importance(weekday),
      );
      await _schedule(
        id: _kEveningBase + (weekday - 1),
        weekday: weekday,
        hour: eveningHour,
        minute: eveningMinute,
        title: _title(weekday, isMorning: false),
        body: _body(weekday, isMorning: false),
        importance: _importance(weekday),
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Scheduling helper ────────────────────────────────────────────────────────

  Future<void> _schedule({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required Importance importance,
  }) async {
    final isHighIntent = importance == Importance.max;
    final androidDetails = AndroidNotificationDetails(
      isHighIntent ? 'hc_reminders_high' : 'hc_reminders',
      isHighIntent ? 'Special Day Reminders' : 'Daily Reminders',
      channelDescription: 'Hanuman Chalisa daily practice reminders',
      importance: importance,
      priority: isHighIntent ? Priority.max : Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextWeekday(weekday, hour, minute),
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var dt =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (dt.weekday != weekday) {
      dt = dt.add(const Duration(days: 1));
    }
    if (dt.isBefore(now)) {
      dt = dt.add(const Duration(days: 7));
    }
    return dt;
  }

  void _setLocalTimezone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      final name = tz.timeZoneDatabase.locations.keys.firstWhere(
        (n) {
          try {
            return tz.TZDateTime.now(tz.getLocation(n)).timeZoneOffset ==
                offset;
          } catch (_) {
            return false;
          }
        },
        orElse: () => 'UTC',
      );
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  // ── Copy helpers ─────────────────────────────────────────────────────────────

  bool _isHighIntent(int weekday) =>
      weekday == DateTime.tuesday || weekday == DateTime.saturday;

  Importance _importance(int weekday) =>
      _isHighIntent(weekday) ? Importance.max : Importance.high;

  String _title(int weekday, {required bool isMorning}) {
    if (_isHighIntent(weekday)) {
      final day = weekday == DateTime.tuesday ? 'Tuesday' : 'Saturday';
      return '🙏 $day Special — Hanuman Chalisa';
    }
    return isMorning
        ? '🌅 Good Morning — Hanuman Chalisa'
        : '🌙 Good Evening — Hanuman Chalisa';
  }

  String _body(int weekday, {required bool isMorning}) {
    if (_isHighIntent(weekday)) {
      return 'A blessed day to recite the Chalisa. Jai Bajrangbali! 🙏';
    }
    return isMorning
        ? 'Start your day with the Hanuman Chalisa.'
        : 'Complete today\'s recitation and keep your streak alive.';
  }
}
