import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The native BayMath experience selected by the Dart entry point.
enum AppVariant { student, staff }

/// Defaults to the staff experience for the legacy `lib/main.dart` entry
/// point. Variant-specific entry points override this once at bootstrap.
final Provider<AppVariant> appVariantProvider = Provider<AppVariant>(
  (ref) => AppVariant.staff,
);
