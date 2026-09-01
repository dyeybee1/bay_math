import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/quiz.dart';

/// The canonical order of BayMath's built-in lesson catalog.
///
/// The database query is intentionally shared with Teacher screens and returns
/// titles alphabetically. Student catalogs apply this presentation-only order
/// so changing the student curriculum sequence cannot affect Teacher views.
const Map<String, int> _builtInLessonOrder = <String, int>{
  // Grade 4
  'Addition and Subtraction of Numbers up to 1,000,000': 0,
  'Comparing Numbers up to 1,000,000': 1,
  'Place Value of Whole Numbers': 2,
  'Multiplication, Division, and MDAS': 3,
  'Types of Fractions': 4,
  'Converting and Plotting Fractions': 5,
  'Comparing, Adding, and Subtracting Fractions': 6,
  'Factors of Numbers up to 100': 7,
  'Decimals and Their Relationship to Fractions': 8,
  'Place Value and Value of Decimal Digits': 9,

  // Grade 5
  'Understanding 12-Hour and 24-Hour Time': 0,
  'Solving Operations Using GMDAS': 1,
  'Multiplying and Dividing Fractions': 2,
  'Finding the Area of Plane Figures': 3,
  'Adding, Subtracting, and Multiplying Decimals': 4,
  'Using Divisibility Rules': 5,
  'Prime and Composite Numbers': 6,
  'Understanding and Solving Probability': 7,
  'GMDAS with Fractions and Decimals': 8,
  'Finding the Surface Area of Solid Figures': 9,

  // Grade 6
  'Operations with Fractions, Whole Numbers, and Mixed Numbers': 0,
  'Operations with Decimals': 1,
  'Understanding Ratio and Proportion': 2,
  'Exponents and GEMDAS': 3,
  'Volume of Cubes and Rectangular Prisms': 4,
  'Perimeter and Area of Plane and Composite Figures': 5,
  'Parts and Circumference of a Circle': 6,
  'Area of a Circle': 7,
  'Common Factors and Greatest Common Factor (GCF)': 8,
  'Common Multiples and Least Common Multiple (LCM)': 9,
};

/// Returns a new list in curriculum order without mutating provider data.
///
/// Exact duplicate built-in rows are collapsed to the earliest canonical
/// record. Unknown or teacher-created titles are kept after the known
/// curriculum in their original relative order.
List<Lesson> orderStudentLessons(List<Lesson> lessons) {
  final List<Lesson> deduplicated = _deduplicateBuiltInLessons(lessons);
  final List<({int index, Lesson lesson})> indexed = deduplicated.indexed
      .map(((int, Lesson) entry) => (index: entry.$1, lesson: entry.$2))
      .toList(growable: false);

  indexed.sort((left, right) {
    final int leftRank = _lessonRank(left.lesson);
    final int rightRank = _lessonRank(right.lesson);
    final int rankComparison = leftRank.compareTo(rightRank);
    return rankComparison != 0
        ? rankComparison
        : left.index.compareTo(right.index);
  });

  return indexed
      .map((({int index, Lesson lesson}) entry) => entry.lesson)
      .toList(growable: false);
}

int _lessonRank(Lesson lesson) {
  if (lesson.sourceType != ContentSourceType.builtIn) return 1000;
  return _builtInLessonOrder[lesson.title] ?? 1000;
}

List<Lesson> _deduplicateBuiltInLessons(List<Lesson> lessons) {
  final Map<String, ({int index, Lesson lesson})> canonicalByIdentity =
      <String, ({int index, Lesson lesson})>{};
  final List<({int index, Lesson lesson})> retained =
      <({int index, Lesson lesson})>[];

  for (final (int index, Lesson lesson) in lessons.indexed) {
    if (lesson.sourceType != ContentSourceType.builtIn) {
      retained.add((index: index, lesson: lesson));
      continue;
    }

    final String identity =
        '${lesson.gradeLevel?.name ?? 'unknown'}|${lesson.title.trim().toLowerCase()}';
    final ({int index, Lesson lesson})? existing =
        canonicalByIdentity[identity];
    if (existing == null ||
        lesson.createdAt.isBefore(existing.lesson.createdAt)) {
      canonicalByIdentity[identity] = (index: index, lesson: lesson);
    }
  }

  retained.addAll(canonicalByIdentity.values);
  retained.sort((left, right) => left.index.compareTo(right.index));
  return retained
      .map((({int index, Lesson lesson}) entry) => entry.lesson)
      .toList(growable: false);
}

