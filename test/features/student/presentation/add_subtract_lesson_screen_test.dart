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
import 'package:instructional_math_app/features/student/presentation/add_subtract_lesson_math.dart';
import 'package:instructional_math_app/features/student/presentation/add_subtract_lesson_screen.dart';
import 'package:instructional_math_app/features/student/presentation/add_subtract_lesson_state.dart';
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
      throw StateError('temporary save failure');
    }
  }
}

AddSubtractLessonState _completedPractice() {
  final AddSubtractLessonState state = AddSubtractLessonState()..navigate(4);
  for (int i = 0; i < 4; i++) {
    final ArithmeticWork work = state.currentWork!;
    while (!work.done) {
      switch (work.mode) {
        case ArithmeticMode.carry:
          work.placeCarry(work.column - 1);
        case ArithmeticMode.exchange:
          work.exchange(work.donorColumn!, work.donorColumn! + 1);
        case ArithmeticMode.answer:
          work.placeDigit(work.expectedDigit, work.column);
        case ArithmeticMode.checked:
          work.continueColumn();
        case ArithmeticMode.done:
          break;
      }
    }
    if (i < 3) state.nextExercise();
  }
  state.navigate(5);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const Key captureKey = Key('add_subtract_capture');
  final Lesson lesson = Lesson(
    id: 'add-subtract',
    title: 'Addition and Subtraction of Numbers up to 1,000,000',
    body: '',
    sourceType: ContentSourceType.builtIn,
    gradeLevel: GradeLevel.grade4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpLesson(
    WidgetTester tester, {
    AddSubtractLessonState? state,
    Lesson? target,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: AppColors.scheme),
          home: RepaintBoundary(
            key: captureKey,
            child: Scaffold(
              body: AddSubtractLessonScreen(
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
        tester.element(find.byType(AddSubtractLessonScreen)),
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
      final Directory directory = Directory('artifacts/add_subtract_lesson');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  ValueKey<String> tileKey(LessonTile tile) =>
      ValueKey<String>('tile_${tile.identity}');
  ValueKey<String> zoneKey(LessonZone zone) =>
      ValueKey<String>('drop_${zone.kind}_${zone.row}_${zone.column}');

  testWidgets('landscape phases fit target sizes and rotation retains state', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('CAPTURE_LESSON_SCREENSHOTS') &&
        Platform.isWindows) {
      await tester.runAsync(() async {
        await (FontLoader('Roboto')..addFont(
          File('C:/Windows/Fonts/segoeui.ttf').readAsBytes().then(
            (List<int> b) => ByteData.sublistView(Uint8List.fromList(b)),
          ),
        )).load();
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
      expect(find.text('More books for the library'), findsOneWidget);
      expect(find.text('← Previous part'), findsOneWidget);
      expect(find.text('Next part →'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(tileKey(const LessonTile.operation('+'))))
            .height,
        greaterThanOrEqualTo(52),
      );
      expect(
        tester.getSize(find.byKey(zoneKey(const LessonZone.operation()))).width,
        greaterThanOrEqualTo(52),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      await capture(
        tester,
        'start_${size.width.toInt()}x${size.height.toInt()}',
      );
    }
    tester.view.physicalSize = const Size(1024, 600);
    await tester.pumpAndSettle();
    for (final (String, String) phase in <(String, String)>[
      ('Place value', 'place_value'),
      ('Addition', 'addition'),
      ('Subtraction', 'subtraction'),
      ('Practice', 'practice'),
      ('Recap', 'recap'),
    ]) {
      await tester.tap(find.text(phase.$1).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: phase.$1);
      await capture(tester, '${phase.$2}_1024x600');
    }
    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(tileKey(const LessonTile.operation('+'))));
    await tester.tap(find.byKey(zoneKey(const LessonZone.operation())));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(600, 1024);
    await tester.pumpAndSettle();
    expect(find.text('Turn your tablet sideways'), findsOneWidget);
    tester.view.physicalSize = const Size(1024, 600);
    await tester.pumpAndSettle();
    expect(find.textContaining('Add to find the total.'), findsWidgets);
  });

  testWidgets(
    'drag, outside cancellation, tap and keyboard use one validation path',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      await pumpLesson(tester);
      final Finder plus = find.byKey(tileKey(const LessonTile.operation('+')));
      final Finder minus = find.byKey(tileKey(const LessonTile.operation('−')));
      final Finder target = find.byKey(zoneKey(const LessonZone.operation()));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(plus),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.text('Add to find the total.'), findsNothing);
      await tester.dragFrom(tester.getCenter(plus), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(find.text('Add to find the total.'), findsNothing);
      await tester.dragFrom(
        tester.getCenter(minus),
        tester.getCenter(target) - tester.getCenter(minus),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Think about what changes.'), findsOneWidget);
      final BuildContext sourceContext = tester.element(plus);
      Focus.of(sourceContext).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.textContaining('Tile selected.'), findsOneWidget);
      Focus.of(tester.element(target)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.textContaining('Add to find the total.'), findsWidgets);
    },
  );

  testWidgets('carry and zero-chain regrouping remain readable at 1024×600', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);

    final AddSubtractLessonState carryState =
        AddSubtractLessonState()
          ..navigate(2)
          ..additionIndex = 1;
    final ArithmeticWork carryWork = carryState.currentWork!;
    carryWork.placeDigit(0, 6);
    carryWork.continueColumn();
    await pumpLesson(tester, state: carryState);
    expect(find.textContaining('Exchange 10 tens.'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(zoneKey(const LessonZone.carry(4)))).height,
      greaterThanOrEqualTo(52),
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'carry_1024x600');

    final AddSubtractLessonState regroupState =
        AddSubtractLessonState()
          ..navigate(3)
          ..subtractionIndex = 1;
    final ArithmeticWork regroupWork = regroupState.currentWork!;
    for (int donor = 1; donor < 6; donor++) {
      regroupState.place(
        LessonTile.exchange(donor),
        LessonZone.exchange(donor + 1),
      );
    }
    expect(regroupWork.top, <int>[0, 6, 9, 9, 9, 9, 10]);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpLesson(tester, state: regroupState);
    expect(find.textContaining('10'), findsWidgets);
    expect(tester.takeException(), isNull);
    await capture(tester, 'regrouped_1024x600');
  });

  testWidgets(
    'completion retries once and optional quiz opens existing route',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
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
        title: 'Addition quiz',
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
        state: _completedPractice(),
        target: linked,
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
          linkedQuizProvider.overrideWith((Ref ref, String id) async => quiz),
        ],
      );
      expect(find.text('Finish lesson ✓'), findsOneWidget);
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
    },
  );
}
