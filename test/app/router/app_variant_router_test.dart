import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instructional_math_app/app/app_variant.dart';
import 'package:instructional_math_app/app/router/app_router.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('native app variant routing', () {
    test('Student router starts at Student login', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appVariantProvider.overrideWithValue(AppVariant.student),
          studentSessionProvider.overrideWith((ref) => null),
        ],
      );
      final GoRouter router = container.read(appRouterProvider);
      addTearDown(() {
        router.dispose();
        container.dispose();
      });

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.studentLogin,
      );
    });

    test('Student guard sends a valid session into the Student app', () {
      final StudentSession session = StudentSession(
        accessToken: 'test-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        studentId: 'student-id',
      );

      expect(
        studentRedirectForSession(session, AppRoutes.studentLogin),
        AppRoutes.studentHome,
      );
      expect(
        studentRedirectForSession(session, AppRoutes.login),
        AppRoutes.studentHome,
      );
    });

    test('Student guard keeps unauthenticated users in Student login', () {
      expect(
        studentRedirectForSession(null, AppRoutes.studentHome),
        AppRoutes.studentLogin,
      );
      expect(studentRedirectForSession(null, AppRoutes.studentLogin), isNull);
    });

    test('Staff guard sends no restored session to unified login', () {
      expect(
        redirectForStaffSession(const SessionNone(), AppRoutes.splash),
        AppRoutes.login,
      );
      expect(
        redirectForStaffSession(const SessionNone(), AppRoutes.studentLogin),
        AppRoutes.login,
      );
    });

    test('Staff guard preserves Teacher role routing', () {
      expect(
        redirectForStaffSession(
          SessionTeacher(_profile(ProfileRole.teacher)),
          AppRoutes.splash,
        ),
        AppRoutes.teacherHome,
      );
      expect(
        redirectForStaffSession(
          SessionTeacher(_profile(ProfileRole.teacher)),
          AppRoutes.studentLogin,
        ),
        AppRoutes.teacherHome,
      );
    });

    test('Staff guard preserves Administrator role routing', () {
      expect(
        redirectForStaffSession(
          SessionAdmin(_profile(ProfileRole.admin)),
          AppRoutes.splash,
        ),
        AppRoutes.adminHome,
      );
      expect(
        redirectForStaffSession(
          SessionAdmin(_profile(ProfileRole.admin)),
          AppRoutes.studentHome,
        ),
        AppRoutes.adminHome,
      );
    });
  });
}

Profile _profile(ProfileRole role) {
  final DateTime timestamp = DateTime.utc(2026);
  return Profile(
    id: '${role.name}-id',
    role: role,
    status: ProfileStatus.approved,
    fullName: role.name,
    email: '${role.name}@example.com',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
