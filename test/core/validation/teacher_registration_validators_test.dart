import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/core/validation/teacher_registration_validators.dart';

void main() {
  group('TeacherRegistrationValidators.validateName', () {
    test('accepts legitimate human names', () {
      expect(
        TeacherRegistrationValidators.validateName('Juan Dela Cruz'),
        isNull,
      );
      expect(
        TeacherRegistrationValidators.validateName("Anne-Marie O'Connor"),
        isNull,
      );
      expect(
        TeacherRegistrationValidators.validateName('Anne-Marie O\u2019Connor'),
        isNull,
      );
      expect(
        TeacherRegistrationValidators.validateName('María Santos'),
        isNull,
      );
      expect(TeacherRegistrationValidators.validateName('李 明'), isNull);
    });

    test('rejects digits, symbols, repeated spaces, and blank input', () {
      for (final String name in <String>[
        '12345',
        'Juan123',
        '123 Santos',
        '@#%^',
        'Juan  Santos',
        '   ',
        "Robert'); DROP TABLE users;--",
      ]) {
        expect(
          TeacherRegistrationValidators.validateName(name),
          isNotNull,
          reason: name,
        );
      }
    });

    test('rejects names beyond the configured maximum', () {
      expect(
        TeacherRegistrationValidators.validateName(
          'A' * (TeacherRegistrationValidators.nameMaxLength + 1),
        ),
        contains('characters or fewer'),
      );
    });
  });

  group('TeacherRegistrationValidators.validateEmail', () {
    test('accepts normal email and normalizes case and whitespace', () {
      expect(
        TeacherRegistrationValidators.validateEmail(' Teacher@School.EDU '),
        isNull,
      );
      expect(
        TeacherRegistrationValidators.normalizeEmail(' Teacher@School.EDU '),
        'teacher@school.edu',
      );
    });

    test('rejects malformed and malicious-looking values', () {
      for (final String email in <String>[
        '',
        'teacher',
        'teacher@',
        '@school.edu',
        'teacher@@school.edu',
        'teacher.@school.edu',
        'teacher@school-.edu',
        'teacher@school.com;DROP',
        "' OR '1'='1",
      ]) {
        expect(
          TeacherRegistrationValidators.validateEmail(email),
          isNotNull,
          reason: email,
        );
      }
    });

    test('rejects emails beyond the configured maximum', () {
      final String email =
          '${'a' * TeacherRegistrationValidators.emailMaxLength}@test.com';
      expect(
        TeacherRegistrationValidators.validateEmail(email),
        contains('characters or fewer'),
      );
    });
  });

  group('TeacherRegistrationValidators.validatePassword', () {
    test('enforces every independent password requirement', () {
      expect(
        TeacherRegistrationValidators.validatePassword('password'),
        isNotNull,
      );
      expect(
        TeacherRegistrationValidators.validatePassword('Password'),
        isNotNull,
      );
      expect(
        TeacherRegistrationValidators.validatePassword('Password1'),
        isNotNull,
      );
      expect(
        TeacherRegistrationValidators.validatePassword('Password!'),
        isNotNull,
      );
      expect(
        TeacherRegistrationValidators.validatePassword('Pass1!'),
        isNotNull,
      );
      expect(
        TeacherRegistrationValidators.validatePassword('Password1!'),
        isNull,
      );
    });
  });

  test('confirm password is required and must match exactly', () {
    expect(
      TeacherRegistrationValidators.validateConfirmPassword('', 'Password1!'),
      'Confirm your password.',
    );
    expect(
      TeacherRegistrationValidators.validateConfirmPassword(
        'Password2!',
        'Password1!',
      ),
      'Passwords do not match.',
    );
    expect(
      TeacherRegistrationValidators.validateConfirmPassword(
        'Password1!',
        'Password1!',
      ),
      isNull,
    );
  });
}
