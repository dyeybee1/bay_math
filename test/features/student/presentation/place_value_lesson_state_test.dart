import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/student/presentation/place_value_lesson_content.dart';
import 'package:instructional_math_app/features/student/presentation/place_value_lesson_state.dart';

void completeBoard(PlaceValueLessonState state) {
  final PlaceActivity task = state.current!;
  for (final int col in task.positions) {
    expect(
      state.drop(
        PlaceCard(PlaceCardKind.digit, task.digits[col]),
        PlaceTarget(PlaceTargetKind.digit, column: col),
      ),
      isTrue,
    );
  }
}

void completeExpanded(PlaceValueLessonState state) {
  final PlaceActivity task = state.current!;
  for (final int col in task.positions) {
    expect(
      state.drop(
        PlaceCard(
          PlaceCardKind.contribution,
          task.digits[col] * placeValueUnits[col],
          id: col,
        ),
        PlaceTarget(PlaceTargetKind.contribution, column: col),
      ),
      isTrue,
    );
  }
}

void completeIdentify(PlaceValueLessonState state) {
  final PlaceActivity task = state.current!;
  final int col = task.highlightedColumn;
  expect(
    state.drop(
      PlaceCard(PlaceCardKind.place, col, column: col),
      const PlaceTarget(PlaceTargetKind.place),
    ),
    isTrue,
  );
  expect(
    state.drop(
      PlaceCard(PlaceCardKind.value, task.digits[col] * placeValueUnits[col]),
      const PlaceTarget(PlaceTargetKind.value),
    ),
    isTrue,
  );
}

void completeRepeat(PlaceValueLessonState state) {
  final PlaceActivity task = state.current!;
  final List<int> values = task.repeatedValues;
  for (int i = 0; i < 2; i++) {
    expect(
      state.drop(
        PlaceCard(PlaceCardKind.value, values[i]),
        PlaceTarget(PlaceTargetKind.repeated, slot: i),
      ),
      isTrue,
    );
  }
  expect(
    state.drop(
      PlaceCard(PlaceCardKind.greater, values[0]),
      const PlaceTarget(PlaceTargetKind.greater),
    ),
    isTrue,
  );
}

