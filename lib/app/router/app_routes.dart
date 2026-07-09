/// Centralized route path constants.
///
/// Phase 0 only defines placeholder routes. No business screens
/// (dashboards, lessons, quizzes, etc.) are added here yet.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String loginPlaceholder = '/login';
  static const String unauthorizedPlaceholder = '/unauthorized';

  /// Development-only route previewing the reusable widget library.
  /// Excluded from release builds — see `app_router.dart`.
  static const String devComponentGallery = '/dev/components';

  // Not a routable path — used as the go_router `errorBuilder` fallback
  // for unmatched routes (see app_router.dart).
  static const String notFoundName = 'not-found';
}
