import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_quiz_result_row.dart';
import '../../../core/models/section.dart' show GradeLevel;
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/admin_quiz_results_repository.dart';

/// Admin -> Quiz Results (0051) — Part 2 deliverable (repository provider +
/// filter-selection state + fetch providers for
/// `AdminQuizResultsRepository`'s two methods).
///
/// Lives under `lib/features/admin/data/` rather than `lib/core/providers/`,
/// same placement reasoning `admin_dashboard_providers.dart` gives for
/// itself: repository providers live in `core/providers/` only once more
/// than one feature file needs them; this phase's only consumer is this
/// file, so the repository provider is declared here instead.
///
/// ---------------------------------------------------------------------
/// Repository provider
/// ---------------------------------------------------------------------
///
/// Built from [supabaseClientProvider] (the calling Admin's own Supabase
/// Auth session) — NOT `studentScopedClientProvider` — identical reasoning
/// to [adminDashboardRepositoryProvider]/`teacherDashboardRepositoryProvider`:
/// an Admin session already carries a normal Supabase Auth JWT, so
/// `app.is_admin()` inside each `app.admin_quiz_results*` function (0051)
/// reads it directly with no separate forwarded-JWT client needed.
final Provider<AdminQuizResultsRepository> adminQuizResultsRepositoryProvider =
    Provider<AdminQuizResultsRepository>((ref) {
  return AdminQuizResultsRepository(ref.watch(supabaseClientProvider));
});

/// ---------------------------------------------------------------------
/// Session guard
/// ---------------------------------------------------------------------
///
/// Duplicated from `admin_dashboard_providers.dart`'s own
/// `_requireAdminSession` rather than shared — that function is file-
/// private (leading underscore), matching the same per-file duplication
/// `admin_dashboard_providers.dart` itself already accepted when it noted
/// it mirrors `teacher_dashboard_providers.dart`'s `_requireTeacherSession`
/// "exactly" rather than factoring a shared helper out. Same behavior:
/// throws [SessionExpiredFailure] if watched with no Admin signed in.
/// Teachers are deliberately NOT included (`is! SessionAdmin`, not
/// `is SessionNone`) — this screen is Admin-only per 0051's own
/// `app.is_admin()` gating.
void _requireAdminSession(Ref ref) {
  final SessionState session = ref.watch(sessionProvider).value ?? const SessionNone();
  if (session is! SessionAdmin) throw const SessionExpiredFailure();
}

/// ---------------------------------------------------------------------
/// Filter selection state
/// ---------------------------------------------------------------------
///
/// The Quiz Results screen's current grade/section/assessment-type/
/// school-year selection — all four independently settable, and all four
/// have an explicit "All ___" catch-all (unlike
/// `TeacherQuizResultsSelection`, 0045, whose two fields are `null` only
/// in the "not yet chosen" sense and have no standing "show everything"
/// state at all — see that class's own doc comment). Here, by contrast,
/// "All ___" IS the default, starting state for every field, matching the
/// mockup's dropdowns and 0051's own "unset parameter = no filter on this
/// dimension" convention:
///  - [gradeLevel] `null` = "All Grades".
///  - [sectionId] `null` = "All Sections".
///  - [assessmentTypeFilter] defaults to
///    [AdminQuizResultsAssessmentTypeFilter.all] = "All Types" (this field
///    cannot reuse a bare `null` the way the other three do — see that
///    enum's own doc comment for why "regular" and "no filter" both need
///    representing).
///  - [schoolYearId] `null` = "All Time" (0051's own default scope for the
///    whole feature).
class AdminQuizResultsFilterSelection {
  const AdminQuizResultsFilterSelection({
    this.gradeLevel,
    this.sectionId,
    this.assessmentTypeFilter = AdminQuizResultsAssessmentTypeFilter.all,
    this.schoolYearId,
  });

  final GradeLevel? gradeLevel;
  final String? sectionId;
  final AdminQuizResultsAssessmentTypeFilter assessmentTypeFilter;
  final String? schoolYearId;

