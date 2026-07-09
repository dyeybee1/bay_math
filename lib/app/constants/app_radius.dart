import 'package:flutter/rendering.dart';

/// Centralized corner-radius scale.
///
/// Use these everywhere a `BorderRadius`/`Radius` is needed instead of a
/// literal number, so every card, button, dialog, and input shares the
/// same rounding language.
class AppRadius {
  const AppRadius._();

  static const double small = 4;
  static const double medium = 8;
  static const double large = 16;
  static const double extraLarge = 24;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius extraLargeAll =
      BorderRadius.all(Radius.circular(extraLarge));
}
