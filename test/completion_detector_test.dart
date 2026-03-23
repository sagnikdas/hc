import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/core/completion_detector.dart';

void main() {
  group('CompletionDetector', () {
    test('fires at exactly 95%', () {
      int calls = 0;
      final d = CompletionDetector(onCompleted: () => calls++);
      const total = Duration(minutes: 15);
      d.update(Duration(seconds: (900 * 0.95).round()), total);
      expect(calls, 1);
    });

    test('fires only once even if called again past 95%', () {
      int calls = 0;
      final d = CompletionDetector(onCompleted: () => calls++);
      const total = Duration(minutes: 15);
      d.update(const Duration(seconds: 860), total);
      d.update(const Duration(seconds: 880), total);
      d.update(const Duration(seconds: 900), total);
      expect(calls, 1);
    });

    test('does not fire before 95%', () {
      int calls = 0;
      final d = CompletionDetector(onCompleted: () => calls++);
      const total = Duration(minutes: 15);
      d.update(const Duration(seconds: 800), total); // ~88%
      expect(calls, 0);
    });

    test('reset allows re-fire on next session', () {
      int calls = 0;
      final d = CompletionDetector(onCompleted: () => calls++);
      const total = Duration(minutes: 15);
      d.update(const Duration(seconds: 900), total);
      expect(calls, 1);
      d.reset();
      d.update(const Duration(seconds: 900), total);
      expect(calls, 2);
    });

    test('does not fire when total is zero', () {
      int calls = 0;
      final d = CompletionDetector(onCompleted: () => calls++);
      d.update(Duration.zero, Duration.zero);
      expect(calls, 0);
    });
  });
}
