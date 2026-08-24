import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../repositories/endless_quiz_repository.dart';
import '../repositories/lesson_progress_repository.dart';
import '../repositories/lessons_repository.dart';
import '../repositories/profiles_repository.dart';
import '../repositories/question_bank_repository.dart';
import '../repositories/quiz_attempts_repository.dart';
import '../repositories/quiz_content_repository.dart';
import '../repositories/quiz_questions_repository.dart';
import '../repositories/quizzes_repository.dart';
import '../repositories/school_years_repository.dart';
import '../repositories/schools_repository.dart';
import '../repositories/sections_repository.dart';
import '../repositories/student_auth_repository.dart';
import '../repositories/student_enrollments_repository.dart';
import '../repositories/student_profile_repository.dart';
import '../repositories/student_statistics_repository.dart';
import '../repositories/students_repository.dart';
import '../repositories/teacher_dashboard_repository.dart';
import '../repositories/teacher_quiz_results_repository.dart';
import '../repositories/teacher_sections_repository.dart';
import 'student_scoped_client_provider.dart';

/// The shared Supabase client. Every repository provider below depends on
/// this rather than calling `Supabase.instance.client` directly, so tests
/// can override it with a fake.
final Provider<SupabaseClient> supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final Provider<ProfilesRepository> profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  return ProfilesRepository(ref.watch(supabaseClientProvider));
});

/// Phase 2 — Admin workflows (school/section/school-year management).
final Provider<SchoolsRepository> schoolsRepositoryProvider = Provider<SchoolsRepository>((ref) {
  return SchoolsRepository(ref.watch(supabaseClientProvider));
});

final Provider<SchoolYearsRepository> schoolYearsRepositoryProvider =
    Provider<SchoolYearsRepository>((ref) {
  return SchoolYearsRepository(ref.watch(supabaseClientProvider));
});

final Provider<SectionsRepository> sectionsRepositoryProvider = Provider<SectionsRepository>((ref) {
  return SectionsRepository(ref.watch(supabaseClientProvider));
});

final Provider<TeacherSectionsRepository> teacherSectionsRepositoryProvider =
    Provider<TeacherSectionsRepository>((ref) {
  return TeacherSectionsRepository(ref.watch(supabaseClientProvider));
});

/// Phase 9 (Teacher Dashboard). Built from [supabaseClientProvider] — the
/// same non-nullable, always-present client every other Teacher/Admin
/// repository provider on this page depends on (e.g.
/// [teacherSectionsRepositoryProvider], [sectionsRepositoryProvider]
/// above) — NOT [studentScopedClientProvider]. A Teacher/Admin session is
/// a real Supabase Auth (GoTrue) session already carried by the app-wide
/// client; only a Student session needs the separate forwarded-custom-JWT
/// client, which is why every Student-scoped repository provider further
/// below is nullable (`Repository?`) while this one, like every other
/// Teacher-facing provider above it, is not.
final Provider<TeacherDashboardRepository> teacherDashboardRepositoryProvider =
    Provider<TeacherDashboardRepository>((ref) {
  return TeacherDashboardRepository(ref.watch(supabaseClientProvider));
});

/// `v_teacher_quiz_results` (0045) results table. Built from
/// [supabaseClientProvider] — same rationale as
/// [teacherDashboardRepositoryProvider] directly above: this is a
/// Teacher-facing read, so it rides the app-wide Teacher/Admin GoTrue
/// session, NOT [studentScopedClientProvider]. Non-nullable for the same
/// reason every other Teacher-facing provider on this page is (see the
/// comment on [teacherDashboardRepositoryProvider]).
final Provider<TeacherQuizResultsRepository> teacherQuizResultsRepositoryProvider =
    Provider<TeacherQuizResultsRepository>((ref) {
  return TeacherQuizResultsRepository(ref.watch(supabaseClientProvider));
});

/// Phase 4 — Teacher section/student account management.
final Provider<StudentsRepository> studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  return StudentsRepository(ref.watch(supabaseClientProvider));
});

final Provider<StudentEnrollmentsRepository> studentEnrollmentsRepositoryProvider =
    Provider<StudentEnrollmentsRepository>((ref) {
  return StudentEnrollmentsRepository(ref.watch(supabaseClientProvider));
});

/// Student custom-JWT auth (Phase 4 architecture §2/§6) — deliberately
/// separate from [authRepositoryProvider], since a student session is not a
/// Supabase Auth/GoTrue session at all (no matching `auth.users` row).
final Provider<StudentAuthRepository> studentAuthRepositoryProvider =
    Provider<StudentAuthRepository>((ref) {
  return StudentAuthRepository(ref.watch(supabaseClientProvider));
});

