import 'package:flutter/material.dart';

/// Baseline design width (iPhone 14 / Pixel 6 reference, logical pixels).
const double _kBaseWidth = 375.0;

extension Rsp on BuildContext {
  double get sw => MediaQuery.sizeOf(this).width;

  /// Scale [value] proportionally to screen width.
  ///
  /// Clamped to [0.85 × baseline, 1.28 × baseline] so the UI stays sane on
  /// 320 px phones and doesn't balloon on 600 px tablets.
  ///
  /// Examples (baseline 375):
  ///   320 px → 0.85×  |  375 px → 1.00×  |  412 px → 1.10×  |  600 px → 1.28×
  double sp(double value) =>
      value * (sw / _kBaseWidth).clamp(0.85, 1.28);
}
