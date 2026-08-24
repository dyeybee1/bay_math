import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_result_row.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_enrollment.dart';
import '../../../core/providers/supabase_providers.dart';
import '../presentation/teacher_shell_screen.dart';

/// Which quizzes populate the matrix's columns, once a section is chosen:
/// one of the two built-in assessment types, or every "regular" (non
/// Pre-Test/Post-Test) quiz visible for that section — built-in and
/// teacher-created alike, treated as one category here since, from a
/// results standpoint, they're the same kind of thing; only Pre-Test/
/// Post-Test is a genuinely distinct category worth separating out.
/// Mirrors [AssessmentType] for its two real cases but adds [regular] for
/// everything [AssessmentType] itself has no value for
/// (`quizzes.assessment_type IS NULL`, 0043) — modeled as its own enum
/// here rather than widening [AssessmentType] itself, since
/// [AssessmentType] mirrors a real Postgres enum (0002) that has no third
/// value in the database.
enum QuizResultsAssessmentFilter {
  preTest,
  postTest,
  regular;

  String get label => switch (this) {
        QuizResultsAssessmentFilter.preTest => 'Pre-Test',
        QuizResultsAssessmentFilter.postTest => 'Post-Test',
        QuizResultsAssessmentFilter.regular => 'Regular Quiz',
      };

  /// Whether a quiz/result row carrying this [AssessmentType] belongs in
  /// this filter's matrix — the one place the [preTest]/[postTest]/
  /// [regular] mapping to an actual `assessmentType` value lives, so
  /// column-selection and cell-matching in
  /// [teacherQuizResultsMatrixProvider] below can't drift apart.
  bool matches(AssessmentType? assessmentType) => switch (this) {
        QuizResultsAssessmentFilter.preTest => assessmentType == AssessmentType.preTest,
        QuizResultsAssessmentFilter.postTest => assessmentType == AssessmentType.postTest,
        QuizResultsAssessmentFilter.regular => assessmentType == null,
      };
}

/// The Quiz Results matrix screen's current section/assessment-filter
/// selection. Unlike the flat-list `QuizResultsFilter` this replaces,
/// there is no "All ___" catch-all for either field — a matrix has no
/// meaning until a teacher has chosen exactly one section (its rows) and
/// exactly one [QuizResultsAssessmentFilter] (which quizzes become its
/// columns), so both fields are `null` only in the "not yet chosen"
/// sense, never as a standing "no filter, show everything" state.
class TeacherQuizResultsSelection {
  const TeacherQuizResultsSelection({this.sectionId, this.assessmentType});

  final String? sectionId;
  final QuizResultsAssessmentFilter? assessmentType;

  /// Each dimension gets its own explicit setter (mirrors the old
  /// `QuizResultsFilter.withSectionId`/`withAssessmentType` — same
  /// rationale: both fields are nullable, so a single sentinel-based
  /// `copyWith` couldn't distinguish "set to unchosen" from "leave
  /// unchanged").
  TeacherQuizResultsSelection withSectionId(String? sectionId) =>
      TeacherQuizResultsSelection(sectionId: sectionId, assessmentType: assessmentType);

  TeacherQuizResultsSelection withAssessmentType(QuizResultsAssessmentFilter? assessmentType) =>
      TeacherQuizResultsSelection(sectionId: sectionId, assessmentType: assessmentType);
}

/// Current section/assessment-type selection for the Quiz Results matrix
/// screen. One `StateProvider` (not two) so [teacherQuizResultsMatrixProvider]
/// below has a single atomic value to watch, the same reasoning the old
/// `quizResultsFilterProvider` used.
final StateProvider<TeacherQuizResultsSelection> teacherQuizResultsSelectionProvider =
    StateProvider<TeacherQuizResultsSelection>(
      (ref) => const TeacherQuizResultsSelection(
        assessmentType: QuizResultsAssessmentFilter.regular,
      ),
    );

/// One fully-assembled Quiz Results matrix for a single section +
/// assessment type: the section's roster (rows), that grade level's
/// quizzes of the chosen assessment type (columns), and a lookup from
/// (student, quiz) to the student's completed result for that quiz, if
/// any.
class QuizResultsMatrix {
  const QuizResultsMatrix({
    required this.students,
    required this.quizzes,
    required this.cellsByStudentThenQuiz,
    required this.totalQuestionsByQuizId,
  });

