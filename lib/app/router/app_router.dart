import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/profile.dart';
import '../../core/providers/session_provider.dart';
import '../../dev/component_gallery/component_gallery_screen.dart';
import '../../features/admin/presentation/admin_shell_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/error/presentation/not_found_screen.dart';
import '../../features/error/presentation/unauthorized_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/student/presentation/student_avatar_select_screen.dart';
import '../../features/student/presentation/student_home_screen.dart';
import '../../features/student/presentation/student_lessons_screen.dart';
import '../../features/student/presentation/student_login_screen.dart';
import '../../features/student/presentation/student_quizzes_screen.dart';
import '../../features/student/presentation/student_statistics_screen.dart';
import '../../features/teacher/presentation/teacher_shell_screen.dart';
import 'app_routes.dart';
import 'router_refresh_listenable.dart';

/// Exposes the app's [GoRouter] instance as a Riverpod provider.
///
/// Phase 1 scope: real Teacher/Admin auth-based redirects (Phase 4.1
/// architecture §3 — this IS the "one place every redirect flows through"
/// the GoRouter + Riverpod refresh architecture calls for). Student routes
/// are not added yet (Phase 3+).
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final RouterRefreshListenable refreshListenable = ref.watch(
    routerRefreshListenableProvider,
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) => _redirect(ref, state),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.pendingApproval,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherHome,
        builder: (context, state) => const TeacherShellScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (context, state) => const AdminShellScreen(),
      ),
      GoRoute(
        path: AppRoutes.unauthorized,
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      // Phase 4 login proof-of-concept — see the note on these constants in
      // app_routes.dart: intentionally not part of the Teacher/Admin
      // redirect switch below.
      GoRoute(
        path: AppRoutes.studentLogin,
        builder: (context, state) => const StudentLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) => const StudentHomeScreen(),
      ),
      // First-login avatar picker — same "outside the Teacher/Admin
      // redirect" scope note as the two routes above.
      GoRoute(
        path: AppRoutes.studentAvatarSelect,
        builder: (context, state) => const StudentAvatarSelectScreen(),
      ),
      // Phase 6 — same "outside the Teacher/Admin redirect" scope note as
      // the two routes above applies here too.
      GoRoute(
        path: AppRoutes.studentQuizzes,
        builder: (context, state) => const StudentQuizzesScreen(),
      ),
      // Guided-lesson-viewer feature — same scope note as above.
      GoRoute(
        path: AppRoutes.studentLessons,
        builder: (context, state) => const StudentLessonsScreen(),
      ),
      // Phase 8 (Student Statistics) — same scope note as above.
      GoRoute(
        path: AppRoutes.studentStatistics,
        builder: (context, state) => const StudentStatisticsScreen(),
      ),
      // Development-only: previews the reusable widget library. Never
      // registered in release builds (Phase 0.75A).
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.devComponentGallery,
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
});

/// The single redirect function every navigation in the app passes through.
/// Reads (not watches) [sessionProvider] — freshness is guaranteed by
/// [RouterRefreshListenable] triggering a re-evaluation whenever the
/// provider's state actually changes, not by this function itself
/// depending on it reactively.
String? _redirect(Ref ref, GoRouterState state) {
  final String location = state.matchedLocation;

  // Phase 4 login proof-of-concept: student routes are deliberately outside
  // the Teacher/Admin redirect entirely (see the note on these constants in
  // app_routes.dart) — a student session is a separate, non-Supabase-Auth
  // concept for now, so it must not be evaluated against `sessionProvider`
  // at all (a SessionNone visitor, the normal case here, would otherwise be
  // bounced to /login before ever reaching /student-login).
  if (location == AppRoutes.studentLogin ||
      location == AppRoutes.studentHome ||
      location == AppRoutes.studentAvatarSelect ||
      location == AppRoutes.studentQuizzes ||
      location == AppRoutes.studentLessons ||
      location == AppRoutes.studentStatistics) {
    return null;
  }

  final AsyncValue<SessionState> asyncSession = ref.read(sessionProvider);

  return asyncSession.when(
    // Still resolving the restored session (app startup) — stay on splash,
    // which is the initial location, and don't fight it with a redirect.
    loading: () => null,
    // Resolution itself failed (e.g. SessionExpiredFailure via markExpired)
    // — the Unified Session-Expiration Policy's outcome: back to login.
    error: (_, _) => location == AppRoutes.login ? null : AppRoutes.login,
    data: (session) => _redirectForSession(session, location),
  );
}

String? _redirectForSession(SessionState session, String location) {
  final bool atSplash = location == AppRoutes.splash;
  final bool atAuthRoute =
      location == AppRoutes.login || location == AppRoutes.register;

  switch (session) {
    case SessionNone _:
      return atAuthRoute ? null : AppRoutes.login;

    case final SessionTeacher teacher:
      switch (teacher.profile.status) {
        case ProfileStatus.pending:
          return location == AppRoutes.pendingApproval
              ? null
              : AppRoutes.pendingApproval;
        case ProfileStatus.approved:
          return (atAuthRoute ||
                  atSplash ||
                  location == AppRoutes.pendingApproval)
              ? AppRoutes.teacherHome
              : null;
        case ProfileStatus.rejected:
        case ProfileStatus.suspended:
        case ProfileStatus.archived:
          return location == AppRoutes.unauthorized
              ? null
              : AppRoutes.unauthorized;
      }

    case SessionAdmin _:
      return (atAuthRoute || atSplash) ? AppRoutes.adminHome : null;

    case SessionStudent _:
      // Not reachable until Phase 3 implements student login.
      return null;
  }
}
