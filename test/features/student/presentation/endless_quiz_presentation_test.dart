import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/features/student/presentation/endless_quiz_leaderboard_widgets.dart';

void main() {
  group('Endless Quiz presentation helpers', () {
    test('initials remain compact for long and single-part names', () {
      expect(endlessInitials('Jay Bryan Blas'), 'JB');
      expect(endlessInitials('Alexandria'), 'AL');
      expect(endlessInitials('  Jean   Cyril  '), 'JC');
      expect(endlessInitials(''), '?');
    });
  });
}
