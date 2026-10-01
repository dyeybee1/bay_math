import 'fractions_lesson_content.dart';

class FractionFeedback {
  const FractionFeedback(this.correct, this.text);
  final bool correct;
  final String text;
}

enum FractionTileKind { whole, piece }

class FractionTile {
  const FractionTile(this.kind, this.id);
  final FractionTileKind kind;
  final int id;
}

enum FractionDestinationKind { whole, piece }

class FractionDestination {
  const FractionDestination(this.kind, {this.id = 0});
  final FractionDestinationKind kind;
  final int id;
}

class FractionActivity {
  FractionActivity(this.spec) : modelVisible = !spec.initiallyHidden;

  final FractionActivitySpec spec;
  bool modelVisible;
  bool numeratorFound = false;
  bool denominatorFound = false;
  bool done = false;
  String? answer;
  FractionFeedback? feedback;
  int hints = 0;
  final Set<int> wholeSlots = <int>{};
  final Set<int> usedWholeTiles = <int>{};
  final Set<int> usedPieces = <int>{};

  int get piecesPlaced => usedPieces.length;
  int get wholesPlaced => wholeSlots.length;
  bool get modelBuilt =>
      wholesPlaced == spec.wholes && piecesPlaced == spec.numerator;
  int get remainingWholes => spec.wholes - usedWholeTiles.length;
  int get remainingPieces => spec.numerator - usedPieces.length;
}

class FractionsLessonState {
  FractionsLessonState()
    : tasks =
          fractionsActivities
              .map(
                (List<FractionActivitySpec> phase) =>
                    phase.map(FractionActivity.new).toList(),
              )
              .toList(),
      indices = List<int>.filled(fractionsPhases.length, 0);

  final List<List<FractionActivity>> tasks;
  final List<int> indices;
  int phase = 0;
  bool recap = false;
  bool finished = false;
  FractionTile? selectedTile;

  FractionActivity get current => tasks[phase][indices[phase]];
  bool get practiceDone =>
      tasks.last.every((FractionActivity task) => task.done);

  bool phaseUnlocked(int target) =>
      target >= 0 &&
      target < tasks.length &&
      (target == 0 ||
          tasks
              .take(target)
              .every(
                (List<FractionActivity> activities) => activities.every(
                  (FractionActivity activity) => activity.done,
                ),
              ));

  void navigate(int target) {
    if (!phaseUnlocked(target)) return;
    phase = target;
    recap = false;
    selectedTile = null;
  }

  void next() {
    if (recap || !current.done) return;
    if (indices[phase] < tasks[phase].length - 1) {
      indices[phase]++;
    } else if (phase < tasks.length - 1) {
      phase++;
    } else if (practiceDone) {
      recap = true;
    }
    selectedTile = null;
  }

  void previous() {
    if (recap) {
      recap = false;
    } else if (indices[phase] > 0) {
      indices[phase]--;
    } else if (phase > 0) {
      phase--;
    }
    selectedTile = null;
  }

  void reviewPractice() {
    if (!practiceDone) return;
    phase = tasks.length - 1;
    indices[phase] = 0;
    recap = false;
    selectedTile = null;
  }

  void showModel() => current.modelVisible = true;

  void requestHint() {
    final FractionActivity task = current;
    task.hints++;
    task.feedback = FractionFeedback(false, switch (task.spec.type) {
      FractionActivityType.parts =>
        task.numeratorFound ? 'Tap the bottom number.' : 'Tap the top number.',
      FractionActivityType.proper || FractionActivityType.improper =>
        'Compare the shaded amount with one full strip.',
      FractionActivityType.build =>
        task.modelBuilt
            ? 'The whole-number part is beside the fraction.'
            : 'Whole tiles go in whole slots; pieces go in the divided strip.',
      FractionActivityType.identify =>
        'Compare the two numbers, or look for a whole number beside the fraction.',
    });
  }

  bool chooseNumber(int value) {
    final FractionActivity task = current;
    if (recap || task.done || task.spec.type != FractionActivityType.parts) {
      return false;
    }
    final bool numerator = !task.numeratorFound;
    final int expected =
        numerator ? task.spec.numerator : task.spec.denominator;
    if (value != expected) {
      task.feedback = FractionFeedback(
        false,
        numerator
            ? 'The numerator is the top number. It counts shaded parts.'
            : 'The denominator is the bottom number. It counts all equal parts in one whole.',
      );
      return false;
    }
    if (numerator) {
      task.numeratorFound = true;
      task.feedback = FractionFeedback(
        true,
        '$value is the numerator. It counts the $value shaded parts. Now tap the denominator.',
      );
    } else {
      task.denominatorFound = true;
      task.done = true;
      task.feedback = FractionFeedback(
        true,
        '$value is the denominator. $value equal parts make one whole.',
      );
    }
    return true;
  }

