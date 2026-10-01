import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/teacher_dashboard.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/features/teacher/data/teacher_dashboard_providers.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_dashboard_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_intervention_screens.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_shell_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard cards open redesigned drill-downs and Back works', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total sections'));
    await tester.pumpAndSettle();
    expect(find.text('Manage and view your assigned classes'), findsOneWidget);
    expect(find.text('Section B'), findsOneWidget);
    expect(find.text('No assessment data yet'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Total sections'), findsOneWidget);

    await tester.tap(find.text('Total students'));
    await tester.pumpAndSettle();
    expect(find.text('All grades • All sections'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Average quiz score'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Cruz'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Students needing help'));
    await tester.pumpAndSettle();
    expect(
      find.text('Students who may need additional support'),
      findsOneWidget,
    );

    await tester.tap(find.text('Grade 4'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose a section to review students needing support'),
      findsOneWidget,
    );

    await tester.tap(find.text('Section B'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Average score is below 70%'), findsOneWidget);
    expect(find.text('2 missed or unfinished quizzes'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('Choose a section to review students needing support'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('Students who may need additional support'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Total sections'), findsOneWidget);
  });

  testWidgets('student intervention rows adapt to a narrow window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(520, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const TeacherInterventionStudentNamesScreen(
          sectionName: 'B',
          students: <TeacherInterventionStudent>[_interventionStudent],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Needs support in:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp() {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(_TeacherSessionNotifier.new),
      mySectionsProvider.overrideWith((Ref ref) async => const <MySection>[]),
      dashboardSummaryTilesProvider.overrideWith(
        (Ref ref) async => const DashboardSummaryTiles(
          totalSections: 1,
          totalStudents: 1,
          studentsNeedingIntervention: 1,
          averageQuizScorePercent: 58,
        ),
      ),
      dashboardAverageScoreBySectionProvider.overrideWith(
        (Ref ref) async => const <SectionAverageScore>[
          SectionAverageScore(
            sectionId: 'section-b',
            sectionName: 'B',
            gradeLevel: GradeLevel.grade4,
            studentCount: 1,
          ),
        ],
      ),
      dashboardCompetencyMasteryProvider.overrideWith(
        (Ref ref) async => const <TopicMasteryEntry>[],
      ),
      dashboardRosterProvider.overrideWith(
        (Ref ref) async => const <DashboardRosterEntry>[_rosterEntry],
      ),
      dashboardInterventionStudentsProvider.overrideWith(
        (Ref ref) async => const <TeacherInterventionStudent>[
          _interventionStudent,
        ],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: TeacherDashboardScreen()),
    ),
  );
}

const DashboardRosterEntry _rosterEntry = DashboardRosterEntry(
  studentId: 'student-1',
  fullName: 'Ana Cruz',
  sectionId: 'section-b',
  sectionName: 'B',
  averageQuizScorePercent: 58,
  quizzesCompleted: 3,
  missedOrUnfinishedCount: 2,
  needsIntervention: true,
);

const TeacherInterventionStudent _interventionStudent =
    TeacherInterventionStudent(
      studentId: 'student-1',
      fullName: 'Ana Cruz',
      gradeLevel: GradeLevel.grade4,
      sectionId: 'section-b',
      sectionName: 'B',
      averageQuizScorePercent: 58,
      missedOrUnfinishedCount: 2,
    );

class _TeacherSessionNotifier extends SessionNotifier {
  @override
  Future<SessionState> build() async {
    final DateTime timestamp = DateTime.utc(2026);
    return SessionTeacher(
      Profile(
        id: 'teacher-id',
        role: ProfileRole.teacher,
        status: ProfileStatus.approved,
        fullName: 'Teacher Rivera',
        email: 'teacher@example.com',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }
}
