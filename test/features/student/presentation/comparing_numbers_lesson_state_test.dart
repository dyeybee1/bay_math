import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/student/presentation/comparing_numbers_lesson_state.dart';
import 'package:instructional_math_app/features/student/presentation/comparing_numbers_lesson_math.dart';

void main() {
  Lesson lesson({
    String title = 'Comparing Numbers up to 1,000,000',
    ContentSourceType source = ContentSourceType.builtIn,
    GradeLevel grade = GradeLevel.grade4,
  }) => Lesson(
    id: 'seed-generated-id',
    title: title,
    body: 'Unrelated content',
    sourceType: source,
    gradeLevel: grade,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('only the intended built-in Grade 4 lesson matches', () {
    expect(isComparingNumbersLesson(lesson()), isTrue);
    expect(
      isComparingNumbersLesson(
        lesson(title: ' Comparing   Numbers up to 1,000,000 '),
      ),
      isTrue,
    );
    expect(
      isComparingNumbersLesson(lesson(source: ContentSourceType.teacher)),
      isFalse,
    );
    expect(isComparingNumbersLesson(lesson(grade: GradeLevel.grade5)), isFalse);
    expect(isComparingNumbersLesson(lesson(title: 'Other lesson')), isFalse);
  });

  test('first different digit decides, including digit count boundary', () {
    expect(const ComparisonCase(723450, 723405).decidingIndex, 4);
    expect(const ComparisonCase(305678, 350678).decidingIndex, 1);
    expect(const ComparisonCase(640000, 640000).decidingIndex, -1);
    expect(const ComparisonCase(999999, 1000000).symbol, '<');
    expect(const ComparisonCase(999999, 1000000).decidingIndex, 0);
    expect(formatNumber(1000000), '1,000,000');
  });

  test('start retries, hints, and navigating retain answers', () {
    final state = ComparingNumbersLessonState();
    state.chooseIntro(58000);
    expect(state.introFeedback?.correct, isFalse);
    state.addHint();
    expect(state.hint, contains('ten thousands'));
    state.chooseIntro(85000);
    expect(state.introSolved, isTrue);
    state.navigate(1);
    state.compareColumn();
    state.navigate(0);
    state.navigate(1);
    expect(state.learn.checked, isTrue);
    expect(state.introChoice, 85000);
  });

  test('demonstration stops at tens and replay resets it', () {
    final state = ComparingNumbersLessonState()..navigate(1);
    for (int i = 0; i < 4; i++) {
      state.compareColumn();
      expect(state.learn.readyForSymbol, isFalse);
      state.nextColumn();
    }
    expect(state.learn.cursor, 4);
    state.compareColumn();
    expect(state.learn.readyForSymbol, isTrue);
    state.nextColumn();
    expect(state.learn.cursor, 4);
    state.replayLearn();
    expect(state.learn.cursor, 0);
    expect(state.learn.checked, isFalse);
  });

  test('guided places, symbols, and next example handle retries', () {
    final state = ComparingNumbersLessonState()..navigate(2);
    state.choosePlace(0);
    expect(state.guided.feedback?.detail, contains('match'));
    state.choosePlace(5);
    expect(state.guided.feedback?.detail, contains('earlier'));
    state.choosePlace(4);
    state.answerSymbol('<');
    expect(state.guided.solved, isFalse);
    state.answerSymbol('>');
    expect(state.guided.solved, isTrue);
    state.nextExercise();
    expect(state.guided.index, 1);
    state.choosePlace(1);
    state.answerSymbol('<');
    expect(state.guided.solved, isTrue);
  });

  test('equality checks all columns and counts digits without commas', () {
    final state = ComparingNumbersLessonState()..navigate(3);
    for (int i = 0; i < 5; i++) {
      state.compareColumn();
      expect(state.special.readyForSymbol, isFalse);
      state.nextColumn();
    }
    state.compareColumn();
    expect(state.special.readyForSymbol, isTrue);
    state.answerSymbol('>');
    expect(state.special.feedback?.detail, contains('all six columns'));
    state.answerSymbol('=');
    state.nextExercise();
    expect(state.special.index, 1);
    expect(state.special.readyForSymbol, isFalse);
    state.countDigits();
    expect(state.special.counted, isTrue);
    expect(state.currentCase.first.toString().length, 6);
    expect(state.currentCase.second.toString().length, 7);
    state.answerSymbol('<');
    expect(state.special.solved, isTrue);
  });

  test('practice requires three correct answers before recap', () {
    final state = ComparingNumbersLessonState()..navigate(4);
    state.answerSymbol('>');
    expect(state.practice.feedback?.detail, contains('Compare digit counts'));
    state.addHint();
    state.addHint();
    expect(state.hint, contains('7 digits'));
    state.answerSymbol('<');
    state.nextExercise();
    expect(state.practice.index, 1);
    state.answerSymbol('>');
    state.nextExercise();
    expect(state.practice.index, 2);
    state.answerSymbol('=');
    expect(state.practiceDone, isFalse);
    state.nextExercise();
    expect(state.practiceDone, isTrue);
    expect(state.finished, isFalse);
    state.nextExercise();
    expect(state.practiceDone, isTrue);
  });
}
