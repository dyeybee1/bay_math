import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/section.dart';
import '../models/student.dart';
import '../repositories/student_profile_repository.dart';
import 'student_session_provider.dart';
import 'supabase_providers.dart';

/// The logged-in student's own `students` row (full_name, avatar_id, ...).
///
/// Watches [studentSessionProvider] so it automatically re-resolves to
/// `null`/refetches on login/logout — same reactive shape as every other
/// student-scoped provider in this app. Screens that only need `avatarId`
/// for display (e.g. `StudentHomeScreen`) and screens that need to decide
/// whether to route to the avatar picker (e.g. `StudentLoginScreen`, via a
/// direct repository call rather than this provider — see that screen's
/// own comment) both read from the same underlying row shape.
///
/// After `StudentAvatarSelectScreen` calls `setAvatar`, it invalidates this
/// provider so `StudentHomeScreen` picks up the new avatar immediately
/// without requiring a fresh login.
final FutureProvider<Student?> ownStudentProfileProvider = FutureProvider<Student?>((ref) async {
  final session = ref.watch(studentSessionProvider);
  if (session == null) return null;

  final StudentProfileRepository? repository = ref.watch(studentProfileRepositoryProvider);
  if (repository == null) return null;

  return repository.fetchOwnProfile();
});

/// The logged-in student's current `GradeLevel` (e.g. "Grade 6", header
/// display on `StudentHomeScreen`) — same reactive shape as
/// [ownStudentProfileProvider], kept as a separate provider rather than a
/// field folded into [Student] because it comes from a different query
/// (`student_current_grade`, derived from the student's section, not a
/// `students` table column at all).
final FutureProvider<GradeLevel?> ownStudentGradeLevelProvider = FutureProvider<GradeLevel?>((ref) async {
  final session = ref.watch(studentSessionProvider);
  if (session == null) return null;

  final StudentProfileRepository? repository = ref.watch(studentProfileRepositoryProvider);
  if (repository == null) return null;

  return repository.fetchOwnGradeLevel();
});
