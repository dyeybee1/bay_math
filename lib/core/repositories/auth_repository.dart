import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';

/// Wraps Supabase Auth for Teacher/Admin (Students are never `auth.users`
/// rows — see `phase-4-1-architecture-revision.md`). This is the only class
/// in the app that calls `Supabase.instance.client.auth.*`.
class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  /// The SDK's own restored session, if any (native Supabase Auth session
  /// persistence — nothing custom here for Teacher/Admin).
  Session? get currentSession => _client.auth.currentSession;

  /// Fires on sign-in, sign-out, and token refresh. Drives session
  /// restoration and reactive redirects.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Teacher self-registration. Creates the Auth identity, then inserts the
  /// corresponding `profiles` row directly (role='teacher', status='pending')
  /// — the only shape the profiles_admin_insert policy permits for a
  /// self-registering user (0019).
  Future<void> signUpTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      final User? user = response.user;
      if (user == null) {
        throw const ServerFailure('Sign up did not return a user.');
      }

      await _client.from('profiles').insert({
        'id': user.id,
        'role': 'teacher',
        'status': 'pending',
        'full_name': fullName,
        'email': email,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
