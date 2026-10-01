import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/quiz_attempt.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import 'student_statistics_providers.dart';

/// Coordinates the authoritative final quiz write with dependent cache
/// invalidation. Navigation remains a presentation concern.
final Provider<StudentQuizSubmissionController?>
studentQuizSubmissionControllerProvider =
    Provider<StudentQuizSubmissionController?>((Ref ref) {
      final QuizAttemptsRepository? repository = ref.watch(
        quizAttemptsRepositoryProvider,
      );
      if (repository == null) return null;

      final StudentStatisticsSynchronizer statisticsSynchronizer = ref.watch(
        studentStatisticsSynchronizerProvider,
      );
      return StudentQuizSubmissionController(
        finalizeAttempt: repository.finalize,
        onQuizCompleted: statisticsSynchronizer.quizCompleted,
      );
    });

class StudentQuizSubmissionController {
  const StudentQuizSubmissionController({
    required this.finalizeAttempt,
    required this.onQuizCompleted,
  });

  final Future<QuizAttempt> Function(String attemptId) finalizeAttempt;
  final void Function() onQuizCompleted;

  /// Invalidates derived Statistics only after the final database update has
  /// completed successfully. A failed write leaves the existing cache intact.
  Future<QuizAttempt> submit(String attemptId) async {
    final QuizAttempt completedAttempt = await finalizeAttempt(attemptId);
    onQuizCompleted();
    return completedAttempt;
  }
}
