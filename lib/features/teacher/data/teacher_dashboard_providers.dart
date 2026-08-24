import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved StateProvider out of the main barrel file — see the
// identical import comment in `sections_screen.dart` (the one existing
// `StateProvider` precedent in this codebase).
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';

/// Phase 9 (Teacher Dashboard) — Part 2 deliverable.
///
/// This lives under `lib/features/teacher/data/` rather than
/// `lib/core/providers/`, mirroring `student_statistics_providers.dart`'s
/// own placement reasoning exactly: this project's convention is
/// "repository providers live in `core/providers/`, one-shot fetch
/// providers live next to the screen that watches them." No screen exists
/// yet for this phase (that's Part 3), so this file is the nearest
/// equivalent — a home for the fetch providers (and the filter state they
/// depend on) that stays trivial to leave as-is, or inline into the
/// screen file, once Part 3 exists, without disturbing `core/providers/`.
///
/// ---------------------------------------------------------------------
/// Filter state — the single source of truth the (Part 3) header's grade
/// dropdown and section picker write to, and every fetch provider below
/// reads from.
/// ---------------------------------------------------------------------

/// Which grade the dashboard is currently filtered to. Null = "All
/// Grades".
final StateProvider<GradeLevel?> selectedGradeLevelProvider =
    StateProvider<GradeLevel?>((ref) => null);

/// Which section (within [selectedGradeLevelProvider]) the dashboard is
/// currently filtered to. Null = "All Sections" (within whatever grade is
/// currently selected).
///
/// MUST be reset to null whenever [selectedGradeLevelProvider] changes —
/// a previously-selected section from a different grade is not a valid
/// filter combination (0037's functions don't reject a mismatched
/// grade/section pair, they'd just silently return zero rows, which would
/// look like an empty dashboard rather than a stale filter). There is no
/// existing "cascading reset between two `StateProvider`s" precedent in
/// this codebase to match (`selectedSchoolYearIdProvider` in
/// `sections_screen.dart` is the only other `StateProvider`, and it has no
/// dependent filter beneath it) — this file therefore does NOT wire an
/// implicit `ref.listen` here to auto-reset this provider when the grade
/// changes. Instead, [selectGradeLevel] below sets both providers
/// together, explicitly, in one place — Part 3's grade dropdown's
/// `onChanged` should call it rather than writing
/// `selectedGradeLevelProvider.notifier).state = ...` directly, so the
/// reset can never be forgotten at a call site. This was chosen over a
/// `ref.listen`-based auto-reset because the dependency is one-directional
/// and only has a single writer (the grade dropdown) — an explicit,
/// synchronous dual-set at that one call site is simpler to trace than an
/// implicit listener side effect for a dependency this narrow.
void selectGradeLevel(WidgetRef ref, GradeLevel? gradeLevel) {
  ref.read(selectedGradeLevelProvider.notifier).state = gradeLevel;
  ref.read(selectedSectionIdProvider.notifier).state = null;
}

final StateProvider<String?> selectedSectionIdProvider = StateProvider<String?>((ref) => null);

/// ---------------------------------------------------------------------
/// Fetch providers — one per `0037` RPC, matching
/// `TeacherDashboardRepository`'s four independent methods (see that
/// class's own doc comment for why there is no combined `fetchAll()` /
/// combined provider). Each is `.autoDispose` — unlike
/// `studentStatisticsProvider`, these are filter-driven and refetch on
/// every grade/section change, so there is no reason to keep a stale
/// filter combination's result cached in memory once nothing is watching
/// it; this is the first `.autoDispose` provider in this codebase, a
/// deliberate divergence for that reason, not an accidental one.
///
/// Each watches [selectedGradeLevelProvider] (and, where relevant,
/// [selectedSectionIdProvider]) directly and re-fetches automatically
/// when either changes — no `.family` here, since the parameters driving
/// these fetches are already global filter state, not caller-supplied
/// arguments a widget would pass in per call site.
///
/// Every provider throws [SessionExpiredFailure] if watched with no
/// Teacher signed in, mirroring `studentStatisticsProvider`'s guard
/// exactly (`teacher_shell_screen.dart`'s own
/// `ref.watch(sessionProvider).value ?? const SessionNone()` /
/// `is! SessionTeacher` pattern), adapted to [SessionTeacher] instead of
/// a student-scoped null-repository check — screens under this dashboard
/// are only ever reachable after a Teacher signs in, so this is a
/// "should not happen" guard, not a normal empty state. Admins are
/// deliberately NOT included in this guard (`is! SessionTeacher`, not
/// `is SessionNone`) — this dashboard is Teacher-only per 0037/0038's own
/// RLS model (`app.teacher_has_section`), not an Admin cross-section view;
/// an Admin session reaching this provider is treated the same as no
/// session at all.
void _requireTeacherSession(Ref ref) {
  final SessionState session = ref.watch(sessionProvider).value ?? const SessionNone();
  if (session is! SessionTeacher) throw const SessionExpiredFailure();
}

