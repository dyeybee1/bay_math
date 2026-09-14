import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/lesson_page.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/teacher_section.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/lessons_repository.dart';
import 'package:instructional_math_app/features/teacher/presentation/lesson_composer_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/lessons_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_shell_screen.dart';

const List<Size> _desktopSizes = <Size>[
  Size(800, 700),
  Size(1280, 800),
  Size(1920, 1080),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher lesson composer', () {
    testWidgets('adapts between stacked and two-column desktop layouts', (
      WidgetTester tester,
    ) async {
      for (final Size size in _desktopSizes) {
        final _FakeLessonsRepository repository = _FakeLessonsRepository();
        await _pumpComposer(tester, size: size, repository: repository);

        expect(find.text('Create lesson'), findsOneWidget);
        expect(find.text('Lesson content'), findsOneWidget);
        expect(find.text('Audience & status'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Composer at $size');
      }
    });

    testWidgets('previews shared blocks and saves one atomic draft payload', (
      WidgetTester tester,
    ) async {
      final _FakeLessonsRepository repository = _FakeLessonsRepository();
      await _pumpComposer(
        tester,
        size: const Size(1280, 800),
        repository: repository,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('lesson_composer_title')),
          matching: find.byType(TextField),
        ),
        'Understanding equivalent fractions',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('lesson_composer_summary')),
          matching: find.byType(TextField),
        ),
        'Learn how two fractions can name the same amount.',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Paragraph'),
        'A fraction can have an equivalent name.',
      );

      await tester.tap(find.byKey(const Key('lesson_composer_add_content')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Key idea').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Important note'),
        'Multiply the numerator and denominator by the same number.',
      );

      await tester.ensureVisible(find.byTooltip('Duplicate block').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Duplicate block').last);
      await tester.pump();
      expect(find.byTooltip('Delete block'), findsNWidgets(3));
      await tester.ensureVisible(find.byTooltip('Delete block').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete block').last);
      await tester.pump();
      expect(find.byTooltip('Delete block'), findsNWidgets(2));
      await tester.ensureVisible(find.byTooltip('Move up').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move up').last);
      await tester.pump();

      final Finder sectionCheckbox = find.byKey(
        Key('lesson_composer_section_${_section.id}'),
      );
      await tester.ensureVisible(sectionCheckbox);
      await tester.pumpAndSettle();
      await tester.tap(sectionCheckbox);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('lesson_composer_preview')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson_composer_preview')));
      await tester.pumpAndSettle();

      expect(find.text('Student preview'), findsOneWidget);
      expect(find.text('Understanding equivalent fractions'), findsOneWidget);
      expect(
        find.text('A fraction can have an equivalent name.'),
        findsOneWidget,
      );
      expect(
        find.text('Multiply the numerator and denominator by the same number.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('lesson_composer_save_draft')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson_composer_save_draft')));
      await tester.pumpAndSettle();

      expect(repository.saveCount, 1);
      expect(repository.savedStatus, LessonPublicationStatus.draft);
      expect(repository.savedSectionIds, <String>[_section.id]);
      expect(repository.savedBlocks, hasLength(2));
      expect(
        repository.savedBlocks!.map((LessonPageInput page) => page.sectionType),
        containsAll(<String>['composer_paragraph', 'composer_key_idea']),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'requires an audience to publish and loads an existing lesson',
      (WidgetTester tester) async {
        final _FakeLessonsRepository repository = _FakeLessonsRepository(
          pages: <LessonPage>[
            LessonPage(
              id: 'page-1',
              lessonId: _existingLesson.id,
              displayOrder: 1,
              sectionType: 'composer_heading',
              title: 'What is a fraction?',
              body: '',
              createdAt: _timestamp,
              updatedAt: _timestamp,
            ),
          ],
          sectionIds: <String>[_section.id],
        );
        await _pumpComposer(
          tester,
          size: const Size(1280, 800),
          repository: repository,
          lesson: _existingLesson,
        );

        expect(find.text('Edit lesson'), findsOneWidget);
        expect(find.text('Published'), findsWidgets);
        expect(find.widgetWithText(TextFormField, 'Heading'), findsOneWidget);
        expect(find.text('Grade 4 — A'), findsOneWidget);

        final Finder sectionCheckbox = find.byKey(
          Key('lesson_composer_section_${_section.id}'),
        );
        await tester.tap(sectionCheckbox);
        await tester.pump();
        await tester.tap(find.byKey(const Key('lesson_composer_publish')));
        await tester.pump();
        expect(
          find.text('Choose at least one section before publishing.'),
          findsOneWidget,
        );
        expect(repository.saveCount, 0);

        await tester.tap(sectionCheckbox);
        await tester.pump();
        await tester.tap(find.byKey(const Key('lesson_composer_publish')));
        await tester.pumpAndSettle();
        expect(repository.saveCount, 1);
        expect(repository.savedLessonId, _existingLesson.id);
        expect(repository.savedStatus, LessonPublicationStatus.published);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('lesson list distinguishes source and publication status', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sessionProvider.overrideWith(_TestSessionNotifier.new),
            lessonsProvider.overrideWith(
              (Ref ref) => <Lesson>[_builtInLesson, _draftLesson],
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const LessonsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Built-in algebra'), findsOneWidget);
      expect(find.text('My draft lesson'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      await tester.tap(find.text('My lessons'));
      await tester.pump();
      expect(find.text('Built-in algebra'), findsNothing);
      expect(find.text('My draft lesson'), findsOneWidget);
      await tester.tap(find.text('Built-in'));
      await tester.pump();
      expect(find.text('Built-in algebra'), findsOneWidget);
      expect(find.text('My draft lesson'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  required Size size,
  required _FakeLessonsRepository repository,
  Lesson? lesson,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final List<Override> overrides = <Override>[
    sessionProvider.overrideWith(_TestSessionNotifier.new),
    lessonsRepositoryProvider.overrideWithValue(repository),
    mySectionsProvider.overrideWith((Ref ref) => <MySection>[_mySection]),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: LessonComposerScreen(lesson: lesson),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestSessionNotifier extends SessionNotifier {
  @override
  Future<SessionState> build() async => SessionTeacher(_teacher);
}

class _FakeLessonsRepository implements LessonsRepository {
  _FakeLessonsRepository({
    this.pages = const <LessonPage>[],
    this.sectionIds = const <String>[],
  });

  final List<LessonPage> pages;
  final List<String> sectionIds;
  int saveCount = 0;
  String? savedLessonId;
  LessonPublicationStatus? savedStatus;
  List<String>? savedSectionIds;
  List<LessonPageInput>? savedBlocks;

  @override
  Future<List<LessonPage>> fetchPages(String lessonId) async => pages;

  @override
  Future<List<String>> fetchSectionIds(String lessonId) async => sectionIds;

  @override
  Future<String> saveComposedLesson({
    String? lessonId,
    required String title,
    required String summary,
    required LessonPublicationStatus publicationStatus,
    required List<String> sectionIds,
    required List<LessonPageInput> blocks,
  }) async {
    saveCount += 1;
    savedLessonId = lessonId;
    savedStatus = publicationStatus;
    savedSectionIds = List<String>.of(sectionIds);
    savedBlocks = List<LessonPageInput>.of(blocks);
    return lessonId ?? 'new-lesson-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final DateTime _timestamp = DateTime.utc(2026, 9, 2);

final Profile _teacher = Profile(
  id: '11111111-1111-4111-8111-111111111111',
  role: ProfileRole.teacher,
  status: ProfileStatus.approved,
  fullName: 'Teacher Ada',
  email: 'ada@example.test',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Section _section = Section(
  id: '22222222-2222-4222-8222-222222222222',
  schoolYearId: '33333333-3333-4333-8333-333333333333',
  gradeLevel: GradeLevel.grade4,
  name: 'A',
  status: SectionStatus.active,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final TeacherSection _teacherSection = TeacherSection(
  id: '44444444-4444-4444-8444-444444444444',
  teacherId: '11111111-1111-4111-8111-111111111111',
  sectionId: '22222222-2222-4222-8222-222222222222',
  isPrimary: true,
  assignedAt: _timestamp,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final MySection _mySection = MySection(_teacherSection, _section);

final Lesson _existingLesson = Lesson(
  id: '55555555-5555-4555-8555-555555555555',
  title: 'Fractions in everyday life',
  body: 'Recognize fractions in familiar objects.',
  sourceType: ContentSourceType.teacher,
  createdBy: '11111111-1111-4111-8111-111111111111',
  publicationStatus: LessonPublicationStatus.published,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Lesson _builtInLesson = Lesson(
  id: '66666666-6666-4666-8666-666666666666',
  title: 'Built-in algebra',
  body: 'An existing BayMath lesson.',
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade4,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Lesson _draftLesson = Lesson(
  id: '77777777-7777-4777-8777-777777777777',
  title: 'My draft lesson',
  body: 'Still being prepared.',
  sourceType: ContentSourceType.teacher,
  createdBy: _teacher.id,
  publicationStatus: LessonPublicationStatus.draft,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
