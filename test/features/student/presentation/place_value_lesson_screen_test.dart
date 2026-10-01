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
import 'package:instructional_math_app/features/student/presentation/place_value_lesson_screen.dart';
import 'package:instructional_math_app/features/student/presentation/place_value_lesson_state.dart';
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
  const Key captureKey = Key('place_value_capture');
  bool fontLoaded = false;
  final Lesson lesson = Lesson(
    id: 'place-value',
    title: 'Place Value of Whole Numbers',
    body: '',
    sourceType: ContentSourceType.builtIn,
    gradeLevel: GradeLevel.grade4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpLesson(
    WidgetTester tester, {
    PlaceValueLessonState? state,
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
              body: PlaceValueLessonScreen(
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
        tester.element(find.byType(PlaceValueLessonScreen)),
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
      final Directory directory = Directory('artifacts/place_value_lesson');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  ValueKey<String> cardKey(PlaceCard card) =>
      ValueKey<String>('place_card_${card.identity}');
  ValueKey<String> targetKey(PlaceTarget target) =>
      ValueKey<String>('place_target_${target.identity}');

  testWidgets(
    'all landscape sizes and phases render without overflow; rotation retains state',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final PlaceValueLessonState state = PlaceValueLessonState();
      for (final Size size in <Size>[
        const Size(1024, 600),
        const Size(1024, 768),
        const Size(1280, 800),
      ]) {
        tester.view.physicalSize = size;
        await pumpLesson(tester, state: state);
        expect(tester.takeException(), isNull, reason: '$size');
        expect(find.text('← Previous part'), findsOneWidget);
        expect(find.text('Next part →'), findsOneWidget);
        expect(
          tester
              .getSize(
                find.byKey(cardKey(const PlaceCard(PlaceCardKind.explore, 5))),
              )
              .height,
          greaterThanOrEqualTo(52),
        );
        expect(
          tester
              .getSize(
                find.byKey(
                  targetKey(
                    const PlaceTarget(PlaceTargetKind.explore, column: 4),
                  ),
                ),
              )
              .height,
          greaterThanOrEqualTo(52),
        );
        await capture(
          tester,
          'explore_${size.width.toInt()}x${size.height.toInt()}',
        );
      }
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      for (final (String, String) phase in <(String, String)>[
        ('Place & value', 'place_value'),
        ('Standard form', 'standard'),
        ('Expanded form', 'expanded'),
        ('Same digits', 'same_digits'),
        ('Practice', 'practice'),
      ]) {
        await tester.tap(find.text(phase.$1).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: phase.$1);
        await capture(tester, '${phase.$2}_1024x600');
      }
      await tester.tap(find.text('Explore').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(cardKey(const PlaceCard(PlaceCardKind.explore, 5))),
      );
      await tester.tap(
        find.byKey(
          targetKey(const PlaceTarget(PlaceTargetKind.explore, column: 4)),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(600, 1024);
      await tester.pumpAndSettle();
      expect(find.text('Turn your tablet sideways'), findsOneWidget);
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      expect(find.text('5 × 100 = 500'), findsOneWidget);
    },
  );

  testWidgets(
    'drag, wrong drop, tap, keyboard, and outside cancellation use one state',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      final PlaceValueLessonState state = PlaceValueLessonState()..navigate(1);
      await pumpLesson(tester, state: state);
      const PlaceCard first = PlaceCard(PlaceCardKind.alignment, 5, id: 0);
      await tester.drag(find.byKey(cardKey(first)), const Offset(-450, -150));
      await tester.pumpAndSettle();
      expect(state.current!.usedCards, isEmpty);
      await tester.tap(find.byKey(cardKey(first)));
      await tester.tap(
        find.byKey(
          targetKey(const PlaceTarget(PlaceTargetKind.digit, column: 2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.current!.usedCards, isEmpty);
      expect(state.current!.feedback?.correct, isFalse);
      expect(find.textContaining('Try again.'), findsOneWidget);
      await tester.tap(find.byKey(cardKey(first)));
      await tester.tap(
        find.byKey(
          targetKey(const PlaceTarget(PlaceTargetKind.digit, column: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.current!.usedCards, <int>{0});
      const PlaceCard second = PlaceCard(PlaceCardKind.alignment, 2, id: 1);
      Focus.of(tester.element(find.byKey(cardKey(second)))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(state.selected?.identity, second.identity);
      Focus.of(
        tester.element(
          find.byKey(
            targetKey(const PlaceTarget(PlaceTargetKind.digit, column: 2)),
          ),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.current!.usedCards, <int>{0, 1});
    },
  );

  testWidgets('completed recap retries progress save and opens linked quiz', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    final PlaceValueLessonState state = PlaceValueLessonState()..navigate(5);
    for (final PlaceActivity task in state.tasks[5]) {
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
      linkedQuizId: 'quiz-id',
      createdAt: lesson.createdAt,
      updatedAt: lesson.updatedAt,
    );
    final Quiz quiz = Quiz(
      id: 'quiz-id',
      title: 'Place value quiz',
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
    await tester.tap(find.text('Finish lesson ✓'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(find.text('Retry saving lesson'), findsOneWidget);
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
