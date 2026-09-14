import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/endless_question.dart';
import 'package:instructional_math_app/core/models/endless_quiz_leaderboard.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/lesson_page.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/quiz_answer_check_result.dart';
import 'package:instructional_math_app/core/models/quiz_attempt.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_choice.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_content.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_question.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/providers/student_profile_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/endless_quiz_repository.dart';
import 'package:instructional_math_app/core/repositories/quiz_attempts_repository.dart';
import 'package:instructional_math_app/core/repositories/quiz_content_repository.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_screen.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_taking_screen.dart';

const String _gemdasPrompt = 'Evaluate: 24 ÷ 6 × 2';
const String _gemdasExplanation =
    'Division comes first: 24 ÷ 6 = 4. Then multiply: 4 × 2 = 8.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new migrations cannot silently store JSON Unicode escapes', () {
    final Directory migrations = Directory('supabase/migrations');
    final RegExp unicodeEscape = RegExp(r'\\u[0-9a-fA-F]{4}');
    final List<String> unsafeLocations = <String>[];

    for (final FileSystemEntity entity in migrations.listSync()) {
      if (entity is! File || !entity.path.endsWith('.sql')) continue;

      final String filename = entity.uri.pathSegments.last;
      final int? migrationNumber = int.tryParse(filename.split('_').first);
      if (migrationNumber == null || migrationNumber < 88) continue;

      final List<String> lines = entity.readAsLinesSync();
      for (int index = 0; index < lines.length; index += 1) {
        final String line = lines[index];
        final String trimmed = line.trimLeft();
        if (trimmed.startsWith('--')) continue;

        for (final RegExpMatch match in unicodeEscape.allMatches(line)) {
          final String prefix = line.substring(0, match.start);
          if (!prefix.contains("E'")) {
            unsafeLocations.add('${entity.path}:${index + 1}');
          }
        }
      }
    }

    expect(unsafeLocations, isEmpty);
  });

  test('Unicode repair migration is update-only and narrowly scoped', () {
    final String repair =
        File(
          'supabase/migrations/0088_repair_educational_unicode_escapes.sql',
        ).readAsStringSync();
    final RegExp disallowedOperation = RegExp(
      r'^\s*(insert|merge|delete|create|alter|drop|truncate|copy)\b',
      caseSensitive: false,
      multiLine: true,
    );
    final RegExp updatedTable = RegExp(
      r'^\s*update\s+(public\.[a-z_]+)\b',
      caseSensitive: false,
      multiLine: true,
    );

    expect(repair, isNot(matches(disallowedOperation)));
    expect(
      updatedTable
          .allMatches(repair)
          .map((RegExpMatch match) => match.group(1))
          .toSet(),
      <String?>{
        'public.question_bank',
        'public.question_choices',
        'public.quiz_attempt_answers',
        'public.quiz_attempt_answer_choice_snapshots',
      },
    );
    expect(repair, contains("chr(92) || 'u00f7'"));
    expect(repair, contains("q.title = 'Quiz 4: Exponents and GEMDAS'"));
    expect(repair, contains("q.source_type = 'built_in'"));
    expect(repair, contains("q.grade_level = 'grade_6'"));
    expect(RegExp(r'\bstrpos\(').allMatches(repair), hasLength(5));
  });

  testWidgets('lesson content renders representative Unicode math symbols', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      LessonViewerScreen(lesson: _lesson),
      overrides: <Override>[
        lessonProgressRepositoryProvider.overrideWith((Ref ref) => null),
        lessonPagesProvider.overrideWith(
          (Ref ref, String lessonId) =>
              Future<List<LessonPage>>.value(<LessonPage>[_lessonPage]),
        ),
      ],
    );

    expect(find.textContaining('90°'), findsOneWidget);
    expect(find.textContaining('x²'), findsOneWidget);
    expect(find.textContaining('½'), findsOneWidget);
    expect(find.textContaining('≤ 10'), findsOneWidget);
    expect(find.textContaining('π ≈ 3.14'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular quiz renders prompt, choices, and feedback symbols', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      QuizTakingScreen(quiz: _quiz),
      overrides: <Override>[
        quizActiveAttemptProvider.overrideWith(
          (Ref ref, String quizId) => Future<QuizAttempt>.value(_attempt),
        ),
        quizContentProvider.overrideWith(
          (Ref ref, String attemptId) =>
              Future<QuizAttemptContent>.value(_quizContent),
        ),
        quizContentRepositoryProvider.overrideWith(
          (Ref ref) => _UnicodeQuizContentRepository(),
        ),
        quizAttemptsRepositoryProvider.overrideWith(
          (Ref ref) => _UnicodeQuizAttemptsRepository(),
        ),
      ],
    );

    expect(find.text(_gemdasPrompt), findsOneWidget);
    expect(find.text(r'Evaluate: 24 \u00f7 6 \u00d7 2'), findsNothing);
    expect(find.text('8'), findsOneWidget);

    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.tap(find.text('Check Answer'));
    await tester.pump();

    expect(find.text(_gemdasExplanation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Endless Quiz renders decoded mathematical symbols', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const EndlessQuizScreen(),
      overrides: <Override>[
        ownStudentGradeLevelProvider.overrideWith(
          (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade6),
        ),
        endlessQuizRepositoryProvider.overrideWith(
          (Ref ref) => _UnicodeEndlessQuizRepository(),
        ),
      ],
    );

    expect(find.text(_gemdasPrompt), findsOneWidget);
    expect(find.text(r'Evaluate: 24 \u00f7 6 \u00d7 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

final DateTime _timestamp = DateTime.utc(2026, 1, 1);

final Lesson _lesson = Lesson(
  id: 'lesson-unicode',
  title: 'Mathematical Symbols',
  body: 'Body',
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade6,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final LessonPage _lessonPage = LessonPage(
  id: 'page-unicode',
  lessonId: _lesson.id,
  displayOrder: 1,
  title: 'Symbols in mathematics',
  body:
      'The angle is 90°. If x² ≤ 10 and one half is ½, then π ≈ 3.14. Also compare 7 ≥ 6 and 4 ≠ 5.',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Quiz _quiz = Quiz(
  id: 'quiz-unicode',
  title: 'Unicode rendering check',
  quizType: QuizType.internal,
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade6,
  shuffleQuestions: false,
  shuffleChoices: false,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final QuizAttempt _attempt = QuizAttempt(
  id: 'attempt-unicode',
  studentId: 'student-1',
  quizId: _quiz.id,
  sectionId: 'section-1',
  schoolYearId: 'school-year-1',
  attemptStatus: QuizAttemptStatus.active,
  totalQuestions: 1,
  openedAt: _timestamp,
);

const List<QuizAttemptChoice> _choices = <QuizAttemptChoice>[
  QuizAttemptChoice(choiceId: 'choice-8', choiceText: '8'),
  QuizAttemptChoice(choiceId: 'choice-2', choiceText: '2'),
  QuizAttemptChoice(choiceId: 'choice-4', choiceText: '4'),
  QuizAttemptChoice(choiceId: 'choice-288', choiceText: '288'),
];

const QuizAttemptContent _quizContent = QuizAttemptContent(
  questions: <QuizAttemptQuestion>[
    QuizAttemptQuestion(
      questionId: 'question-unicode',
      promptText: _gemdasPrompt,
      choices: _choices,
    ),
  ],
  answeredQuestionIds: <String>[],
);

const EndlessQuestion _endlessQuestion = EndlessQuestion(
  questionId: 'question-unicode',
  promptText: _gemdasPrompt,
  choices: _choices,
);

class _UnicodeQuizContentRepository implements QuizContentRepository {
  @override
  Future<QuizAnswerCheckResult> checkAnswer({
    required String attemptId,
    required String questionId,
    required String choiceId,
  }) async {
    return const QuizAnswerCheckResult(
      isCorrect: true,
      explanationText: _gemdasExplanation,
      choices: <CheckedChoice>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnicodeQuizAttemptsRepository implements QuizAttemptsRepository {
  @override
  Future<void> submitAnswer({
    required String attemptId,
    required String questionId,
    required String questionTextSnapshot,
    required String choiceId,
    required bool isCorrect,
    required List<CheckedChoice> choiceSnapshots,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnicodeEndlessQuizRepository implements EndlessQuizRepository {
  @override
  Future<EndlessQuestion> fetchQuestion() async => _endlessQuestion;

  @override
  Future<bool> checkAnswer({
    required String questionId,
    required String choiceId,
  }) async => true;

  @override
  Future<void> finalizeSession({
    required String studentId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int questionsAnswered,
    required int bestStreakSession,
  }) async {}

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboardTop({int limit = 50}) async =>
      const <LeaderboardEntry>[];

  @override
  Future<LeaderboardEntry> fetchMyRank() async => const LeaderboardEntry(
    rank: 1,
    fullName: 'Student',
    bestEndlessStreak: 0,
  );
}
