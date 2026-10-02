import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instructional_math_app/app/app_variant.dart';
import 'package:instructional_math_app/app/router/app_router.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/core/providers/password_recovery_provider.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('app variant routing', () {
    test(
      'default Web build opens Student while native desktop stays Staff',
      () {
        expect(defaultAppVariant(isWeb: true), AppVariant.student);
        expect(defaultAppVariant(isWeb: false), AppVariant.staff);
      },
    );

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
      expect(
        studentRedirectForSession(null, AppRoutes.login),
        AppRoutes.studentLogin,
      );
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

    test('Teacher lesson view route is Teacher-only', () {
      const String lessonPath = '/teacher/lessons/lesson-1/view';
      expect(
        redirectForStaffSession(
          SessionTeacher(_profile(ProfileRole.teacher)),
          lessonPath,
        ),
        isNull,
      );
      expect(
        redirectForStaffSession(
          SessionAdmin(_profile(ProfileRole.admin)),
          lessonPath,
        ),
        AppRoutes.adminHome,
      );
      expect(
        redirectForStaffSession(const SessionNone(), lessonPath),
        AppRoutes.login,
      );
      expect(
        AppRoutes.teacherLessonViewPath('lesson 1'),
        '/teacher/lessons/lesson%201/view',
      );
    });

    test('recovery sessions cannot enter Teacher or Admin workspaces', () {
      for (final SessionState session in <SessionState>[
        SessionTeacher(_profile(ProfileRole.teacher)),
        SessionAdmin(_profile(ProfileRole.admin)),
      ]) {
        expect(
          redirectForStaffSession(
            session,
            AppRoutes.teacherHome,
            recoveryStatus: PasswordRecoveryStatus.valid,
          ),
          AppRoutes.resetPassword,
        );
        expect(
          redirectForStaffSession(
            session,
            AppRoutes.resetPassword,
            recoveryStatus: PasswordRecoveryStatus.valid,
          ),
          isNull,
        );
      }
    });

    test('pending Teacher remains pending after recovery completion', () {
      expect(
        redirectForStaffSession(
          SessionTeacher(
            _profile(ProfileRole.teacher, status: ProfileStatus.pending),
          ),
          AppRoutes.login,
          recoveryStatus: PasswordRecoveryStatus.completed,
        ),
        AppRoutes.pendingApproval,
      );
    });

    test('approved Teacher and Admin retain their normal role routes', () {
      expect(
        redirectForStaffSession(
          SessionTeacher(_profile(ProfileRole.teacher)),
          AppRoutes.login,
          recoveryStatus: PasswordRecoveryStatus.completed,
        ),
        AppRoutes.teacherHome,
      );
      expect(
        redirectForStaffSession(
          SessionAdmin(_profile(ProfileRole.admin)),
          AppRoutes.login,
          recoveryStatus: PasswordRecoveryStatus.completed,
        ),
        AppRoutes.adminHome,
      );
    });

    test('approved staff cannot remain trapped on Unauthorized', () {
      expect(
        redirectForStaffSession(
          SessionTeacher(_profile(ProfileRole.teacher)),
          AppRoutes.unauthorized,
        ),
        AppRoutes.teacherHome,
      );
      expect(
        redirectForStaffSession(
          SessionAdmin(_profile(ProfileRole.admin)),
          AppRoutes.unauthorized,
        ),
        AppRoutes.adminHome,
      );
    });

    test('disabled Teacher accounts remain Unauthorized', () {
      for (final ProfileStatus status in <ProfileStatus>[
        ProfileStatus.rejected,
        ProfileStatus.suspended,
        ProfileStatus.archived,
      ]) {
        expect(
          redirectForStaffSession(
            SessionTeacher(_profile(ProfileRole.teacher, status: status)),
            AppRoutes.teacherHome,
          ),
          AppRoutes.unauthorized,
        );
        expect(
          redirectForStaffSession(
            SessionTeacher(_profile(ProfileRole.teacher, status: status)),
            AppRoutes.unauthorized,
          ),
          isNull,
        );
      }
    });
  });
}

Profile _profile(
  ProfileRole role, {
  ProfileStatus status = ProfileStatus.approved,
}) {
  final DateTime timestamp = DateTime.utc(2026);
  return Profile(
    id: '${role.name}-id',
    role: role,
    status: status,
    fullName: role.name,
    email: '${role.name}@example.com',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