final RegExp _numberedQuizTitle = RegExp(
  r'^Quiz\s+(\d+)\s*:',
  caseSensitive: false,
);

/// Returns a new list in the Student assessment sequence:
/// Pre-Test, Post-Test, numbered regular quizzes, other regular quizzes, then
/// external activities. Exact duplicate built-in rows are collapsed to the
/// earliest canonical record; items with the same rank retain source order.
List<Quiz> orderStudentQuizzes(List<Quiz> quizzes) {
  final List<Quiz> deduplicated = _deduplicateBuiltInQuizzes(quizzes);
  final List<({int index, Quiz quiz})> indexed = deduplicated.indexed
      .map(((int, Quiz) entry) => (index: entry.$1, quiz: entry.$2))
      .toList(growable: false);

  indexed.sort((left, right) {
    final ({int group, int sequence}) leftRank = _quizRank(left.quiz);
    final ({int group, int sequence}) rightRank = _quizRank(right.quiz);

    final int groupComparison = leftRank.group.compareTo(rightRank.group);
    if (groupComparison != 0) return groupComparison;

    final int sequenceComparison = leftRank.sequence.compareTo(
      rightRank.sequence,
    );
    return sequenceComparison != 0
        ? sequenceComparison
        : left.index.compareTo(right.index);
  });

  return indexed
      .map((({int index, Quiz quiz}) entry) => entry.quiz)
      .toList(growable: false);
}

List<Quiz> _deduplicateBuiltInQuizzes(List<Quiz> quizzes) {
  final Map<String, ({int index, Quiz quiz})> canonicalByIdentity =
      <String, ({int index, Quiz quiz})>{};
  final List<({int index, Quiz quiz})> retained = <({int index, Quiz quiz})>[];

  for (final (int index, Quiz quiz) in quizzes.indexed) {
    if (quiz.sourceType != ContentSourceType.builtIn) {
      retained.add((index: index, quiz: quiz));
      continue;
    }

    final String identity =
        '${quiz.gradeLevel?.name ?? 'unknown'}|${quiz.quizType.name}|'
        '${quiz.assessmentType?.name ?? 'regular'}|'
        '${quiz.title.trim().toLowerCase()}';
    final ({int index, Quiz quiz})? existing = canonicalByIdentity[identity];
    if (existing == null || quiz.createdAt.isBefore(existing.quiz.createdAt)) {
      canonicalByIdentity[identity] = (index: index, quiz: quiz);
    }
  }

  retained.addAll(canonicalByIdentity.values);
  retained.sort((left, right) => left.index.compareTo(right.index));
  return retained
      .map((({int index, Quiz quiz}) entry) => entry.quiz)
      .toList(growable: false);
}

({int group, int sequence}) _quizRank(Quiz quiz) {
  if (quiz.assessmentType == AssessmentType.preTest) {
    return (group: 0, sequence: 0);
  }
  if (quiz.assessmentType == AssessmentType.postTest) {
    return (group: 1, sequence: 0);
  }
  if (quiz.quizType == QuizType.externalActivity) {
    return (group: 4, sequence: 0);
  }
  if (quiz.sourceType != ContentSourceType.builtIn) {
    return (group: 3, sequence: 0);
  }

  final RegExpMatch? match = _numberedQuizTitle.firstMatch(quiz.title.trim());
  final int? sequence = match == null ? null : int.tryParse(match.group(1)!);
  return sequence == null
      ? (group: 3, sequence: 0)
      : (group: 2, sequence: sequence);
}
