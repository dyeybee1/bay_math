import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/section.dart';

const int teacherCreatedContentStartNumber = 11;

class TeacherContentListEntry<T> {
  const TeacherContentListEntry({
    required this.content,
    required this.sequenceNumber,
  });

  final T content;
  final int? sequenceNumber;
}

const Map<GradeLevel, List<String>> _lessonTitlesByGrade =
    <GradeLevel, List<String>>{
      GradeLevel.grade4: <String>[
        'Addition and Subtraction of Numbers up to 1,000,000',
        'Comparing Numbers up to 1,000,000',
        'Place Value of Whole Numbers',
        'Multiplication, Division, and MDAS',
        'Types of Fractions',
        'Converting and Plotting Fractions',
        'Comparing, Adding, and Subtracting Fractions',
        'Factors of Numbers up to 100',
        'Decimals and Their Relationship to Fractions',
        'Place Value and Value of Decimal Digits',
      ],
      GradeLevel.grade5: <String>[
        'Understanding 12-Hour and 24-Hour Time',
        'Solving Operations Using GMDAS',
        'Multiplying and Dividing Fractions',
        'Finding the Area of Plane Figures',
        'Adding, Subtracting, and Multiplying Decimals',
        'Using Divisibility Rules',
        'Prime and Composite Numbers',
        'Understanding and Solving Probability',
        'GMDAS with Fractions and Decimals',
        'Finding the Surface Area of Solid Figures',
      ],
      GradeLevel.grade6: <String>[
        'Operations with Fractions, Whole Numbers, and Mixed Numbers',
        'Operations with Decimals',
        'Understanding Ratio and Proportion',
        'Exponents and GEMDAS',
        'Volume of Cubes and Rectangular Prisms',
        'Perimeter and Area of Plane and Composite Figures',
        'Parts and Circumference of a Circle',
        'Area of a Circle',
        'Common Factors and Greatest Common Factor (GCF)',
        'Common Multiples and Least Common Multiple (LCM)',
      ],
    };

/// Applies the curriculum sequence to the Teacher Lessons screen without
/// changing the repository query or persisted lesson records.
List<TeacherContentListEntry<Lesson>> orderTeacherLessons(
  Iterable<Lesson> lessons,
) {
  final List<Lesson> builtIn = <Lesson>[
    for (final Lesson lesson in lessons)
      if (lesson.sourceType == ContentSourceType.builtIn) lesson,
  ]..sort(_compareBuiltInLessons);
  final List<Lesson> teacherCreated = <Lesson>[
    for (final Lesson lesson in lessons)
      if (lesson.sourceType == ContentSourceType.teacher) lesson,
  ]..sort(_compareTeacherLessons);

  return <TeacherContentListEntry<Lesson>>[
    for (final Lesson lesson in builtIn)
      TeacherContentListEntry<Lesson>(
        content: lesson,
        sequenceNumber: _lessonSequenceNumber(lesson),
      ),
    for (int index = 0; index < teacherCreated.length; index++)
      TeacherContentListEntry<Lesson>(
        content: teacherCreated[index],
        sequenceNumber: teacherCreatedContentStartNumber + index,
      ),
  ];
}

/// Orders regular built-in quizzes by their `Quiz 1:` through `Quiz 10:`
/// prefixes. Pre-tests and post-tests remain unnumbered and do not consume a
/// curriculum number. Teacher-created quizzes continue from 11.
List<TeacherContentListEntry<Quiz>> orderTeacherQuizzes(
  Iterable<Quiz> quizzes,
) {
  final List<Quiz> builtIn = <Quiz>[
    for (final Quiz quiz in quizzes)
      if (quiz.sourceType == ContentSourceType.builtIn) quiz,
  ]..sort(_compareBuiltInQuizzes);
  final List<Quiz> teacherCreated = <Quiz>[
    for (final Quiz quiz in quizzes)
      if (quiz.sourceType == ContentSourceType.teacher) quiz,
  ]..sort(_compareTeacherQuizzes);

  return <TeacherContentListEntry<Quiz>>[
    for (final Quiz quiz in builtIn)
      TeacherContentListEntry<Quiz>(
        content: quiz,
        sequenceNumber: _quizSequenceNumber(quiz),
      ),
    for (int index = 0; index < teacherCreated.length; index++)
      TeacherContentListEntry<Quiz>(
        content: teacherCreated[index],
        sequenceNumber: teacherCreatedContentStartNumber + index,
      ),
  ];
}

