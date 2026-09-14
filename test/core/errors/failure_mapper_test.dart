import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/errors/failure_mapper.dart';

void main() {
  test('maps an existing Auth email to the safe registration message', () {
    final AppFailure failure = mapExceptionToFailure(
      const AuthException('User already registered'),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'An account with this email already exists.');
  });

  test('does not expose unexpected Auth details', () {
    final AppFailure failure = mapExceptionToFailure(
      const AuthException('Database error: public.profiles constraint_name'),
    );

    expect(failure, isA<ServerFailure>());
    expect(failure.message, 'Something went wrong. Please try again.');
    expect(failure.message, isNot(contains('profiles')));
  });

  test('maps Supabase weak-password responses without raw details', () {
    final AppFailure failure = mapExceptionToFailure(
      AuthWeakPasswordException(
        message: 'Password should contain a character from: raw-policy-data',
        statusCode: '422',
        reasons: const <String>['characters'],
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'Use a password that meets every security requirement.',
    );
    expect(failure.message, isNot(contains('raw-policy-data')));
  });

  test('maps rate limits and retryable network failures safely', () {
    expect(
      mapExceptionToFailure(
        const AuthApiException(
          'raw limit detail',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      isA<RateLimitFailure>(),
    );
    expect(
      mapExceptionToFailure(AuthRetryableFetchException()),
      isA<NetworkFailure>(),
    );
  });

  test('maps a missing recovery session without raw details', () {
    final AppFailure failure = mapExceptionToFailure(
      AuthSessionMissingException('raw session detail'),
    );

    expect(failure, isA<RecoveryLinkFailure>());
    expect(failure.message, isNot(contains('raw session detail')));
  });

  test('maps a reused password to actionable validation', () {
    final AppFailure failure = mapExceptionToFailure(
      const AuthApiException(
        'raw same-password detail',
        statusCode: '422',
        code: 'same_password',
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'Choose a password different from your current password.',
    );
  });

  test('does not expose unexpected PostgREST details', () {
    final AppFailure failure = mapExceptionToFailure(
      const PostgrestException(
        message: 'relation public.profiles failed',
        code: 'XX000',
        details: 'internal SQL details',
      ),
    );

    expect(failure, isA<ServerFailure>());
    expect(failure.message, 'Something went wrong. Please try again.');
    expect(failure.message, isNot(contains('profiles')));
  });

  test('debug logging includes complete PostgREST diagnostics', () {
    final DebugPrintCallback originalDebugPrint = debugPrint;
    final List<String> messages = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    final AppFailure failure = mapExceptionToFailure(
      const PostgrestException(
        message:
            'update or delete on table "quizzes" violates foreign key constraint',
        code: '23503',
        details: 'Key is still referenced from table "quiz_attempts".',
        hint: 'Preserve historical attempts.',
      ),
    );

    expect(failure, isA<ServerFailure>());
    final String log = messages.join('\n');
    expect(log, contains('code=23503'));
    expect(log, contains('message=update or delete on table "quizzes"'));
    expect(log, contains('details=Key is still referenced'));
    expect(log, contains('hint=Preserve historical attempts.'));
  });
}
