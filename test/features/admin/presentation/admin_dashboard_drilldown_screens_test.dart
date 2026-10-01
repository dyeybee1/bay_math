import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/admin_dashboard.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/admin/data/admin_dashboard_providers.dart';
import 'package:instructional_math_app/features/admin/presentation/admin_dashboard_drilldown_screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('teacher directory opens details and handles no assignments', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const AdminTeachersListScreen(), <Override>[
        adminTeachersListProvider.overrideWith(
          (Ref ref) => Future<List<AdminTeacherListEntry>>.value(
            const <AdminTeacherListEntry>[
              AdminTeacherListEntry(
                teacherId: 'teacher-1',
                fullName: 'Jay Bryan Blas',
                email: 'jay@gmail.com',
                sectionCount: 0,
              ),
              AdminTeacherListEntry(
                teacherId: 'teacher-2',
                fullName: 'Maria Santos',
                email: 'maria@gmail.com',
                sectionCount: 2,
              ),
            ],
          ),
        ),
        adminTeacherSectionsProvider.overrideWith(
          (Ref ref, String teacherId) =>
              Future<List<Section>>.value(const <Section>[]),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 Teachers'), findsOneWidget);
    expect(find.text('0 assigned sections'), findsOneWidget);
    expect(find.text('2 assigned sections'), findsOneWidget);
    expect(find.text('View details'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey<String>('admin_teacher_teacher-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher details'), findsOneWidget);
    expect(find.text('Jay Bryan Blas'), findsOneWidget);
    expect(find.text('No assigned sections'), findsOneWidget);
    expect(
      find.text('This teacher does not have any assigned sections.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Teachers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher details show real assigned sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const AdminTeacherDetailsScreen(
          teacher: AdminTeacherListEntry(
            teacherId: 'teacher-1',
            fullName: 'Jay Bryan Blas',
            email: 'jay@gmail.com',
            sectionCount: 1,
          ),
        ),
        <Override>[
          adminTeacherSectionsProvider.overrideWith(
            (Ref ref, String teacherId) =>
                Future<List<Section>>.value(<Section>[_section]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Section'), findsOneWidget);
    expect(find.text('Section B'), findsOneWidget);
    expect(find.text('Grade 4'), findsOneWidget);
    expect(find.text('Active section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('intervention drill-down remains navigable at narrow width', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 620);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _testApp(const AdminInterventionStudentsScreen(), <Override>[
        adminInterventionStudentsProvider.overrideWith(
          (Ref ref) => Future<List<AdminInterventionStudent>>.value(
            const <AdminInterventionStudent>[
              AdminInterventionStudent(
                studentId: 'student-1',
                fullName: 'Alex Rivera',
                gradeLevel: GradeLevel.grade4,
                sectionName: 'Section B',
                averageScorePercent: 62,
                missedOrUnfinishedCount: 3,
              ),
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View sections'));
    await tester.pumpAndSettle();
    expect(find.text('Grade 4 sections'), findsOneWidget);

    await tester.tap(find.text('View students'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('3 missed/unfinished'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget home, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    ),
  );
}

final DateTime _timestamp = DateTime.utc(2026, 1, 1);

final Section _section = Section(
  id: 'section-1',
  schoolYearId: 'school-year-1',
  gradeLevel: GradeLevel.grade4,
  name: 'Section B',
  status: SectionStatus.active,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
