/// The typed failure hierarchy every repository maps exceptions into.
///
/// Widgets/providers never handle raw [PostgrestException]/[AuthException]/
/// network errors directly — repositories are the only layer that imports
/// `supabase_flutter`, and they always translate its exceptions into one of
/// these before letting them propagate. Phase 4 architecture, Part 12.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// A short, user-facing message. Safe to show directly in the UI — never
  /// a raw database/server error string.
  final String message;

  @override
  String toString() => message;
}

/// The device appears to be offline, or the request couldn't reach the
/// server at all. Safe to retry.
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Could not connect. Check your internet connection.',
  ]);
}

/// Supabase rejected a burst of authentication requests. Kept distinct so
/// recovery screens can offer a useful retry-later message without exposing
/// account existence or raw provider details.
final class RateLimitFailure extends AppFailure {
  const RateLimitFailure([
    super.message =
        'Too many requests. Please wait a few minutes before trying again.',
  ]);
}

/// The current session is no longer valid (expired, revoked, or malformed).
/// Triggers the Unified Session-Expiration Policy (Phase 4.1 architecture,
/// §3) — sessionProvider transitions to "expired" as this failure is
/// produced, which is what drives the reactive redirect to login.
final class SessionExpiredFailure extends AppFailure {
  const SessionExpiredFailure([
    super.message = 'Your session has expired. Please log in again.',
  ]);
}

/// A password-recovery URL could not establish a valid recovery session.
/// Invalid, expired, and already-used links intentionally share one message.
final class RecoveryLinkFailure extends AppFailure {
  const RecoveryLinkFailure([
    super.message =
        'This password reset link is invalid, expired, or has already been '
            'used. Request a new link and try again.',
  ]);
}

/// The request was well-formed but rejected for a business-rule reason the
/// user can fix (e.g. a password that's too short, an email already in
/// use). Shown inline on the relevant field, not as a global error.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// The caller is authenticated but not permitted to do this. Distinct from
/// [SessionExpiredFailure] on purpose — the fix here is not "log in again."
final class NotAuthorizedFailure extends AppFailure {
  const NotAuthorizedFailure([
    super.message = 'You are not permitted to do this.',
  ]);
}

/// The requested row/resource does not exist (or is not visible to the
/// caller, which — by RLS design — looks identical from the outside).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'The requested item was not found.']);
}

/// The authenticated Student has no eligible quiz-linked questions for their
/// authoritative grade/section. Kept distinct from a missing resource so the
/// Endless Quiz screen can present a calm empty state instead of an error.
final class NoEndlessQuestionsFailure extends AppFailure {
  const NoEndlessQuestionsFailure([
    super.message =
        'No Endless Quiz questions are available for your grade yet.',
  ]);
}

/// Anything unexpected. Logged for diagnosis; never shows a raw stack
/// trace or database error string to the user.
final class ServerFailure extends AppFailure {
  const ServerFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