int _compareBuiltInLessons(Lesson a, Lesson b) {
  final int byGrade = _gradeRank(
    a.gradeLevel,
  ).compareTo(_gradeRank(b.gradeLevel));
  if (byGrade != 0) return byGrade;

  final int bySequence = (_lessonSequenceNumber(a) ?? 999).compareTo(
    _lessonSequenceNumber(b) ?? 999,
  );
  if (bySequence != 0) return bySequence;
  return _compareByCreatedAtTitleAndId(
    a.createdAt,
    a.title,
    a.id,
    b.createdAt,
    b.title,
    b.id,
  );
}

int _compareBuiltInQuizzes(Quiz a, Quiz b) {
  final int byGrade = _gradeRank(
    a.gradeLevel,
  ).compareTo(_gradeRank(b.gradeLevel));
  if (byGrade != 0) return byGrade;

  final int byPhase = _quizPhase(a).compareTo(_quizPhase(b));
  if (byPhase != 0) return byPhase;

  final int bySequence = (_quizSequenceNumber(a) ?? 999).compareTo(
    _quizSequenceNumber(b) ?? 999,
  );
  if (bySequence != 0) return bySequence;
  return _compareByCreatedAtTitleAndId(
    a.createdAt,
    a.title,
    a.id,
    b.createdAt,
    b.title,
    b.id,
  );
}

int _compareTeacherLessons(Lesson a, Lesson b) {
  return _compareByCreatedAtTitleAndId(
    a.createdAt,
    a.title,
    a.id,
    b.createdAt,
    b.title,
    b.id,
  );
}

int _compareTeacherQuizzes(Quiz a, Quiz b) {
  return _compareByCreatedAtTitleAndId(
    a.createdAt,
    a.title,
    a.id,
    b.createdAt,
    b.title,
    b.id,
  );
}

int _compareByCreatedAtTitleAndId(
  DateTime aCreatedAt,
  String aTitle,
  String aId,
  DateTime bCreatedAt,
  String bTitle,
  String bId,
) {
  final int byCreatedAt = aCreatedAt.compareTo(bCreatedAt);
  if (byCreatedAt != 0) return byCreatedAt;
  final int byTitle = aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
  if (byTitle != 0) return byTitle;
  return aId.compareTo(bId);
}

int? _lessonSequenceNumber(Lesson lesson) {
  final List<String>? titles = _lessonTitlesByGrade[lesson.gradeLevel];
  if (titles == null) return null;
  final String normalizedTitle = _normalizeTitle(lesson.title);
  final int index = titles.indexWhere(
    (String title) => _normalizeTitle(title) == normalizedTitle,
  );
  return index == -1 ? null : index + 1;
}

int? _quizSequenceNumber(Quiz quiz) {
  if (quiz.assessmentType != null) return null;
  final Match? match = RegExp(
    r'^quiz\s+(10|[1-9])\s*:',
    caseSensitive: false,
  ).firstMatch(quiz.title.trim());
  return match == null ? null : int.parse(match.group(1)!);
}

int _quizPhase(Quiz quiz) => switch (quiz.assessmentType) {
  AssessmentType.preTest => 0,
  null when _quizSequenceNumber(quiz) != null => 1,
  AssessmentType.postTest => 2,
  null => 3,
};

int _gradeRank(GradeLevel? gradeLevel) => switch (gradeLevel) {
  GradeLevel.grade4 => 0,
  GradeLevel.grade5 => 1,
  GradeLevel.grade6 => 2,
  null => 3,
};

String _normalizeTitle(String title) {
  return title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
