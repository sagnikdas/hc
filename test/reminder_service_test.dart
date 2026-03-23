import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/core/reminder_service.dart';

void main() {
  group('NoOpReminderService', () {
    const service = NoOpReminderService();

    test('init returns false', () async {
      expect(await service.init(), isFalse);
    });

    test('scheduleAll completes without error', () async {
      await expectLater(service.scheduleAll(), completes);
    });

    test('cancelAll completes without error', () async {
      await expectLater(service.cancelAll(), completes);
    });
  });

  group('Reminder timing constants', () {
    test('morning window is within 5:30–8:30 AM', () {
      expect(kMorningHour, greaterThanOrEqualTo(5));
      expect(kMorningHour, lessThanOrEqualTo(8));
      // If on the boundary hour, minute must fit.
      if (kMorningHour == 5) expect(kMorningMinute, greaterThanOrEqualTo(30));
      if (kMorningHour == 8) expect(kMorningMinute, lessThanOrEqualTo(30));
    });

    test('evening window is within 7:00–10:00 PM', () {
      expect(kEveningHour, greaterThanOrEqualTo(19));
      expect(kEveningHour, lessThanOrEqualTo(22));
      if (kEveningHour == 22) expect(kEveningMinute, equals(0));
    });
  });
}
