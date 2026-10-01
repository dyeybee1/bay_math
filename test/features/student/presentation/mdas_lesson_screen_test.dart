import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/app/theme/app_colors.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/lesson_progress_repository.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart'
    show linkedQuizProvider;
import 'package:instructional_math_app/features/student/presentation/mdas_lesson_screen.dart';
import 'package:instructional_math_app/features/student/presentation/mdas_lesson_state.dart';
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
  int calls = 0;
  bool failNext = true;

  @override
  Future<void> markCompleted({
    required String studentId,
    required String lessonId,
  }) async {
    calls++;
    if (failNext) {
      failNext = false;
      throw StateError('temporary failure');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const Key captureKey = Key('mdas_capture');
  bool fontLoaded = false;
  final Lesson lesson = Lesson(
    id: 'mdas',
    title: 'Multiplication, Division, and MDAS',
    body: '',
    sourceType: ContentSourceType.builtIn,
    gradeLevel: GradeLevel.grade4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpLesson(
    WidgetTester tester, {
    MdasLessonState? state,
    Lesson? target,
    List<Override> overrides = const <Override>[],
  }) async {
    if (const bool.fromEnvironment('CAPTURE_LESSON_SCREENSHOTS') &&
        Platform.isWindows &&
        !fontLoaded) {
      await tester.runAsync(() async {
        await (FontLoader('Roboto')..addFont(
          File('C:/Windows/Fonts/segoeui.ttf').readAsBytes().then(
            (List<int> bytes) =>
                ByteData.sublistView(Uint8List.fromList(bytes)),
          ),
        )).load();
      });
      fontLoaded = true;
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: AppColors.scheme),
          home: RepaintBoundary(
            key: captureKey,
            child: Scaffold(
              body: MdasLessonScreen(
                lesson: target ?? lesson,
                initialState: state,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/comparing_numbers_owl.jpg'),
        tester.element(find.byType(MdasLessonScreen)),
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
      final Directory directory = Directory('artifacts/mdas_lesson');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  ValueKey<String> cardKey(MdasCard card) =>
      ValueKey<String>('mdas_card_${card.identity}');
  ValueKey<String> targetKey(MdasTarget target) =>
      ValueKey<String>('mdas_target_${target.identity}');

  testWidgets(
    'seven phases render at target sizes and rotation retains the activity',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final MdasLessonState state = MdasLessonState();
      for (final Size size in <Size>[
        const Size(1024, 600),
        const Size(1024, 768),
        const Size(1280, 800),
      ]) {
        tester.view.physicalSize = size;
        await pumpLesson(tester, state: state);
        expect(tester.takeException(), isNull, reason: '$size');
        expect(find.text('← Previous'), findsOneWidget);
        expect(find.text('Next →'), findsOneWidget);
        expect(
          tester
              .getSize(
                find.byKey(cardKey(const MdasCard(MdasCardKind.bundle, id: 0))),
              )
              .height,
          greaterThanOrEqualTo(52),
        );
        expect(
          tester
              .getSize(
                find.byKey(
                  targetKey(const MdasTarget(MdasTargetKind.tray, id: 0)),
                ),
              )
              .height,
          greaterThanOrEqualTo(52),
        );
        await capture(
          tester,
          'groups_${size.width.toInt()}x${size.height.toInt()}',
        );
      }
      tester.view.physicalSize = const Size(1024, 600);
      for (int phase = 1; phase < 7; phase++) {
        state.phase = phase;
        await pumpLesson(tester, state: state);
        expect(tester.takeException(), isNull, reason: 'phase $phase');
        await capture(tester, 'phase_${phase + 1}_1024x600');
      }
      state.phase = 0;
      await pumpLesson(tester, state: state);
      await tester.tap(
        find.byKey(cardKey(const MdasCard(MdasCardKind.bundle, id: 0))),
      );
      await tester.tap(
        find.byKey(targetKey(const MdasTarget(MdasTargetKind.tray, id: 0))),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(600, 1024);
      await tester.pumpAndSettle();
      expect(find.text('Turn your tablet sideways'), findsOneWidget);
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      expect(state.current.runningTotal, 6);
      expect(find.textContaining('Total so far: 6'), findsWidgets);
    },
  );

  testWidgets('larger groups and later steps fit the short tablet', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    final MdasLessonState state = MdasLessonState();
    for (final (int phase, int index, String name) in <(int, int, String)>[
      (0, 1, 'groups_7x8'),
      (0, 2, 'groups_9x6'),
      (1, 2, 'division_64'),
      (3, 2, 'first_left_to_right'),
      (6, 2, 'practice_mdas'),
    ]) {
      state.phase = phase;
      state.indices[phase] = index;
      await pumpLesson(tester, state: state);
      expect(tester.takeException(), isNull, reason: name);
      await capture(tester, '${name}_1024x600');
    }
    state.phase = 4;
    state.indices[4] = 1;
    expect(state.chooseOperation(1), isTrue);
    await pumpLesson(tester, state: state);
    expect(tester.takeException(), isNull);
    await capture(tester, 'solve_result_1024x600');
    state.phase = 5;
    state.indices[5] = 1;
    expect(state.chooseStoryOperation('÷'), isTrue);
    await pumpLesson(tester, state: state);
    expect(tester.takeException(), isNull);
    await capture(tester, 'pencil_shares_1024x600');
  });

  testWidgets('drag, tap, keyboard, and one-tap operation and result work', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    final MdasLessonState state = MdasLessonState();
    await pumpLesson(tester, state: state);
    await tester.drag(
      find.byKey(cardKey(const MdasCard(MdasCardKind.bundle, id: 0))),
      const Offset(-380, -160),
    );
    await tester.pumpAndSettle();
    expect(state.current.placedBundles, isEmpty);
    await tester.drag(
      find.byKey(cardKey(const MdasCard(MdasCardKind.bundle, id: 0))),
      tester.getCenter(
            find.byKey(targetKey(const MdasTarget(MdasTargetKind.tray, id: 0))),
          ) -
          tester.getCenter(
            find.byKey(cardKey(const MdasCard(MdasCardKind.bundle, id: 0))),
          ),
    );
    await tester.pumpAndSettle();
    expect(state.current.placedBundles, <int>{0});
    Focus.of(
      tester.element(
        find.byKey(cardKey(const MdasCard(MdasCardKind.bundle, id: 1))),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    Focus.of(
      tester.element(
        find.byKey(targetKey(const MdasTarget(MdasTargetKind.tray, id: 1))),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(state.current.placedBundles, <int>{0, 1});

    state.phase = 4;
    await pumpLesson(tester, state: state);
    await tester.tap(find.byKey(const ValueKey<String>('mdas_operation_1')));
    await tester.pumpAndSettle();
    expect(state.current.step, MdasStep.result);
    await tester.tap(find.byKey(const ValueKey<String>('mdas_answer_24')));
    await tester.pumpAndSettle();
    expect(state.current.expression, <Object>[24, '+', 6]);
    expect(find.text('24 + 6'), findsWidgets);
  });

  testWidgets('completed recap retries progress save and opens Quiz 4', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    final MdasLessonState state = MdasLessonState()..phase = 6;
    for (final MdasActivity task in state.tasks[6]) {
      task.done = true;
    }
    state.recap = true;
    final _FakeProgressRepository repository = _FakeProgressRepository();
    final Lesson linked = Lesson(
      id: lesson.id,
      title: lesson.title,
      body: lesson.body,
      sourceType: lesson.sourceType,
      gradeLevel: lesson.gradeLevel,
      linkedQuizId: 'quiz-4',
      createdAt: lesson.createdAt,
      updatedAt: lesson.updatedAt,
    );
    final Quiz quiz = Quiz(
      id: 'quiz-4',
      title: 'Quiz 4',
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
      state: state,
      target: linked,
      overrides: <Override>[
        studentSessionProvider.overrideWith(
          (Ref ref) => StudentSession(
            accessToken: 'test',
            expiresAt: DateTime(2100),
            studentId: 'student',
          ),
        ),
        lessonProgressRepositoryProvider.overrideWith((Ref ref) => repository),
        linkedQuizProvider.overrideWith((Ref ref, String id) async => quiz),
      ],
    );
    expect(repository.calls, 0);
    await tester.tap(find.text('Finish Lesson ✓'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    await tester.tap(find.text('Retry saving lesson'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('Lesson finished!'), findsOneWidget);
    await capture(tester, 'completed_recap_1024x600');
    await tester.tap(find.text('Take Quiz · Optional'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizTakingScreen), findsOneWidget);
  });
}
