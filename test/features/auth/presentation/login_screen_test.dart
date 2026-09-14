import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/providers/session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/auth_repository.dart';
import 'package:instructional_math_app/features/auth/presentation/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher and Administrator login presentation', () {
    testWidgets('fits representative desktop and laptop viewports', (
      WidgetTester tester,
    ) async {
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final Size size in <Size>[
        const Size(1024, 700),
        const Size(1280, 720),
        const Size(1366, 768),
        const Size(1440, 900),
        const Size(1920, 1080),
        const Size(800, 700),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(_testApp(authRepository));
        await tester.pumpAndSettle();

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.byKey(const Key('login_email_field')), findsOneWidget);
        expect(find.byKey(const Key('login_password_field')), findsOneWidget);
        expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
        expect(
          find.byKey(const Key('login_forgot_password_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('login_registration_button')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('supports focus, password visibility, and empty validation', (
      WidgetTester tester,
    ) async {
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_email_field')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode
            ?.hasFocus,
        isTrue,
      );

      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'baymath-password',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('login_password_visibility')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('login_password_field')));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Enter your email and password.'), findsOneWidget);
      expect(authRepository.signInCalls, 0);
    });

    testWidgets('submits once, disables the form, and preserves auth errors', (
      WidgetTester tester,
    ) async {
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'teacher@baymath.test',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'baymath-password',
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
      await tester.tap(find.byKey(const Key('login_submit_button')));

      expect(authRepository.signInCalls, 1);
      expect(authRepository.lastEmail, 'teacher@baymath.test');
      expect(find.text('Signing in…'), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((TextField field) => field.enabled == false),
        isTrue,
      );

      authRepository.completeWith(
        const ValidationFailure('Email or password is incorrect.'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.text('Sign in to workspace'), findsOneWidget);
    });
  });
}

Widget _testApp(_FakeAuthRepository authRepository) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      sessionProvider.overrideWith(_TestSessionNotifier.new),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    ),
  );
}

class _TestSessionNotifier extends SessionNotifier {
  @override
  Future<SessionState> build() async => const SessionNone();
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Completer<void> _signInCompleter = Completer<void>();
  int signInCalls = 0;
  String? lastEmail;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) {
    signInCalls += 1;
    lastEmail = email;
    return _signInCompleter.future;
  }

  void completeWith(AppFailure failure) {
    _signInCompleter.completeError(failure);
  }
}
