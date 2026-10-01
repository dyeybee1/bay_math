import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/quiz_attempt.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/models/student_statistics.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/quiz_attempts_repository.dart';
import 'package:instructional_math_app/features/student/data/student_quiz_submission_controller.dart';
import 'package:instructional_math_app/features/student/data/student_statistics_providers.dart';

void main() {
  group('Student quiz completion synchronization', () {
    test(
      'successful submission invalidates and refetches Statistics',
      () async {
        int completedQuizCount = 0;
        int statisticsFetchCount = 0;
        final StudentSession session = _session;
        final _FakeQuizAttemptsRepository repository =
            _FakeQuizAttemptsRepository(
              onFinalize: (String attemptId) async {
                completedQuizCount += 1;
                return _attempt(attemptId);
              },
            );
        final ProviderContainer container = _container(
          repository: repository,
          session: session,
          loadStatistics: () async {
            statisticsFetchCount += 1;
            return _statistics(completedQuizCount);
          },
        );
        addTearDown(container.dispose);
        final ProviderSubscription<AsyncValue<StudentStatistics>> subscription =
            container.listen(studentStatisticsProvider, (_, _) {});
        addTearDown(subscription.close);

        final StudentStatistics before = await container.read(
          studentStatisticsProvider.future,
        );
        expect(before.summary.quizzesCompleted, 0);
        expect(statisticsFetchCount, 1);

        final StudentQuizSubmissionController controller =
            container.read(studentQuizSubmissionControllerProvider)!;
        final QuizAttempt completed = await controller.submit('attempt-1');
        final StudentStatistics after = await container.read(
          studentStatisticsProvider.future,
        );

        expect(completed.id, 'attempt-1');
        expect(completed.isSubmitted, isTrue);
        expect(after.summary.quizzesCompleted, 1);
        expect(statisticsFetchCount, 2);
        expect(repository.finalizeCount, 1);
        expect(
          identical(container.read(studentSessionProvider), session),
          isTrue,
        );
      },
    );

    test('multiple sequential submissions each refresh Statistics', () async {
      int completedQuizCount = 0;
      int statisticsFetchCount = 0;
      final _FakeQuizAttemptsRepository repository =
          _FakeQuizAttemptsRepository(
            onFinalize: (String attemptId) async {
              completedQuizCount += 1;
              return _attempt(attemptId);
            },
          );
      final ProviderContainer container = _container(
        repository: repository,
        session: _session,
        loadStatistics: () async {
          statisticsFetchCount += 1;
          return _statistics(completedQuizCount);
        },
      );
      addTearDown(container.dispose);
      final ProviderSubscription<AsyncValue<StudentStatistics>> subscription =
          container.listen(studentStatisticsProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(
        (await container.read(
          studentStatisticsProvider.future,
        )).summary.quizzesCompleted,
        0,
      );
      final StudentQuizSubmissionController controller =
          container.read(studentQuizSubmissionControllerProvider)!;

      await controller.submit('attempt-1');
      expect(
        (await container.read(
          studentStatisticsProvider.future,
        )).summary.quizzesCompleted,
        1,
      );

      await controller.submit('attempt-2');
      expect(
        (await container.read(
          studentStatisticsProvider.future,
        )).summary.quizzesCompleted,
        2,
      );
      expect(repository.finalizeCount, 2);
      expect(statisticsFetchCount, 3);
    });

    test(
      'failed submission does not invalidate or update Statistics',
      () async {
        int statisticsFetchCount = 0;
        final _FakeQuizAttemptsRepository repository =
            _FakeQuizAttemptsRepository(
              onFinalize:
                  (String attemptId) => Future<QuizAttempt>.error(
                    const ServerFailure('Submission failed.'),
                  ),
            );
        final ProviderContainer container = _container(
          repository: repository,
          session: _session,
          loadStatistics: () async {
            statisticsFetchCount += 1;
            return _statistics(0);
          },
        );
        addTearDown(container.dispose);

        final StudentStatistics before = await container.read(
          studentStatisticsProvider.future,
        );
        final StudentQuizSubmissionController controller =
            container.read(studentQuizSubmissionControllerProvider)!;

        await expectLater(
          controller.submit('attempt-failed'),
          throwsA(isA<ServerFailure>()),
        );
        final StudentStatistics after = await container.read(
          studentStatisticsProvider.future,
        );

        expect(identical(after, before), isTrue);
        expect(statisticsFetchCount, 1);
        expect(repository.finalizeCount, 1);
      },
    );

    test(
      'statistics refresh never finalizes or duplicates the attempt',
      () async {
        int statisticsFetchCount = 0;
        final _FakeQuizAttemptsRepository repository =
            _FakeQuizAttemptsRepository(
              onFinalize: (String attemptId) async => _attempt(attemptId),
            );
        final ProviderContainer container = _container(
          repository: repository,
          session: _session,
          loadStatistics: () async {
            statisticsFetchCount += 1;
            return _statistics(1);
          },
        );
        addTearDown(container.dispose);

        await container.read(studentStatisticsProvider.future);
        await container
            .read(studentQuizSubmissionControllerProvider)!
            .submit('attempt-1');
        await container.read(studentStatisticsProvider.future);
        await container.read(studentStatisticsProvider.future);

        expect(repository.finalizeCount, 1);
        expect(statisticsFetchCount, 2);
      },
    );
  });
}

ProviderContainer _container({
  required _FakeQuizAttemptsRepository repository,
  required StudentSession session,
  required Future<StudentStatistics> Function() loadStatistics,
}) {
  return ProviderContainer(
    overrides: <Override>[
      studentSessionProvider.overrideWith((Ref ref) => session),
      quizAttemptsRepositoryProvider.overrideWithValue(repository),
      studentStatisticsProvider.overrideWith((Ref ref) => loadStatistics()),
    ],
  );
}

class _FakeQuizAttemptsRepository extends QuizAttemptsRepository {
  _FakeQuizAttemptsRepository({required this.onFinalize})
    : super(SupabaseClient('http://localhost', 'test-anon-key'));

  final Future<QuizAttempt> Function(String attemptId) onFinalize;
  int finalizeCount = 0;

  @override
  Future<QuizAttempt> finalize(String attemptId) {
    finalizeCount += 1;
    return onFinalize(attemptId);
  }
}

final StudentSession _session = StudentSession(
  accessToken: 'student-token',
  expiresAt: DateTime.utc(2027),
  studentId: 'student-1',
);

QuizAttempt _attempt(String id) => QuizAttempt(
  id: id,
  studentId: _session.studentId,
  quizId: 'quiz-1',
  sectionId: 'section-1',
  schoolYearId: 'school-year-1',
  attemptStatus: QuizAttemptStatus.active,
  totalQuestions: 1,
  score: 1,
  openedAt: DateTime.utc(2026),
  submittedAt: DateTime.utc(2026, 1, 1, 0, 1),
);

StudentStatistics _statistics(int completedQuizCount) => StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: _session.studentId,
    bestEndlessStreak: 0,
    lessonsTotal: 1,
    lessonsCompleted: 0,
    quizzesCompleted: completedQuizCount,
    averageScorePercent: completedQuizCount == 0 ? null : 100,
    bestScorePercent: completedQuizCount == 0 ? null : 100,
  ),
  lessonQuizScores: const <LessonQuizScore>[],
  competencyMastery: const <TopicMastery>[],
  overallAccuracy: OverallAccuracy(
    studentId: _session.studentId,
    correct: completedQuizCount,
    incorrect: 0,
    accuracyPercent: completedQuizCount == 0 ? null : 100,
  ),
);
