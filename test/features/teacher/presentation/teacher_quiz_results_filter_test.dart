import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/teacher_section.dart';
import 'package:instructional_math_app/features/teacher/data/teacher_quiz_results_providers.dart';
import 'package:instructional_math_app/features/teacher/presentation/quiz_results_table.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_shell_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stages section and assessment filters until one atomic apply', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(QuizResultsTable)),
    );
    int appliedChanges = 0;
    final ProviderSubscription<TeacherQuizResultsSelection> subscription =
        container.listen<TeacherQuizResultsSelection>(
          teacherQuizResultsSelectionProvider,
          (_, _) => appliedChanges += 1,
        );
    addTearDown(subscription.close);

    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    expect(find.text('Filters'), findsOneWidget);

    // Section-only change: selecting a dropdown remains draft state.
    await _openFilters(tester);
    await _selectSection(tester, 'Grade 4 — B');
    expect(
      find.byKey(const Key('teacher_quiz_results_filter_popover')),
      findsOneWidget,
    );
    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    expect(appliedChanges, 0);

    await _applyFilters(tester);
    _expectApplied(
      container,
      sectionId: 'section-b',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    expect(appliedChanges, 1);
    expect(find.text('Filters · 1'), findsOneWidget);

    // Reset also remains draft until Apply, then restores both defaults.
    await _openFilters(tester);
    await tester.tap(
      find.byKey(const Key('teacher_quiz_results_filter_reset')),
    );
    await tester.pumpAndSettle();
    _expectApplied(
      container,
      sectionId: 'section-b',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    expect(find.text('Grade 4 — A'), findsOneWidget);
    expect(find.text('Regular Quiz'), findsOneWidget);

    await _applyFilters(tester);
    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    expect(appliedChanges, 2);
    expect(find.text('Filters'), findsOneWidget);

    // Assessment-only change.
    await _openFilters(tester);
    await _selectAssessment(tester, 'Post-Test');
    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    await _applyFilters(tester);
    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.postTest,
    );
    expect(appliedChanges, 3);
    expect(find.text('Filters · 1'), findsOneWidget);

    // Dismissing a both-filter draft preserves the currently applied pair.
    await _openFilters(tester);
    await _selectSection(tester, 'Grade 4 — B');
    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.postTest,
    );
    await tester.tapAt(const Offset(20, 690));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacher_quiz_results_filter_popover')),
      findsNothing,
    );
    expect(appliedChanges, 3);

    // Reopening reflects applied values, not the dismissed draft.
    await _openFilters(tester);
    expect(find.text('Grade 4 — A'), findsOneWidget);
    expect(find.text('Post-Test'), findsOneWidget);
    await _selectSection(tester, 'Grade 4 — B');
    await _applyFilters(tester);
    _expectApplied(
      container,
      sectionId: 'section-b',
      assessmentType: QuizResultsAssessmentFilter.postTest,
    );
    expect(appliedChanges, 4);
    expect(find.text('Filters · 2'), findsOneWidget);

    // Resetting a previously applied pair remains staged, then commits once.
    await _openFilters(tester);
    await tester.tap(
      find.byKey(const Key('teacher_quiz_results_filter_reset')),
    );
    await tester.pumpAndSettle();
    _expectApplied(
      container,
      sectionId: 'section-b',
      assessmentType: QuizResultsAssessmentFilter.postTest,
    );
    expect(appliedChanges, 4);
    await _applyFilters(tester);
    _expectApplied(
      container,
      sectionId: 'section-a',
      assessmentType: QuizResultsAssessmentFilter.regular,
    );
    expect(appliedChanges, 5);
    expect(find.text('Filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('teacher_quiz_results_filters_button')),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('teacher_quiz_results_filter_popover')),
    findsOneWidget,
  );
}

Future<void> _selectSection(WidgetTester tester, String label) async {
  await tester.tap(
    find.byKey(const Key('teacher_quiz_results_section_filter')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectAssessment(WidgetTester tester, String label) async {
  await tester.tap(
    find.byKey(const Key('teacher_quiz_results_assessment_filter')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _applyFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('teacher_quiz_results_filter_apply')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('teacher_quiz_results_filter_popover')),
    findsNothing,
  );
}

void _expectApplied(
  ProviderContainer container, {
  required String sectionId,
  required QuizResultsAssessmentFilter assessmentType,
}) {
  final TeacherQuizResultsSelection selection = container.read(
    teacherQuizResultsSelectionProvider,
  );
  expect(selection.sectionId, sectionId);
  expect(selection.assessmentType, assessmentType);
}

Widget _testApp() {
  return ProviderScope(
    overrides: <Override>[
      mySectionsProvider.overrideWith((Ref ref) => _sections),
      teacherQuizResultsSelectionProvider.overrideWith(
        (Ref ref) => const TeacherQuizResultsSelection(
          sectionId: 'section-a',
          assessmentType: QuizResultsAssessmentFilter.regular,
        ),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: QuizResultsTable(
              matrix: QuizResultsMatrix(
                students: <Never>[],
                quizzes: <Never>[],
                cellsByStudentThenQuiz: <Never, Never>{},
                totalQuestionsByQuizId: <Never, Never>{},
              ),
              subtitle: 'Grade 4 · A · Regular Quiz',
            ),
          ),
        ),
      ),
    ),
  );
}

final DateTime _timestamp = DateTime.utc(2026, 9, 2);

final List<MySection> _sections = <MySection>[
  MySection(
    TeacherSection(
      id: 'assignment-a',
      teacherId: 'teacher-1',
      sectionId: 'section-a',
      isPrimary: true,
      assignedAt: _timestamp,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    ),
    Section(
      id: 'section-a',
      schoolYearId: 'school-year-1',
      gradeLevel: GradeLevel.grade4,
      name: 'A',
      status: SectionStatus.active,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    ),
  ),
  MySection(
    TeacherSection(
      id: 'assignment-b',
      teacherId: 'teacher-1',
      sectionId: 'section-b',
      isPrimary: false,
      assignedAt: _timestamp,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    ),
    Section(
      id: 'section-b',
      schoolYearId: 'school-year-1',
      gradeLevel: GradeLevel.grade4,
      name: 'B',
      status: SectionStatus.active,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    ),
  ),
];