void main() {
  test('matcher only selects the seeded built-in Grade 4 title', () {
    Lesson lesson({
      required ContentSourceType source,
      required GradeLevel grade,
      required String title,
    }) => Lesson(
      id: 'generated',
      title: title,
      body: '',
      sourceType: source,
      gradeLevel: grade,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(
      isPlaceValueLesson(
        lesson(
          source: ContentSourceType.builtIn,
          grade: GradeLevel.grade4,
          title: ' Place Value of Whole Numbers ',
        ),
      ),
      isTrue,
    );
    expect(
      isPlaceValueLesson(
        lesson(
          source: ContentSourceType.teacher,
          grade: GradeLevel.grade4,
          title: 'Place Value of Whole Numbers',
        ),
      ),
      isFalse,
    );
    expect(
      isPlaceValueLesson(
        lesson(
          source: ContentSourceType.builtIn,
          grade: GradeLevel.grade5,
          title: 'Place Value of Whole Numbers',
        ),
      ),
      isFalse,
    );
  });

  test('explore moves one active 5 and changes its value', () {
    final PlaceValueLessonState state = PlaceValueLessonState();
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.explore, 5),
        const PlaceTarget(PlaceTargetKind.explore, column: 4),
      ),
      isTrue,
    );
    expect(state.exploreColumn, 4);
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.explore, 5),
        const PlaceTarget(PlaceTargetKind.explore, column: 5),
      ),
      isTrue,
    );
    expect(state.exploreColumn, 5);
    expect(state.exploredColumns, <int>{4, 5});
  });

  test('alignment sources are distinct and consumed once', () {
    final PlaceValueLessonState state = PlaceValueLessonState()..navigate(1);
    const PlaceCard first = PlaceCard(PlaceCardKind.alignment, 5, id: 0);
    expect(
      state.drop(first, const PlaceTarget(PlaceTargetKind.digit, column: 2)),
      isFalse,
    );
    expect(
      state.drop(first, const PlaceTarget(PlaceTargetKind.digit, column: 1)),
      isTrue,
    );
    expect(
      state.drop(first, const PlaceTarget(PlaceTargetKind.digit, column: 1)),
      isFalse,
    );
    for (int i = 1; i < 6; i++) {
      final int digit = state.current!.digits[i + 1];
      expect(
        state.drop(
          PlaceCard(PlaceCardKind.alignment, digit, id: i),
          PlaceTarget(PlaceTargetKind.digit, column: i + 1),
        ),
        isTrue,
      );
    }
    expect(state.current!.done, isTrue);
  });

  test('place and value require separate correct matches', () {
    final PlaceValueLessonState state = PlaceValueLessonState()..navigate(1);
    state.indices[1] = 1;
    final PlaceActivity task = state.current!;
    expect(task.highlightedColumn, 3);
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.value, 8000),
        const PlaceTarget(PlaceTargetKind.place),
      ),
      isFalse,
    );
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.place, 3, column: 3),
        const PlaceTarget(PlaceTargetKind.place),
      ),
      isTrue,
    );
    expect(task.done, isFalse);
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.value, 80),
        const PlaceTarget(PlaceTargetKind.value),
      ),
      isFalse,
    );
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.value, 8000),
        const PlaceTarget(PlaceTargetKind.value),
      ),
      isTrue,
    );
    expect(task.done, isTrue);
  });

  test(
    'standard form requires all zero placeholders and leaves unused places blank',
    () {
      final PlaceValueLessonState state = PlaceValueLessonState()..navigate(2);
      state.indices[2] = 1;
      final PlaceActivity task = state.current!;
      expect(task.spec.number, 304005);
      for (final int col in task.positions.where(
        (int col) => task.digits[col] != 0,
      )) {
        state.drop(
          PlaceCard(PlaceCardKind.digit, task.digits[col]),
          PlaceTarget(PlaceTargetKind.digit, column: col),
        );
      }
      expect(task.done, isFalse);
      expect(
        state.drop(
          const PlaceCard(PlaceCardKind.digit, 0),
          const PlaceTarget(PlaceTargetKind.digit, column: 0),
        ),
        isFalse,
      );
      for (final int col in task.positions.where(
        (int col) => task.digits[col] == 0,
      )) {
        expect(
          state.drop(
            const PlaceCard(PlaceCardKind.digit, 0),
            PlaceTarget(PlaceTargetKind.digit, column: col),
          ),
          isTrue,
        );
      }
      expect(task.done, isTrue);
      expect(task.filled[0], isNull);
      state.indices[2] = 2;
      completeBoard(state);
      expect(state.current!.filled, <int?>[1, 0, 0, 0, 0, 0, 0]);
    },
  );

  test(
    'expanded terms match positions; interchangeable zero cards consume once',
    () {
      final PlaceValueLessonState state = PlaceValueLessonState()..navigate(5);
      state.indices[5] = 2;
      final PlaceActivity task = state.current!;
      expect(task.spec.number, 507030);
      final List<int> zeroColumns =
          task.positions.where((int col) => task.digits[col] == 0).toList();
      expect(zeroColumns.length, 3);
      expect(
        state.drop(
          PlaceCard(PlaceCardKind.contribution, 0, id: zeroColumns[0]),
          PlaceTarget(PlaceTargetKind.contribution, column: zeroColumns[1]),
        ),
        isTrue,
      );
      expect(
        state.drop(
          PlaceCard(PlaceCardKind.contribution, 0, id: zeroColumns[0]),
          PlaceTarget(PlaceTargetKind.contribution, column: zeroColumns[0]),
        ),
        isFalse,
      );
      final List<int> remaining = <int>[zeroColumns[1], zeroColumns[2]];
      for (int i = 0; i < remaining.length; i++) {
        final int destination = i == 0 ? zeroColumns[0] : zeroColumns[2];
        expect(
          state.drop(
            PlaceCard(PlaceCardKind.contribution, 0, id: remaining[i]),
            PlaceTarget(PlaceTargetKind.contribution, column: destination),
          ),
          isTrue,
        );
      }
      for (final int col in task.positions.where(
        (int col) => task.digits[col] != 0,
      )) {
        expect(
          state.drop(
            PlaceCard(
              PlaceCardKind.contribution,
              task.digits[col] * placeValueUnits[col],
              id: col,
            ),
            PlaceTarget(PlaceTargetKind.contribution, column: col),
          ),
          isTrue,
        );
      }
      expect(task.done, isTrue);
      expect(task.usedCards.length, 6);
      expect(placeExpandedTerms(507030), <int>[500000, 0, 7000, 0, 30, 0]);
      expect(placeExpandedTerms(304952, includeZeros: false), <int>[
        300000,
        4000,
        900,
        50,
        2,
      ]);
    },
  );

  test('both repeated digits have distinct values and greater answer', () {
    final PlaceValueLessonState state = PlaceValueLessonState()..navigate(4);
    final PlaceActivity task = state.current!;
    expect(task.repeatedValues, <int>[400000, 40000]);
    expect(
      state.drop(
        const PlaceCard(PlaceCardKind.value, 40000),
        const PlaceTarget(PlaceTargetKind.repeated, slot: 0),
      ),
      isFalse,
    );
    completeRepeat(state);
    expect(task.done, isTrue);
    expect(task.greater, 400000);
  });

  test(
    'all activities complete, navigation preserves answers and recap is gated',
    () {
      final PlaceValueLessonState state = PlaceValueLessonState()..navigate(5);
      expect(state.nextActivity(), isFalse);
      completeIdentify(state);
      expect(state.nextActivity(), isTrue);
      completeBoard(state);
      expect(state.nextActivity(), isTrue);
      completeExpanded(state);
      expect(state.nextActivity(), isTrue);
      completeRepeat(state);
      expect(state.practiceDone, isTrue);
      expect(state.nextActivity(), isTrue);
      expect(state.recap, isTrue);
      state.navigate(1);
      state.navigate(5);
      expect(state.recap, isTrue);
      expect(state.tasks[5][1].filled[1], 2);
      state.reviewPractice();
      expect(state.recap, isFalse);
      expect(state.tasks[5].every((PlaceActivity task) => task.done), isTrue);
    },
  );

  test('every seeded activity accepts its complete mathematical answer', () {
    final PlaceValueLessonState state = PlaceValueLessonState();
    for (int phase = 1; phase <= 5; phase++) {
      state.navigate(phase);
      for (int index = 0; index < state.tasks[phase].length; index++) {
        state.indices[phase] = index;
        final PlaceActivity task = state.current!;
        switch (task.spec.type) {
          case PlaceTaskType.align:
            for (int i = 0; i < task.positions.length; i++) {
              final int col = task.positions[i];
              expect(
                state.drop(
                  PlaceCard(PlaceCardKind.alignment, task.digits[col], id: i),
                  PlaceTarget(PlaceTargetKind.digit, column: col),
                ),
                isTrue,
              );
            }
          case PlaceTaskType.identify:
            completeIdentify(state);
          case PlaceTaskType.standard || PlaceTaskType.reverse:
            completeBoard(state);
          case PlaceTaskType.expanded:
            completeExpanded(state);
          case PlaceTaskType.repeat:
            completeRepeat(state);
        }
        expect(task.done, isTrue, reason: 'phase $phase activity $index');
      }
    }
    expect(state.practiceDone, isTrue);
  });
}
