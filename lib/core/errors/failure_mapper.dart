import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// The single place raw Supabase/network exceptions are translated into
/// [AppFailure]. Every repository funnels its `catch` blocks through this,
/// so the mapping logic exists in exactly one place.
AppFailure mapExceptionToFailure(Object error) {
  if (error is AppFailure) return error;

  _logExceptionForDebugging(error);

  if (error is AuthException) return _mapAuthException(error);
  if (error is PostgrestException) return _mapPostgrestException(error);
  if (error is FunctionException) return _mapFunctionException(error);
  if (error is SocketException) return const NetworkFailure();

  return const ServerFailure();
}

/// Records enough information to diagnose transport failures in development
/// without logging request bodies, credentials, tokens, or server responses.
void _logExceptionForDebugging(Object error) {
  if (!kDebugMode) return;

  if (error is PostgrestException) {
    debugPrint(
      '[BayMath] PostgREST request failed: '
      'code=${error.code}; '
      'message=${error.message}; '
      'details=${error.details}; '
      'hint=${error.hint}',
    );
    return;
  }

  if (error is SocketException) {
    final OSError? osError = error.osError;
    final String osDetails =
        osError == null
            ? ''
            : ' (${osError.message}, OS code ${osError.errorCode})';
    debugPrint(
      '[BayMath] Network request failed: ${error.runtimeType}$osDetails',
    );
    return;
  }

  debugPrint('[BayMath] Request failed: ${error.runtimeType}');
}

/// Maps errors from `supabase.functions.invoke(...)` (the
/// `create-student` / `set-student-password` / `view-student-password` /
/// `student-login` Edge Functions). Every one of those functions responds
/// with a JSON body of the shape `{code, message}` on non-2xx — see
/// `supabase/functions/*/index.ts` — so [FunctionException.details] is read
/// back out here rather than showing a raw HTTP status to the user.
///
/// The `code` field is checked first, before falling back to HTTP status:
/// `student-login` and the Teacher-initiated functions both use 401, but
/// with different meanings — `student-login` returns 401/`invalid_credentials`
/// for a wrong username or password (nothing has "expired"; the student was
/// never signed in), while the others return 401/`missing_authorization`
/// when the caller's own session token is missing or stale. Mapping purely
/// on HTTP status would show a signed-out student "Your session has
/// expired" instead of "Incorrect username or password" — status alone
/// can't distinguish the two, only the `code` can.
///
/// NOTE: this mapping was written by cross-referencing the `FunctionException`
/// API surface (status/details/reasonPhrase) documented on pub.dev, not by
/// compiling this project — flagged per the handoff prompt's request to be
/// explicit about anything not compiler-verified.
AppFailure _mapFunctionException(FunctionException error) {
  final String? code = _extractFunctionErrorCode(error);
  final String? message = _extractFunctionErrorMessage(error);

  if (code == 'invalid_credentials' || code == 'validation_error') {
    return ValidationFailure(
      message ?? 'Please check the values you entered and try again.',
    );
  }

  switch (error.status) {
    case 401:
      return const SessionExpiredFailure();
    case 403:
      return const NotAuthorizedFailure();
    case 404:
      return const NotFoundFailure();
    case 400:
    case 409:
    case 422:
      return ValidationFailure(
        message ?? 'Please check the values you entered and try again.',
      );
    default:
      return ServerFailure(
        message ?? 'Something went wrong. Please try again.',
      );
  }
}

String? _extractFunctionErrorCode(FunctionException error) {
  final Object? details = error.details;
  if (details is Map && details['code'] is String) {
    return details['code'] as String;
  }
  return null;
}

String? _extractFunctionErrorMessage(FunctionException error) {
  final Object? details = error.details;
  if (details is Map && details['message'] is String) {
    return details['message'] as String;
  }
  if (details is String && details.isNotEmpty) return details;
  return null;
}

AppFailure _mapAuthException(AuthException error) {
  final String message = error.message.toLowerCase();

  if (error is AuthRetryableFetchException) {
    return const NetworkFailure();
  }
  if (error.statusCode == '429' ||
      error.code == 'over_email_send_rate_limit' ||
      error.code == 'over_request_rate_limit' ||
      message.contains('rate limit') ||
      message.contains('too many requests')) {
    return const RateLimitFailure();
  }

  if (error is AuthWeakPasswordException || error.code == 'weak_password') {
    return const ValidationFailure(
      'Use a password that meets every security requirement.',
    );
  }
  if (error.code == 'same_password') {
    return const ValidationFailure(
      'Choose a password different from your current password.',
    );
  }
  if (message.contains('invalid login credentials')) {
    return const ValidationFailure('Incorrect email or password.');
  }
  if (error.code == 'user_already_exists' ||
      message.contains('already registered') ||
      message.contains('already exists') ||
      message.contains('user already registered')) {
    return const ValidationFailure(
      'An account with this email already exists.',
    );
  }
  if (error.statusCode == '401' ||
      message.contains('expired') ||
      message.contains('invalid jwt')) {
    return const SessionExpiredFailure();
  }
  if (error is AuthSessionMissingException ||
      error.code == 'otp_expired' ||
      error.code == 'bad_code_verifier' ||
      error.code == 'flow_state_expired' ||
      error.code == 'flow_state_not_found' ||
      message.contains('session missing')) {
    return const RecoveryLinkFailure();
  }

  return const ServerFailure();
}

AppFailure _mapPostgrestException(PostgrestException error) {
  switch (error.code) {
    case '23505': // unique_violation
      return const ValidationFailure('That value is already in use.');
    case '42501': // insufficient_privilege (RLS denial)
      return const NotAuthorizedFailure();
    case 'PGRST116': // no rows found for .single()
      return const NotFoundFailure();
    default:
      if (error.code == '401' || error.message.toLowerCase().contains('jwt')) {
        return const SessionExpiredFailure();
      }
      return const ServerFailure();
  }
}
