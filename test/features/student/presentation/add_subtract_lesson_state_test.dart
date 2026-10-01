import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/student/presentation/add_subtract_lesson_content.dart';
import 'package:instructional_math_app/features/student/presentation/add_subtract_lesson_math.dart';
import 'package:instructional_math_app/features/student/presentation/add_subtract_lesson_state.dart';

void solveCurrent(AddSubtractLessonState state) {
  final ArithmeticWork work = state.currentWork!;
  int guard = 0;
  while (!work.done) {
    expect(guard++, lessThan(60));
    switch (work.mode) {
      case ArithmeticMode.carry:
        expect(
          state.place(
            LessonTile.carry(work.column - 1),
            LessonZone.carry(work.column - 1),
          ),
          isTrue,
        );
      case ArithmeticMode.exchange:
        final int donor = work.donorColumn!;
        expect(
          state.place(
            LessonTile.exchange(donor),
            LessonZone.exchange(donor + 1),
          ),
          isTrue,
        );
        expect(work.conservedTopValue, work.problem.first);
      case ArithmeticMode.answer:
        expect(
          state.place(
            LessonTile.digit(work.expectedDigit),
            LessonZone.answer(work.column),
          ),
          isTrue,
        );
      case ArithmeticMode.checked:
        expect(state.continueColumn(), isTrue);
      case ArithmeticMode.done:
        break;
    }
  }
  final int builtAnswer = int.parse(
    work.results.map((int? digit) => digit?.toString() ?? '0').join(),
  );
  expect(builtAnswer, work.problem.answer);
}

