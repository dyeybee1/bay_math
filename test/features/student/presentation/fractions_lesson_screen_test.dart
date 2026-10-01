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
import 'package:instructional_math_app/features/student/presentation/fractions_lesson_screen.dart';
import 'package:instructional_math_app/features/student/presentation/fractions_lesson_state.dart';
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
  const Key captureKey = Key('fractions_capture');
  bool fontLoaded = false;
  final Lesson lesson = Lesson(
    id: 'fractions',
    title: 'Types of Fractions',
    body: '',
    sourceType: ContentSourceType.builtIn,
    gradeLevel: GradeLevel.grade4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpLesson(
    WidgetTester tester, {
    FractionsLessonState? state,
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
              body: FractionsLessonScreen(
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
        tester.element(find.byType(FractionsLessonScreen)),
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
      final Directory directory = Directory('artifacts/fractions_lesson');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'all six phases fit the tablet sizes and rotation retains state',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final FractionsLessonState state = FractionsLessonState();
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
        await capture(
          tester,
          'parts_${size.width.toInt()}x${size.height.toInt()}',
        );
      }
      tester.view.physicalSize = const Size(1024, 600);
      for (int phase = 1; phase < 6; phase++) {
        state.phase = phase;
        await pumpLesson(tester, state: state);
        expect(tester.takeException(), isNull, reason: 'phase $phase');
        await capture(tester, 'phase_${phase + 1}_1024x600');
      }
      state.phase = 2;
      state.indices[2] = 2;
      await pumpLesson(tester, state: state);
      await capture(tester, 'improper_6_6_1024x600');
      state.phase = 3;
      state.indices[3] = 2;
      await pumpLesson(tester, state: state);
      await capture(tester, 'build_3_2_5_1024x600');
      state.phase = 0;
      state.chooseNumber(3);
      await pumpLesson(tester, state: state);
      tester.view.physicalSize = const Size(600, 1024);
      await tester.pumpAndSettle();
      expect(find.text('Turn your tablet sideways'), findsOneWidget);
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      expect(state.current.numeratorFound, isTrue);
      expect(find.text('Tap the denominator.'), findsOneWidget);
    },
  );

  testWidgets(
    'builder keeps source and destination visible and supports drag, tap, keyboard',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final FractionsLessonState state = FractionsLessonState()..phase = 3;
      final Finder whole = find.byKey(
        const ValueKey<String>('fraction_source_whole_0'),
      );
      final Finder wholeTarget = find.byKey(
        const ValueKey<String>('fraction_destination_whole_0'),
      );
      final Finder piece = find.byKey(
        const ValueKey<String>('fraction_source_piece_0'),
      );
      final Finder pieceTarget = find.byKey(
        const ValueKey<String>('fraction_destination_piece_0'),
      );
      for (final Size size in <Size>[
        const Size(1024, 600),
        const Size(1024, 768),
        const Size(1280, 800),
      ]) {
        tester.view.physicalSize = size;
        await pumpLesson(tester, state: state);
        expect(tester.takeException(), isNull, reason: '$size');
        final Rect sourceRect = tester.getRect(whole);
        final Rect destinationRect = tester.getRect(wholeTarget);
        expect(sourceRect.height, greaterThanOrEqualTo(52));
        expect(destinationRect.height, greaterThanOrEqualTo(52));
        expect(sourceRect.bottom, lessThanOrEqualTo(size.height - 66));
        expect(destinationRect.bottom, lessThanOrEqualTo(size.height - 66));
        await capture(
          tester,
          'build_1_3_4_${size.width.toInt()}x${size.height.toInt()}',
        );
      }
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      await tester.drag(whole, const Offset(-380, -170));
      await tester.pumpAndSettle();
      expect(state.current.wholesPlaced, 0);
      await tester.drag(
        whole,
        tester.getCenter(wholeTarget) - tester.getCenter(whole),
      );
      await tester.pumpAndSettle();
      expect(state.current.wholesPlaced, 1);
      await tester.tap(piece);
      await tester.tap(pieceTarget);
      await tester.pumpAndSettle();
      expect(state.current.piecesPlaced, 1);
      final Finder secondPiece = find.byKey(
        const ValueKey<String>('fraction_source_piece_1'),
      );
      Focus.of(
        tester.element(
          find
              .descendant(of: secondPiece, matching: find.byType(Container))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      Focus.of(
        tester.element(
          find
              .descendant(of: pieceTarget, matching: find.byType(Container))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.current.piecesPlaced, 2);
    await tester.tap(
      find.byKey(const ValueKey<String>('fraction_source_piece_2')),
    );
    await tester.tap(pieceTarget);
    await tester.pumpAndSettle();
    expect(state.current.modelBuilt, isTrue);
    expect(find.text('Which part is the whole number?'), findsOneWidget);
    await capture(tester, 'built_1_3_4_1024x600');
    await tester.tap(find.text('Fraction part'));
    await tester.pumpAndSettle();
    expect(state.current.done, isFalse);
    await tester.tap(find.text('Whole-number part'));
    await tester.pumpAndSettle();
    expect(state.current.done, isTrue);
    },
  );

  testWidgets(
    'single tap classification, Show model, and mixed identification',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      final FractionsLessonState state = FractionsLessonState()..phase = 5;
      state.indices[5] = 2;
      await pumpLesson(tester, state: state);
      expect(find.text('Show model'), findsOneWidget);
      await tester.tap(find.text('Proper fraction'));
      await tester.pumpAndSettle();
      expect(state.current.done, isFalse);
      await tester.tap(find.text('Show model'));
      await tester.pumpAndSettle();
      expect(state.current.modelVisible, isTrue);
      await tester.tap(find.text('Improper fraction'));
      await tester.pumpAndSettle();
      expect(state.current.done, isTrue);
      await capture(tester, 'practice_5_5_1024x600');
      state.indices[5] = 3;
      await pumpLesson(tester, state: state);
      await tester.tap(find.text('Mixed number'));
      await tester.pumpAndSettle();
      expect(state.current.done, isTrue);
    },
  );

  testWidgets('recap retries completion save and opens linked Quiz 5', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    final FractionsLessonState state = FractionsLessonState()..phase = 5;
    for (final FractionActivity task in state.tasks[5]) {
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
      linkedQuizId: 'quiz-5',
      createdAt: lesson.createdAt,
      updatedAt: lesson.updatedAt,
    );
    final Quiz quiz = Quiz(
      id: 'quiz-5',
      title: 'Quiz 5',
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
    await tester.tap(find.text('Take Quiz 5 · Optional'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizTakingScreen), findsOneWidget);
  });
}
