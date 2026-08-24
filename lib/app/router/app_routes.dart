/// Centralized route path constants.
///
/// Phase 1 scope: Teacher/Admin auth + app shell. Student routes are
/// reserved for Phase 3+ and are not added here yet — adding them then is a
/// pure addition, not a change to anything below.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';

  // --- Auth (Teacher/Admin — Supabase Auth) ---
  static const String login = '/login';
  static const String register = '/register';
  static const String pendingApproval = '/pending-approval';

  // --- App shells ---
  static const String teacherHome = '/teacher';
  static const String adminHome = '/admin';

  // --- Student (custom-JWT, not Supabase Auth — Phase 4 §2/§6) ---
  // Deliberately NOT gated by the sessionProvider redirect switch in
  // app_router.dart (that switch tracks Supabase Auth's own
  // Teacher/Admin session; a student session is a separate, in-memory-only
  // concept for now — see student_session_provider.dart). Reachable
  // directly, proof-of-concept only, per the phase's own scope note.
  static const String studentLogin = '/student-login';
  static const String studentHome = '/student-home';

  // First-login avatar picker (0053_student_avatar.sql). Reached only from
  // StudentLoginScreen, right after a successful sign-in, when the
  // student's `avatar_id` is still NULL — never linked to from anywhere
  // else. A real GoRouter path (not a bare Navigator.push) so it survives
  // a page refresh on web mid-pick, same reasoning as studentStatistics.
  static const String studentAvatarSelect = '/student-avatar-select';

  // Phase 6 (Quiz-Taking). Quiz-taking/results screens are pushed via
  // Navigator with a Quiz/attemptId argument, exactly like every other
  // detail screen in this project (e.g. teacher's quizzes_screen.dart) —
  // no path params are used anywhere in this codebase, so this is the only
  // new GoRouter path Phase 6 needs.
  static const String studentQuizzes = '/student-quizzes';

  // Guided-lesson-viewer feature. Same reasoning as studentQuizzes above:
  // a lessons LIST screen is a real GoRouter path (reached from the
  // Student home screen), but the guided-mode PageView viewer itself is
  // pushed via Navigator with a Lesson argument, exactly like
  // QuizTakingScreen — no path param is used anywhere in this codebase.
  static const String studentLessons = '/student-lessons';

  // Phase 8 (Student Statistics). Same reasoning as studentLessons/
  // studentQuizzes above: this is a list-style landing screen reached from
  // the Student home screen (not a detail/viewer screen pushed with an
  // argument), so it gets a real GoRouter path rather than a bare
  // Navigator.push.
  static const String studentStatistics = '/student-statistics';

  // --- Errors ---
  static const String unauthorized = '/unauthorized';

  /// Not a routable path — used as the go_router `errorBuilder` fallback
  /// for unmatched routes (see app_router.dart).
  static const String notFoundName = 'not-found';

  /// Development-only route previewing the reusable widget library
  /// (Phase 0.75A). Excluded from release builds — see app_router.dart.
  static const String devComponentGallery = '/dev/components';
}