  bool chooseAmount(String value) {
    final FractionActivity task = current;
    if (recap || task.done) return false;
    if (task.spec.type != FractionActivityType.proper &&
        task.spec.type != FractionActivityType.improper) {
      return false;
    }
    final FractionActivitySpec spec = task.spec;
    final String expected =
        spec.numerator < spec.denominator
            ? 'less'
            : spec.numerator == spec.denominator
            ? 'equal'
            : 'greater';
    if (value != expected) {
      task.feedback = FractionFeedback(
        false,
        expected == 'less'
            ? 'The strip is not full yet. The amount is less than one whole.'
            : expected == 'equal'
            ? 'Exactly one whole is full. The numerator and denominator are equal.'
            : 'One whole is full, with more shaded parts in another strip.',
      );
      return false;
    }
    task.answer = value;
    task.done = true;
    task.feedback = FractionFeedback(
      true,
      expected == 'less'
          ? '${spec.numerator} is less than ${spec.denominator}. ${spec.label} is a proper fraction.'
          : expected == 'equal'
          ? '${spec.numerator} parts fill one whole. ${spec.numerator} = ${spec.denominator}, so ${spec.label} is an improper fraction equal to 1.'
          : '${spec.numerator} is greater than ${spec.denominator}. ${spec.label} is an improper fraction greater than 1.',
    );
    return true;
  }

  bool chooseType(FractionType value) {
    final FractionActivity task = current;
    if (recap || task.done || task.spec.type != FractionActivityType.identify) {
      return false;
    }
    final FractionActivitySpec spec = task.spec;
    if (value != spec.writtenType) {
      task.feedback = FractionFeedback(
        false,
        spec.wholes > 0
            ? 'A whole number beside a proper fraction is a mixed number.'
            : spec.numerator == spec.denominator
            ? 'Equal top and bottom numbers make one whole. This written form is improper.'
            : 'Compare the numerator with the denominator in the written form.',
      );
      return false;
    }
    task.answer = value.name;
    task.done = true;
    task.feedback = FractionFeedback(
      true,
      spec.wholes > 0
          ? '${spec.label} has a whole number and a proper fraction. It is a mixed number.'
          : spec.numerator == spec.denominator
          ? '${spec.label} is exactly one whole. It is written as an improper fraction.'
          : '${spec.numerator} ${spec.numerator < spec.denominator ? 'is less than' : 'is greater than'} ${spec.denominator}. ${spec.label} is a ${value.name} fraction.',
    );
    return true;
  }

  bool chooseWholePart(bool whole) {
    final FractionActivity task = current;
    if (recap ||
        task.done ||
        task.spec.type != FractionActivityType.build ||
        !task.modelBuilt) {
      return false;
    }
    if (!whole) {
      task.feedback = const FractionFeedback(
        false,
        'The whole-number part is the number beside the fraction. Look at the complete wholes.',
      );
      return false;
    }
    task.answer = 'whole';
    task.done = true;
    final FractionActivitySpec spec = task.spec;
    task.feedback = FractionFeedback(
      true,
      '${spec.wholes} is the whole-number part. ${spec.numerator}/${spec.denominator} is the proper-fraction part. Together, they make ${spec.label}.',
    );
    return true;
  }

  void selectTile(FractionTile tile) {
    if (recap ||
        current.done ||
        current.spec.type != FractionActivityType.build ||
        current.modelBuilt ||
        _used(current, tile)) {
      return;
    }
    selectedTile =
        selectedTile?.kind == tile.kind && selectedTile?.id == tile.id
            ? null
            : tile;
  }

  bool placeSelected(FractionDestination destination) {
    final FractionTile? tile = selectedTile;
    if (tile == null) return false;
    selectedTile = null;
    return drop(tile, destination);
  }

  bool _used(FractionActivity task, FractionTile tile) =>
      tile.kind == FractionTileKind.whole
          ? task.usedWholeTiles.contains(tile.id)
          : task.usedPieces.contains(tile.id);

  bool drop(FractionTile tile, FractionDestination destination) {
    final FractionActivity task = current;
    if (recap ||
        task.done ||
        task.spec.type != FractionActivityType.build ||
        task.modelBuilt ||
        _used(task, tile)) {
      return false;
    }
    final FractionActivitySpec spec = task.spec;
    if (tile.kind == FractionTileKind.whole) {
      if (destination.kind != FractionDestinationKind.whole) {
        task.feedback = const FractionFeedback(
          false,
          'Put the whole tile in a whole slot.',
        );
        return false;
      }
      if (tile.id < 0 ||
          tile.id >= spec.wholes ||
          destination.id < 0 ||
          destination.id >= spec.wholes ||
          task.wholeSlots.contains(destination.id)) {
        return false;
      }
      task.usedWholeTiles.add(tile.id);
      task.wholeSlots.add(destination.id);
    } else {
      if (destination.kind != FractionDestinationKind.piece) {
        task.feedback = const FractionFeedback(
          false,
          'Place the fractional piece in the divided strip.',
        );
        return false;
      }
      if (tile.id < 0 ||
          tile.id >= spec.numerator ||
          task.piecesPlaced >= spec.numerator) {
        return false;
      }
      task.usedPieces.add(tile.id);
    }
    task.feedback = FractionFeedback(
      true,
      task.modelBuilt
          ? 'You built ${spec.wholes} whole${spec.wholes == 1 ? '' : 's'} and ${spec.numerator}/${spec.denominator}. Now tap the whole-number part.'
          : '${task.wholesPlaced} of ${spec.wholes} wholes placed. ${task.piecesPlaced} of ${spec.numerator} pieces placed.',
    );
    return true;
  }
}
