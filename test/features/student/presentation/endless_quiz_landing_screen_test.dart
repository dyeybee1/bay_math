import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/endless_quiz_leaderboard.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/providers/student_profile_provider.dart';
import 'package:instructional_math_app/features/student/data/endless_quiz_leaderboard_providers.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_full_leaderboard_screen.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_landing_screen.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_screen.dart';

const List<LeaderboardEntry> _entries = <LeaderboardEntry>[
  LeaderboardEntry(rank: 1, fullName: 'Ada Reyes', bestEndlessStreak: 37),
  LeaderboardEntry(rank: 2, fullName: 'Ben Cruz', bestEndlessStreak: 32),
  LeaderboardEntry(rank: 3, fullName: 'Cora Santos', bestEndlessStreak: 32),
  LeaderboardEntry(rank: 4, fullName: 'Dee Lim', bestEndlessStreak: 18),
];

const LeaderboardEntry _myRank = LeaderboardEntry(
  rank: 7,
  fullName: 'Jules Rivera',
  bestEndlessStreak: 11,
);

Future<void> _pumpLanding(
  WidgetTester tester,
  Size size, {
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ownStudentGradeLevelProvider.overrideWith(
          (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade4),
        ),
        endlessQuizLeaderboardProvider.overrideWith(
          (Ref ref) => Future<EndlessQuizLeaderboardData>.value((
            topEntries: _entries,
            myRank: _myRank,
          )),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder:
            (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
        home: const EndlessQuizLandingScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('landing uses live values and two columns at tablet sizes', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(1024, 768),
      const Size(1280, 800),
    ]) {
      await _pumpLanding(tester, size);
      expect(find.text('Small steps.\nBig math energy.'), findsOneWidget);
      expect(find.text('PERSONAL BEST'), findsOneWidget);
      expect(find.text('GRADE RANK'), findsOneWidget);
      expect(find.text('11'), findsWidgets);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('Ada Reyes'), findsOneWidget);
      expect(find.text('Ben Cruz'), findsOneWidget);
      expect(find.text('Cora Santos'), findsOneWidget);
      expect(find.text('Jules Rivera'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Streak leaders')).dx,
        greaterThan(tester.getTopLeft(find.text('PERSONAL BEST')).dx),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('How to play'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('How a run works'), findsOneWidget);
    await tester.tap(find.text('Ready to practice'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Your personal best'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your Endless Quiz progress'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('See all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(EndlessQuizFullLeaderboardScreen), findsOneWidget);
  });

  testWidgets('portrait fallback remains scrollable without layout errors', (
    WidgetTester tester,
  ) async {
    await _pumpLanding(tester, const Size(390, 844));
    expect(find.text('Small steps.\nBig math energy.'), findsOneWidget);
    await tester.ensureVisible(find.text('See all'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('See all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mascot rotation pauses, resumes, and respects reduced motion', (
    WidgetTester tester,
  ) async {
    await _pumpLanding(tester, const Size(1024, 768));
    expect(find.text("You've got this!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Ready for a question?'), findsOneWidget);

    await tester.tap(find.text('Ready for a question?'));
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Ready for a question?'), findsOneWidget);
    await tester.tap(find.text('Ready for a question?'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Take your time.'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Take your time.'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('One step at a time!'), findsOneWidget);

    await tester.tap(find.text('How to play'));
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('One step at a time!'), findsOneWidget);
    await tester.tap(find.text('Ready to practice'));
    await tester.pump(const Duration(milliseconds: 250));

    await _pumpLanding(tester, const Size(1024, 768), reduceMotion: true);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text("You've got this!"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('start action opens existing quiz screen', (
    WidgetTester tester,
  ) async {
    await _pumpLanding(tester, const Size(1024, 768));
    await tester.tap(find.text('Start a run'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(EndlessQuizScreen), findsOneWidget);
  });
}
