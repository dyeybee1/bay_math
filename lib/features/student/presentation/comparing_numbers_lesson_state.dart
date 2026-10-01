import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/section.dart';
import 'comparing_numbers_lesson_content.dart' as content;
import 'comparing_numbers_lesson_math.dart';

/// The seed assigns random lesson UUIDs, so identify this one built-in lesson
/// by its stable source, grade and normalized title instead of page text.
bool isComparingNumbersLesson(Lesson lesson) =>
    lesson.sourceType == ContentSourceType.builtIn &&
    lesson.gradeLevel == GradeLevel.grade4 &&
    lesson.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
        'comparing numbers up to 1,000,000';

class ComparisonFeedback {
  const ComparisonFeedback(this.title, this.detail, {required this.correct});
  final String title;
  final String detail;
  final bool correct;
}

class ComparisonExercise {
  int index = 0;
  int cursor = 0;
  bool checked = false;
  bool readyForSymbol = false;
  bool counted = false;
  bool solved = false;
  int errors = 0;
  int hints = 0;
  int? selectedPlace;
  String? selectedSymbol;
  ComparisonFeedback? feedback;
}

class ComparingNumbersLessonState {
  static const List<ComparisonCase> guidedCases = content.guidedComparisonCases;
  static const List<ComparisonCase> specialCases =
      content.specialComparisonCases;
  static const List<ComparisonCase> practiceCases =
      content.practiceComparisonCases;

  int phase = 0;
  int? introChoice;
  bool introSolved = false;
  int introHints = 0;
  ComparisonFeedback? introFeedback;
  ComparisonExercise learn = ComparisonExercise();
  ComparisonExercise guided = ComparisonExercise();
  ComparisonExercise special = ComparisonExercise();
  ComparisonExercise practice = ComparisonExercise()..readyForSymbol = true;
  bool practiceDone = false;
  bool finished = false;

  ComparisonCase get currentCase => switch (phase) {
    2 => guidedCases[guided.index],
    3 => specialCases[special.index],
    4 => practiceCases[practice.index],
    _ => guidedCases[0],
  };
  ComparisonExercise get currentExercise => switch (phase) {
    1 => learn,
    2 => guided,
    3 => special,
    _ => practice,
  };

  void navigate(int target) {
    phase = target.clamp(0, 4);
  }

  void chooseIntro(int number) {
    if (introSolved) return;
    introChoice = number;
    if (number == 85000) {
      introSolved = true;
      introFeedback = const ComparisonFeedback(
        'Good comparison!',
        '85,000 has 8 ten thousands. 58,000 has 5 ten thousands.',
        correct: true,
      );
    } else {
      introFeedback = const ComparisonFeedback(
        'Try the leftmost digits.',
        'Compare 8 and 5. Which digit is greater?',
        correct: false,
      );
    }
  }

  void compareColumn() {
    final ComparisonExercise item = phase == 1 ? learn : special;
    if (item.checked || item.readyForSymbol || item.solved) return;
    final ComparisonCase example =
        phase == 1 ? guidedCases[0] : specialCases[0];
    item.checked = true;
    if (example.firstDigits[item.cursor] != example.secondDigits[item.cursor] ||
        item.cursor == example.length - 1) {
      item.readyForSymbol = true;
    }
  }

  void nextColumn() {
    final ComparisonExercise item = phase == 1 ? learn : special;
    if (!item.checked || item.readyForSymbol) return;
    item.cursor++;
    item.checked = false;
  }

  void replayLearn() {
    learn = ComparisonExercise();
  }

  void choosePlace(int index) {
    if (phase != 2 || guided.readyForSymbol) return;
    guided.selectedPlace = index;
    final ComparisonCase example = currentCase;
    if (index == example.decidingIndex) {
      guided.readyForSymbol = true;
      guided.feedback = ComparisonFeedback(
        'You found the deciding place!',
        'Compare ${example.firstDigits[index]} and ${example.secondDigits[index]} '
            'in the ${example.place(index).toLowerCase()} column. Now choose a symbol.',
        correct: true,
      );
    } else {
      guided.errors++;
      guided.feedback = ComparisonFeedback(
        'Look from the left.',
        index < example.decidingIndex
            ? 'These digits match. Move one place to the right.'
            : 'An earlier place is different. Start from the left.',
        correct: false,
      );
    }
  }

  void countDigits() {
    if (phase != 3 || special.index != 1) return;
    special.counted = true;
    special.readyForSymbol = true;
  }

  void answerSymbol(String symbol) {
    if (phase < 2 || phase > 4) return;
    final ComparisonExercise item = currentExercise;
    if (!item.readyForSymbol || item.solved) return;
    item.selectedSymbol = symbol;
    final ComparisonCase example = currentCase;
    if (symbol == example.symbol) {
      item.solved = true;
      item.feedback = ComparisonFeedback(
        phase == 3 && special.index == 0
            ? 'Equal numbers!'
            : 'Correct comparison!',
        example.explanation,
        correct: true,
      );
    } else {
      item.errors++;
      final String detail =
          phase == 3 && special.index == 0
              ? 'Look at all six columns. Every pair matches. Choose the symbol for equal numbers.'
              : phase == 3 && special.index == 1
              ? example.explanation
              : phase == 4 && item.errors == 1
              ? 'Compare digit counts first. If they match, start at the leftmost digit.'
              : example.explanation;
      item.feedback = ComparisonFeedback(
        'Try another symbol.',
        detail,
        correct: false,
      );
    }
  }

  void nextExercise() {
    final ComparisonExercise item = currentExercise;
    if (!item.solved) return;
    if (phase == 2 && guided.index < 1) {
      guided = ComparisonExercise()..index = 1;
    } else if (phase == 3 && special.index < 1) {
      special = ComparisonExercise()..index = 1;
    } else if (phase == 4) {
      if (practice.index < 2) {
        practice =
            ComparisonExercise()
              ..index = item.index + 1
              ..readyForSymbol = true;
      } else {
        practiceDone = true;
      }
    }
  }

  void addHint() {
    if (phase == 0) introHints++;
    if (phase >= 2) currentExercise.hints++;
  }

  String get hint {
    if (phase == 0) {
      return 'Both numbers have 5 digits. Start at the ten thousands place.';
    }
    if (phase == 1) {
      return 'Read the highlighted pair. Move right only if the digits match.';
    }
    final ComparisonCase example = currentCase;
    if (currentExercise.hints > 1) return example.explanation;
    if (example.first == example.second) {
      return 'Compare every place. Equal numbers have the same digit in every column.';
    }
    if (example.first.toString().length != example.second.toString().length) {
      return 'Count the digits. Do not count commas.';
    }
    return 'Start at the leftmost column. Stop at the first different digit.';
  }
}