void main() {
  Lesson lesson({
    String title = 'Addition and Subtraction of Numbers up to 1,000,000',
    ContentSourceType source = ContentSourceType.builtIn,
    GradeLevel grade = GradeLevel.grade4,
  }) => Lesson(
    id: 'seed-generated-id',
    title: title,
    body: 'Different paragraph',
    sourceType: source,
    gradeLevel: grade,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('matcher is limited to the built-in Grade 4 full title', () {
    expect(isAddSubtractLesson(lesson()), isTrue);
    expect(
      isAddSubtractLesson(
        lesson(
          title: ' Addition and   Subtraction of Numbers up to 1,000,000 ',
        ),
      ),
      isTrue,
    );
    expect(
      isAddSubtractLesson(lesson(source: ContentSourceType.teacher)),
      isFalse,
    );
    expect(isAddSubtractLesson(lesson(grade: GradeLevel.grade5)), isFalse);
    expect(isAddSubtractLesson(lesson(title: 'Another lesson')), isFalse);
  });

  test('wrong operation retries, correct operation locks once', () {
    final state = AddSubtractLessonState();
    expect(
      state.place(
        const LessonTile.operation('−'),
        const LessonZone.operation(),
      ),
      isFalse,
    );
    expect(state.startFeedback?.detail, contains('receives more books'));
    expect(state.startDone, isFalse);
    expect(
      state.place(
        const LessonTile.operation('+'),
        const LessonZone.operation(),
      ),
      isTrue,
    );
    expect(state.startDone, isTrue);
    expect(
      state.place(
        const LessonTile.operation('+'),
        const LessonZone.operation(),
      ),
      isFalse,
    );
  });

  test(
    'alignment checks row and column and keeps duplicate sixes distinct',
    () {
      final state = AddSubtractLessonState()..navigate(1);
      const sixA = LessonTile.alignment(1, 2, 6);
      const sixB = LessonTile.alignment(1, 3, 6);
      expect(sixA.identity, isNot(sixB.identity));
      expect(state.place(sixA, const LessonZone.alignment(0, 4)), isFalse);
      expect(state.place(sixA, const LessonZone.alignment(1, 3)), isFalse);
      expect(state.place(sixA, const LessonZone.alignment(1, 4)), isTrue);
      expect(state.place(sixB, const LessonZone.alignment(1, 5)), isTrue);
      expect(state.alignmentPlaced[1][4], 2);
      expect(state.alignmentPlaced[1][5], 3);
      expect(state.place(sixA, const LessonZone.alignment(1, 4)), isFalse);
      for (int row = 0; row < 2; row++) {
        final String digits =
            AddSubtractLessonState.alignmentNumbers[row].toString();
        for (int i = 0; i < digits.length; i++) {
          if (state.alignmentPlaced[row].contains(i)) continue;
          expect(
            state.place(
              LessonTile.alignment(row, i, int.parse(digits[i])),
              LessonZone.alignment(row, 7 - digits.length + i),
            ),
            isTrue,
          );
        }
      }
      expect(state.alignmentDone, isTrue);
      expect(state.alignmentPlaced[1].first, isNull);
    },
  );

  test('carry moves only to adjacent left space and affects next column', () {
    final state = AddSubtractLessonState()..navigate(2);
    state.nextExercise(); // Unfinished work cannot be skipped.
    expect(state.additionIndex, 0);
    state.additionIndex = 1;
    final ArithmeticWork work = state.currentWork!;
    expect(
      state.place(const LessonTile.digit(0), const LessonZone.answer(6)),
      isTrue,
    );
    expect(state.continueColumn(), isTrue);
    expect(work.column, 5);
    expect(work.mode, ArithmeticMode.carry);
    expect(
      state.place(const LessonTile.carry(4), const LessonZone.carry(3)),
      isFalse,
    );
    expect(work.carries[4], 0);
    expect(
      state.place(const LessonTile.carry(4), const LessonZone.carry(4)),
      isTrue,
    );
    expect(work.carries[4], 1);
    expect(
      state.place(const LessonTile.carry(4), const LessonZone.carry(4)),
      isFalse,
    );
    expect(
      state.place(const LessonTile.digit(0), const LessonZone.answer(5)),
      isTrue,
    );
    expect(state.continueColumn(), isTrue);
    expect(work.column, 4);
    expect(work.total, 10); // 3 + 6 + incoming carry.
  });

  test('wrong answer and wrong answer cell leave result hidden', () {
    final state = AddSubtractLessonState()..navigate(2);
    final ArithmeticWork work = state.currentWork!;
    expect(
      state.place(const LessonTile.digit(0), const LessonZone.answer(5)),
      isFalse,
    );
    expect(
      state.place(const LessonTile.digit(1), const LessonZone.answer(6)),
      isFalse,
    );
    expect(work.results[6], isNull);
    expect(
      state.place(const LessonTile.digit(0), const LessonZone.answer(6)),
      isTrue,
    );
    expect(work.results[6], 0);
  });

  test('zero-chain exchange is adjacent and conserves 700,000', () {
    final state = AddSubtractLessonState()..navigate(3);
    state.subtractionIndex = 1;
    final ArithmeticWork work = state.currentWork!;
    expect(work.mode, ArithmeticMode.exchange);
    expect(work.donorColumn, 1);
    expect(
      state.place(const LessonTile.exchange(1), const LessonZone.exchange(4)),
      isFalse,
    );
    expect(
      state.place(const LessonTile.exchange(2), const LessonZone.exchange(3)),
      isFalse,
    );
    expect(work.conservedTopValue, 700000);
    for (int donor = 1; donor < 6; donor++) {
      expect(
        state.place(LessonTile.exchange(donor), LessonZone.exchange(donor + 1)),
        isTrue,
      );
      expect(work.conservedTopValue, 700000);
    }
    expect(work.top, <int>[0, 6, 9, 9, 9, 9, 10]);
    expect(work.mode, ArithmeticMode.answer);
    expect(work.expectedDigit, 1);
  });

  test('all nine examples and practice problems build correct answers', () {
    final state = AddSubtractLessonState();
    for (int phase = 2; phase <= 4; phase++) {
      state.navigate(phase);
      final int count =
          phase == 2
              ? 3
              : phase == 3
              ? 2
              : 4;
      for (int i = 0; i < count; i++) {
        solveCurrent(state);
        if (i < count - 1) expect(state.nextExercise(), isTrue);
      }
    }
    expect(state.additions.last.problem.answer, 1000000);
    expect(state.additions.last.results[0], 1);
    expect(state.subtractions.first.results[6], 0);
    expect(state.practiceDone, isTrue);
    expect(state.practiceCompleteCount, 4);
    expect(state.finished, isFalse);
  });

  test('hints, selection cancellation, and phase navigation retain work', () {
    final state = AddSubtractLessonState()..navigate(4);
    final ArithmeticWork work = state.currentWork!;
    state.select(const LessonTile.digit(0));
    expect(state.selected?.value, 0);
    state.clearSelection(); // Pointer cancellation or Escape.
    expect(work.results[6], isNull);
    state.addHint();
    expect(state.calculationHint, contains('updated top value'));
    state.addHint();
    expect(state.calculationHint, contains('answer digit'));
    expect(
      state.place(const LessonTile.digit(0), const LessonZone.answer(6)),
      isTrue,
    );
    state.navigate(1);
    state.navigate(4);
    expect(state.currentWork, same(work));
    expect(work.results[6], 0);
  });
}
