import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_dashboard.dart';
import '../../../core/models/section.dart' show GradeLevel;
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/admin_dashboard_repository.dart';

/// Admin Dashboard (0039) — Part 3 deliverable (repository providers +
/// fetch providers for `AdminDashboardRepository`'s three methods).
///
/// Lives under `lib/features/admin/data/` rather than `lib/core/providers/`,
/// the same placement reasoning `teacher_dashboard_providers.dart` gives
/// for itself: repository providers live in `core/providers/`, one-shot
/// fetch providers live next to the screen that watches them. No screen
/// exists yet for this phase (that comes later), so this file is the
/// nearest equivalent home for the three fetch providers below.
///
/// ---------------------------------------------------------------------
/// Repository provider
/// ---------------------------------------------------------------------
///
/// Not declared in `core/providers/supabase_providers.dart` alongside
/// [teacherDashboardRepositoryProvider] — kept here instead, next to the
/// fetch providers that are its only consumers, since this phase's scope
/// is this one file. Built from [supabaseClientProvider] (the calling
/// Admin's own Supabase Auth session) — NOT `studentScopedClientProvider`
/// — identical reasoning to `teacherDashboardRepositoryProvider`: an Admin
/// session, like a Teacher session, already carries a normal Supabase Auth
/// JWT, so `app.is_admin()` inside each `app.admin_dashboard_*` function
/// (0039) reads it directly with no separate forwarded-JWT client needed.
final Provider<AdminDashboardRepository> adminDashboardRepositoryProvider =
    Provider<AdminDashboardRepository>((ref) {
  return AdminDashboardRepository(ref.watch(supabaseClientProvider));
});

/// ---------------------------------------------------------------------
/// Session guard
/// ---------------------------------------------------------------------
///
/// Mirrors `teacher_dashboard_providers.dart`'s `_requireTeacherSession`
/// exactly, adapted to [SessionAdmin]: throws [SessionExpiredFailure] if
/// watched with no Admin signed in. This dashboard is only ever reachable
/// after an Admin signs in (`admin_shell_screen.dart`), so this is a
/// "should not happen" guard, not a normal empty state — it exists to
/// surface a clear, immediate failure client-side rather than relying
/// solely on the round trip to 0039's `app.is_admin()` guard (which would
/// still correctly reject a non-admin session with 42501/
/// [NotAuthorizedFailure] via `mapExceptionToFailure`, but only after a
/// network call). Teachers are deliberately NOT included here
/// (`is! SessionAdmin`, not `is SessionNone`) — this dashboard is
/// Admin-only per 0039's own `app.is_admin()` gating, not a Teacher view;
/// a Teacher session reaching this provider is treated the same as no
/// session at all.
void _requireAdminSession(Ref ref) {
  final SessionState session = ref.watch(sessionProvider).value ?? const SessionNone();
  if (session is! SessionAdmin) throw const SessionExpiredFailure();
}

/// ---------------------------------------------------------------------
/// Fetch providers — one per 0039 RPC, matching
/// `AdminDashboardRepository`'s three independent methods (see that
/// class's own doc comment for why there is no combined `fetchAll()` /
/// combined provider here either — mirrors `teacher_dashboard_providers.dart`
/// keeping its four fetch providers separate for the identical reason:
/// each panel is an independent SQL round-trip with its own
/// loading/error/refresh state, not one shared `Future` that would force
/// every panel to reload or fail together).
///
/// Plain `FutureProvider`s, NOT `.autoDispose` — this deliberately
/// diverges from `teacher_dashboard_providers.dart`'s choice. Those four
/// providers are `.autoDispose` because they watch filter state
/// (`selectedGradeLevelProvider`/`selectedSectionIdProvider`) and need to
/// re-fetch on every filter change; there is no equivalent filter state
/// here (0039's functions take no `p_*` parameters — the Admin Dashboard
/// is unscoped/system-wide by design, per `AdminDashboardRepository`'s own
/// doc comment), so there is nothing for `.autoDispose` to react to. This
/// instead follows `teachersListProvider`'s convention
/// (`teacher_approval_screen.dart`, invalidated from
/// `admin_shell_screen.dart`'s `onDestinationSelected` on tab re-entry): a
/// plain, cached `FutureProvider` that is only refreshed by an explicit
/// `ref.invalidate(...)` call from the screen/shell that owns this
/// dashboard's tab — not wired in this file, since no such screen exists
/// yet in this phase.
final FutureProvider<AdminSummaryTiles> adminSummaryTilesProvider =
    FutureProvider<AdminSummaryTiles>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchSummaryTiles();
});

final FutureProvider<List<GradeLevelAverageScore>> adminScoreByGradeProvider =
    FutureProvider<List<GradeLevelAverageScore>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchScoreByGrade();
});

final FutureProvider<List<ProficiencyDistribution>> adminProficiencyDistributionProvider =
    FutureProvider<List<ProficiencyDistribution>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchProficiencyDistribution();
});

// ---------------------------------------------------------------------
// Tile drill-down providers (0041)
// ---------------------------------------------------------------------
//
// Plain (non-`.family`) `FutureProvider`s for the two flat-list
// drill-downs (Total Teachers, Total Sections) and the intervention list
// — same "cached, refreshed only by explicit `ref.invalidate(...)`"
// convention as the three providers above, since none of them take a
// parameter.
//
// `.family` `FutureProvider`s for the two grade-scoped level-2
// drill-downs (Total Quiz Attempts' and Average Mathematics Score's
// per-section breakdowns) — each keyed by the [GradeLevel] the person
// tapped on level 1, so navigating into a different grade gets its own
// cached result rather than reusing/clobbering another grade's.

final FutureProvider<List<AdminTeacherListEntry>> adminTeachersListProvider =
    FutureProvider<List<AdminTeacherListEntry>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchTeachersList();
});

final FutureProvider<List<AdminSectionListEntry>> adminSectionsListProvider =
    FutureProvider<List<AdminSectionListEntry>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchSectionsList();
});

final FutureProvider<List<GradeQuizAttempts>> adminQuizAttemptsByGradeProvider =
    FutureProvider<List<GradeQuizAttempts>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchQuizAttemptsByGrade();
});

final adminQuizAttemptsBySectionProvider =
    FutureProvider.family<List<SectionQuizAttempts>, GradeLevel>((ref, gradeLevel) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchQuizAttemptsBySection(gradeLevel);
});

final adminScoreBySectionProvider =
    FutureProvider.family<List<AdminSectionAverageScore>, GradeLevel>((ref, gradeLevel) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchScoreBySection(gradeLevel);
});

final FutureProvider<List<AdminInterventionStudent>> adminInterventionStudentsProvider =
    FutureProvider<List<AdminInterventionStudent>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminDashboardRepositoryProvider).fetchInterventionStudents();
});
