import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/student/presentation/fractions_lesson_content.dart';
import 'package:instructional_math_app/features/student/presentation/fractions_lesson_state.dart';

void main() {
  test('only the seeded Grade 4 built-in lesson uses the custom screen', () {
    Lesson lesson({
      String title = 'Types of Fractions',
      GradeLevel grade = GradeLevel.grade4,
      ContentSourceType source = ContentSourceType.builtIn,
    }) => Lesson(
      id: 'lesson',
      title: title,
      body: '',
      sourceType: source,
      gradeLevel: grade,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(isTypesOfFractionsLesson(lesson()), isTrue);
    expect(
      isTypesOfFractionsLesson(lesson(title: 'Types of Fractions 2')),
      isFalse,
    );
    expect(isTypesOfFractionsLesson(lesson(grade: GradeLevel.grade5)), isFalse);
    expect(
      isTypesOfFractionsLesson(lesson(source: ContentSourceType.teacher)),
      isFalse,
    );
  });

  test('models use equal whole strips with exact shaded counts', () {
    expect(fractionsActivities[2][0].shadedPartsByStrip, <int>[4, 3]);
    expect(fractionsActivities[2][1].shadedPartsByStrip, <int>[5, 4]);
    expect(fractionsActivities[2][2].shadedPartsByStrip, <int>[6]);
    expect(fractionsActivities[4][1].shadedPartsByStrip, <int>[4, 4, 1]);
    expect(fractionsActivities[5][1].shadedPartsByStrip, <int>[3, 3, 2]);
    expect(fractionsActivities[5][2].shadedPartsByStrip, <int>[5]);
    for (final List<FractionActivitySpec> phase in fractionsActivities) {
      for (final FractionActivitySpec spec in phase) {
        expect(
          spec.shadedPartsByStrip.reduce((int a, int b) => a + b),
          spec.totalParts,
        );
        expect(
          spec.shadedPartsByStrip.every(
            (int parts) => parts <= spec.denominator,
          ),
          isTrue,
        );
      }
    }
  });

  test('numerator then denominator must be selected without skipping', () {
    final FractionsLessonState state = FractionsLessonState();
    expect(state.chooseNumber(5), isFalse);
    expect(state.current.numeratorFound, isFalse);
    expect(state.chooseNumber(3), isTrue);
    expect(state.current.numeratorFound, isTrue);
    expect(state.current.done, isFalse);
    expect(state.chooseNumber(3), isFalse);
    expect(state.current.numeratorFound, isTrue);
    expect(state.chooseNumber(5), isTrue);
    expect(state.current.denominatorFound, isTrue);
    expect(state.current.done, isTrue);
  });

  test('proper fractions remain unsimplified and below one', () {
    final FractionsLessonState state = FractionsLessonState()..phase = 1;
    for (int i = 0; i < 3; i++) {
      state.indices[1] = i;
      expect(state.chooseAmount('one-or-more'), isFalse);
      expect(state.current.done, isFalse);
      expect(state.chooseAmount('less'), isTrue);
      expect(state.current.done, isTrue);
    }
    expect(state.tasks[1][2].spec.label, '6/9');
  });

  test('improper equality is accepted as one whole', () {
    final FractionsLessonState state = FractionsLessonState()..phase = 2;
    expect(state.chooseAmount('greater'), isTrue);
    state.indices[2] = 1;
    expect(state.chooseAmount('greater'), isTrue);
    state.indices[2] = 2;
    expect(state.chooseAmount('greater'), isFalse);
    expect(state.chooseAmount('equal'), isTrue);
    expect(state.current.spec.writtenType, FractionType.improper);
    expect(state.current.feedback!.text, contains('equal to 1'));
    state.phase = 5;
    state.indices[5] = 2;
    expect(state.chooseType(FractionType.proper), isFalse);
    expect(state.chooseType(FractionType.improper), isTrue);
    expect(state.current.spec.label, '5/5');
  });

  test('mixed form is classified by notation, even at equal value', () {
    final FractionsLessonState state = FractionsLessonState()..phase = 4;
    state.indices[4] = 1;
    expect(state.chooseType(FractionType.improper), isTrue);
    state.indices[4] = 2;
    expect(state.chooseType(FractionType.improper), isFalse);
    expect(state.chooseType(FractionType.mixed), isTrue);
    expect(state.current.spec.label, '2 1/4');
  });

  test(
    'mixed builder consumes one source at a time and keeps accepted work',
    () {
      final FractionsLessonState state = FractionsLessonState()..phase = 3;
      const FractionDestination whole = FractionDestination(
        FractionDestinationKind.whole,
      );
      const FractionDestination piece = FractionDestination(
        FractionDestinationKind.piece,
      );
      const FractionTile wholeTile = FractionTile(FractionTileKind.whole, 0);
      const FractionTile firstPiece = FractionTile(FractionTileKind.piece, 0);
      expect(state.drop(wholeTile, piece), isFalse);
      expect(state.current.wholesPlaced, 0);
      expect(state.drop(wholeTile, whole), isTrue);
      expect(state.drop(wholeTile, whole), isFalse);
      expect(state.current.wholesPlaced, 1);
      expect(state.drop(firstPiece, whole), isFalse);
      expect(state.current.wholesPlaced, 1);
      expect(state.drop(firstPiece, piece), isTrue);
      expect(state.drop(firstPiece, piece), isFalse);
      expect(state.current.piecesPlaced, 1);
      expect(
        state.drop(const FractionTile(FractionTileKind.piece, 1), piece),
        isTrue,
      );
      expect(
        state.drop(const FractionTile(FractionTileKind.piece, 2), piece),
        isTrue,
      );
      expect(state.current.modelBuilt, isTrue);
      expect(state.current.done, isFalse);
      expect(state.chooseWholePart(false), isFalse);
      expect(state.current.modelBuilt, isTrue);
      expect(state.chooseWholePart(true), isTrue);
      expect(state.current.done, isTrue);
    },
  );

  test('occupied destinations and extra pieces do not consume tiles', () {
    final FractionsLessonState state = FractionsLessonState()..phase = 3;
    state.indices[3] = 1;
    expect(
      state.drop(
        const FractionTile(FractionTileKind.whole, 0),
        const FractionDestination(FractionDestinationKind.whole, id: 0),
      ),
      isTrue,
    );
    expect(
      state.drop(
        const FractionTile(FractionTileKind.whole, 1),
        const FractionDestination(FractionDestinationKind.whole, id: 0),
      ),
      isFalse,
    );
    expect(state.current.remainingWholes, 1);
    expect(
      state.drop(
        const FractionTile(FractionTileKind.piece, 0),
        const FractionDestination(FractionDestinationKind.piece),
      ),
      isTrue,
    );
    expect(
      state.drop(
        const FractionTile(FractionTileKind.piece, 1),
        const FractionDestination(FractionDestinationKind.piece),
      ),
      isFalse,
    );
    expect(state.current.piecesPlaced, 1);
  });

  test('Show Model and wrong answers preserve state', () {
    final FractionsLessonState state = FractionsLessonState()..phase = 5;
    state.indices[5] = 2;
    expect(state.current.modelVisible, isFalse);
    expect(state.chooseType(FractionType.proper), isFalse);
    expect(state.current.done, isFalse);
    state.showModel();
    expect(state.current.modelVisible, isTrue);
    expect(state.current.feedback!.correct, isFalse);
    expect(state.chooseType(FractionType.improper), isTrue);
    expect(state.current.modelVisible, isTrue);
  });

  test(
    'navigation gates future phases and recap, and preserves activity work',
    () {
      final FractionsLessonState state = FractionsLessonState();
      state.navigate(5);
      expect(state.phase, 0);
      state.next();
      expect(state.phase, 0);
      state.chooseNumber(3);
      state.chooseNumber(5);
      state.next();
      expect(state.phase, 1);
      state.previous();
      expect(state.current.numeratorFound, isTrue);
      expect(state.current.denominatorFound, isTrue);
      state.phase = 5;
      state.indices[5] = 3;
      state.current.done = true;
      state.next();
      expect(state.recap, isFalse);
      for (final FractionActivity task in state.tasks[5]) {
        task.done = true;
      }
      state.next();
      expect(state.recap, isTrue);
      state.reviewPractice();
      expect(state.recap, isFalse);
      expect(state.indices[5], 0);
      expect(
        state.tasks[5].every((FractionActivity task) => task.done),
        isTrue,
      );
    },
  );
}
