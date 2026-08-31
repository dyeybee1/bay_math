import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/admin_dashboard.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/features/admin/data/account_management_providers.dart';
import 'package:instructional_math_app/features/admin/data/admin_dashboard_providers.dart';
import 'package:instructional_math_app/features/admin/data/admin_quiz_results_providers.dart';
import 'package:instructional_math_app/features/admin/data/performance_reports_providers.dart';
import 'package:instructional_math_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:instructional_math_app/features/admin/presentation/admin_shell_screen.dart';
import 'package:instructional_math_app/features/admin/presentation/school_years_screen.dart';
import 'package:instructional_math_app/features/admin/presentation/sections_screen.dart';
import 'package:instructional_math_app/features/admin/presentation/teacher_approval_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Administrator Statistics presentation', () {
    testWidgets('fits every target desktop and laptop viewport', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final Size size in <Size>[
        const Size(1024, 700),
        const Size(1280, 720),
        const Size(1366, 768),
        const Size(1440, 900),
        const Size(1920, 1080),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(_testApp());
        await tester.pump(const Duration(seconds: 1));

        expect(find.byKey(const Key('admin_statistics_title')), findsOneWidget);
        expect(find.text('School context'), findsOneWidget);
        expect(find.text('Learning and support'), findsOneWidget);
        expect(find.text('Average score by grade level'), findsOneWidget);
        expect(find.text('Proficiency distribution'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('shell presents Statistics as the selected destination', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp(includeShell: true));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('admin_brand_logo')), findsOneWidget);
      expect(find.byKey(const Key('admin_navigation_0')), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.byKey(const Key('admin_logout_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shows the preserved metrics and opens an existing drill-down',
      (WidgetTester tester) async {
        await tester.pumpWidget(_testApp());
        await tester.pump(const Duration(seconds: 1));

        for (final String value in <String>['15', '4', '5', '11', '90%']) {
          expect(find.text(value), findsAtLeastNWidgets(1));
        }
        expect(find.text('Students requiring intervention'), findsOneWidget);

        await tester.tap(find.text('Teachers'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('No teachers yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('supports keyboard focus and activation for metric details', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No teachers yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps independently loaded analytics visible', (
      WidgetTester tester,
    ) async {
      final Completer<AdminSummaryTiles> pendingSummary =
          Completer<AdminSummaryTiles>();
      addTearDown(() {
        if (!pendingSummary.isCompleted) pendingSummary.complete(_summary);
      });

      await tester.pumpWidget(
        _testApp(summaryOverride: (Ref ref) => pendingSummary.future),
      );
      await tester.pump();

      expect(find.text('Loading school statistics'), findsOneWidget);
      expect(find.text('Average score by grade level'), findsOneWidget);
      expect(find.text('Proficiency distribution'), findsOneWidget);
      expect(find.text('Grade 4'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('presents readable independent errors and empty analytics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          summaryOverride:
              (Ref ref) =>
                  throw const NetworkFailure(
                    'Summary is temporarily unavailable.',
                  ),
          scoreOverride: (Ref ref) => const <GradeLevelAverageScore>[],
          proficiencyOverride:
              (Ref ref) =>
                  throw const NetworkFailure(
                    'Proficiency data is temporarily unavailable.',
                  ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Summary is temporarily unavailable.'), findsOneWidget);
      expect(find.text('No grade-level data yet'), findsOneWidget);
      expect(
        find.text('Proficiency data is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testApp({
  bool includeShell = false,
  FutureOr<AdminSummaryTiles> Function(Ref ref)? summaryOverride,
  FutureOr<List<GradeLevelAverageScore>> Function(Ref ref)? scoreOverride,
  FutureOr<List<ProficiencyDistribution>> Function(Ref ref)?
  proficiencyOverride,
}) {
  return ProviderScope(
    retry: (int retryCount, Object error) => null,
    overrides: [
      sessionProvider.overrideWith(_TestSessionNotifier.new),
      adminSummaryTilesProvider.overrideWith(
        summaryOverride ?? (Ref ref) => _summary,
      ),
      adminScoreByGradeProvider.overrideWith(
        scoreOverride ?? (Ref ref) => _gradeScores,
      ),
      adminProficiencyDistributionProvider.overrideWith(
        proficiencyOverride ?? (Ref ref) => _proficiency,
      ),
      adminTeachersListProvider.overrideWith(
        (Ref ref) => const <AdminTeacherListEntry>[],
      ),
      teachersListProvider.overrideWith((Ref ref) => const []),
      defaultSchoolProvider.overrideWith((Ref ref) => null),
      schoolYearsListProvider.overrideWith((Ref ref) => const []),
      approvedTeachersProvider.overrideWith((Ref ref) => const []),
      adminAccountsTeachersProvider.overrideWith((Ref ref) => const []),
      adminAccountsStudentsProvider.overrideWith((Ref ref) => const []),
      adminQuizResultsProvider.overrideWith((Ref ref) => const []),
      adminQuizResultsSchoolYearsProvider.overrideWith((Ref ref) => const []),
      adminPerformanceReportsProvider.overrideWith((Ref ref) => const []),
      adminPerformanceReportsTopicsProvider.overrideWith((Ref ref) => const []),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home:
          includeShell
              ? const AdminShellScreen()
              : const AdminDashboardScreen(),
    ),
  );
}

class _TestSessionNotifier extends SessionNotifier {
  @override
  Future<SessionState> build() async => const SessionNone();
}

const AdminSummaryTiles _summary = AdminSummaryTiles(
  totalStudents: 15,
  totalTeachers: 4,
  totalSections: 5,
  totalQuizAttempts: 11,
  averageScore: 90,
  studentsRequiringIntervention: 3,
);

const List<GradeLevelAverageScore> _gradeScores = <GradeLevelAverageScore>[
  GradeLevelAverageScore(
    gradeLevel: GradeLevel.grade4,
    studentCount: 5,
    averageScore: 92,
  ),
  GradeLevelAverageScore(
    gradeLevel: GradeLevel.grade5,
    studentCount: 6,
    averageScore: 84,
  ),
  GradeLevelAverageScore(
    gradeLevel: GradeLevel.grade6,
    studentCount: 4,
    averageScore: 76,
  ),
];

const List<ProficiencyDistribution> _proficiency = <ProficiencyDistribution>[
  ProficiencyDistribution(
    bucket: ProficiencyBucket.advanced,
    studentCount: 5,
    percent: 33.3,
  ),
  ProficiencyDistribution(
    bucket: ProficiencyBucket.proficient,
    studentCount: 6,
    percent: 40,
  ),
  ProficiencyDistribution(
    bucket: ProficiencyBucket.approachingProficiency,
    studentCount: 3,
    percent: 20,
  ),
  ProficiencyDistribution(
    bucket: ProficiencyBucket.belowBasic,
    studentCount: 1,
    percent: 6.7,
  ),
];
