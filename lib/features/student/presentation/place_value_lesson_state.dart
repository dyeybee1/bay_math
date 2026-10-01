import 'place_value_lesson_content.dart';

enum PlaceCardKind {
  explore,
  alignment,
  digit,
  place,
  value,
  contribution,
  greater,
}

enum PlaceTargetKind {
  explore,
  digit,
  place,
  value,
  contribution,
  repeated,
  greater,
}

class PlaceCard {
  const PlaceCard(this.kind, this.value, {this.id = -1, this.column = -1});
  final PlaceCardKind kind;
  final int value;
  final int id;
  final int column;
  String get identity => '$kind:$value:$id:$column';
}

class PlaceTarget {
  const PlaceTarget(this.kind, {this.column = -1, this.slot = -1});
  final PlaceTargetKind kind;
  final int column;
  final int slot;
  String get identity => '$kind:$column:$slot';
}

class PlaceFeedback {
  const PlaceFeedback(this.title, this.detail, {required this.correct});
  final String title;
  final String detail;
  final bool correct;
}

class PlaceActivity {
  PlaceActivity(this.spec);
  final PlaceTaskSpec spec;
  final List<int?> filled = List<int?>.filled(7, null);
  final Set<int> usedCards = <int>{};
  final List<int?> repeated = <int?>[null, null];
  int? place;
  int? value;
  int? greater;
  int hints = 0;
  bool simplified = false;
  bool done = false;
  PlaceFeedback? feedback;

  List<int> get positions => placePositions(spec.number);
  List<int> get digits => placeDigits(spec.number);
  int get highlightedColumn =>
      7 - spec.number.toString().length + spec.highlight;
  List<int> get repeatedColumns => <int>[
    7 - spec.number.toString().length,
    8 - spec.number.toString().length,
  ];
  List<int> get repeatedValues =>
      repeatedColumns
          .map((int column) => digits[column] * placeValueUnits[column])
          .toList();
  bool get hasZero => positions.any((int column) => digits[column] == 0);
}

class PlaceValueLessonState {
  int phase = 0;
  final List<int> indices = List<int>.filled(6, 0);
  late final List<List<PlaceActivity>> tasks =
      placeValueTasks
          .map(
            (List<PlaceTaskSpec> specs) =>
                specs.map(PlaceActivity.new).toList(),
          )
          .toList();
  final Set<int> exploredColumns = <int>{};
  int? exploreColumn;
  PlaceFeedback? exploreFeedback;
  PlaceCard? selected;
  bool recap = false;
  bool finished = false;

  PlaceActivity? get current =>
      phase == 0 || (phase == 5 && recap) ? null : tasks[phase][indices[phase]];
  PlaceFeedback? get feedback =>
      phase == 0 ? exploreFeedback : current?.feedback;
  int get completedPractice =>
      tasks[5].where((PlaceActivity task) => task.done).length;
  bool get practiceDone => completedPractice == tasks[5].length;

  void navigate(int target) {
    phase = target.clamp(0, 5);
    selected = null;
  }

  void reviewPractice() {
    phase = 5;
    recap = false;
    indices[5] = 0;
    selected = null;
  }

  bool nextActivity() {
    final PlaceActivity? task = current;
    if (task == null || !task.done) return false;
    selected = null;
    if (indices[phase] < tasks[phase].length - 1) {
      indices[phase]++;
    } else if (phase == 5) {
      recap = true;
    } else {
      phase++;
    }
    return true;
  }

  void select(PlaceCard card) {
    selected = selected?.identity == card.identity ? null : card;
  }

  void addHint() {
    current?.hints++;
  }

  bool drop(PlaceCard card, PlaceTarget target) {
    selected = null;
    if (phase == 0) {
      if (card.kind != PlaceCardKind.explore ||
          target.kind != PlaceTargetKind.explore ||
          !<int>[4, 5].contains(target.column)) {
        return false;
      }
      exploreColumn = target.column;
      exploredColumns.add(target.column);
      exploreFeedback = PlaceFeedback(
        'The position changes the value.',
        '5 × ${placeFormat(placeValueUnits[target.column])} = '
            '${placeFormat(5 * placeValueUnits[target.column])}. '
            'Try the other place.',
        correct: true,
      );
      return true;
    }
    final PlaceActivity? task = current;
    if (task == null || task.done) return false;
    switch (task.spec.type) {
      case PlaceTaskType.align:
        return _align(task, card, target);
      case PlaceTaskType.standard || PlaceTaskType.reverse:
        return _standard(task, card, target);
      case PlaceTaskType.identify:
        return _identify(task, card, target);
      case PlaceTaskType.expanded:
        return _expanded(task, card, target);
      case PlaceTaskType.repeat:
        return _repeat(task, card, target);
    }
  }

  bool _wrong(PlaceActivity task, String detail) {
    task.feedback = PlaceFeedback('Try again.', detail, correct: false);
    return false;
  }

  bool _right(PlaceActivity task, String detail) {
    task.feedback = PlaceFeedback(
      task.done ? 'Activity complete!' : 'Good match!',
      detail,
      correct: true,
    );
    return true;
  }

  bool _align(PlaceActivity task, PlaceCard card, PlaceTarget target) {
    final int expected = 7 - task.spec.number.toString().length + card.id;
    if (card.kind != PlaceCardKind.alignment ||
        target.kind != PlaceTargetKind.digit ||
        card.id < 0 ||
        card.id >= task.positions.length ||
        task.usedCards.contains(card.id) ||
        card.value != task.digits[expected] ||
        target.column != expected ||
        task.filled[target.column] != null) {
      return _wrong(
        task,
        'Start at ones on the right. Each card belongs under its own place label.',
      );
    }
    task.filled[target.column] = card.value;
    task.usedCards.add(card.id);
    task.done = task.positions.every(
      (int column) => task.filled[column] == task.digits[column],
    );
    return _right(
      task,
      '${card.value} is in the ${placeValueNames[target.column].toLowerCase()} place.',
    );
  }

