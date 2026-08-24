/// A student's custom-JWT session (Phase 4 architecture §2/§6).
///
/// Deliberately NOT a [SessionState]/`SessionStudent` value yet — wiring a
/// student session into the main `sessionProvider` (which tracks Supabase
/// Auth's own `onAuthStateChange` stream for Teacher/Admin) would require
/// designing token persistence/refresh/restoration, which is explicitly
/// out of scope for this phase ("keep this part minimal — just enough to
/// prove login works end-to-end"). This is an in-memory-only holder; it
/// does not survive an app restart.
class StudentSession {
  const StudentSession({
    required this.accessToken,
    required this.expiresAt,
    required this.studentId,
  });

  /// The raw custom JWT minted by the `student-login` Edge Function. Holding
  /// it here (rather than handing it to `supabase_flutter`'s own session
  /// management) is intentional — this token has no matching `auth.users`
  /// row, so the SDK's GoTrue session handling doesn't apply to it.
  final String accessToken;
  final DateTime expiresAt;
  final String studentId;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}
