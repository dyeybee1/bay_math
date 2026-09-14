import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../validation/teacher_registration_validators.dart';

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

  /// Requests Supabase Auth's password-recovery email. Supabase owns token
  /// generation and delivery; [redirectTo] is the hosted BayMath Web route
  /// that completes the flow for portable Windows builds.
  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) async {
    final String normalizedEmail = TeacherRegistrationValidators.normalizeEmail(
      email,
    );
    final String? emailError = TeacherRegistrationValidators.validateEmail(
      normalizedEmail,
    );
    if (emailError != null) throw ValidationFailure(emailError);

    final Uri? redirectUri = Uri.tryParse(redirectTo);
    final bool isLocalDevelopment =
        redirectUri?.scheme == 'http' &&
        (redirectUri?.host == 'localhost' || redirectUri?.host == '127.0.0.1');
    if (redirectUri == null ||
        !redirectUri.hasAbsolutePath ||
        (redirectUri.scheme != 'https' && !isLocalDevelopment) ||
        redirectUri.path != '/reset-password' ||
        redirectUri.hasQuery ||
        redirectUri.hasFragment) {
      throw const ServerFailure(
        'Password recovery is not configured. Contact your BayMath '
        'Administrator.',
      );
    }

    try {
      await _client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: redirectUri.toString(),
      );
    } on AuthException catch (error) {
      // Some Supabase configurations return a user-not-found error while
      // others deliberately return success. Treat both identically so the
      // UI never becomes an account-discovery oracle.
      final String message = error.message.toLowerCase();
      if (error.code == 'user_not_found' ||
          message.contains('user not found')) {
        return;
      }
      throw mapExceptionToFailure(error);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Changes only the current Supabase Auth user's password. No profile table
  /// or metadata fields are touched, so role and approval state stay intact.
  Future<void> updateRecoveredPassword(String password) async {
    final String? passwordError =
        TeacherRegistrationValidators.validatePassword(password);
    if (passwordError != null) throw ValidationFailure(passwordError);
    if (_client.auth.currentSession == null) {
      throw const RecoveryLinkFailure();
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Ends only this browser's short-lived recovery session after a successful
  /// update. Other devices are left to Supabase's configured session policy.
  Future<void> endRecoverySession() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Teacher self-registration. Migration 0090 creates the matching pending
  /// Teacher profile in the Auth signup transaction, so role and approval
  /// status are never accepted from Flutter.
  Future<void> signUpTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final String normalizedName = TeacherRegistrationValidators.normalizeName(
      fullName,
    );
    final String normalizedEmail = TeacherRegistrationValidators.normalizeEmail(
      email,
    );
    final String? nameError = TeacherRegistrationValidators.validateName(
      normalizedName,
    );
    final String? emailError = TeacherRegistrationValidators.validateEmail(
      normalizedEmail,
    );
    final String? passwordError =
        TeacherRegistrationValidators.validatePassword(password);

    if (nameError != null) throw ValidationFailure(nameError);
    if (emailError != null) throw ValidationFailure(emailError);
    if (passwordError != null) throw ValidationFailure(passwordError);

    try {
      final AuthResponse response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: <String, dynamic>{
          'full_name': normalizedName,
          'registration_source': 'teacher_self_signup',
        },
      );

      final User? user = response.user;
      if (user == null) {
        throw const ServerFailure('Sign up did not return a user.');
      }
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
