import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/school_year.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/sections_repository.dart';
import 'package:instructional_math_app/features/admin/presentation/school_years_screen.dart';
import 'package:instructional_math_app/features/admin/presentation/sections_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Administrator Sections archive management', () {
    testWidgets('scopes Active and Archive views at repository level', (
      WidgetTester tester,
    ) async {
      final _FakeSectionsRepository repository = _FakeSectionsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('Grade 6 — Orion'), findsOneWidget);
      expect(find.text('Grade 5 — Legacy'), findsNothing);
      expect(find.text('Delete permanently'), findsNothing);
      expect(repository.requestedStatuses, <SectionStatus>[
        SectionStatus.active,
      ]);

      await tester.tap(find.byKey(const Key('sections_view_archive')));
      await tester.pumpAndSettle();

      expect(find.text('Grade 6 — Orion'), findsNothing);
      expect(find.text('Grade 5 — Legacy'), findsOneWidget);
      expect(find.text('Restore'), findsNWidgets(2));
      expect(find.text('Delete permanently'), findsNWidgets(2));
      expect(repository.requestedStatuses, contains(SectionStatus.archived));
      expect(tester.takeException(), isNull);
    });

    testWidgets('archive and restore move a section between views', (
      WidgetTester tester,
    ) async {
      final _FakeSectionsRepository repository = _FakeSectionsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('archive_section_section-active')));
      await tester.pumpAndSettle();
      expect(find.text('Section archived successfully.'), findsOneWidget);
      expect(find.text('Grade 6 — Orion'), findsNothing);

      await tester.tap(find.byKey(const Key('sections_view_archive')));
      await tester.pumpAndSettle();
      expect(find.text('Grade 6 — Orion'), findsOneWidget);

      await tester.tap(find.byKey(const Key('restore_section_section-active')));
      await tester.pumpAndSettle();
      expect(repository.restoredIds, <String>['section-active']);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Section restored successfully.'), findsOneWidget);
      expect(find.text('Grade 6 — Orion'), findsNothing);

      await tester.tap(find.byKey(const Key('sections_view_active')));
      await tester.pumpAndSettle();
      expect(find.text('Grade 6 — Orion'), findsOneWidget);
      expect(repository.archivedIds, <String>['section-active']);
      expect(repository.restoredIds, <String>['section-active']);
    });

    testWidgets('permanent delete is confirmed and leaves unrelated rows', (
      WidgetTester tester,
    ) async {
      final _FakeSectionsRepository repository = _FakeSectionsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sections_view_archive')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('delete_section_section-archived')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Delete this archived section permanently?'),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(repository.deletedIds, isEmpty);

      await tester.tap(find.text('Delete permanently').last);
      await tester.pumpAndSettle();
      expect(repository.deletedIds, <String>['section-archived']);
      expect(find.text('Section deleted permanently.'), findsOneWidget);
      expect(find.text('Grade 5 — Legacy'), findsNothing);
      expect(find.text('Grade 4 — Preserve'), findsOneWidget);
    });

    testWidgets('dependency-blocked delete shows a safe message', (
      WidgetTester tester,
    ) async {
      final _FakeSectionsRepository repository = _FakeSectionsRepository(
        blockedId: 'section-preserve',
      );
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sections_view_archive')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('delete_section_section-preserve')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently').last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This section cannot be deleted because it has student enrollment history that must be preserved.',
        ),
        findsOneWidget,
      );
      expect(find.text('Grade 4 — Preserve'), findsOneWidget);
      expect(repository.deletedIds, isEmpty);
    });

    testWidgets('fits representative admin content widths', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final Size size in <Size>[
        const Size(760, 700),
        const Size(1024, 700),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(_testApp(_FakeSectionsRepository()));
        await tester.pumpAndSettle();
        expect(find.text('Sections'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });
  });
}

Widget _testApp(_FakeSectionsRepository repository) {
  return ProviderScope(
    overrides: [
      schoolYearsListProvider.overrideWith((Ref ref) => <SchoolYear>[_year]),
      sectionsRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: SectionsScreen()),
    ),
  );
}

final DateTime _now = DateTime.utc(2026, 9, 14);

final SchoolYear _year = SchoolYear(
  id: 'school-year',
  schoolId: 'school',
  label: '2026–2027',
  startDate: DateTime.utc(2026, 6),
  endDate: DateTime.utc(2027, 4),
  isCurrent: true,
  status: SchoolYearStatus.active,
  createdAt: _now,
  updatedAt: _now,
);

final SupabaseClient _testClient = SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeSectionsRepository extends SectionsRepository {
  _FakeSectionsRepository({this.blockedId})
    : _sections = <Section>[
        _section(
          'section-active',
          'Orion',
          SectionStatus.active,
          GradeLevel.grade6,
        ),
        _section(
          'section-archived',
          'Legacy',
          SectionStatus.archived,
          GradeLevel.grade5,
        ),
        _section(
          'section-preserve',
          'Preserve',
          SectionStatus.archived,
          GradeLevel.grade4,
        ),
      ],
      super(_testClient);

  final String? blockedId;
  final List<Section> _sections;
  final List<SectionStatus> requestedStatuses = <SectionStatus>[];
  final List<String> archivedIds = <String>[];
  final List<String> restoredIds = <String>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<List<Section>> fetchForSchoolYear(
    String schoolYearId, {
    SectionStatus? status,
  }) async {
    if (status != null) requestedStatuses.add(status);
    return _sections
        .where(
          (Section section) =>
              section.schoolYearId == schoolYearId &&
              (status == null || section.status == status),
        )
        .toList();
  }

  @override
  Future<void> archive(String sectionId) async {
    archivedIds.add(sectionId);
    _replaceStatus(sectionId, SectionStatus.archived);
  }

  @override
  Future<void> restore(String sectionId) async {
    restoredIds.add(sectionId);
    _replaceStatus(sectionId, SectionStatus.active);
  }

  @override
  Future<void> deletePermanently(String sectionId) async {
    if (sectionId == blockedId) {
      throw const ValidationFailure(
        'This section cannot be deleted because it has student enrollment history that must be preserved.',
      );
    }
    final Section target = _sections.firstWhere(
      (Section section) => section.id == sectionId,
    );
    if (target.status != SectionStatus.archived) {
      throw const ValidationFailure(
        'Only archived sections can be permanently deleted.',
      );
    }
    deletedIds.add(sectionId);
    _sections.removeWhere((Section section) => section.id == sectionId);
  }

  void _replaceStatus(String id, SectionStatus status) {
    final int index = _sections.indexWhere(
      (Section section) => section.id == id,
    );
    final Section current = _sections[index];
    _sections[index] = Section(
      id: current.id,
      schoolYearId: current.schoolYearId,
      gradeLevel: current.gradeLevel,
      name: current.name,
      status: status,
      createdAt: current.createdAt,
      updatedAt: _now,
    );
  }
}

Section _section(
  String id,
  String name,
  SectionStatus status,
  GradeLevel gradeLevel,
) {
  return Section(
    id: id,
    schoolYearId: 'school-year',
    gradeLevel: gradeLevel,
    name: name,
    status: status,
    createdAt: _now,
    updatedAt: _now,
  );
}
