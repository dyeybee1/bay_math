import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_topic_mastery.dart';
import '../../../core/models/section.dart' show GradeLevel;
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/admin_topic_mastery_repository.dart';

/// Admin -> Performance Reports / Topic Mastery (0052) — Part 2 deliverable
/// (repository provider + filter-selection state + fetch providers for
/// [AdminTopicMasteryRepository.fetchTopicMastery]), mirroring
/// `admin_quiz_results_providers.dart`'s (0051 Part 2) structure exactly.
///
/// SCHOOL YEAR DROPDOWN — deliberately NOT re-declared here. Per 0052's own
/// migration note, this feature reuses the existing
/// `adminQuizResultsSchoolYearsProvider` (`admin_quiz_results_providers.
/// dart`) directly for the School Year filter dropdown — import that
/// provider from its own file at the call site (Part 3's screen) rather
/// than duplicating a second, functionally-identical provider here.
///
/// ---------------------------------------------------------------------
/// Repository provider
/// ---------------------------------------------------------------------
///
/// Lives under `lib/features/admin/data/` rather than `lib/core/providers/`
/// — same placement reasoning `adminQuizResultsRepositoryProvider`'s own
/// doc comment gives for itself: this phase's only consumer is this file.
///
/// Built from [supabaseClientProvider] (the calling Admin's own Supabase
/// Auth session) — NOT `studentScopedClientProvider` — identical reasoning
/// to `adminQuizResultsRepositoryProvider`: an Admin session already
/// carries a normal Supabase Auth JWT, so `app.is_admin()` inside
/// `app.admin_competency_mastery` (0052) reads it directly with no separate
/// forwarded-JWT client needed.
final Provider<AdminTopicMasteryRepository> adminTopicMasteryRepositoryProvider =
    Provider<AdminTopicMasteryRepository>((ref) {
  return AdminTopicMasteryRepository(ref.watch(supabaseClientProvider));
});

/// ---------------------------------------------------------------------
/// Session guard
/// ---------------------------------------------------------------------
///
/// Duplicated from `admin_quiz_results_providers.dart`'s own
/// `_requireAdminSession` rather than shared — file-private (leading
/// underscore), same per-file duplication that file's own comment already
/// accepted (mirroring `admin_dashboard_providers.dart`/
/// `teacher_dashboard_providers.dart`'s equivalent guards). Same behavior:
/// throws [SessionExpiredFailure] if watched with no Admin signed in.
/// Teachers are deliberately NOT included (`is! SessionAdmin`, not
/// `is SessionNone`) — this feature is Admin-only per 0052's own
/// `app.is_admin()` gating.
void _requireAdminSession(Ref ref) {
  final SessionState session = ref.watch(sessionProvider).value ?? const SessionNone();
  if (session is! SessionAdmin) throw const SessionExpiredFailure();
}

/// ---------------------------------------------------------------------
/// Filter selection state
/// ---------------------------------------------------------------------
///
/// The Performance Reports / Topic Mastery screen's current grade/section/
/// school-year/topic selection. Mirrors
/// `AdminQuizResultsFilterSelection`'s (0051) "All ___ is the default,
/// starting state for every field" convention exactly:
///  - [gradeLevel] `null` = "All Grades".
///  - [sectionId] `null` = "All Sections".
///  - [schoolYearId] `null` = "All Time" (0052's own default scope,
///    matching 0051's convention exactly).
///  - [topic] `null` = "All Topics".
///
/// [topic] IS included here even though `admin_competency_mastery` (0052)
/// has no `p_topic` RPC parameter to send it to — see
/// [adminPerformanceReportsProvider]'s own comment below for exactly how
/// and where it is applied instead.
class AdminPerformanceReportsFilterSelection {
  const AdminPerformanceReportsFilterSelection({
    this.gradeLevel,
    this.sectionId,
    this.schoolYearId,
    this.topic,
  });

  final GradeLevel? gradeLevel;
  final String? sectionId;
  final String? schoolYearId;
  final String? topic;

  /// Each dimension gets its own explicit setter (mirrors
  /// `AdminQuizResultsFilterSelection.withGradeLevel`/`withSectionId`/
  /// `withSchoolYearId`, 0051 — same rationale: every field here is
  /// nullable, so a single sentinel-based `copyWith` couldn't distinguish
  /// "set back to All ___" from "leave unchanged").
  AdminPerformanceReportsFilterSelection withGradeLevel(GradeLevel? gradeLevel) =>
      AdminPerformanceReportsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        schoolYearId: schoolYearId,
        topic: topic,
      );

  AdminPerformanceReportsFilterSelection withSectionId(String? sectionId) =>
      AdminPerformanceReportsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        schoolYearId: schoolYearId,
        topic: topic,
      );

  AdminPerformanceReportsFilterSelection withSchoolYearId(String? schoolYearId) =>
      AdminPerformanceReportsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        schoolYearId: schoolYearId,
        topic: topic,
      );

  AdminPerformanceReportsFilterSelection withTopic(String? topic) =>
      AdminPerformanceReportsFilterSelection(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        schoolYearId: schoolYearId,
        topic: topic,
      );
}

