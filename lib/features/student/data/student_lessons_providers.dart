import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/providers/supabase_providers.dart';

/// Every lesson currently available to the signed-in student. The Student
/// Lessons catalog and every lesson-count consumer must share this provider so
/// they use the same RLS-filtered result rather than independently estimating
/// visibility.
final FutureProvider<List<Lesson>> studentVisibleLessonsProvider =
    FutureProvider<List<Lesson>>((Ref ref) {
      final repo = ref.watch(studentLessonsRepositoryProvider);
      if (repo == null) throw const SessionExpiredFailure();
      return repo.fetchVisibleToTeacher();
    });