  /// Rows, in `Student.fullName` order.
  ///
  /// Plain string ordering, not last-name-aware — "Ana Cruz" and "Bo Reyes"
  /// sort by first name as typed, not surname. Known limitation, deferred;
  /// revisit if teachers actually want a surname-first roster order.
  final List<Student> students;

  /// Columns: quizzes visible in the chosen section (built-in quizzes via
  /// `gradeLevel`, teacher-created quizzes via their own `quiz_sections`
  /// assignment — see [teacherQuizResultsMatrixProvider]) whose
  /// `assessmentType` matches the chosen
  /// [TeacherQuizResultsSelection.assessmentType], ordered by
  /// `Quiz.createdAt` ascending, `Quiz.title` as a tiebreaker.
  final List<Quiz> quizzes;

  /// `[studentId][quizId] -> QuizResultRow`. Look up with
  /// `cellsByStudentThenQuiz[studentId]?[quizId]`, never `[][]` — a
  /// missing entry means "blank cell", and that covers both "never
  /// started" and "started but not submitted" identically. Only
  /// `QuizResultStatus.completed` rows are ever placed here; an
  /// opened-but-unsubmitted attempt is a deliberate product decision to
  /// hide, not an oversight — see [teacherQuizResultsMatrixProvider].
  ///
  /// KNOWN LIMITATION: `v_teacher_quiz_results` (0045) exposes
  /// `student_name`, not `student_id` — there's no `quiz_attempts.student_id`
  /// column on the view to join against directly. This map is built by
  /// matching each result row's `studentName` against the roster's
  /// `Student.fullName` (see [teacherQuizResultsMatrixProvider]), which is
  /// a soft join: two students with the same full name enrolled in the
  /// same section would be indistinguishable from the view's data alone,
  /// and any such row is silently dropped rather than guessed at. This is
  /// a real (if currently unlikely) correctness gap — if it ever matters,
  /// the fix belongs one layer down, adding a `student_id` column to the
  /// view — not patched over here with fuzzier name matching.
  final Map<String, Map<String, QuizResultRow>> cellsByStudentThenQuiz;

  /// Each column's item count, keyed by `Quiz.id` — from `quiz_questions`
  /// (`QuizQuestionsRepository.fetchQuestionCountsForQuizzes`), not from
  /// any attempt's `QuizResultRow.totalQuestions`. That distinction
  /// matters: a quiz nobody has completed yet still has a real, known
  /// item count (its actual question membership), so this map is
  /// populated for every column regardless of whether any cell in it has
  /// data — unlike [cellsByStudentThenQuiz], which is necessarily empty
  /// for a quiz nobody's completed. A missing key here means the quiz
  /// genuinely has no questions rows (e.g. an External Activity, which
  /// never has any per `enforce_internal_only`, 0014), not "not loaded
  /// yet".
  final Map<String, int> totalQuestionsByQuizId;
}

