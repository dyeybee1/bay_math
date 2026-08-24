import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../models/profile.dart';
import 'supabase_providers.dart';

/// "Who is currently signed in." Every screen's role-gating and every
/// repository call's implicit identity flows from this one provider —
/// deliberately centralized (Phase 4 architecture, Part 4) so a full
/// identity switch has exactly one place to invalidate.
sealed class SessionState {
  const SessionState();
}

final class SessionNone extends SessionState {
  const SessionNone();
}

final class SessionTeacher extends SessionState {
  const SessionTeacher(this.profile);
  final Profile profile;
}

final class SessionAdmin extends SessionState {
  const SessionAdmin(this.profile);
  final Profile profile;
}

/// Reserved for Phase 3 (student custom-JWT login, Phase 4.1 architecture
/// §2). Not reachable yet — students don't authenticate until Phase 3 is
/// implemented. Included now so this sealed hierarchy doesn't need a
/// breaking change later; every `switch` on [SessionState] in this phase
/// still must handle it, which is intentional — it keeps this file honest
/// about the full shape the frozen architecture already specifies.
final class SessionStudent extends SessionState {
  const SessionStudent(this.studentId);
  final String studentId;
}

/// Subscribes to Supabase Auth's `onAuthStateChange` exactly ONCE for the
/// whole app's lifetime, invalidating [sessionProvider] on real changes.
///
/// This used to live inside [SessionNotifier.build] instead. That was the
/// bug: every `invalidateSelf()` reran `build()`, which created a BRAND
/// NEW `.listen(...)` subscription on the same broadcast stream — and if
/// the previous subscription's teardown (`ref.onDispose`) didn't complete
/// before the next one was created, both stayed alive at once. A single
/// real sign-in event then fired every surviving subscription
/// simultaneously, each calling `invalidateSelf()` again, creating a new
/// subscription each time — an effectively infinite feedback loop
/// (observed as hundreds of `AuthChangeEvent.signedIn` events firing back
/// to back, with `build()` never getting far enough to actually resolve
/// and let GoRouter redirect; only a full app restart, which starts with
/// zero stale subscriptions, let it settle).
///
/// Subscribing exactly once, in a plain [Provider] with no reason to ever
/// be invalidated, removes the "resubscribe every rebuild" pattern
/// entirely rather than trying to make teardown ordering more reliable.
final Provider<void> _authStateListenerProvider = Provider<void>((ref) {
  final StreamSubscription<AuthState> subscription =
      ref.read(authRepositoryProvider).onAuthStateChange.listen((data) {
    // Supabase always fires `initialSession` immediately upon subscribing,
    // even when there is no session — that's exactly what sessionProvider's
    // own build() already resolves as part of app startup, so reacting to
    // it here too would just be a redundant extra rebuild, not a loop risk
    // (this provider itself never gets re-subscribed), but there's no
    // reason to.
    if (data.event == AuthChangeEvent.initialSession) return;
    ref.invalidate(sessionProvider);
  });
  ref.onDispose(subscription.cancel);
});

class SessionNotifier extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    // Ensures the singleton auth-state listener above exists — cheap to
    // call on every build, since a plain Provider's body only ever runs
    // once no matter how many times it's watched.
    ref.watch(_authStateListenerProvider);
    return _resolveCurrentSession();
  }

  Future<SessionState> _resolveCurrentSession() async {
    final session = ref.read(authRepositoryProvider).currentSession;
    if (session == null) return const SessionNone();

    final profile = await ref
        .read(profilesRepositoryProvider)
        .fetchOwnProfile(session.user.id);

    if (profile == null) {
      // A real Auth session exists but no profiles row does — a real,
      // recoverable possibility (e.g. self-registration interrupted
      // between sign-up and the profile insert), not a crash.
      return const SessionNone();
    }

    return switch (profile.role) {
      ProfileRole.admin => SessionAdmin(profile),
      ProfileRole.teacher => SessionTeacher(profile),
    };
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(SessionNone());
  }

  /// The Unified Session-Expiration Policy's global layer (Phase 4.1 §3):
  /// any repository that maps an error to [SessionExpiredFailure] should
  /// ultimately cause this. In Phase 1, Supabase Auth's own session stream
  /// already covers Teacher/Admin token invalidation automatically (see
  /// [_authStateListenerProvider]) — this method exists for repositories
  /// added in later phases that aren't backed by that stream (e.g. once a
  /// student session is involved) to call explicitly.
  void markExpired() {
    state = AsyncValue<SessionState>.error(
      const SessionExpiredFailure(),
      StackTrace.current,
    );
  }

  /// Forces a fresh restore — used after Teacher self-registration, since a
  /// new sign-up produces a session before its profile row exists in the
  /// same request, so the very next resolution needs to pick that row up.
  void refresh() => ref.invalidateSelf();
}

final AsyncNotifierProvider<SessionNotifier, SessionState> sessionProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
