import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student.dart';
import 'package:instructional_math_app/core/models/teacher_section.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/sections_repository.dart';
import 'package:instructional_math_app/core/repositories/students_repository.dart';
import 'package:instructional_math_app/core/repositories/teacher_sections_repository.dart';
import 'package:instructional_math_app/features/admin/data/account_management_providers.dart';
import 'package:instructional_math_app/features/admin/presentation/account_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Administrator Accounts presentation', () {
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

        expect(find.byKey(const Key('accounts_page_title')), findsOneWidget);
        expect(find.byKey(const Key('accounts_overview')), findsOneWidget);
        expect(
          find.byKey(const Key('accounts_filter_toolbar')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('accounts_directory')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('switches status views and preserves account actions', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Ada Teacher'), findsOneWidget);
      expect(find.text('Mia Student'), findsOneWidget);
      expect(find.text('Archived Teacher'), findsNothing);
      expect(find.text('Archived Student'), findsNothing);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Active'), findsAtLeastNWidgets(2));

      final Finder activeTeacher = find.byKey(
        const Key('account_row_teacher-active'),
      );
      final Finder editAction = find.descendant(
        of: activeTeacher,
        matching: find.text('Edit'),
      );
      await tester.ensureVisible(editAction);
      await tester.tap(editAction);
      await tester.pumpAndSettle();
      expect(find.text('Edit User'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accounts_status_archived')));
      await tester.pumpAndSettle();

      expect(find.text('Ada Teacher'), findsNothing);
      expect(find.text('Mia Student'), findsNothing);
      expect(find.text('Archived Teacher'), findsOneWidget);
      expect(find.text('Archived Student'), findsOneWidget);
      expect(find.text('Restore'), findsNWidgets(2));
      expect(find.text('Archived'), findsAtLeastNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('search no-results state can clear active filters', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final Finder searchField = find.descendant(
        of: find.byKey(const Key('accounts_search_field')),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'Nobody in this directory');
      await tester.pump();

      expect(find.text('No accounts match your filters'), findsOneWidget);
      expect(find.text('Clear filters'), findsWidgets);

      final Finder clearFilters = find.byKey(
        const Key('accounts_clear_filters'),
      );
      await tester.ensureVisible(clearFilters);
      await tester.tap(clearFilters);
      await tester.pumpAndSettle();

      expect(find.text('Ada Teacher'), findsOneWidget);
      expect(find.text('Mia Student'), findsOneWidget);
      expect(find.text('No accounts match your filters'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('distinguishes an empty archived view from filtered results', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          teachersOverride: (Ref ref) => <Profile>[_teachers.first],
          studentsOverride: (Ref ref) => <StudentWithSection>[_students.first],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accounts_status_archived')));
      await tester.pumpAndSettle();

      expect(find.text('No archived accounts yet'), findsOneWidget);
      expect(
        find.text('Accounts you archive will appear here for recovery.'),
        findsOneWidget,
      );
      expect(find.text('No accounts match your filters'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows polished loading, error, and empty states', (
      WidgetTester tester,
    ) async {
      final Completer<List<Profile>> pendingTeachers =
          Completer<List<Profile>>();
      addTearDown(() {
        if (!pendingTeachers.isCompleted) {
          pendingTeachers.complete(const <Profile>[]);
        }
      });

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('loading'),
          teachersOverride: (Ref ref) => pendingTeachers.future,
        ),
      );
      await tester.pump();
      expect(find.text('Loading account directory'), findsOneWidget);
      expect(find.byKey(const Key('accounts_filter_toolbar')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('error'),
          teachersOverride:
              (Ref ref) =>
                  throw const NetworkFailure('Accounts are unavailable.'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Accounts are unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _testApp(
          scopeKey: const ValueKey<String>('empty'),
          teachersOverride: (Ref ref) => const <Profile>[],
          studentsOverride: (Ref ref) => const <StudentWithSection>[],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No accounts yet'), findsOneWidget);
      expect(find.text('0'), findsAtLeastNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testApp({
  Key? scopeKey,
  FutureOr<List<Profile>> Function(Ref ref)? teachersOverride,
  FutureOr<List<StudentWithSection>> Function(Ref ref)? studentsOverride,
}) {
  return ProviderScope(
    key: scopeKey,
    retry: (int retryCount, Object error) => null,
    overrides: [
      adminAccountsTeachersProvider.overrideWith(
        teachersOverride ?? (Ref ref) => _teachers,
      ),
      adminAccountsStudentsProvider.overrideWith(
        studentsOverride ?? (Ref ref) => _students,
      ),
      teacherSectionsRepositoryProvider.overrideWithValue(
        _FakeTeacherSectionsRepository(_teacherAssignments),
      ),
      sectionsRepositoryProvider.overrideWithValue(
        _FakeSectionsRepository(_sections),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: AccountManagementScreen()),
    ),
  );
}

final DateTime _now = DateTime.utc(2026, 8, 31);

final List<Section> _sections = <Section>[
  Section(
    id: 'section-active',
    schoolYearId: 'school-year',
    gradeLevel: GradeLevel.grade6,
    name: 'Orion',
    status: SectionStatus.active,
    createdAt: _now,
    updatedAt: _now,
  ),
  Section(
    id: 'section-archived',
    schoolYearId: 'school-year',
    gradeLevel: GradeLevel.grade5,
    name: 'Legacy',
    status: SectionStatus.archived,
    createdAt: _now,
    updatedAt: _now,
  ),
];

final List<Profile> _teachers = <Profile>[
  Profile(
    id: 'teacher-active',
    role: ProfileRole.teacher,
    status: ProfileStatus.approved,
    fullName: 'Ada Teacher',
    email: 'ada@baymath.test',
    createdAt: _now,
    updatedAt: _now,
  ),
  Profile(
    id: 'teacher-archived',
    role: ProfileRole.teacher,
    status: ProfileStatus.archived,
    fullName: 'Archived Teacher',
    email: 'archived.teacher@baymath.test',
    createdAt: _now,
    updatedAt: _now,
  ),
];

final List<StudentWithSection> _students = <StudentWithSection>[
  StudentWithSection(
    Student(
      id: 'student-active',
      username: 'mia.student',
      fullName: 'Mia Student',
      createdBy: 'teacher-active',
      status: StudentStatus.active,
      bestEndlessStreak: 8,
      createdAt: _now,
      updatedAt: _now,
    ),
    _sections.first,
  ),
  StudentWithSection(
    Student(
      id: 'student-archived',
      username: 'archived.student',
      fullName: 'Archived Student',
      createdBy: 'teacher-active',
      status: StudentStatus.archived,
      bestEndlessStreak: 2,
      createdAt: _now,
      updatedAt: _now,
    ),
    _sections.last,
  ),
];

final List<TeacherSection> _teacherAssignments = <TeacherSection>[
  TeacherSection(
    id: 'teacher-section-active',
    teacherId: 'teacher-active',
    sectionId: 'section-active',
    isPrimary: true,
    assignedAt: _now,
    createdAt: _now,
    updatedAt: _now,
  ),
  TeacherSection(
    id: 'teacher-section-archived',
    teacherId: 'teacher-archived',
    sectionId: 'section-archived',
    isPrimary: true,
    assignedAt: _now,
    createdAt: _now,
    updatedAt: _now,
  ),
];

final SupabaseClient _testClient = SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeTeacherSectionsRepository extends TeacherSectionsRepository {
  _FakeTeacherSectionsRepository(this.assignments) : super(_testClient);

  final List<TeacherSection> assignments;

  @override
  Future<List<TeacherSection>> fetchAll() async => assignments;
}

class _FakeSectionsRepository extends SectionsRepository {
  _FakeSectionsRepository(this.sections) : super(_testClient);

  final List<Section> sections;

  @override
  Future<List<Section>> fetchByIds(List<String> ids) async =>
      sections.where((Section section) => ids.contains(section.id)).toList();
}