/// Phase 5 — Content management (lessons, question bank, quizzes).
final Provider<LessonsRepository> lessonsRepositoryProvider = Provider<LessonsRepository>((ref) {
  return LessonsRepository(ref.watch(supabaseClientProvider));
});

final Provider<QuestionBankRepository> questionBankRepositoryProvider =
    Provider<QuestionBankRepository>((ref) {
  return QuestionBankRepository(ref.watch(supabaseClientProvider));
});

final Provider<QuizzesRepository> quizzesRepositoryProvider = Provider<QuizzesRepository>((ref) {
  return QuizzesRepository(ref.watch(supabaseClientProvider));
});

final Provider<QuizQuestionsRepository> quizQuestionsRepositoryProvider =
    Provider<QuizQuestionsRepository>((ref) {
  return QuizQuestionsRepository(ref.watch(supabaseClientProvider));
});

/// Phase 6 — Quiz-Taking. Both of these are built from
/// [studentScopedClientProvider], not [supabaseClientProvider] — a student
/// session carries its own custom JWT, never the app-wide Teacher/Admin
/// GoTrue session (see the comment on that provider). Null whenever no
/// student is signed in; screens under `/student-*` are only ever reached
/// after login, so callers can safely treat a null repository here as a
/// "should not happen" case (e.g. surface a generic error) rather than a
/// normal empty state.
final Provider<QuizAttemptsRepository?> quizAttemptsRepositoryProvider =
    Provider<QuizAttemptsRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : QuizAttemptsRepository(client);
});

final Provider<QuizContentRepository?> quizContentRepositoryProvider =
    Provider<QuizContentRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : QuizContentRepository(client);
});

/// Student-scoped instances of two Phase 2/5 repository classes that
/// already work for either role purely via RLS — `QuizzesRepository`'s
/// `fetchVisibleToTeacher()` is really just `select * from quizzes`, whose
/// visibility PostgREST/RLS resolves differently per caller
/// (`quizzes_student_select` vs `quizzes_teacher_select`, 0015). Reusing
/// the same class from the student-scoped client avoids introducing a
/// parallel repository for what is, underneath, the identical query.
final Provider<QuizzesRepository?> studentQuizzesRepositoryProvider =
    Provider<QuizzesRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : QuizzesRepository(client);
});

final Provider<StudentEnrollmentsRepository?> studentOwnEnrollmentsRepositoryProvider =
    Provider<StudentEnrollmentsRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : StudentEnrollmentsRepository(client);
});

/// Student-scoped instance of `LessonsRepository` — same reuse rationale
/// as [studentQuizzesRepositoryProvider] above: `fetchVisibleToTeacher()`/
/// `fetchPages()` are plain selects whose visibility RLS
/// (`lessons_student_select`/`lesson_pages_select`, 0015/0028) resolves
/// differently per caller, so no parallel student-only repository class is
/// needed.
final Provider<LessonsRepository?> studentLessonsRepositoryProvider =
    Provider<LessonsRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : LessonsRepository(client);
});

/// The Lesson-Viewer's write path for `lesson_progress` (0007) — student-
/// scoped for the same reason [quizAttemptsRepositoryProvider] is.
final Provider<LessonProgressRepository?> lessonProgressRepositoryProvider =
    Provider<LessonProgressRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : LessonProgressRepository(client);
});

/// Phase 7 (Endless Quiz) — student-scoped for the same reason
/// [quizAttemptsRepositoryProvider]/[quizContentRepositoryProvider] are;
/// see `EndlessQuizRepository`'s own doc comment for why this single
/// repository (and so this single provider) covers both Connection A and
/// Connection B calls rather than being split the way Phase 6's pair is.
final Provider<EndlessQuizRepository?> endlessQuizRepositoryProvider =
    Provider<EndlessQuizRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : EndlessQuizRepository(client);
});

/// First-login avatar picker — student-scoped for the same reason
/// [quizAttemptsRepositoryProvider] is: reads/writes the student's own
/// `students` row entirely through their own forwarded JWT (RLS own-row
/// SELECT + the `set_student_avatar` RPC, both 0053), no service_role call
/// involved.
final Provider<StudentProfileRepository?> studentProfileRepositoryProvider =
    Provider<StudentProfileRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : StudentProfileRepository(client);
});

/// Phase 8 (Student Statistics) — student-scoped for the same reason
/// [quizAttemptsRepositoryProvider] is: every read here goes through
/// `0035`'s views under RLS via the student's own forwarded JWT, no
/// service_role call involved (see `StudentStatisticsRepository`'s own
/// doc comment).
final Provider<StudentStatisticsRepository?> studentStatisticsRepositoryProvider =
    Provider<StudentStatisticsRepository?>((ref) {
  final SupabaseClient? client = ref.watch(studentScopedClientProvider);
  return client == null ? null : StudentStatisticsRepository(client);
});
