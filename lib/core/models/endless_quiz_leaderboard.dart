/// A Dart-side mirror of one row returned by either
/// `public.endless_quiz_leaderboard_top` or
/// `public.endless_quiz_leaderboard_my_rank` (0036) — both pass-through
/// wrappers around the identically-shaped `app.*` functions, so both RPCs
/// return exactly `{rank, full_name, best_endless_streak}` and share this
/// one model rather than two near-identical classes (see 0036's header on
/// why the two functions are always consistent with each other: same
/// grade-scoped, full-population `RANK()` ordering).
///
/// [rank] mirrors Postgres's `rank() over (...)`, which is `bigint`.
/// supabase-flutter deserializes JSON numbers straight to Dart `int` for
/// values in the normal range, and this project has no existing
/// bigint-from-Postgres model that does anything more defensive than that
/// (`quiz_attempts_repository.dart`'s `resolveSchoolYearId` is the closest
/// bigint-adjacent RPC in this codebase and returns a scalar `String`, not
/// a row) — a leaderboard rank is bounded by the number of active students
/// in one grade, nowhere near the range where that would matter, so plain
/// `as int` is used here, not a defensive `num`/string parse.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.fullName,
    required this.bestEndlessStreak,
  });

  /// Shared rank when tied (`RANK()`, not `ROW_NUMBER()`) — two students
  /// tied at rank 3 both get `3`, and the next distinct streak is `5`, not
  /// `4` (see 0036's header).
  final int rank;

  /// `students.full_name` (0006) — the only student-identifying column
  /// this leaderboard is allowed to surface; no username or student
  /// number is exposed by either RPC.
  final String fullName;

  /// `students.best_endless_streak` (0006) — the ranking metric itself,
  /// carried along so the client can render it next to the rank without a
  /// second lookup.
  final int bestEndlessStreak;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      fullName: json['full_name'] as String,
      bestEndlessStreak: json['best_endless_streak'] as int,
    );
  }
}
