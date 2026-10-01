import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/core/models/endless_quiz_leaderboard.dart';

void main() {
  test('maps the optional leaderboard avatar id', () {
    final LeaderboardEntry entry = LeaderboardEntry.fromJson(<String, dynamic>{
      'rank': 2,
      'full_name': 'Alex Rivera',
      'best_endless_streak': 18,
      'avatar_id': 'fox',
    });

    expect(entry.avatarId, 'fox');
  });

  test('accepts responses from an older RPC without avatar_id', () {
    final LeaderboardEntry entry = LeaderboardEntry.fromJson(<String, dynamic>{
      'rank': 2,
      'full_name': 'Alex Rivera',
      'best_endless_streak': 18,
    });

    expect(entry.avatarId, isNull);
  });
}