/// Assembles the Quiz Results matrix for the current
/// [teacherQuizResultsSelectionProvider] selection, or `null` if the
/// teacher hasn't chosen both a section and an assessment filter yet —
/// the screen shows a "pick a section and assessment type" prompt in that
/// case, not a loading/empty matrix.
final FutureProvider<QuizResultsMatrix?> teacherQuizResultsMatrixProvider =
    FutureProvider<QuizResultsMatrix?>((ref) async {
  final TeacherQuizResultsSelection selection = ref.watch(teacherQuizResultsSelectionProvider);
  final String? sectionId = selection.sectionId;
  final QuizResultsAssessmentFilter? assessmentFilter = selection.assessmentType;
  if (sectionId == null || assessmentFilter == null) return null;

  // Resolve the chosen Section (for its gradeLevel) from the teacher's own
  // section list — reuses mySectionsProvider's cache rather than issuing a
  // second query for data that provider already holds.
  final List<MySection> mySections = await ref.watch(mySectionsProvider.future);
  final MySection chosen = mySections.firstWhere(
    (MySection my) => my.teacherSection.sectionId == sectionId,
    orElse: () => throw StateError(
      'teacherQuizResultsMatrixProvider: sectionId "$sectionId" is not one '
      "of this teacher's own sections — the section picker should only "
      'ever offer sectionIds sourced from mySectionsProvider.',
    ),
  );
  final Section? section = chosen.section;
  if (section == null) {
    // Mirrors MySection.section's own doc comment: null only if the
    // section row was deleted out from under an existing assignment — not
    // expected in practice, but handled rather than assumed.
    throw StateError(
      'teacherQuizResultsMatrixProvider: section "$sectionId" has no '
      'resolved Section row, so its gradeLevel cannot be determined.',
    );
  }

  // Roster: this section's active enrollments -> the Student rows behind
  // them. These are the matrix's rows regardless of whether a given
  // student has completed anything yet.
  final List<StudentEnrollment> enrollments =
      await ref.watch(studentEnrollmentsRepositoryProvider).fetchActiveForSection(sectionId);
  final List<Student> students = await ref
      .watch(studentsRepositoryProvider)
      .fetchByIds([for (final StudentEnrollment e in enrollments) e.studentId]);
  final List<Student> sortedStudents = [...students]
    ..sort((Student a, Student b) => a.fullName.compareTo(b.fullName));

  // Columns: quizzes visible in this section matching the chosen filter.
  // A quiz's per-section visibility is resolved two different ways
  // depending on who made it (see Quiz.gradeLevel's own doc comment):
  // built-in quizzes are scoped by gradeLevel alone, while a
  // teacher-created quiz's gradeLevel is optional metadata only — its
  // real visibility lives in quiz_sections, the same join table
  // QuizzesRepository.assign/unassign write to. Both paths are needed
  // together (not just gradeLevel) so a teacher's own "Regular Quiz"
  // columns show up here at all — see the
  // QuizResultsAssessmentFilter.regular doc comment for why teacher-made
  // and built-in quizzes are one combined category rather than two.
  final List<Quiz> allQuizzes = await ref.watch(quizzesRepositoryProvider).fetchVisibleToTeacher();
  final Set<String> teacherQuizIdsForSection =
      (await ref.watch(quizzesRepositoryProvider).fetchQuizIdsForSection(sectionId)).toSet();
  final List<Quiz> quizzes = [
    for (final Quiz quiz in allQuizzes)
      if (assessmentFilter.matches(quiz.assessmentType) &&
          (quiz.createdBy == null
              ? quiz.gradeLevel == section.gradeLevel
              : teacherQuizIdsForSection.contains(quiz.id)))
        quiz,
  ]..sort((Quiz a, Quiz b) {
      final int byCreatedAt = a.createdAt.compareTo(b.createdAt);
      return byCreatedAt != 0 ? byCreatedAt : a.title.compareTo(b.title);
    });

  // Each column's item count, independent of whether anyone's completed
  // it yet — see QuizResultsMatrix.totalQuestionsByQuizId's own doc
  // comment for why this can't just be read off the cells built below.
  final Map<String, int> totalQuestionsByQuizId = await ref
      .watch(quizQuestionsRepositoryProvider)
      .fetchQuestionCountsForQuizzes([for (final Quiz quiz in quizzes) quiz.id]);

  // Cells: only completed attempts for this section + assessment type — an
  // opened-but-unsubmitted attempt must never appear as a cell value, it
  // should look identical to "never started" (blank). Deliberate product
  // decision, not an oversight.
  final List<QuizResultRow> allResults =
      await ref.watch(teacherQuizResultsRepositoryProvider).fetchResultsForTeacher();

  // See the KNOWN LIMITATION note on QuizResultsMatrix.cellsByStudentThenQuiz:
  // the view has no student_id, so rows are matched to roster students by
  // full name. A name shared by more than one roster student can't be
  // resolved from this data alone — those rows are dropped rather than
  // guessed at, so a collision shows up as missing cells, never wrong ones.
  final Map<String, List<Student>> rosterByName = {};
  for (final Student student in sortedStudents) {
    rosterByName.putIfAbsent(student.fullName, () => []).add(student);
  }

  final Map<String, Map<String, QuizResultRow>> cells = {};
  for (final QuizResultRow row in allResults) {
    if (row.sectionId != sectionId) continue;
    if (!assessmentFilter.matches(row.assessmentType)) continue;
    if (row.status != QuizResultStatus.completed) continue;

    final List<Student>? matches = rosterByName[row.studentName];
    if (matches == null || matches.length != 1) continue;

    cells.putIfAbsent(matches.first.id, () => {})[row.quizId] = row;
  }

  return QuizResultsMatrix(
    students: sortedStudents,
    quizzes: quizzes,
    cellsByStudentThenQuiz: cells,
    totalQuestionsByQuizId: totalQuestionsByQuizId,
  );
});
