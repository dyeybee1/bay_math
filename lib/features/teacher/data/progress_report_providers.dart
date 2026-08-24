import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved StateProvider out of the main barrel file — same
// import comment/precedent as `teacher_dashboard_providers.dart` and
// `sections_screen.dart`.
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import 'teacher_dashboard_providers.dart' show selectedGradeLevelProvider, selectedSectionIdProvider;

/// Teacher Progress Reports (0046) — Part 2 deliverable.
///
/// Lives under `lib/features/teacher/data/`, alongside
/// `teacher_dashboard_providers.dart`, for the same reasoning that file's
/// own header gives: no screen exists yet for this feature (Part 3), and
/// this is the nearest home for its fetch providers / filter state until
/// one does.
///
/// FILTER STATE: deliberately does NOT redeclare
/// `selectedGradeLevelProvider` / `selectedSectionIdProvider` — those are
/// imported from `teacher_dashboard_providers.dart` and reused as-is
/// (locked instruction: reuse, don't redeclare). Progress Reports and the
/// Teacher Dashboard share one grade/section filter concept; there is no
/// product reason for a teacher's grade/section selection to reset when
/// navigating between the two screens, so sharing the same provider
/// instances (not just the same shape) is intentional, not incidental.
///
/// `selectedTopicProvider` below is new and local to this file — it has no
/// Teacher Dashboard equivalent (that screen has no per-topic filter), and
/// is a pure client-side filter per the locked product decision: it is
/// never sent as an RPC parameter, only used to filter an
/// already-fetched `List<StudentTopicMasteryEntry>` client-side (Part 3's
/// job).
final StateProvider<String?> selectedTopicProvider = StateProvider<String?>((ref) => null);

/// `_requireTeacherSession` in `teacher_dashboard_providers.dart` is
/// private (leading underscore) and therefore cannot be imported across
/// files in Dart — flagging this as the one deviation from "reuse, don't
/// redeclare" the instructions asked to call out explicitly rather than
/// silently duplicate. The body below is copied verbatim (same guard,
/// same [SessionTeacher]-only check, same [SessionExpiredFailure]) rather
/// than widening the original's visibility, since widening a private
/// helper's visibility is a change to a file this part was told not to
/// modify. If a shared, exported version is preferred instead, the fix is
/// a one-line visibility change in `teacher_dashboard_providers.dart`
/// (drop the leading underscore) plus deleting this copy — flagging for
/// the reviewer rather than making that call unilaterally.
void _requireTeacherSession(Ref ref) {
  final SessionState session = ref.watch(sessionProvider).value ?? const SessionNone();
  if (session is! SessionTeacher) throw const SessionExpiredFailure();
}

/// Fetches `dashboard_student_topic_mastery` (0046 Part 1) — one row per
/// (student, topic) for every actively-enrolled student in scope. Watches
/// the shared [selectedGradeLevelProvider] / [selectedSectionIdProvider]
/// (not [selectedTopicProvider] — the topic filter is applied client-side
/// by Part 3 over this provider's already-fetched list, not re-fetched
/// per topic selection). `.autoDispose`, same reasoning as every fetch
/// provider in `teacher_dashboard_providers.dart`: this is filter-driven
/// and refetches on every grade/section change, so there is no reason to
/// keep a stale filter combination cached once nothing is watching it.
final FutureProvider<List<StudentTopicMasteryEntry>> dashboardStudentTopicMasteryProvider =
    FutureProvider.autoDispose<List<StudentTopicMasteryEntry>>((ref) {
  _requireTeacherSession(ref);
  final GradeLevel? gradeLevel = ref.watch(selectedGradeLevelProvider);
  final String? sectionId = ref.watch(selectedSectionIdProvider);
  return ref.watch(teacherDashboardRepositoryProvider).fetchStudentTopicMastery(
        gradeLevel: gradeLevel,
        sectionId: sectionId,
      );
});

/// ---------------------------------------------------------------------
/// Pure helper functions — plain functions over already-fetched lists,
/// not providers, so they are unit-testable without Riverpod and can be
/// called directly by Part 3's widgets against whatever
/// `dashboardCompetencyMasteryProvider` (existing,
/// `teacher_dashboard_providers.dart`) currently holds. Per the locked
/// product decision, "Most Difficult Competency" / "Highest Mastered
/// Competency" / "Students Requiring Intervention" are derived from
/// already-existing providers — no new fetch provider is created for any
/// of the three; only these stateless helpers are added.
/// ---------------------------------------------------------------------

/// The topic with the lowest [TopicMasteryEntry.masteryPercent] among
/// [entries] — "Most Difficult Competency". `masteryPercent` is
/// non-nullable on [TopicMasteryEntry] (see that class's own doc
/// comment), so no null-filtering is needed here. Returns `null` only
/// for an empty [entries] list. Ties are broken by keeping the first
/// entry encountered (stable on [entries]' incoming order), since there
/// is no product rule for breaking a tie between two equally-difficult
/// topics.
TopicMasteryEntry? mostDifficultCompetency(List<TopicMasteryEntry> entries) {
  TopicMasteryEntry? worst;
  for (final TopicMasteryEntry entry in entries) {
    final num percent = entry.masteryPercent;
    if (worst == null || percent < (worst.masteryPercent)) {
      worst = entry;
    }
  }
  return worst;
}

/// The topic with the highest [TopicMasteryEntry.masteryPercent] among
/// [entries] — "Highest Mastered Competency". Same null-handling and
/// tie-breaking rules as [mostDifficultCompetency], mirrored exactly
/// (min vs max is the only difference).
TopicMasteryEntry? highestMasteredCompetency(List<TopicMasteryEntry> entries) {
  TopicMasteryEntry? best;
  for (final TopicMasteryEntry entry in entries) {
    final num percent = entry.masteryPercent;
    if (best == null || percent > (best.masteryPercent)) {
      best = entry;
    }
  }
  return best;
}

/// Classifies [masteryPercent] into a [MasteryBand] per the locked
/// product decision's thresholds:
/// - `< 70` -> [MasteryBand.needsSupport]
/// - `70`-`84` (inclusive) -> [MasteryBand.proficient]
/// - `>= 85` -> [MasteryBand.mastered]
///
/// Returns `null` for a `null` [masteryPercent] — "no data" is a distinct
/// state from any band (see [MasteryBand]'s own doc comment) and must be
/// rendered as such by the caller, not silently folded into
/// [MasteryBand.needsSupport] or any other case.
MasteryBand? masteryBandFor(num? masteryPercent) {
  if (masteryPercent == null) return null;
  if (masteryPercent < 70) return MasteryBand.needsSupport;
  if (masteryPercent < 85) return MasteryBand.proficient;
  return MasteryBand.mastered;
}
