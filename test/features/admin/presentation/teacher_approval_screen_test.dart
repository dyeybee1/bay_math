import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/profiles_repository.dart';
import 'package:instructional_math_app/features/admin/presentation/teacher_approval_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher Accounts registration queue', () {
    testWidgets(
      'main view shows pending Teachers only with the correct count',
      (WidgetTester tester) async {
        final _FakeProfilesRepository repository = _repository();

        await tester.pumpWidget(_testApp(repository));
        await tester.pumpAndSettle();

        expect(find.text('Teacher Accounts'), findsOneWidget);
        expect(
          find.text('Review and manage Teacher registration requests.'),
          findsOneWidget,
        );
        expect(find.text('Pending Teacher One'), findsOneWidget);
        expect(find.text('Pending Teacher Two'), findsOneWidget);
        expect(find.text('Approved Teacher'), findsNothing);
        expect(find.text('Rejected Teacher'), findsNothing);
        expect(
          find.byKey(const Key('teacher_accounts_count_2')),
          findsOneWidget,
        );
        expect(find.text('Requested Aug 25, 2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('approved Teacher disappears and pending count updates', (
      WidgetTester tester,
    ) async {
      final _FakeProfilesRepository repository = _repository();

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('approve_teacher_pending-one')));
      await tester.pumpAndSettle();

      expect(find.text('Pending Teacher One'), findsNothing);
      expect(find.byKey(const Key('teacher_accounts_count_1')), findsOneWidget);
      expect(find.text('Teacher approved successfully.'), findsOneWidget);
      expect(repository.approvedTeacherIds, <String>['pending-one']);
      expect(repository.approvedByIds, <String>['admin-id']);

      await tester.tap(
        find.byKey(const Key('teacher_accounts_history_action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending Teacher One'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('history_teacher_pending-one')),
          matching: find.text('Approved'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rejected Teacher disappears and rejection behavior remains', (
      WidgetTester tester,
    ) async {
      final _FakeProfilesRepository repository = _repository();

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reject_teacher_pending-two')));
      await tester.pumpAndSettle();

      expect(find.text('Pending Teacher Two'), findsNothing);
      expect(find.byKey(const Key('teacher_accounts_count_1')), findsOneWidget);
      expect(find.text('Teacher request rejected.'), findsOneWidget);
      expect(repository.rejectedTeacherIds, <String>['pending-two']);
    });

    testWidgets('History excludes pending and includes processed requests', (
      WidgetTester tester,
    ) async {
      final _FakeProfilesRepository repository = _repository();

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacher_accounts_history_action')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Teacher One'), findsNothing);
      expect(find.text('Pending Teacher Two'), findsNothing);
      expect(find.text('Approved Teacher'), findsOneWidget);
      expect(find.text('Rejected Teacher'), findsOneWidget);
      expect(find.textContaining('Approved by BayMath Admin'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('Approved and Rejected History filters work', (
      WidgetTester tester,
    ) async {
      final _FakeProfilesRepository repository = _repository();

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacher_accounts_history_action')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('teacher_history_filter_approved')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approved Teacher'), findsOneWidget);
      expect(find.text('Rejected Teacher'), findsNothing);

      await tester.tap(
        find.byKey(const Key('teacher_history_filter_rejected')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approved Teacher'), findsNothing);
      expect(find.text('Rejected Teacher'), findsOneWidget);
    });

    testWidgets('shows distinct empty states for pending and History', (
      WidgetTester tester,
    ) async {
      final _FakeProfilesRepository repository = _FakeProfilesRepository(
        pending: <Profile>[],
        processed: <Profile>[],
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      expect(find.text('No pending Teacher requests.'), findsOneWidget);
      expect(
        find.text('New Teacher registrations will appear here for review.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('teacher_accounts_history_action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No registration history yet.'), findsOneWidget);
    });

    testWidgets('History retry recovers after a repository failure', (
      WidgetTester tester,
    ) async {
      final _FakeProfilesRepository repository =
          _repository()..processedFailuresRemaining = 1;

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacher_accounts_history_action')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(repository.processedFetchCount, 1);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Approved Teacher'), findsOneWidget);
      expect(find.text('Rejected Teacher'), findsOneWidget);
      expect(repository.processedFetchCount, 2);
    });

    testWidgets('fits laptop, desktop, and narrow web content widths', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final Size size in <Size>[
        const Size(760, 700),
        const Size(1024, 720),
        const Size(1440, 900),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _testApp(_repository(), scopeKey: ValueKey<Size>(size)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });
  });
}

Widget _testApp(_FakeProfilesRepository repository, {Key? scopeKey}) {
  return ProviderScope(
    key: scopeKey,
    retry: (int retryCount, Object error) => null,
    overrides: [
      sessionProvider.overrideWith(_AdminSessionNotifier.new),
      profilesRepositoryProvider.overrideWithValue(repository),
      teachersListProvider.overrideWith(
        (Ref ref) => repository.fetchTeachers(status: ProfileStatus.pending),
      ),
      processedTeachersListProvider.overrideWith(
        (Ref ref) => repository.fetchProcessedTeachers(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: TeacherApprovalScreen()),
    ),
  );
}

class _AdminSessionNotifier extends SessionNotifier {
  @override
  Future<SessionState> build() async => SessionAdmin(_admin);
}

class _FakeProfilesRepository extends ProfilesRepository {
  _FakeProfilesRepository({
    required List<Profile> pending,
    required List<Profile> processed,
  }) : _pending = pending,
       _processed = processed,
       super(_testClient);

  final List<Profile> _pending;
  final List<Profile> _processed;
  final List<String> approvedTeacherIds = <String>[];
  final List<String> approvedByIds = <String>[];
  final List<String> rejectedTeacherIds = <String>[];
  int processedFailuresRemaining = 0;
  int processedFetchCount = 0;

  @override
  Future<List<Profile>> fetchTeachers({ProfileStatus? status}) async {
    expect(status, ProfileStatus.pending);
    return List<Profile>.unmodifiable(_pending);
  }

  @override
  Future<List<Profile>> fetchProcessedTeachers() async {
    processedFetchCount += 1;
    if (processedFailuresRemaining > 0) {
      processedFailuresRemaining -= 1;
      throw const ServerFailure();
    }
    return List<Profile>.unmodifiable(_processed);
  }

  @override
  Future<void> approveTeacher({
    required String teacherId,
    required String approvedByAdminId,
  }) async {
    approvedTeacherIds.add(teacherId);
    approvedByIds.add(approvedByAdminId);
    final Profile teacher = _removePending(teacherId);
    _processed.insert(
      0,
      _copyWithStatus(
        teacher,
        ProfileStatus.approved,
        approvedBy: approvedByAdminId,
        approvedByName: _admin.fullName,
        approvedAt: _now,
      ),
    );
  }

  @override
  Future<void> rejectTeacher(String teacherId) async {
    rejectedTeacherIds.add(teacherId);
    final Profile teacher = _removePending(teacherId);
    _processed.insert(0, _copyWithStatus(teacher, ProfileStatus.rejected));
  }

  Profile _removePending(String teacherId) {
    final int index = _pending.indexWhere(
      (Profile teacher) => teacher.id == teacherId,
    );
    return _pending.removeAt(index);
  }
}

_FakeProfilesRepository _repository() => _FakeProfilesRepository(
  pending: <Profile>[
    _profile(
      id: 'pending-one',
      name: 'Pending Teacher One',
      email: 'pending.one@baymath.test',
      status: ProfileStatus.pending,
      createdAt: DateTime.utc(2026, 8, 25),
    ),
    _profile(
      id: 'pending-two',
      name: 'Pending Teacher Two',
      email: 'pending.two@baymath.test',
      status: ProfileStatus.pending,
      createdAt: DateTime.utc(2026, 8, 27),
    ),
  ],
  processed: <Profile>[
    _profile(
      id: 'approved',
      name: 'Approved Teacher',
      email: 'approved@baymath.test',
      status: ProfileStatus.approved,
      approvedBy: _admin.id,
      approvedByName: _admin.fullName,
      approvedAt: DateTime.utc(2026, 8, 30),
      updatedAt: DateTime.utc(2026, 8, 30),
    ),
    _profile(
      id: 'rejected',
      name: 'Rejected Teacher',
      email: 'rejected@baymath.test',
      status: ProfileStatus.rejected,
      updatedAt: DateTime.utc(2026, 8, 29),
    ),
  ],
);

final DateTime _now = DateTime.utc(2026, 8, 31);

final Profile _admin = _profile(
  id: 'admin-id',
  name: 'BayMath Admin',
  email: 'admin@baymath.test',
  role: ProfileRole.admin,
  status: ProfileStatus.approved,
  approvedAt: DateTime.utc(2026, 1, 1),
);

Profile _profile({
  required String id,
  required String name,
  required String email,
  ProfileRole role = ProfileRole.teacher,
  required ProfileStatus status,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? approvedBy,
  String? approvedByName,
  DateTime? approvedAt,
}) {
  return Profile(
    id: id,
    role: role,
    status: status,
    fullName: name,
    email: email,
    approvedBy: approvedBy,
    approvedByName: approvedByName,
    approvedAt: approvedAt,
    createdAt: createdAt ?? _now,
    updatedAt: updatedAt ?? _now,
  );
}

Profile _copyWithStatus(
  Profile profile,
  ProfileStatus status, {
  String? approvedBy,
  String? approvedByName,
  DateTime? approvedAt,
}) {
  return Profile(
    id: profile.id,
    role: profile.role,
    status: status,
    fullName: profile.fullName,
    email: profile.email,
    approvedBy: approvedBy,
    approvedByName: approvedByName,
    approvedAt: approvedAt,
    createdAt: profile.createdAt,
    updatedAt: _now,
  );
}

final SupabaseClient _testClient = SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);
