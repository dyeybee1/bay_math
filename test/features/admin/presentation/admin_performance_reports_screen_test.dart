import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/admin_quiz_result_row.dart';
import 'package:instructional_math_app/core/models/admin_topic_mastery.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/repositories/admin_quiz_results_repository.dart';
import 'package:instructional_math_app/core/widgets/buttons/app_button.dart';
import 'package:instructional_math_app/features/admin/data/admin_quiz_results_providers.dart';
import 'package:instructional_math_app/features/admin/data/performance_reports_providers.dart';
import 'package:instructional_math_app/features/admin/presentation/performance_reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Administrator Performance Reports presentation', () {
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
          find.byKey(const Key('performance_reports_page_title')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('performance_reports_filter_toolbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('performance_reports_mastery_surface')),
          findsOneWidget,
        );
        expect(find.text(_longTopic), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('preserves exact topics, percentages, and export enablement', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('5 topics'), findsOneWidget);
      expect(find.text(_longTopic), findsAtLeastNWidgets(1));
      expect(find.text('42.5%'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('83.3%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('25'), findsNothing);
      expect(find.text('50'), findsNothing);
      expect(find.text('75'), findsNothing);

      final AppButton exportButton = tester.widget<AppButton>(
        find.byKey(const Key('performance_reports_export_button')),
      );
      expect(exportButton.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps all four existing filters wired and clears safely', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(AdminPerformanceReportsScreen)),
      );

      await _selectDropdownOption(
        tester,
        const Key('performance_reports_grade_filter'),
        'Grade 4',
      );
      expect(
        container
            .read(adminPerformanceReportsFilterSelectionProvider)
            .gradeLevel,
        GradeLevel.grade4,
      );
      expect(find.text('1 topic'), findsOneWidget);

      await _selectDropdownOption(
        tester,
        const Key('performance_reports_topic_filter'),
        _longTopic,
      );
      expect(
        container.read(adminPerformanceReportsFilterSelectionProvider).topic,
        _longTopic,
      );

      await _selectDropdownOption(
        tester,
        const Key('performance_reports_date_filter'),
        '2026-2027 (Current)',
      );
      expect(
        container
            .read(adminPerformanceReportsFilterSelectionProvider)
            .schoolYearId,
        'year-2026',
      );

      await _selectDropdownOption(
        tester,
        const ValueKey<String>('performance_reports_section_all'),
        'Orion',
      );
      expect(
        container
            .read(adminPerformanceReportsFilterSelectionProvider)
            .sectionId,
        'section-orion',
      );

      await tester.tap(
        find.byKey(const Key('performance_reports_clear_filters')),
      );
      await tester.pumpAndSettle();

      final AdminPerformanceReportsFilterSelection cleared = container.read(
        adminPerformanceReportsFilterSelectionProvider,
      );
      expect(cleared.gradeLevel, isNull);
      expect(cleared.sectionId, isNull);
      expect(cleared.topic, isNull);
      expect(cleared.schoolYearId, isNull);
      expect(find.text('5 topics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('distinguishes base empty and filtered empty states', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('base-empty'),
          reportsOverride: (Ref ref) => const <AdminTopicMasteryRow>[],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No mastery data available yet'), findsOneWidget);

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('filtered-empty'),
          reportsOverride: (Ref ref) {
            ref.watch(adminPerformanceReportsFilterSelectionProvider);
            return const <AdminTopicMasteryRow>[];
          },
        ),
      );
      await tester.pumpAndSettle();
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(AdminPerformanceReportsScreen)),
      );
      container
          .read(adminPerformanceReportsFilterSelectionProvider.notifier)
          .update(
            (AdminPerformanceReportsFilterSelection selection) =>
                selection.withGradeLevel(GradeLevel.grade5),
          );
      await tester.pumpAndSettle();

      expect(
        find.text('No performance data matches the selected filters'),
        findsOneWidget,
      );
      expect(find.text('Clear filters'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('presents stable loading and error states', (
      WidgetTester tester,
    ) async {
      final Completer<List<AdminTopicMasteryRow>> pending =
          Completer<List<AdminTopicMasteryRow>>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(_rows);
      });

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('loading'),
          reportsOverride: (Ref ref) => pending.future,
        ),
      );
      await tester.pump();
      expect(find.text('Loading topic mastery'), findsOneWidget);
      final AppButton loadingExport = tester.widget<AppButton>(
        find.byKey(const Key('performance_reports_export_button')),
      );
      expect(loadingExport.onPressed, isNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('error'),
          reportsOverride:
              (Ref ref) =>
                  throw const NetworkFailure(
                    'Performance data is unavailable.',
                  ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Performance data is unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _selectDropdownOption(
  WidgetTester tester,
  Key fieldKey,
  String option,
) async {
  final Finder field = find.descendant(
    of: find.byKey(fieldKey),
    matching: find.byType(TextField),
  );
  await tester.tap(field);
  await tester.pumpAndSettle();
  final Finder optionButton = find.ancestor(
    of: find.text(option),
    matching: find.byType(MenuItemButton),
  );
  await tester.tap(optionButton.last);
  await tester.pumpAndSettle();
}

Widget _testApp({
  Key? scopeKey,
  FutureOr<List<AdminTopicMasteryRow>> Function(Ref ref)? reportsOverride,
}) {
  return ProviderScope(
    key: scopeKey,
    retry: (int retryCount, Object error) => null,
    overrides: [
      adminPerformanceReportsProvider.overrideWith(
        reportsOverride ??
            (Ref ref) {
              final AdminPerformanceReportsFilterSelection selection = ref
                  .watch(adminPerformanceReportsFilterSelectionProvider);
              Iterable<AdminTopicMasteryRow> rows = _rows;
              if (selection.gradeLevel == GradeLevel.grade4) {
                rows = rows.where(
                  (AdminTopicMasteryRow row) => row.topic == _longTopic,
                );
              }
              if (selection.topic != null) {
                rows = rows.where(
                  (AdminTopicMasteryRow row) => row.topic == selection.topic,
                );
              }
              return rows.toList();
            },
      ),
      adminPerformanceReportsTopicsProvider.overrideWith(
        (Ref ref) =>
            _rows.map((AdminTopicMasteryRow row) => row.topic).toList(),
      ),
      adminQuizResultsSchoolYearsProvider.overrideWith(
        (Ref ref) => _schoolYears,
      ),
      adminQuizResultsRepositoryProvider.overrideWithValue(
        _FakeAdminQuizResultsRepository(_quizRows),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: AdminPerformanceReportsScreen()),
    ),
  );
}

const String _longTopic = 'Addition and Subtraction of Numbers up to 1,000,000';

const List<AdminTopicMasteryRow> _rows = <AdminTopicMasteryRow>[
  AdminTopicMasteryRow(
    topic: _longTopic,
    questionsTotal: 40,
    questionsCorrect: 17,
    masteryPercent: 42.5,
  ),
  AdminTopicMasteryRow(
    topic: 'Comparing Numbers up to 1,000,000',
    questionsTotal: 30,
    questionsCorrect: 20,
    masteryPercent: 67,
  ),
  AdminTopicMasteryRow(
    topic: 'Multiplication, Division, and MDAS',
    questionsTotal: 30,
    questionsCorrect: 25,
    masteryPercent: 83.3,
  ),
  AdminTopicMasteryRow(
    topic: 'Place Value of Whole Numbers',
    questionsTotal: 20,
    questionsCorrect: 20,
    masteryPercent: 100,
  ),
  AdminTopicMasteryRow(
    topic: 'Understanding Decimal Place Value',
    questionsTotal: 10,
    questionsCorrect: 0,
    masteryPercent: 0,
  ),
];

final List<AdminQuizResultRow> _quizRows = <AdminQuizResultRow>[
  AdminQuizResultRow(
    quizAttemptId: 'attempt-1',
    studentName: 'Ada Student',
    sectionId: 'section-orion',
    sectionName: 'Orion',
    gradeLevel: GradeLevel.grade4,
    quizId: 'quiz-1',
    assessmentName: 'Whole Numbers',
    score: 8,
    totalQuestions: 10,
    percentage: 80,
    dateTaken: DateTime.utc(2026, 8, 31),
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
  }) async => rows;
}