final FutureProvider<DashboardSummaryTiles> dashboardSummaryTilesProvider =
    FutureProvider.autoDispose<DashboardSummaryTiles>((ref) {
  _requireTeacherSession(ref);
  final GradeLevel? gradeLevel = ref.watch(selectedGradeLevelProvider);
  final String? sectionId = ref.watch(selectedSectionIdProvider);
  return ref.watch(teacherDashboardRepositoryProvider).fetchSummaryTiles(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
      );
});

/// Watches only [selectedGradeLevelProvider] — `dashboard_avg_score_by_section`
/// (0037 Function 2) takes no section filter by design (see that
/// function's own comment: narrowing to one section would defeat its own
/// per-section-breakdown purpose), so this provider does not watch
/// [selectedSectionIdProvider] at all.
final FutureProvider<List<SectionAverageScore>> dashboardAverageScoreBySectionProvider =
    FutureProvider.autoDispose<List<SectionAverageScore>>((ref) {
  _requireTeacherSession(ref);
  final GradeLevel? gradeLevel = ref.watch(selectedGradeLevelProvider);
  return ref.watch(teacherDashboardRepositoryProvider).fetchAverageScoreBySection(
        gradeLevel: gradeLevel,
      );
});

final FutureProvider<List<TopicMasteryEntry>> dashboardCompetencyMasteryProvider =
    FutureProvider.autoDispose<List<TopicMasteryEntry>>((ref) {
  _requireTeacherSession(ref);
  final GradeLevel? gradeLevel = ref.watch(selectedGradeLevelProvider);
  final String? sectionId = ref.watch(selectedSectionIdProvider);
  return ref.watch(teacherDashboardRepositoryProvider).fetchCompetencyMastery(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
      );
});

/// Built now per Part 2's spec regardless of trigger timing; Part 4 (not
/// this session) decides whether the roster is eagerly watched alongside
/// the tiles or only fetched on-demand when a drill-down card is tapped —
/// either way, watching this provider re-fetches automatically on every
/// grade/section change, same as the other three.
final FutureProvider<List<DashboardRosterEntry>> dashboardRosterProvider =
    FutureProvider.autoDispose<List<DashboardRosterEntry>>((ref) {
  _requireTeacherSession(ref);
  final GradeLevel? gradeLevel = ref.watch(selectedGradeLevelProvider);
  final String? sectionId = ref.watch(selectedSectionIdProvider);
  return ref.watch(teacherDashboardRepositoryProvider).fetchRoster(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
      );
});

/// Intervention drill-down feed (0047) shared by the Teacher Dashboard's
/// "Students Needing Help" tile and the Progress Reports' "Students
/// Requiring Intervention" tile. Deliberately watches NEITHER
/// [selectedGradeLevelProvider] nor [selectedSectionIdProvider] — unlike
/// every provider above, this always fetches the teacher's full flagged
/// list; [TeacherInterventionStudentsScreen] groups it Grade Level ->
/// Section -> Student client-side instead of re-fetching per level, the
/// same "one fetch, group locally" shape the Admin Dashboard's own
/// intervention drill-down (0041/0042) already uses.
final FutureProvider<List<TeacherInterventionStudent>> dashboardInterventionStudentsProvider =
    FutureProvider.autoDispose<List<TeacherInterventionStudent>>((ref) {
  _requireTeacherSession(ref);
  return ref.watch(teacherDashboardRepositoryProvider).fetchInterventionStudents();
});
