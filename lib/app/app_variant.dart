import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The native BayMath experience selected by the Dart entry point.
enum AppVariant { student, staff }

/// The default Web build is the Student PWA. Native desktop builds retain the
/// Staff workspace; explicit variant entry points can still override this.
AppVariant defaultAppVariant({required bool isWeb}) =>
    isWeb ? AppVariant.student : AppVariant.staff;

/// Fallback for provider consumers outside bootstrap. Every entry point
/// overrides this with its chosen variant before the app starts.
final Provider<AppVariant> appVariantProvider = Provider<AppVariant>(
  (ref) => AppVariant.staff,
);
