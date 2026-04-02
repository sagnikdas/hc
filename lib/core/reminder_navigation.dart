import 'package:flutter/foundation.dart';

/// Bumped when the user taps a paath reminder notification (foreground tap or
/// cold start via launch details). [MainShell] listens and opens [PlayScreen].
final ValueNotifier<int> reminderNotificationTapVersion = ValueNotifier(0);

void bumpReminderNotificationTap() {
  reminderNotificationTapVersion.value++;
}