  bool _standard(PlaceActivity task, PlaceCard card, PlaceTarget target) {
    if (card.kind != PlaceCardKind.digit ||
        target.kind != PlaceTargetKind.digit ||
        !task.positions.contains(target.column) ||
        task.filled[target.column] != null) {
      return _wrong(task, 'Use a digit card and an empty place-value cell.');
    }
    if (card.value != task.digits[target.column]) {
      return _wrong(
        task,
        'Read the group for this column. A zero holds an empty place.',
      );
    }
    task.filled[target.column] = card.value;
    task.done = task.positions.every(
      (int column) => task.filled[column] == task.digits[column],
    );
    return _right(
      task,
      task.done
          ? 'You built ${placeFormat(task.spec.number)}.'
          : '${card.value} belongs in ${placeValueNames[target.column].toLowerCase()}.',
    );
  }

  bool _identify(PlaceActivity task, PlaceCard card, PlaceTarget target) {
    final int column = task.highlightedColumn;
    final int digit = task.digits[column];
    final int value = digit * placeValueUnits[column];
    if (target.kind == PlaceTargetKind.place &&
        card.kind == PlaceCardKind.place &&
        task.place == null) {
      if (card.column != column) {
        return _wrong(
          task,
          'Place is the column name above the highlighted digit.',
        );
      }
      task.place = column;
    } else if (target.kind == PlaceTargetKind.value &&
        card.kind == PlaceCardKind.value &&
        task.value == null) {
      if (card.value != value) {
        return _wrong(
          task,
          'Multiply $digit by ${placeFormat(placeValueUnits[column])} to find its value.',
        );
      }
      task.value = value;
    } else {
      return _wrong(task, 'Place needs a column name. Value needs an amount.');
    }
    task.done = task.place != null && task.value != null;
    return _right(
      task,
      task.done
          ? '$digit is in ${placeValueNames[column].toLowerCase()}; its value is ${placeFormat(value)}.'
          : 'Now match the other answer.',
    );
  }

  bool _expanded(PlaceActivity task, PlaceCard card, PlaceTarget target) {
    if (card.kind != PlaceCardKind.contribution ||
        target.kind != PlaceTargetKind.contribution ||
        !task.positions.contains(target.column) ||
        !task.positions.contains(card.id) ||
        task.usedCards.contains(card.id) ||
        card.value != task.digits[card.id] * placeValueUnits[card.id] ||
        task.filled[target.column] != null) {
      return _wrong(
        task,
        'Use an available value card and an empty contribution cell.',
      );
    }
    final int expected =
        task.digits[target.column] * placeValueUnits[target.column];
    if (card.value != expected) {
      return _wrong(
        task,
        'This digit is ${task.digits[target.column]} in ${placeValueNames[target.column].toLowerCase()}. Match digit × place unit.',
      );
    }
    task.filled[target.column] = card.value;
    task.usedCards.add(card.id);
    task.done = task.positions.every(
      (int column) =>
          task.filled[column] == task.digits[column] * placeValueUnits[column],
    );
    return _right(
      task,
      expected == 0
          ? 'Zero contributes 0. Keep its digit in the number.'
          : '${placeFormat(expected)} is this digit’s contribution.',
    );
  }

  bool _repeat(PlaceActivity task, PlaceCard card, PlaceTarget target) {
    final List<int> values = task.repeatedValues;
    if (target.kind == PlaceTargetKind.greater &&
        card.kind == PlaceCardKind.greater) {
      if (task.repeated.any((int? value) => value == null) ||
          task.greater != null) {
        return _wrong(task, 'Match both highlighted digits first.');
      }
      if (card.value != values[0]) {
        return _wrong(task, 'Compare the values of the two columns.');
      }
      task.greater = card.value;
      task.done = true;
      return _right(
        task,
        '${placeFormat(values[0])} is ten times ${placeFormat(values[1])}.',
      );
    }
    if (card.kind != PlaceCardKind.value ||
        target.kind != PlaceTargetKind.repeated ||
        target.slot < 0 ||
        target.slot > 1 ||
        task.repeated[target.slot] != null) {
      return _wrong(
        task,
        'Match a value to the first or second highlighted digit.',
      );
    }
    if (card.value != values[target.slot]) {
      return _wrong(task, 'Read the place label above this highlighted digit.');
    }
    task.repeated[target.slot] = card.value;
    return _right(task, 'You matched this digit with its value.');
  }

  String hintFor(PlaceActivity task) {
    if (task.spec.type == PlaceTaskType.align) {
      return 'Begin with ones on the far right.';
    }
    if (task.spec.type == PlaceTaskType.identify) {
      final int column = task.highlightedColumn;
      return task.hints > 1
          ? '${task.digits[column]} × ${placeFormat(placeValueUnits[column])} = ${placeFormat(task.digits[column] * placeValueUnits[column])}.'
          : 'Place is the column name. Value is digit × place unit.';
    }
    if (task.spec.type == PlaceTaskType.standard ||
        task.spec.type == PlaceTaskType.reverse) {
      return task.hints > 1
          ? 'The number is ${placeFormat(task.spec.number)}.'
          : 'Read the thousands group, then the last three digits. Zero holds an empty place.';
    }
    if (task.spec.type == PlaceTaskType.expanded) {
      return 'Match each digit × its place unit. A zero digit contributes 0.';
    }
    return 'The leftmost highlighted digit has the larger place value.';
  }
}
