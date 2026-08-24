import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/student_statistics.dart';
import '../../../core/providers/supabase_providers.dart';

/// Phase 8 (Student Statistics) — Part 2 deliverable.
///
/// This lives under `lib/features/student/data/` rather than
/// `lib/core/providers/` because the analogous case in this codebase
/// (`studentVisibleLessonsProvider`) is defined directly in its consuming
/// screen file (`student_lessons_screen.dart`) — there's no separate
/// "feature data" file precedent to match exactly, since this project's
/// convention is "repository providers live in `core/providers/`, one-shot
/// fetch providers live next to the screen that watches them." No screen
/// exists yet for this phase (that's Part 3), so this file is the nearest
/// equivalent: a home for the fetch provider that keeps this file trivial
/// to delete/inline into the screen file once Part 3 exists, without
/// disturbing `core/providers/`.
///
/// The full statistics payload for the signed-in student — the single
/// provider the (Part 3) Statistics screen should watch. Composes all four
/// `0035` views into one [StudentStatistics] via
/// [StudentStatisticsRepository.fetchAll], so the screen deals with one
/// `AsyncValue<StudentStatistics>` (one loading/error/data state for the
/// whole screen) rather than four independent ones — appropriate here
/// since every tile/chart on this screen is meant to load together, unlike
/// e.g. a list screen with independent per-item actions.
///
/// Throws [SessionExpiredFailure] if watched with no student signed in,
/// matching [studentVisibleLessonsProvider]'s / every other student-scoped
/// provider's existing convention in this codebase — screens under
/// `/student-*` are only ever reached after login, so this is a
/// "should not happen" guard, not a normal empty state.
final FutureProvider<StudentStatistics> studentStatisticsProvider =
    FutureProvider<StudentStatistics>((ref) {
  final repo = ref.watch(studentStatisticsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchAll();
});
