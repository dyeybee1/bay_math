import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/core/providers/password_recovery_provider.dart';

void main() {
  group('password recovery callback classification', () {
    test('accepts a Supabase implicit recovery callback with a session', () {
      final PasswordRecoveryStatus status =
          passwordRecoveryStatusFromInitialUri(
            Uri.parse(
              'https://staff.example/reset-password#access_token=secret&'
              'refresh_token=secret&type=recovery',
            ),
            hasSessionAfterSupabaseInitialization: true,
          );

      expect(status, PasswordRecoveryStatus.valid);
    });

    test('rejects expired and invalid callbacks without exposing details', () {
      for (final Uri uri in <Uri>[
        Uri.parse(
          'https://staff.example/reset-password#error=access_denied&'
          'error_code=otp_expired',
        ),
        Uri.parse('https://staff.example/reset-password#type=recovery'),
        Uri.parse('https://staff.example/reset-password'),
      ]) {
        expect(
          passwordRecoveryStatusFromInitialUri(
            uri,
            hasSessionAfterSupabaseInitialization: false,
          ),
          PasswordRecoveryStatus.invalid,
        );
      }
    });

    test('ignores recovery-looking fragments on every other route', () {
      expect(
        passwordRecoveryStatusFromInitialUri(
          Uri.parse(
            'https://staff.example/teacher#access_token=secret&'
            'refresh_token=secret&type=recovery',
          ),
          hasSessionAfterSupabaseInitialization: true,
        ),
        PasswordRecoveryStatus.none,
      );
    });
  });
}