/// Current filter selection for the Admin Performance Reports / Topic
/// Mastery screen. One `StateProvider` (not four), same reasoning
/// `adminQuizResultsFilterSelectionProvider`'s own comment gives: a single
/// atomic value for [adminPerformanceReportsProvider] below to watch.
final StateProvider<AdminPerformanceReportsFilterSelection>
    adminPerformanceReportsFilterSelectionProvider =
    StateProvider<AdminPerformanceReportsFilterSelection>(
        (ref) => const AdminPerformanceReportsFilterSelection());

/// ---------------------------------------------------------------------
/// Fetch providers
/// ---------------------------------------------------------------------

/// The filtered Topic Mastery row list, re-fetched every time
/// [adminPerformanceReportsFilterSelectionProvider] changes. `.autoDispose`
/// for the same reason `adminQuizResultsProvider` (0051) is: it watches
/// filter state and must re-fetch on every change.
///
/// TOPIC FILTERING IS CLIENT-SIDE — flagged deliberately, since 0051's own
/// "server-side, via RPC parameters" convention is the norm elsewhere in
/// this codebase. `admin_competency_mastery` (0052) has no `p_topic`
/// parameter: the RPC always returns every distinct topic matching
/// [AdminPerformanceReportsFilterSelection.gradeLevel]/`.sectionId`/
/// `.schoolYearId`, so those three are sent to the server exactly like
/// `adminQuizResultsProvider` sends its filters. [selection.topic], when
/// set, narrows that already-server-filtered list down to the one matching
/// row afterward, in Dart — not a second network round trip, and not a
/// re-derivation of the mastery arithmetic itself (each row's
/// `questionsTotal`/`questionsCorrect`/`masteryPercent` are exactly what
/// the server computed; this only selects which of those rows are shown).
final FutureProvider<List<AdminTopicMasteryRow>> adminPerformanceReportsProvider =
    FutureProvider.autoDispose<List<AdminTopicMasteryRow>>((ref) async {
  _requireAdminSession(ref);
  final AdminPerformanceReportsFilterSelection selection =
      ref.watch(adminPerformanceReportsFilterSelectionProvider);
  final List<AdminTopicMasteryRow> rows =
      await ref.watch(adminTopicMasteryRepositoryProvider).fetchTopicMastery(
            gradeLevel: selection.gradeLevel,
            sectionId: selection.sectionId,
            schoolYearId: selection.schoolYearId,
          );
  if (selection.topic == null) return rows;
  return rows.where((AdminTopicMasteryRow row) => row.topic == selection.topic).toList();
});

/// The distinct set of `question_bank.topic` strings that
/// `admin_competency_mastery` (0052) can return at all, queried fully
/// unfiltered (`school_year_id`/`grade_level`/`section_id` all `null` —
/// "All Time" / "All Grades" / "All Sections"). This is the source of
/// truth for the Topic filter dropdown's options (Part 3's screen) — NOT
/// derived from [adminPerformanceReportsProvider]'s current (possibly
/// grade/section/school-year-narrowed) result set, since narrowing by
/// grade/section/school-year could otherwise make previously-visible topic
/// options disappear from the dropdown out from under the admin mid-use.
///
/// Plain (non-`.autoDispose`) `FutureProvider`, same reasoning
/// `adminQuizResultsSchoolYearsProvider`'s own comment gives: it takes no
/// arguments and does not watch [adminPerformanceReportsFilterSelectionProvider],
/// so there is nothing for `.autoDispose` to react to — the full set of
/// topics in the curriculum does not change as a result of picking a
/// filter.
///
/// `admin_competency_mastery` already returns one row per distinct topic
/// (it is grouped by `question_bank.topic` server-side, 0052), so no row
/// here can share a topic with another — mapped to a plain sorted list of
/// topic strings, not deduplicated via a `Set` (there is nothing to
/// deduplicate; sorting alone gives a stable, alphabetical dropdown order
/// for what may be a long, per-lesson-sized list — see [AdminTopicMasteryRow]'s
/// own doc comment on why this is not assumed to be a short, fixed set).
final FutureProvider<List<String>> adminPerformanceReportsTopicsProvider =
    FutureProvider<List<String>>((ref) async {
  _requireAdminSession(ref);
  final List<AdminTopicMasteryRow> rows =
      await ref.watch(adminTopicMasteryRepositoryProvider).fetchTopicMastery();
  final List<String> topics = rows.map((AdminTopicMasteryRow row) => row.topic).toList()..sort();
  return topics;
});