  /// Each dimension gets its own explicit setter (mirrors
  /// `TeacherQuizResultsSelection.withSectionId`/`withAssessmentType`,
  /// 0045 — same rationale: [gradeLevel]/[sectionId]/[schoolYearId] are
  /// all nullable, so a single sentinel-based `copyWith` couldn't
  /// distinguish "set back to All ___" from "leave unchanged").
  AdminQuizResultsFilterSelection withGradeLevel(GradeLevel? gradeLevel) =>
      AdminQuizResultsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        assessmentTypeFilter: assessmentTypeFilter,
        schoolYearId: schoolYearId,
      );

  AdminQuizResultsFilterSelection withSectionId(String? sectionId) =>
      AdminQuizResultsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        assessmentTypeFilter: assessmentTypeFilter,
        schoolYearId: schoolYearId,
      );

  AdminQuizResultsFilterSelection withAssessmentTypeFilter(
    AdminQuizResultsAssessmentTypeFilter assessmentTypeFilter,
  ) =>
      AdminQuizResultsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        assessmentTypeFilter: assessmentTypeFilter,
        schoolYearId: schoolYearId,
      );

  AdminQuizResultsFilterSelection withSchoolYearId(String? schoolYearId) =>
      AdminQuizResultsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        assessmentTypeFilter: assessmentTypeFilter,
        schoolYearId: schoolYearId,
      );
}

/// Current filter selection for the Admin Quiz Results screen. One
/// `StateProvider` (not four) so [adminQuizResultsProvider] below has a
/// single atomic value to watch — same reasoning
/// `teacherQuizResultsSelectionProvider` (0045) gives for itself.
final StateProvider<AdminQuizResultsFilterSelection> adminQuizResultsFilterSelectionProvider =
    StateProvider<AdminQuizResultsFilterSelection>(
        (ref) => const AdminQuizResultsFilterSelection());

/// ---------------------------------------------------------------------
/// Fetch providers
/// ---------------------------------------------------------------------

/// The filtered Quiz Results row list, re-fetched every time
/// [adminQuizResultsFilterSelectionProvider] changes. `.autoDispose`
/// (unlike every plain `FutureProvider` in `admin_dashboard_providers.dart`,
/// which explicitly stays non-`.autoDispose` because those RPCs take no
/// parameters at all) — this provider DOES watch filter state and must
/// re-fetch on every change, the same reason
/// `teacher_dashboard_providers.dart`'s four filter-scoped providers are
/// `.autoDispose` (per `admin_dashboard_providers.dart`'s own comment
/// contrasting the two cases).
final FutureProvider<List<AdminQuizResultRow>> adminQuizResultsProvider =
    FutureProvider.autoDispose<List<AdminQuizResultRow>>((ref) {
  _requireAdminSession(ref);
  final AdminQuizResultsFilterSelection selection =
      ref.watch(adminQuizResultsFilterSelectionProvider);
  return ref.watch(adminQuizResultsRepositoryProvider).fetchResults(
        gradeLevel: selection.gradeLevel,
        sectionId: selection.sectionId,
        assessmentTypeFilter: selection.assessmentTypeFilter,
        schoolYearId: selection.schoolYearId,
      );
});

/// School Year filter dropdown options (0051's `admin_quiz_results_school_
/// years`). Plain (non-`.autoDispose`) `FutureProvider`, matching
/// `admin_dashboard_providers.dart`'s convention for parameter-free RPCs —
/// this one takes no arguments and does not depend on
/// [adminQuizResultsFilterSelectionProvider], so there is nothing for
/// `.autoDispose` to react to; the list of school years in existence does
/// not change as a result of picking a filter.
final FutureProvider<List<AdminSchoolYearOption>> adminQuizResultsSchoolYearsProvider =
    FutureProvider<List<AdminSchoolYearOption>>((ref) {
  _requireAdminSession(ref);
  return ref.watch(adminQuizResultsRepositoryProvider).fetchSchoolYears();
});
