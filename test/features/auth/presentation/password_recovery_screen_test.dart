import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/providers/password_recovery_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/auth_repository.dart';
import 'package:instructional_math_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:instructional_math_app/features/auth/presentation/reset_password_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Forgot Password', () {
    testWidgets('rejects malformed email before requesting a reset', (
      WidgetTester tester,
    ) async {
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository();
      await tester.pumpWidget(_forgotApp(repository));

      await tester.enterText(
        find.byKey(const Key('forgot_email_field')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repository.resetRequestCalls, 0);
    });

    testWidgets('uses the generic success message for every accepted request', (
      WidgetTester tester,
    ) async {
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository();
      await tester.pumpWidget(_forgotApp(repository));

      await tester.enterText(
        find.byKey(const Key('forgot_email_field')),
        'unknown@school.edu',
      );
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pumpAndSettle();

      expect(repository.resetRequestCalls, 1);
      expect(
        repository.lastRedirectUrl,
        'https://staff.example/reset-password',
      );
      expect(find.text(passwordResetRequestSuccessMessage), findsOneWidget);
      expect(find.textContaining('unknown@school.edu'), findsNothing);
    });

    testWidgets('prevents duplicate requests while one is in flight', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository(resetCompleter: completer);
      await tester.pumpWidget(_forgotApp(repository));
      await tester.enterText(
        find.byKey(const Key('forgot_email_field')),
        'teacher@school.edu',
      );

      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pump();
      expect(repository.resetRequestCalls, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows a safe rate-limit error', (WidgetTester tester) async {
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository(resetFailure: const RateLimitFailure());
      await tester.pumpWidget(_forgotApp(repository));
      await tester.enterText(
        find.byKey(const Key('forgot_email_field')),
        'teacher@school.edu',
      );

      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text(const RateLimitFailure().message), findsOneWidget);
    });
  });

  group('Reset Password', () {
    testWidgets('shows one safe result for invalid or expired links', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _resetApp(
          _FakeRecoveryAuthRepository(),
          PasswordRecoveryStatus.invalid,
        ),
      );

      expect(find.byKey(const Key('reset_invalid_view')), findsOneWidget);
      expect(find.text(const RecoveryLinkFailure().message), findsOneWidget);
      expect(find.byKey(const Key('reset_password_field')), findsNothing);
    });

    testWidgets('enforces registration password rules and live indicators', (
      WidgetTester tester,
    ) async {
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository();
      await tester.pumpWidget(
        _resetApp(repository, PasswordRecoveryStatus.valid),
      );

      await tester.enterText(
        find.byKey(const Key('reset_password_field')),
        'password',
      );
      await tester.pump();
      expect(
        find.byKey(const Key('reset_password_requirement_lowercase')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('reset_submit_button')));
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await tester.pump();

      expect(
        find.text('Use a password that meets every requirement below.'),
        findsOneWidget,
      );
      expect(repository.updateCalls, 0);
    });

    testWidgets('rejects a password confirmation mismatch', (
      WidgetTester tester,
    ) async {
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository();
      await tester.pumpWidget(
        _resetApp(repository, PasswordRecoveryStatus.valid),
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_field')),
        'Password1!',
      );
      await tester.enterText(
        find.byKey(const Key('reset_confirm_password_field')),
        'Password2!',
      );

      await tester.ensureVisible(find.byKey(const Key('reset_submit_button')));
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(repository.updateCalls, 0);
    });

    testWidgets('updates once, signs out locally, and shows desktop guidance', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final _FakeRecoveryAuthRepository repository =
          _FakeRecoveryAuthRepository(updateCompleter: completer);
      await tester.pumpWidget(
        _resetApp(repository, PasswordRecoveryStatus.valid),
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_field')),
        'Password1!',
      );
      await tester.enterText(
        find.byKey(const Key('reset_confirm_password_field')),
        'Password1!',
      );

      await tester.ensureVisible(find.byKey(const Key('reset_submit_button')));
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await tester.pump();
      expect(repository.updateCalls, 1);

      completer.complete();
      await tester.pumpAndSettle();
      expect(repository.endSessionCalls, 1);
      expect(find.byKey(const Key('reset_success_view')), findsOneWidget);
      expect(
        find.textContaining('Return to the BayMath desktop app'),
        findsOneWidget,
      );
    });
  });
}

Widget _forgotApp(_FakeRecoveryAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const ForgotPasswordScreen(
        redirectUrl: 'https://staff.example/reset-password',
      ),
    ),
  );
}

Widget _resetApp(
  _FakeRecoveryAuthRepository repository,
  PasswordRecoveryStatus status,
) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      passwordRecoveryBootstrapProvider.overrideWithValue(status),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const ResetPasswordScreen(),
    ),
  );
}

class _FakeRecoveryAuthRepository extends AuthRepository {
  _FakeRecoveryAuthRepository({
    this.resetFailure,
    this.resetCompleter,
    this.updateCompleter,
  }) : super(
         SupabaseClient(
           'http://localhost',
           'test-anon-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
       );

  final AppFailure? resetFailure;
  final Completer<void>? resetCompleter;
  final Completer<void>? updateCompleter;
  int resetRequestCalls = 0;
  int updateCalls = 0;
  int endSessionCalls = 0;
  String? lastRedirectUrl;

  @override
  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) async {
    resetRequestCalls += 1;
    lastRedirectUrl = redirectTo;
    final AppFailure? failure = resetFailure;
    if (failure != null) throw failure;
    await (resetCompleter?.future ?? Future<void>.value());
  }

  @override
  Future<void> updateRecoveredPassword(String password) async {
    updateCalls += 1;
    await (updateCompleter?.future ?? Future<void>.value());
  }

  @override
  Future<void> endRecoverySession() async {
    endSessionCalls += 1;
  }
}
