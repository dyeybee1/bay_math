import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../../../core/providers/supabase_providers.dart';

/// The combined payload [endlessQuizLeaderboardProvider] resolves to — see
/// that provider's doc comment for why this is one record instead of two
/// independent providers.
typedef EndlessQuizLeaderboardData = ({
  List<LeaderboardEntry> topEntries,
  LeaderboardEntry myRank,
});

/// Phase 7 (Endless Quiz) — Part 3 deliverable: the one-shot fetch provider
/// behind `EndlessQuizLandingScreen`.
///
/// Lives under `lib/features/student/data/` rather than
/// `lib/core/providers/`, matching `student_statistics_providers.dart`'s
/// own placement precedent exactly: repository providers (the
/// null-when-signed-out `EndlessQuizRepository?`) stay in
/// `core/providers/`; one-shot fetch providers for a specific screen live
/// next to that screen instead. No screen existed for this leaderboard
/// before this part, so — same reasoning as that file — this is the
/// natural home for it, kept trivial to relocate/inline later if this
/// project ever settles on a different convention.
///
/// Composes [EndlessQuizRepository.fetchLeaderboardTop] and
/// [EndlessQuizRepository.fetchMyRank] into one [EndlessQuizLeaderboardData]
/// rather than exposing two independent [FutureProvider]s — mirroring
/// [studentStatisticsProvider]'s own composition of four reads into one
/// [StudentStatistics]. This screen has only two pieces of data, but both
/// need to be ready before anything can render meaningfully: the list
/// alone can't say whether the "You're #N" card should appear below it —
/// that decision depends on comparing `myRank` against the list — so one
/// shared `AsyncValue` (one loading/error state for the whole screen) is
/// the right granularity here, unlike a screen with independent per-row
/// actions where separate providers would be the better fit.
///
/// Throws [SessionExpiredFailure] if watched with no student signed in,
/// matching [studentStatisticsProvider]'s exact convention — screens under
/// `/student-*` are only ever reached after login, so this is a
/// "should not happen" guard, not a normal empty state.
final FutureProvider<EndlessQuizLeaderboardData> endlessQuizLeaderboardProvider =
    FutureProvider<EndlessQuizLeaderboardData>((ref) async {
  final repo = ref.watch(endlessQuizRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();

  // Fetched concurrently, not sequentially awaited one after another —
  // neither read depends on the other's result, both are simple RPCs
  // against the same grade-scoped ranking (see 0036's header on why the
  // two are always consistent with each other).
  final List<Object> results = await Future.wait<Object>(<Future<Object>>[
    repo.fetchLeaderboardTop(),
    repo.fetchMyRank(),
  ]);

  return (
    topEntries: results[0] as List<LeaderboardEntry>,
    myRank: results[1] as LeaderboardEntry,
  );
});
