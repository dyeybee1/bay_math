import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/models/question_bank_item.dart';
import 'package:instructional_math_app/core/models/quiz_question.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/quizzes_repository.dart';
import 'package:instructional_math_app/core/widgets/buttons/app_button.dart';
import 'package:instructional_math_app/core/widgets/inputs/app_text_field.dart';
import 'package:instructional_math_app/features/teacher/presentation/quizzes_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_shell_screen.dart'
    show MySection, mySectionsProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('New Quiz creates only an Internal Quiz without a type choice', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 800);
    addTearDown(tester.view.reset);
    final _FakeQuizzesRepository repository = _FakeQuizzesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_TestSessionNotifier.new),
          quizzesRepositoryProvider.overrideWithValue(repository),
          quizzesProvider.overrideWith((Ref ref) => const <Quiz>[]),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const QuizzesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(QuizzesScreen)),
    );
    await container.read(sessionProvider.future);
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'New Quiz').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Type'), findsNothing);
    expect(find.text('External Activity'), findsNothing);
    expect(find.text('URL'), findsNothing);
    expect(find.text('Platform (optional)'), findsNothing);
    expect(find.text('Shuffle questions'), findsOneWidget);
    expect(find.text('Shuffle choices'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Create Quiz'));
    await tester.pump();
    expect(find.text('Enter a quiz title.'), findsOneWidget);
    expect(repository.createCount, 0);

    await tester.enterText(find.byType(AppTextField), 'Fractions Review');
    await tester.tap(find.byType(Switch).first);
    await tester.tap(find.widgetWithText(AppButton, 'Create Quiz'));
    await tester.pumpAndSettle();

    expect(repository.createCount, 1);
    expect(repository.title, 'Fractions Review');
    expect(repository.quizType, QuizType.internal);
    expect(repository.createdBy, _teacher.id);
    expect(repository.externalUrl, isNull);
    expect(repository.externalPlatformHint, isNull);
    expect(repository.shuffleQuestions, isFalse);
    expect(repository.shuffleChoices, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiz library filters use source and assessment fields', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 800);
    addTearDown(tester.view.reset);
    final Quiz regular = _quiz(
      id: 'regular',
      title: 'Quiz 1: Whole Numbers',
      sourceType: ContentSourceType.builtIn,
      gradeLevel: GradeLevel.grade4,
    );
    final Quiz preTest = _quiz(
      id: 'pre-test',
      title: 'Grade 4 Pre-Test',
      sourceType: ContentSourceType.builtIn,
      gradeLevel: GradeLevel.grade4,
      assessmentType: AssessmentType.preTest,
    );
    final Quiz postTest = _quiz(
      id: 'post-test',
      title: 'Grade 4 Post-Test',
      sourceType: ContentSourceType.builtIn,
      gradeLevel: GradeLevel.grade4,
      assessmentType: AssessmentType.postTest,
    );
    final Quiz mine = _quiz(
      id: 'mine',
      title: 'Fractions Review',
      sourceType: ContentSourceType.teacher,
      createdBy: _teacher.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizzesProvider.overrideWith(
            (Ref ref) => <Quiz>[mine, postTest, regular, preTest],
          ),
          quizQuestionCountsProvider.overrideWith(
            (Ref ref) => <String, int>{
              regular.id: 10,
              preTest.id: 30,
              postTest.id: 30,
              mine.id: 1,
            },
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const QuizzesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Built-in'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'My Quizzes'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Pre-Test'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Post-Test'), findsOneWidget);
    expect(find.text('Quiz 11: Fractions Review'), findsOneWidget);
    expect(find.textContaining('Regular Quiz'), findsNWidgets(2));
    expect(find.widgetWithText(AppButton, 'Manage'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('delete-quiz-action')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('delete-quiz-action')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Quiz'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'My Quizzes'));
    await tester.pump();
    expect(find.text('Quiz 11: Fractions Review'), findsOneWidget);
    expect(find.text('Quiz 1: Whole Numbers'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pre-Test'));
    await tester.pump();
    expect(find.text('Grade 4 Pre-Test'), findsOneWidget);
    expect(find.text('Grade 4 Post-Test'), findsNothing);
    expect(find.text('Quiz 1: Whole Numbers'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful delete removes the Teacher quiz card', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 800);
    addTearDown(tester.view.reset);
    final Quiz mine = _quiz(
      id: 'mine-to-delete',
      title: 'Eme lang',
      sourceType: ContentSourceType.teacher,
      createdBy: _teacher.id,
    );
    final _FakeQuizzesRepository repository = _FakeQuizzesRepository(
      quizzes: <Quiz>[mine],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizzesRepositoryProvider.overrideWithValue(repository),
          quizQuestionCountsProvider.overrideWith(
            (Ref ref) => <String, int>{mine.id: 1},
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const Scaffold(body: QuizzesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quiz 11: Eme lang'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('delete-quiz-action')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Delete this quiz permanently? Student attempts and results for this quiz will also be deleted. This action cannot be undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(AppButton, 'Delete permanently'));
    await tester.pumpAndSettle();

    expect(repository.deletedQuizIds, <String>[mine.id]);
    expect(find.text('Quiz 11: Eme lang'), findsNothing);
    expect(find.text('No quizzes yet'), findsOneWidget);
    expect(find.text('Quiz deleted successfully.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete failure keeps the card and shows a useful message', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 800);
    addTearDown(tester.view.reset);
    final Quiz mine = _quiz(
      id: 'mine-with-results',
      title: 'Quiz With Results',
      sourceType: ContentSourceType.teacher,
      createdBy: _teacher.id,
    );
    final _FakeQuizzesRepository repository = _FakeQuizzesRepository(
      quizzes: <Quiz>[mine],
      deleteFailure: const ServerFailure(
        'Could not delete the quiz. Please try again.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizzesRepositoryProvider.overrideWithValue(repository),
          quizQuestionCountsProvider.overrideWith(
            (Ref ref) => <String, int>{mine.id: 1},
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const Scaffold(body: QuizzesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-quiz-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz 11: Quiz With Results'), findsOneWidget);
    expect(
      find.text('Could not delete the quiz. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('existing student attempts or results'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manage opens the responsive details, sections, and questions UI',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(720, 900);
      addTearDown(tester.view.reset);
      final Quiz mine = _quiz(
        id: 'mine',
        title: 'Fractions Review',
        sourceType: ContentSourceType.teacher,
        createdBy: _teacher.id,
      );
      final List<QuizQuestion> quizQuestions = <QuizQuestion>[
        const QuizQuestion(
          id: 'link-1',
          quizId: 'mine',
          questionId: 'question-1',
          displayOrder: 1,
        ),
      ];
      final List<QuestionBankItem> questions = <QuestionBankItem>[
        QuestionBankItem(
          id: 'question-1',
          sourceType: ContentSourceType.builtIn,
          topic: 'Fractions',
          promptText: 'Which fraction is equivalent to one half?',
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizzesProvider.overrideWith((Ref ref) => <Quiz>[mine]),
            quizQuestionCountsProvider.overrideWith(
              (Ref ref) => <String, int>{mine.id: 1},
            ),
            mySectionsProvider.overrideWith((Ref ref) => const <MySection>[]),
            quizSectionIdsProvider(
              mine.id,
            ).overrideWith((Ref ref) => const <String>[]),
            quizQuestionsProvider(
              mine.id,
            ).overrideWith((Ref ref) => quizQuestions),
            allVisibleQuestionsProvider.overrideWith((Ref ref) => questions),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const QuizzesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Manage'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Quiz'), findsOneWidget);
      expect(find.text('Quiz Details'), findsOneWidget);
      expect(find.text('Assigned Sections'), findsOneWidget);
      expect(find.text('Questions'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Save Changes'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Assign Sections'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Add Question'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsOneWidget);

      final Finder assignSections = find.widgetWithText(
        AppButton,
        'Assign Sections',
      );
      await tester.ensureVisible(assignSections);
      await tester.tap(assignSections);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.text('You have no sections to assign this quiz to yet.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Done'));
      await tester.pumpAndSettle();

      final Finder addQuestion = find.widgetWithText(AppButton, 'Add Question');
      await tester.ensureVisible(addQuestion);
      await tester.tap(addQuestion);
      await tester.pumpAndSettle();
      expect(find.textContaining('Add Questions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Quiz _quiz({
  required String id,
  required String title,
  required ContentSourceType sourceType,
  String? createdBy,
  GradeLevel? gradeLevel,
  AssessmentType? assessmentType,
}) {
  return Quiz(
    id: id,
    title: title,
    quizType: QuizType.internal,
    sourceType: sourceType,
    createdBy: createdBy,
    gradeLevel: gradeLevel,
    assessmentType: assessmentType,
    shuffleQuestions: true,
    shuffleChoices: true,
    createdAt: _timestamp,
    updatedAt: _timestamp,
  );
}

class _TestSessionNotifier extends SessionNotifier {
  @override
  Future<SessionState> build() async => SessionTeacher(_teacher);
}

final SupabaseClient _testClient = SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeQuizzesRepository extends QuizzesRepository {
  _FakeQuizzesRepository({
    List<Quiz> quizzes = const <Quiz>[],
    this.deleteFailure,
  }) : quizzes = List<Quiz>.of(quizzes),
       super(_testClient);

  final List<Quiz> quizzes;
  final AppFailure? deleteFailure;
  final List<String> deletedQuizIds = <String>[];
  int createCount = 0;
  String? title;
  QuizType? quizType;
  String? createdBy;
  String? externalUrl;
  ExternalPlatformHint? externalPlatformHint;
  bool? shuffleQuestions;
  bool? shuffleChoices;

  @override
  Future<List<Quiz>> fetchVisibleToTeacher() async => List<Quiz>.of(quizzes);

  @override
  Future<void> delete(String quizId) async {
    final AppFailure? failure = deleteFailure;
    if (failure != null) throw failure;
    deletedQuizIds.add(quizId);
    quizzes.removeWhere((Quiz quiz) => quiz.id == quizId);
  }

  @override
  Future<String> create({
    required String title,
    required QuizType quizType,
    required String createdBy,
    String? externalUrl,
    ExternalPlatformHint? externalPlatformHint,
    bool shuffleQuestions = true,
    bool shuffleChoices = true,
  }) async {
    createCount += 1;
    this.title = title;
    this.quizType = quizType;
    this.createdBy = createdBy;
    this.externalUrl = externalUrl;
    this.externalPlatformHint = externalPlatformHint;
    this.shuffleQuestions = shuffleQuestions;
    this.shuffleChoices = shuffleChoices;
    return 'new-quiz-id';
  }
}

final DateTime _timestamp = DateTime.utc(2026, 9, 7);

final Profile _teacher = Profile(
  id: 'teacher-1',
  role: ProfileRole.teacher,
  status: ProfileStatus.approved,
  fullName: 'Test Teacher',
  email: 'teacher@example.com',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
