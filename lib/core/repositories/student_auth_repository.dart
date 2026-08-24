import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../models/student_session.dart';

/// Student login (Phase 4 architecture §2/§6). Students are never
/// `auth.users` rows — this calls the `student-login` Edge Function, which
/// verifies credentials via `app.verify_student_credentials` (service_role
/// only, 0017) and mints a custom-signed JWT. This is the only class that
/// talks to that Edge Function; screens go through this repository, the
/// same convention every other repository in this app follows.
class StudentAuthRepository {
  const StudentAuthRepository(this._client);

  final SupabaseClient _client;

  /// Response contract (fixed by the frozen architecture doc, not to be
  /// altered): `200 {access_token, expires_at}` on success, `401
  /// {code, message}` on failure. `student_id` is read back out of the
  /// token's own claims here, for display purposes only — never used for
  /// any auth decision.
  Future<StudentSession> signIn({required String username, required String password}) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'student-login',
        body: <String, dynamic>{'username': username, 'password': password},
      );

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final String accessToken = data['access_token'] as String;
      final int expiresAtEpochSeconds = data['expires_at'] as int;

      final Map<String, dynamic> claims = _decodeJwtPayload(accessToken);
      final Object? studentId = claims['student_id'];
      if (studentId is! String) {
        throw const ServerFailure('Received a session token with no student_id claim.');
      }

      return StudentSession(
        accessToken: accessToken,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtEpochSeconds * 1000, isUtc: true),
        studentId: studentId,
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Decodes a JWT's payload segment without verifying its signature —
  /// safe here only because this is our own just-minted token being read
  /// back immediately, not a token being trusted for an auth decision.
  Map<String, dynamic> _decodeJwtPayload(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      throw const ServerFailure('Received a malformed session token.');
    }
    final String normalized = base64Url.normalize(parts[1]);
    final Object? decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (decoded is! Map<String, dynamic>) {
      throw const ServerFailure('Received a malformed session token.');
    }
    return decoded;
  }
}
