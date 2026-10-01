import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/section.dart';

/// Seeded lessons receive generated UUIDs. This narrowly scoped matcher uses
/// stable metadata and the full title, never lesson-page or paragraph text.
bool isAddSubtractLesson(Lesson lesson) =>
    lesson.sourceType == ContentSourceType.builtIn &&
    lesson.gradeLevel == GradeLevel.grade4 &&
    lesson.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
        'addition and subtraction of numbers up to 1,000,000';

const List<String> addSubtractPhases = <String>[
  'Start',
  'Place value',
  'Addition',
  'Subtraction',
  'Practice',
  'Recap',
];
const List<String> placeNames = <String>[
  'Millions',
  'Hundred thousands',
  'Ten thousands',
  'Thousands',
  'Hundreds',
  'Tens',
  'Ones',
];
const List<String> unitNames = <String>[
  'million',
  'hundred thousand',
  'ten thousand',
  'thousand',
  'hundred',
  'ten',
  'one',
];

class ArithmeticProblem {
  const ArithmeticProblem(this.operation, this.first, this.second);
  final String operation;
  final int first;
  final int second;
  int get answer => operation == '+' ? first + second : first - second;
}

const List<ArithmeticProblem> additionProblems = <ArithmeticProblem>[
  ArithmeticProblem('+', 245000, 132500),
  ArithmeticProblem('+', 512340, 87660),
  ArithmeticProblem('+', 999999, 1),
];
const List<ArithmeticProblem> subtractionProblems = <ArithmeticProblem>[
  ArithmeticProblem('−', 875432, 432432),
  ArithmeticProblem('−', 700000, 256789),
];
const List<ArithmeticProblem> practiceProblems = <ArithmeticProblem>[
  ArithmeticProblem('+', 234120, 125230),
  ArithmeticProblem('+', 368750, 241680),
  ArithmeticProblem('−', 865430, 243210),
  ArithmeticProblem('−', 500000, 176458),
];
