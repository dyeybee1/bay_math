import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/env_config.dart';
import '../models/student_session.dart';
import 'student_session_provider.dart';

/// Connection A for every Phase 6 quiz-taking repository call
/// (`QuizAttemptsRepository`) — ordinary PostgREST access under RLS, using
/// the student's own forwarded JWT, exactly like `supabaseClientProvider`
/// does for Teacher/Admin.
///
/// `Supabase.instance.client` (the app-wide singleton, GoTrue-managed)
/// deliberately cannot be reused here: a student session is not a Supabase
/// Auth/GoTrue session at all (see the comment on `StudentSession`), so
/// there's no way to hand GoTrue this token. Instead this constructs an
/// entirely separate `SupabaseClient` instance carrying the token as a
/// plain forwarded `Authorization` header — PostgREST verifies it exactly
/// like a normal Auth token, since `STUDENT_JWT_SIGNING_SECRET` is signed
/// with the project's actual JWT secret (see the comment on
/// `student-login/index.ts`).
///
/// Null whenever no student is signed in — callers must handle that
/// (the same shape as `studentSessionProvider` itself).
///
/// NOT COMPILER-VERIFIED — the `SupabaseClient(url, anonKey, headers: ...)`
/// constructor shape here is written from documented `supabase_flutter`
/// usage, not by compiling this project (no Flutter SDK available in this
/// environment); please confirm this actually authenticates as the student
/// (e.g. a call that only succeeds under `student_id = app.current_student_id()`)
/// before relying on it.
final Provider<SupabaseClient?> studentScopedClientProvider = Provider<SupabaseClient?>((ref) {
  final StudentSession? session = ref.watch(studentSessionProvider);
  if (session == null) return null;

  return SupabaseClient(
    EnvConfig.supabaseUrl,
    EnvConfig.supabaseAnonKey,
    headers: {'Authorization': 'Bearer ${session.accessToken}'},
  );
});
