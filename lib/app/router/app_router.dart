import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/component_gallery/component_gallery_screen.dart';
import '../../features/auth_placeholder/presentation/login_placeholder_screen.dart';
import '../../features/error/presentation/not_found_screen.dart';
import '../../features/error/presentation/unauthorized_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';

/// Exposes the app's [GoRouter] instance as a Riverpod provider so it can
/// be read from `app.dart` (and swapped/overridden in tests later).
///
/// Phase 0 scope: static placeholder routes only. No redirect/auth guard
/// logic — that depends on an auth system that doesn't exist yet.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.loginPlaceholder,
        builder: (context, state) => const LoginPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.unauthorizedPlaceholder,
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      // Development-only: previews the reusable widget library. Never
      // registered in release builds, so it cannot ship to a production
      // tablet/desktop build even if left in place.
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.devComponentGallery,
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
});
