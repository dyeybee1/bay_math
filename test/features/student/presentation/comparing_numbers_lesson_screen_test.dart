import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/app/theme/app_colors.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/lesson_progress_repository.dart';
import 'package:instructional_math_app/features/student/presentation/comparing_numbers_lesson_screen.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart'
    show linkedQuizProvider;
import 'package:instructional_math_app/features/student/presentation/quiz_taking_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeProgressRepository extends LessonProgressRepository {
  _FakeProgressRepository()
    : super(
        SupabaseClient(
          'https://example.test',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int completionCalls = 0;
  bool failNext = true;

  @override
  Future<void> markCompleted({
    required String studentId,
    required String lessonId,
  }) async {
    completionCalls++;
    if (failNext) {
      failNext = false;
      throw StateError('temporary save failure');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const Key captureKey = Key('comparing_lesson_capture');
  final Lesson target = Lesson(
    id: 'comparison',
    title: 'Comparing Numbers up to 1,000,000',
    body: '',
    sourceType: ContentSourceType.builtIn,
    gradeLevel: GradeLevel.grade4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpLesson(
    WidgetTester tester, {
    List<Override> overrides = const <Override>[],
    Lesson? lesson,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: AppColors.scheme),
          home: RepaintBoundary(
            key: captureKey,
            child: Scaffold(
              body: ComparingNumbersLessonScreen(lesson: lesson ?? target),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/comparing_numbers_owl.jpg'),
        tester.element(find.byType(ComparingNumbersLessonScreen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_LESSON_SCREENSHOTS')) return;
    final RenderRepaintBoundary boundary = tester.renderObject(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 1);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Directory directory = Directory(
        'artifacts/comparing_numbers_lesson',
      );
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'fits all requested landscape viewports and retains state in portrait',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_LESSON_SCREENSHOTS') &&
          Platform.isWindows) {
        await tester.runAsync(() async {
          final File font = File('C:/Windows/Fonts/segoeui.ttf');
          for (final String family in <String>['Roboto']) {
            await (FontLoader(family)..addFont(
              font.readAsBytes().then(
                (List<int> bytes) =>
                    ByteData.sublistView(Uint8List.fromList(bytes)),
              ),
            )).load();
          }
        });
      }
      for (final Size size in <Size>[
        const Size(1024, 600),
        const Size(1024, 768),
        const Size(1280, 800),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await pumpLesson(tester);
        expect(find.text('Which number is greater?'), findsWidgets);
        expect(find.text('← Previous'), findsOneWidget);
        expect(find.text('Next part →'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport $size');
        await capture(
          tester,
          'start_${size.width.toInt()}x${size.height.toInt()}',
        );
      }

      await tester.tap(find.text('85,000').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Good comparison!'), findsOneWidget);
      tester.view.physicalSize = const Size(600, 1024);
      await tester.pumpAndSettle();
      expect(find.text('Turn your tablet sideways'), findsOneWidget);
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      expect(find.textContaining('Good comparison!'), findsOneWidget);
      await tester.tap(find.text('Explore the method →'));
      await tester.pumpAndSettle();
      expect(find.text('Compare from left to right'), findsOneWidget);
      await capture(tester, 'learn_1024x600');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'three correct answers and Finish save once, with retry after failure',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      final _FakeProgressRepository repository = _FakeProgressRepository();
      await pumpLesson(
        tester,
        overrides: <Override>[
          studentSessionProvider.overrideWith(
            (Ref ref) => StudentSession(
              accessToken: 'test',
              expiresAt: DateTime(2100),
              studentId: 'student',
            ),
          ),
          lessonProgressRepositoryProvider.overrideWith(
            (Ref ref) => repository,
          ),
        ],
      );
      await tester.tap(find.text('Try together').first);
      await tester.pumpAndSettle();
      await capture(tester, 'try_together_1024x600');
      await tester.tap(find.text('Special cases').first);
      await tester.pumpAndSettle();
      await capture(tester, 'special_equal_1024x600');
      await tester.tap(find.text('Practice').first);
      await tester.pumpAndSettle();
      await capture(tester, 'practice_1024x600');
      expect(find.text('Finish lesson ✓'), findsNothing);
      for (final String symbol in <String>['<', '>', '=']) {
        await tester.tap(find.text(symbol).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(symbol == '=' ? 'See the recap →' : 'Next question →'),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Finish lesson ✓'), findsOneWidget);
      await capture(tester, 'recap_1024x600');
      expect(repository.completionCalls, 0);
      await tester.tap(find.text('Finish lesson ✓'));
      await tester.pumpAndSettle();
      expect(repository.completionCalls, 1);
      expect(find.text('Retry saving lesson'), findsOneWidget);
      await tester.tap(find.text('Retry saving lesson'));
      await tester.pumpAndSettle();
      expect(repository.completionCalls, 2);
      expect(find.text('Lesson finished!'), findsOneWidget);
      expect(find.text('Retry saving lesson'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('optional linked quiz opens the existing quiz screen', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    final Lesson lessonWithQuiz = Lesson(
      id: target.id,
      title: target.title,
      body: target.body,
      sourceType: target.sourceType,
      gradeLevel: target.gradeLevel,
      linkedQuizId: 'quiz-id',
      createdAt: target.createdAt,
      updatedAt: target.updatedAt,
    );
    final Quiz quiz = Quiz(
      id: 'quiz-id',
      title: 'Comparing numbers quiz',
      quizType: QuizType.internal,
      sourceType: ContentSourceType.builtIn,
      gradeLevel: GradeLevel.grade4,
      shuffleQuestions: false,
      shuffleChoices: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await pumpLesson(
      tester,
      lesson: lessonWithQuiz,
      overrides: <Override>[
        linkedQuizProvider.overrideWith((Ref ref, String id) async => quiz),
      ],
    );
    await tester.tap(find.text('Practice').first);
    await tester.pumpAndSettle();
    for (final String symbol in <String>['<', '>', '=']) {
      await tester.tap(find.text(symbol).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(symbol == '=' ? 'See the recap →' : 'Next question →'),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Take Quiz · Optional'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'recap_with_quiz_1024x600');
    await tester.tap(find.text('Take Quiz · Optional'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizTakingScreen), findsOneWidget);
  });
}
