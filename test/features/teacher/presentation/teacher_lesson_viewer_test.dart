import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/lesson_page.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/features/teacher/data/teacher_lessons_providers.dart';
import 'package:instructional_math_app/features/teacher/presentation/lessons_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_lesson_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher lesson viewing', () {
    testWidgets('built-in and owned cards open the read-only viewer', (
      WidgetTester tester,
    ) async {
      await _setDesktopSize(tester);
      await tester.pumpWidget(_lessonListApp());
      await tester.pumpAndSettle();

      final Finder builtInCard = find.byKey(
        const Key('teacher_lesson_card_builtin-lesson'),
      );
      final Finder ownedCard = find.byKey(
        const Key('teacher_lesson_card_owned-lesson'),
      );
      expect(builtInCard, findsOneWidget);
      expect(ownedCard, findsOneWidget);

      expect(
        find.descendant(of: builtInCard, matching: find.text('Edit')),
        findsNothing,
      );
      expect(
        find.descendant(of: builtInCard, matching: find.text('Delete')),
        findsNothing,
      );
      expect(
        find.descendant(of: ownedCard, matching: find.text('Edit')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: ownedCard, matching: find.text('Delete')),
        findsOneWidget,
      );

      await tester.tap(builtInCard);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacher_lesson_viewer')), findsOneWidget);
      expect(find.text('Built-in lesson'), findsOneWidget);
      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('Read only'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);

      await tester.tap(find.byKey(const Key('teacher_lesson_back')));
      await tester.pumpAndSettle();
      expect(find.byType(LessonsScreen), findsOneWidget);

      await tester.tap(ownedCard);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacher_lesson_viewer')), findsOneWidget);
      expect(find.text('My lesson'), findsOneWidget);
      expect(find.text('My Content'), findsOneWidget);
      expect(find.text('Read only'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders ordered pages and navigates without progress writes', (
      WidgetTester tester,
    ) async {
      await _setDesktopSize(tester);
      await tester.pumpWidget(
        _viewerApp(
          lesson: _ownedLesson,
          pages: <LessonPage>[_firstPage, _secondPage],
          extraOverrides: <Override>[
            lessonProgressRepositoryProvider.overrideWith((Ref ref) {
              throw StateError(
                'Teacher preview must not read Student progress services.',
              );
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First content block'), findsOneWidget);
      expect(find.text('Second content block'), findsNothing);
      expect(find.text('Page 1 of 2'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('First content block'), findsNothing);
      expect(find.text('Second content block'), findsOneWidget);
      expect(find.text('Page 2 of 2'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('First content block'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles an inaccessible direct lesson id safely', (
      WidgetTester tester,
    ) async {
      await _setDesktopSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            teacherVisibleLessonProvider.overrideWith(
              (Ref ref, String lessonId) async => null,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TeacherLessonViewerScreen(
              lessonId: 'grade-5-inaccessible',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lesson unavailable'), findsOneWidget);
      expect(
        find.textContaining('not available to your account'),
        findsOneWidget,
      );
      expect(find.text('grade-5-inaccessible'), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('single-page lessons avoid disabled navigation controls', (
      WidgetTester tester,
    ) async {
      await _setDesktopSize(tester);
      await tester.pumpWidget(
        _viewerApp(lesson: _builtInLesson, pages: <LessonPage>[_firstPage]),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 page'), findsOneWidget);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _setDesktopSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(tester.view.reset);
}

Widget _lessonListApp() {
  return ProviderScope(
    overrides: <Override>[
      lessonsProvider.overrideWith(
        (Ref ref) => <Lesson>[_builtInLesson, _ownedLesson],
      ),
      teacherLessonPagesProvider.overrideWith(
        (Ref ref, String lessonId) async => <LessonPage>[
          lessonId == _builtInLesson.id ? _firstPage : _secondPage,
        ],
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LessonsScreen(),
    ),
  );
}

Widget _viewerApp({
  required Lesson lesson,
  required List<LessonPage> pages,
  List<Override> extraOverrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      teacherLessonPagesProvider.overrideWith(
        (Ref ref, String lessonId) async => pages,
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: TeacherLessonViewerScreen(
        lessonId: lesson.id,
        initialLesson: lesson,
      ),
    ),
  );
}

final DateTime _timestamp = DateTime.utc(2026, 9, 16);

final Lesson _builtInLesson = Lesson(
  id: 'builtin-lesson',
  title: 'Built-in lesson',
  body: 'Grade-scoped built-in content.',
  sourceType: ContentSourceType.builtIn,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Lesson _ownedLesson = Lesson(
  id: 'owned-lesson',
  title: 'My lesson',
  body: 'Teacher-created content.',
  sourceType: ContentSourceType.teacher,
  createdBy: 'teacher-1',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final LessonPage _firstPage = LessonPage(
  id: 'page-1',
  lessonId: 'lesson',
  displayOrder: 1,
  sectionType: 'composer_paragraph',
  title: 'First content block',
  body: 'The first page remains first.',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final LessonPage _secondPage = LessonPage(
  id: 'page-2',
  lessonId: 'lesson',
  displayOrder: 2,
  sectionType: 'composer_key_idea',
  title: 'Second content block',
  body: 'The second page remains second.',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
