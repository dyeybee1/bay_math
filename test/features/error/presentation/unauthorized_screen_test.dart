import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/features/error/presentation/unauthorized_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs out and replaces Unauthorized with staff login', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [sessionProvider.overrideWith(_TestSessionNotifier.new)],
    );
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.unauthorized,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.unauthorized,
          builder: (_, _) => const UnauthorizedScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('Staff login')),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsNWidgets(2));
    expect(find.text('Sign Out and Return to Login'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unauthorized_sign_out_button')));
    await tester.pumpAndSettle();

    final _TestSessionNotifier notifier =
        container.read(sessionProvider.notifier) as _TestSessionNotifier;
    expect(notifier.signOutCalls, 1);
    expect(find.text('Staff login'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(router.canPop(), isFalse);
  });
}

class _TestSessionNotifier extends SessionNotifier {
  int signOutCalls = 0;

  @override
  Future<SessionState> build() async => const SessionNone();

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    state = const AsyncValue<SessionState>.data(SessionNone());
  }
}
