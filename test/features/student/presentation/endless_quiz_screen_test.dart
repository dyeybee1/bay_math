import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/endless_question.dart';
import 'package:instructional_math_app/core/models/endless_quiz_leaderboard.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_choice.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/student_profile_provider.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/endless_quiz_repository.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_screen.dart';

void main() {
  testWidgets('shows a dedicated grade-pool empty state without retry loop', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeEndlessQuizRepository(
        fetchFailure: const NoEndlessQuestionsFailure(),
      ),
    );

    expect(find.text('No questions available yet'), findsOneWidget);
    expect(
      find.text('No Endless Quiz questions are available for your grade yet.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders choices, checks an answer, advances, and saves run', (
    WidgetTester tester,
  ) async {
    final _FakeEndlessQuizRepository repository = _FakeEndlessQuizRepository(
      questions: <EndlessQuestion>[_first, _next],
    );

    await _pumpScreen(tester, repository, includeSession: true);

    expect(find.text('Grade 4 · Practice run'), findsOneWidget);
    expect(find.text('What is 6 × 7?'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);

    await tester.tap(find.text('42'));
    await tester.pump();

    expect(repository.checkedQuestionId, _first.questionId);
    expect(repository.checkedChoiceId, 'choice-correct');
    expect(find.text('Correct — keep the run going'), findsOneWidget);
    expect(find.text('1 correct in a row'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();

    expect(find.text('What is 9 × 5?'), findsOneWidget);

    await tester.tap(find.text('Finish this run'));
    await tester.pumpAndSettle();

    expect(repository.finalized, isTrue);
    expect(repository.finalizedStudentId, 'student-grade-4');
    expect(repository.finalizedQuestionsAnswered, 1);
    expect(repository.finalizedBestStreak, 1);
    expect(find.text('Run complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeEndlessQuizRepository repository, {
  bool includeSession = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 700);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ownStudentGradeLevelProvider.overrideWith(
          (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade4),
        ),
        endlessQuizRepositoryProvider.overrideWith((Ref ref) => repository),
        if (includeSession)
          studentSessionProvider.overrideWith(
            (Ref ref) => StudentSession(
              accessToken: 'test-token',
              expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              studentId: 'student-grade-4',
            ),
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const EndlessQuizScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _FakeEndlessQuizRepository implements EndlessQuizRepository {
  _FakeEndlessQuizRepository({
    this.questions = const <EndlessQuestion>[],
    this.fetchFailure,
  });

  final List<EndlessQuestion> questions;
  final AppFailure? fetchFailure;
  int _fetchIndex = 0;

  String? checkedQuestionId;
  String? checkedChoiceId;
  bool finalized = false;
  String? finalizedStudentId;
  int? finalizedQuestionsAnswered;
  int? finalizedBestStreak;

  @override
  Future<EndlessQuestion> fetchQuestion() async {
    if (fetchFailure case final AppFailure failure) throw failure;
    final int index = _fetchIndex.clamp(0, questions.length - 1);
    _fetchIndex += 1;
    return questions[index];
  }

  @override
  Future<bool> checkAnswer({
    required String questionId,
    required String choiceId,
  }) async {
    checkedQuestionId = questionId;
    checkedChoiceId = choiceId;
    return choiceId == 'choice-correct';
  }

  @override
  Future<void> finalizeSession({
    required String studentId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int questionsAnswered,
    required int bestStreakSession,
  }) async {
    finalized = true;
    finalizedStudentId = studentId;
    finalizedQuestionsAnswered = questionsAnswered;
    finalizedBestStreak = bestStreakSession;
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboardTop({int limit = 50}) async =>
      const <LeaderboardEntry>[];

  @override
  Future<LeaderboardEntry> fetchMyRank() async => const LeaderboardEntry(
    rank: 1,
    fullName: 'Student',
    bestEndlessStreak: 1,
  );
}

const EndlessQuestion _first = EndlessQuestion(
  questionId: 'question-1',
  promptText: 'What is 6 × 7?',
  choices: <QuizAttemptChoice>[
    QuizAttemptChoice(choiceId: 'choice-wrong', choiceText: '36'),
    QuizAttemptChoice(choiceId: 'choice-correct', choiceText: '42'),
  ],
);

const EndlessQuestion _next = EndlessQuestion(
  questionId: 'question-2',
  promptText: 'What is 9 × 5?',
  choices: <QuizAttemptChoice>[
    QuizAttemptChoice(choiceId: 'choice-correct', choiceText: '45'),
    QuizAttemptChoice(choiceId: 'choice-wrong', choiceText: '54'),
  ],
);
