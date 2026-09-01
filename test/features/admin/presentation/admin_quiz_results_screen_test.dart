import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/admin_quiz_result_row.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/repositories/admin_quiz_results_repository.dart';
import 'package:instructional_math_app/core/widgets/buttons/app_button.dart';
import 'package:instructional_math_app/features/admin/data/admin_quiz_results_providers.dart';
import 'package:instructional_math_app/features/admin/presentation/quiz_results_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Administrator Quiz Results presentation', () {
    testWidgets('fits representative laptop and desktop content widths', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final Size size in <Size>[
        const Size(760, 700),
        const Size(1024, 700),
        const Size(1280, 720),
        const Size(1440, 900),
        const Size(1920, 1080),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(_testApp());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('quiz_results_page_title')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quiz_results_overview')), findsNothing);
        expect(
          find.byKey(const Key('quiz_results_filter_toolbar')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quiz_results_directory')), findsOneWidget);
        expect(
          find.byKey(const Key('quiz_results_table_header')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('quiz_results_table_scroll')),
          findsOneWidget,
        );
        expect(find.text(_longAssessmentName), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('preserves result values, statuses, and export enablement', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('4 results'), findsWidgets);
      expect(find.text('Ada Student'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('2026-08-31'), findsOneWidget);
      expect(find.text('Passed'), findsWidgets);
      expect(find.text('Needs Improvement'), findsWidgets);
      expect(find.text('—'), findsWidgets);
      for (final String column in <String>[
        'Student Name',
        'Assessment Name',
        'Score',
        'Percentage',
        'Date Taken',
        'Status',
      ]) {
        expect(find.text(column), findsOneWidget);
      }

      final AppButton exportButton = tester.widget<AppButton>(
        find.byKey(const Key('quiz_results_export_button')),
      );
      expect(exportButton.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates the existing grade filter and clears it safely', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final Finder gradeField = find.descendant(
        of: find.byKey(const Key('quiz_results_grade_filter')),
        matching: find.byType(TextField),
      );
      await tester.tap(gradeField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grade 4').last);
      await tester.pumpAndSettle();

      expect(find.text('1 result'), findsWidgets);
      expect(find.text('Dana Student'), findsOneWidget);
      expect(find.text('Ada Student'), findsNothing);

      await tester.tap(find.byKey(const Key('quiz_results_clear_filters')));
      await tester.pumpAndSettle();

      expect(find.text('4 results'), findsWidgets);
      expect(find.text('Ada Student'), findsOneWidget);
      expect(find.text('Filter assessment results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('distinguishes base empty and filtered empty states', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('base-empty'),
          resultsOverride: (Ref ref) => const <AdminQuizResultRow>[],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No quiz results yet'), findsOneWidget);

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('filtered-empty'),
          resultsOverride: (Ref ref) {
            ref.watch(adminQuizResultsFilterSelectionProvider);
            return const <AdminQuizResultRow>[];
          },
        ),
      );
      await tester.pumpAndSettle();
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(AdminQuizResultsScreen)),
      );
      container
          .read(adminQuizResultsFilterSelectionProvider.notifier)
          .update(
            (AdminQuizResultsFilterSelection selection) =>
                selection.withGradeLevel(GradeLevel.grade5),
          );
      await tester.pumpAndSettle();

      expect(
        find.text('No results match your current filters'),
        findsOneWidget,
      );
      expect(find.text('Clear filters'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('presents stable loading and error states', (
      WidgetTester tester,
    ) async {
      final Completer<List<AdminQuizResultRow>> pending =
          Completer<List<AdminQuizResultRow>>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(_rows);
      });

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('loading'),
          resultsOverride: (Ref ref) => pending.future,
        ),
      );
      await tester.pump();
      expect(find.text('Loading assessment results'), findsOneWidget);
      final AppButton loadingExport = tester.widget<AppButton>(
        find.byKey(const Key('quiz_results_export_button')),
      );
      expect(loadingExport.onPressed, isNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('error'),
          resultsOverride:
              (Ref ref) =>
                  throw const NetworkFailure('Results are unavailable.'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Results are unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testApp({
  Key? scopeKey,
  FutureOr<List<AdminQuizResultRow>> Function(Ref ref)? resultsOverride,
}) {
  return ProviderScope(
    key: scopeKey,
    retry: (int retryCount, Object error) => null,
    overrides: [
      adminQuizResultsProvider.overrideWith(
        resultsOverride ??
            (Ref ref) {
              final AdminQuizResultsFilterSelection selection = ref.watch(
                adminQuizResultsFilterSelectionProvider,
              );
              return _rows
                  .where(
                    (AdminQuizResultRow row) =>
                        selection.gradeLevel == null ||
                        row.gradeLevel == selection.gradeLevel,
                  )
                  .toList();
            },
      ),
      adminQuizResultsSchoolYearsProvider.overrideWith(
        (Ref ref) => _schoolYears,
      ),
      adminQuizResultsRepositoryProvider.overrideWithValue(
        _FakeAdminQuizResultsRepository(_rows),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: AdminQuizResultsScreen()),
    ),
  );
}

const String _longAssessmentName =
    'Quiz 7: Multi-Step Fractions, Decimals, and Real-World Mathematical Reasoning';

final List<AdminQuizResultRow> _rows = <AdminQuizResultRow>[
  AdminQuizResultRow(
    quizAttemptId: 'attempt-1',
    studentName: 'Ada Student',
    sectionId: 'section-orion',
    sectionName: 'Orion',
    gradeLevel: GradeLevel.grade6,
    quizId: 'quiz-1',
    assessmentName: _longAssessmentName,
    assessmentType: AssessmentType.postTest,
    score: 10,
    totalQuestions: 10,
    percentage: 100,
    dateTaken: DateTime.utc(2026, 8, 31),
    status: AdminQuizResultStatus.passed,
  ),
  AdminQuizResultRow(
    quizAttemptId: 'attempt-2',
    studentName: 'Ben Student',
    sectionId: 'section-orion',
    sectionName: 'Orion',
    gradeLevel: GradeLevel.grade6,
    quizId: 'quiz-2',
    assessmentName: 'Quiz 4: Multiplication and Division',
    score: 6,
    totalQuestions: 10,
    percentage: 60,
    dateTaken: DateTime.utc(2026, 8, 30),
    status: AdminQuizResultStatus.needsImprovement,
  ),
  AdminQuizResultRow(
    quizAttemptId: 'attempt-3',
    studentName: 'Cara Student',
    sectionId: 'section-summit',
    sectionName: 'Summit',
    gradeLevel: GradeLevel.grade5,
    quizId: 'quiz-3',
    assessmentName: 'Place Value Review',
    score: null,
    totalQuestions: 0,
    percentage: null,
    dateTaken: DateTime.utc(2026, 8, 29),
    status: null,
  ),
  AdminQuizResultRow(
    quizAttemptId: 'attempt-4',
    studentName: 'Dana Student',
    sectionId: 'section-harbor',
    sectionName: 'Harbor',
    gradeLevel: GradeLevel.grade4,
    quizId: 'quiz-4',
    assessmentName: 'Pre-Test: Whole Numbers',
    assessmentType: AssessmentType.preTest,
    score: 8,
    totalQuestions: 10,
    percentage: 80,
    dateTaken: DateTime.utc(2026, 8, 28),
    status: AdminQuizResultStatus.passed,
  ),
];

const List<AdminSchoolYearOption> _schoolYears = <AdminSchoolYearOption>[
  AdminSchoolYearOption(
    schoolYearId: 'year-2026',
    label: '2026-2027',
    isCurrent: true,
  ),
];

final SupabaseClient _testClient = SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeAdminQuizResultsRepository extends AdminQuizResultsRepository {
  _FakeAdminQuizResultsRepository(this.rows) : super(_testClient);

  final List<AdminQuizResultRow> rows;

  @override
  Future<List<AdminQuizResultRow>> fetchResults({
    GradeLevel? gradeLevel,
    String? sectionId,
    AdminQuizResultsAssessmentTypeFilter assessmentTypeFilter =
        AdminQuizResultsAssessmentTypeFilter.all,
    String? schoolYearId,
  }) async =>
      rows
          .where(
            (AdminQuizResultRow row) =>
                gradeLevel == null || row.gradeLevel == gradeLevel,
          )
          .toList();
}
