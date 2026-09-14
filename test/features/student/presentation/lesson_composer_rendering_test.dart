import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/lesson_page.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/widgets/lesson/lesson_content_block_view.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/lesson_composer_screen.dart';

const List<Size> _supportedLandscapeSizes = <Size>[
  Size(1024, 600),
  Size(1280, 720),
  Size(1280, 800),
  Size(1920, 1200),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Composed lesson rendering', () {
    testWidgets('actual Student viewer fits every block at supported sizes', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          LessonViewerScreen(lesson: _lesson),
          overrides: <Override>[
            lessonProgressRepositoryProvider.overrideWith((Ref ref) => null),
            lessonPagesProvider.overrideWith(
              (Ref ref, String lessonId) async => _viewerPages,
            ),
          ],
        );

        for (int page = 0; page < _viewerPages.length; page++) {
          final LessonContentBlockView block = tester.widget(
            find.byType(LessonContentBlockView),
          );
          expect(block.page.id, _viewerPages[page].id);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Student composer page ${page + 1} at $size',
          );
          if (page != _viewerPages.length - 1) {
            await tester.tap(find.text('Next'));
            await tester.pumpAndSettle();
          }
        }
      }
    });

    testWidgets('Preview uses shared renderer and contains wide content', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          LessonComposerPreviewScreen(
            title: _lesson.title,
            summary: _lesson.body,
            pages: _previewPages,
            imageBytesByPageId: <String, Uint8List>{
              'image-page': _transparentPng,
            },
          ),
        );

        expect(find.text(_lesson.title), findsOneWidget);
        expect(find.byType(LessonContentBlockView), findsNWidgets(6));
        expect(
          tester
              .widgetList<LessonContentBlockView>(
                find.byType(LessonContentBlockView),
              )
              .map((LessonContentBlockView block) => block.page.id),
          contains('paragraph-page'),
        );
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Preview at $size');
      }
    });

    testWidgets('image failures produce an in-layout educational error state', (
      WidgetTester tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(1024, 600),
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 720,
              child: LessonContentBlockView(page: _brokenImagePage),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This lesson image could not be loaded.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink());
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
  await tester.pumpAndSettle();
}

final DateTime _timestamp = DateTime.utc(2026, 9, 2);

final Lesson _lesson = Lesson(
  id: 'lesson-composer',
  title: 'Equivalent Fractions in Everyday Life',
  body: 'Learn why different fractions can represent the same amount.',
  sourceType: ContentSourceType.teacher,
  createdBy: 'teacher-1',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

LessonPage _page({
  required String id,
  required int order,
  required String type,
  required String title,
  required String body,
}) => LessonPage(
  id: id,
  lessonId: _lesson.id,
  displayOrder: order,
  sectionType: type,
  title: title,
  body: body,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final List<LessonPage> _viewerPages = <LessonPage>[
  _page(
    id: 'heading-page',
    order: 1,
    type: 'composer_heading',
    title: 'What is an equivalent fraction?',
    body: '',
  ),
  _page(
    id: 'paragraph-page',
    order: 2,
    type: 'composer_paragraph',
    title: '',
    body: List<String>.filled(
      7,
      'A fraction represents part of a whole, and equivalent fractions name the same amount using different equal parts.',
    ).join(' '),
  ),
  _page(
    id: 'key-page',
    order: 3,
    type: 'composer_key_idea',
    title: 'Keep the value equal',
    body: 'Multiply the numerator and denominator by the same number.',
  ),
  _page(
    id: 'example-page',
    order: 4,
    type: 'composer_worked_example',
    title: 'Example: 1/2 = 2/4',
    body: List<String>.filled(
      5,
      'Multiply both 1 and 2 by 2. The numerator becomes 2 and the denominator becomes 4.',
    ).join(' '),
  ),
  _page(
    id: 'link-page',
    order: 5,
    type: 'composer_link',
    title: 'Explore a fraction model',
    body: 'https://example.com/fractions',
  ),
];

final List<LessonPage> _previewPages = <LessonPage>[
  ..._viewerPages,
  _page(
    id: 'image-page',
    order: 6,
    type: 'composer_image',
    title: 'A rectangle divided into four equal parts',
    body: '',
  ),
];

final LessonPage _brokenImagePage = _page(
  id: 'broken-image-page',
  order: 1,
  type: 'composer_image',
  title: 'A missing diagram',
  body: 'not-a-valid-network-url',
);

final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
