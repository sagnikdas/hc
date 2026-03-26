import 'package:flutter/foundation.dart';

/// Global UI font scaling for accessibility (controlled from ProfileScreen).
///
/// Kept outside of `main.dart` to avoid import cycles between core widgets
/// and screens.
final fontScaleNotifier = ValueNotifier<double>(1.0);

