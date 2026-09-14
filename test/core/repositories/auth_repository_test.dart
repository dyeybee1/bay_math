import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/repositories/auth_repository.dart';

void main() {
  final AuthRepository repository = AuthRepository(
    SupabaseClient(
      'http://localhost',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );

  test(
    'rejects invalid registration data before making an Auth request',
    () async {
      await expectLater(
        repository.signUpTeacher(
          email: 'teacher@school.edu',
          password: 'Password1!',
          fullName: "Robert'); DROP TABLE users;--",
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure failure) => failure.message,
            'message',
            contains('Name'),
          ),
        ),
      );

      await expectLater(
        repository.signUpTeacher(
          email: "' OR '1'='1",
          password: 'Password1!',
          fullName: 'Juan Dela Cruz',
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure failure) => failure.message,
            'message',
            contains('email'),
          ),
        ),
      );

      await expectLater(
        repository.signUpTeacher(
          email: 'teacher@school.edu',
          password: 'password',
          fullName: 'Juan Dela Cruz',
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure failure) => failure.message,
            'message',
            contains('requirement'),
          ),
        ),
      );
    },
  );

  test('validates recovery requests before calling Supabase Auth', () async {
    await expectLater(
      repository.requestPasswordReset(
        email: 'not-an-email',
        redirectTo: 'https://staff.example/reset-password',
      ),
      throwsA(isA<ValidationFailure>()),
    );
    await expectLater(
      repository.requestPasswordReset(
        email: 'teacher@school.edu',
        redirectTo: 'baymath://reset-password',
      ),
      throwsA(isA<ServerFailure>()),
    );
    await expectLater(
      repository.requestPasswordReset(
        email: 'teacher@school.edu',
        redirectTo: 'https://staff.example/another-path',
      ),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('rejects weak recovered passwords before requiring a session', () async {
    await expectLater(
      repository.updateRecoveredPassword('password'),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
