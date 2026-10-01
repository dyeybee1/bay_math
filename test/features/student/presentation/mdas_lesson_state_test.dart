import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/student/presentation/mdas_lesson_content.dart';
import 'package:instructional_math_app/features/student/presentation/mdas_lesson_state.dart';

void completeExpression(MdasLessonState state) {
  final MdasActivity task = state.current;
  while (!task.done) {
    if (task.step == MdasStep.choose) {
      expect(state.chooseOperation(task.activeOperation), isTrue);
    } else {
      expect(state.chooseAnswer(task.activeResult), isTrue);
    }
  }
}

void main() {
  test('matcher is limited to the built-in Grade 4 title', () {
    Lesson lesson(ContentSourceType source, GradeLevel grade, String title) =>
        Lesson(
          id: 'generated',
          title: title,
          body: '',
          sourceType: source,
          gradeLevel: grade,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
    expect(
      isMdasLesson(
        lesson(
          ContentSourceType.builtIn,
          GradeLevel.grade4,
          ' Multiplication, Division, and MDAS ',
        ),
      ),
      isTrue,
    );
    expect(
      isMdasLesson(
        lesson(
          ContentSourceType.teacher,
          GradeLevel.grade4,
          'Multiplication, Division, and MDAS',
        ),
      ),
      isFalse,
    );
    expect(
      isMdasLesson(
        lesson(
          ContentSourceType.builtIn,
          GradeLevel.grade5,
          'Multiplication, Division, and MDAS',
        ),
      ),
      isFalse,
    );
  });

  test(
    'grouping totals update and duplicate drops do not consume a bundle',
    () {
      final MdasLessonState state = MdasLessonState();
      expect(state.next(), isFalse);
      expect(
        state.drop(
          const MdasCard(MdasCardKind.bundle, id: 0),
          const MdasTarget(MdasTargetKind.tray, id: 0),
        ),
        isTrue,
      );
      expect(state.current.runningTotal, 6);
      expect(
        state.drop(
          const MdasCard(MdasCardKind.bundle, id: 0),
          const MdasTarget(MdasTargetKind.tray, id: 1),
        ),
        isFalse,
      );
      expect(
        state.drop(
          const MdasCard(MdasCardKind.bundle, id: 1),
          const MdasTarget(MdasTargetKind.tray, id: 0),
        ),
        isFalse,
      );
      expect(state.current.runningTotal, 6);
      for (int i = 1; i < 4; i++) {
        expect(
          state.drop(
            MdasCard(MdasCardKind.bundle, id: i),
            MdasTarget(MdasTargetKind.tray, id: i),
          ),
          isTrue,
        );
      }
      expect(state.current.runningTotal, 24);
      expect(state.current.done, isTrue);
      expect(state.next(), isTrue);
      expect(state.indices[0], 1);
      expect(state.previous(), isTrue);
      expect(state.current.placedBundles.length, 4);
    },
  );

  test('division moves exactly one outlined group at a time', () {
    final MdasLessonState state = MdasLessonState()..phase = 1;
    final MdasActivity task = state.current;
    expect(task.remainingObjects, 24);
    expect(
      state.drop(
        const MdasCard(MdasCardKind.group, id: 0),
        const MdasTarget(MdasTargetKind.newGroup),
      ),
      isTrue,
    );
    expect(task.remainingObjects, 18);
    expect(
      state.drop(
        const MdasCard(MdasCardKind.group, id: 0),
        const MdasTarget(MdasTargetKind.newGroup),
      ),
      isFalse,
    );
    expect(task.groupsMade, 1);
    for (int i = 1; i < 4; i++) {
      expect(
        state.drop(
          MdasCard(MdasCardKind.group, id: i),
          const MdasTarget(MdasTargetKind.newGroup),
        ),
        isTrue,
      );
    }
    expect(task.remainingObjects, 0);
    expect(task.done, isTrue);
    for (final MdasTaskSpec spec in mdasTasks[1]) {
      expect(spec.a ~/ spec.b * spec.b, spec.a);
    }
  });

  test(
    'all four related equations require twelve correct number placements',
    () {
      final MdasLessonState state = MdasLessonState()..phase = 2;
      const List<int> expected = <int>[6, 4, 24, 4, 6, 24, 24, 6, 4, 24, 4, 6];
      expect(
        state.drop(
          const MdasCard(MdasCardKind.number, number: 6),
          const MdasTarget(MdasTargetKind.fact, id: 6),
        ),
        isFalse,
      );
      expect(state.current.facts, isEmpty);
      for (int i = 0; i < expected.length; i++) {
        expect(
          state.drop(
            MdasCard(MdasCardKind.number, number: expected[i]),
            MdasTarget(MdasTargetKind.fact, id: i),
          ),
          isTrue,
        );
      }
      expect(state.current.facts.length, 12);
      expect(state.current.done, isTrue);
    },
  );

  test('MDAS priority rows accept either order within a pair', () {
    final MdasLessonState state = MdasLessonState()..phase = 3;
    final MdasActivity task = state.current;
    expect(
      state.drop(
        const MdasCard(MdasCardKind.operation, operation: '+'),
        const MdasTarget(MdasTargetKind.priority, id: 0, row: 0),
      ),
      isFalse,
    );
    for (final (String symbol, int slot, int row) in <(String, int, int)>[
      ('÷', 0, 0),
      ('×', 1, 0),
      ('−', 2, 1),
      ('+', 3, 1),
    ]) {
      expect(
        state.drop(
          MdasCard(MdasCardKind.operation, operation: symbol),
          MdasTarget(MdasTargetKind.priority, id: slot, row: row),
        ),
        isTrue,
      );
    }
    expect(task.priorities[0], '÷');
    expect(task.priorities[1], '×');
    expect(task.done, isTrue);
  });

  test('first operation follows priority and then left to right', () {
    expect(mdasFirstOperation(<Object>[8, '×', 3, '+', 6]), 1);
    expect(mdasFirstOperation(<Object>[24, '÷', 6, '×', 2]), 1);
    expect(mdasFirstOperation(<Object>[20, '−', 6, '+', 2]), 1);
    final MdasLessonState state = MdasLessonState()..phase = 3;
    state.indices[3] = 2;
    expect(state.chooseOperation(3), isFalse);
    expect(state.current.feedback!.text, contains('left'));
    expect(state.chooseOperation(1), isTrue);
    expect(state.current.done, isTrue);
  });

  test(
    'single tap chooses operation and answer, preserving expression on errors',
    () {
      final MdasLessonState state = MdasLessonState()..phase = 4;
      final MdasActivity task = state.current;
      expect(state.chooseOperation(3), isFalse);
      expect(task.expression, <Object>[8, '×', 3, '+', 6]);
      expect(state.chooseOperation(1), isTrue);
      expect(task.step, MdasStep.result);
      expect(state.chooseAnswer(18), isFalse);
      expect(task.expression, <Object>[8, '×', 3, '+', 6]);
      expect(task.history, isEmpty);
      expect(state.chooseAnswer(24), isTrue);
      expect(task.expression, <Object>[24, '+', 6]);
      expect(task.history, <String>['8 × 3 = 24']);
      expect(state.chooseOperation(1), isTrue);
      expect(state.chooseAnswer(30), isTrue);
      expect(task.expression, <Object>[30]);
      expect(task.done, isTrue);
    },
  );

  test('division and multiplication replace only the solved left segment', () {
    final MdasLessonState state = MdasLessonState()..phase = 4;
    state.indices[4] = 1;
    final MdasActivity task = state.current;
    expect(state.chooseOperation(3), isFalse);
    expect(state.chooseOperation(1), isTrue);
    expect(state.chooseAnswer(4), isTrue);
    expect(task.expression, <Object>[4, '×', 2]);
    expect(state.chooseOperation(1), isTrue);
    expect(state.chooseAnswer(8), isTrue);
    expect(task.history, <String>['24 ÷ 6 = 4', '4 × 2 = 8']);
    expect(task.done, isTrue);
    state.indices[4] = 2;
    completeExpression(state);
    expect(state.current.expression, <Object>[16]);
  });

  test(
    'word problems choose operation then answer, with sharing distinct from grouping',
    () {
      final MdasLessonState state = MdasLessonState()..phase = 5;
      expect(state.chooseAnswer(96), isFalse);
      expect(state.chooseStoryOperation('÷'), isFalse);
      expect(state.chooseStoryOperation('×'), isTrue);
      expect(state.chooseAnswer(96), isTrue);
      state.indices[5] = 1;
      expect(state.chooseStoryOperation('÷'), isTrue);
      expect(state.chooseAnswer(8), isTrue);
      expect(state.current.done, isTrue);
    },
  );

  test(
    'practice gates recap, and navigation preserves history and feedback',
    () {
      final MdasLessonState state = MdasLessonState()..phase = 6;
      expect(state.next(), isFalse);
      expect(state.chooseAnswer(35), isTrue);
      expect(state.next(), isTrue);
      expect(state.chooseAnswer(6), isTrue);
      expect(state.next(), isTrue);
      completeExpression(state);
      expect(state.current.expression, <Object>[12]);
      expect(state.next(), isTrue);
      completeExpression(state);
      expect(state.current.expression, <Object>[14]);
      expect(state.practiceDone, isTrue);
      expect(state.next(), isTrue);
      expect(state.recap, isTrue);
      expect(state.previous(), isTrue);
      expect(state.current.history.length, 2);
      state.reviewPractice();
      expect(state.current.answer, 35);
    },
  );
}
