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
import 'package:instructional_math_app/features/auth/presentation/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher registration presentation', () {
    testWidgets('fits representative desktop and laptop viewports', (
      WidgetTester tester,
    ) async {
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
        await tester.pumpWidget(_testApp(_FakeAuthRepository()));
        await tester.pumpAndSettle();

        expect(find.text('Create your teacher account'), findsOneWidget);
        expect(
          find.byKey(const Key('register_full_name_field')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('register_email_field')), findsOneWidget);
        expect(
          find.byKey(const Key('register_password_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('register_confirm_password_field')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
        expect(
          find.textContaining('Administrator must approve'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('supports focus, both visibility controls, and mismatch', (
      WidgetTester tester,
    ) async {
      _setDesktopViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register_full_name_field')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode
            ?.hasFocus,
        isTrue,
      );

      await _fillForm(tester, confirmation: 'Different2!');
      expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).obscureText,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(3)).obscureText,
        isTrue,
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_password_visibility')),
      );
      await tester.tap(find.byKey(const Key('register_password_visibility')));
      await tester.ensureVisible(
        find.byKey(const Key('register_confirmation_visibility')),
      );
      await tester.tap(
        find.byKey(const Key('register_confirmation_visibility')),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).obscureText,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(3)).obscureText,
        isFalse,
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(authRepository.signUpCalls, 0);
    });

    testWidgets('shows field-level required and password validation', (
      WidgetTester tester,
    ) async {
      _setDesktopViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('register_full_name_field')),
        'Ada Teacher',
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'ada@baymath.test',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'short',
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password_field')),
        'short',
      );
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();
      expect(
        find.text('Use a password that meets every requirement below.'),
        findsOneWidget,
      );
      expect(authRepository.signUpCalls, 0);
    });

    testWidgets('rejects invalid names and malformed emails before signup', (
      WidgetTester tester,
    ) async {
      _setDesktopViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();

      await _fillForm(tester, fullName: 'Robert123', email: "' OR '1'='1");
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(
        find.text('Name must contain letters and cannot contain numbers.'),
        findsOneWidget,
      );
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(authRepository.signUpCalls, 0);
    });

    testWidgets('updates every password requirement while typing', (
      WidgetTester tester,
    ) async {
      _setDesktopViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp(_FakeAuthRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'Password1!',
      );
      await tester.pump();

      for (final String key in <String>[
        'password_requirement_length',
        'password_requirement_uppercase',
        'password_requirement_lowercase',
        'password_requirement_number',
        'password_requirement_special',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byIcon(Icons.check_circle_rounded),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('submits once, disables fields, and preserves server errors', (
      WidgetTester tester,
    ) async {
      _setDesktopViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();
      await _fillForm(
        tester,
        fullName: '  Ada Teacher  ',
        email: '  Ada@BayMath.Test  ',
      );

      await tester.tap(
        find.byKey(const Key('register_confirm_password_field')),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));

      expect(authRepository.signUpCalls, 1);
      expect(authRepository.lastFullName, 'Ada Teacher');
      expect(authRepository.lastEmail, 'ada@baymath.test');
      expect(find.text('Creating account…'), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((TextField field) => field.enabled == false),
        isTrue,
      );

      authRepository.completeWith(
        const ValidationFailure('An account with this email already exists.'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
      expect(find.text('Create teacher account'), findsOneWidget);
    });

    testWidgets('shows safe network failure and restores the submit button', (
      WidgetTester tester,
    ) async {
      _setDesktopViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(authRepository));
      await tester.pumpAndSettle();
      await _fillForm(tester);

      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();
      authRepository.completeWith(const NetworkFailure());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not create the account. Check your internet connection and '
          'try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create teacher account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
}

Future<void> _fillForm(
  WidgetTester tester, {
  String fullName = 'Ada Teacher',
  String email = 'ada@baymath.test',
  String password = 'Password1!',
  String confirmation = 'Password1!',
}) async {
  await tester.enterText(
    find.byKey(const Key('register_full_name_field')),
    fullName,
  );
  await tester.enterText(find.byKey(const Key('register_email_field')), email);
  await tester.enterText(
    find.byKey(const Key('register_password_field')),
    password,
  );
  await tester.enterText(
    find.byKey(const Key('register_confirm_password_field')),
    confirmation,
  );
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
      home: const RegisterScreen(),
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

  final Completer<void> _signUpCompleter = Completer<void>();
  int signUpCalls = 0;
  String? lastFullName;
  String? lastEmail;

  @override
  Future<void> signUpTeacher({
    required String email,
    required String password,
    required String fullName,
  }) {
    signUpCalls += 1;
    lastFullName = fullName;
    lastEmail = email;
    return _signUpCompleter.future;
  }

  void completeWith(AppFailure failure) {
    _signUpCompleter.completeError(failure);
  }
}
