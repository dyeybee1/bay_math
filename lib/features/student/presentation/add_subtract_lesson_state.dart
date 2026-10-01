import 'add_subtract_lesson_content.dart';
import 'add_subtract_lesson_math.dart';

enum LessonTileKind { operation, alignment, digit, carry, exchange }

enum LessonZoneKind { operation, alignment, answer, carry, exchange }

class LessonTile {
  const LessonTile._(
    this.kind, {
    this.symbol,
    this.value,
    this.row,
    this.index,
    this.column,
  });
  const LessonTile.operation(String symbol)
    : this._(LessonTileKind.operation, symbol: symbol);
  const LessonTile.alignment(int row, int index, int value)
    : this._(LessonTileKind.alignment, row: row, index: index, value: value);
  const LessonTile.digit(int value)
    : this._(LessonTileKind.digit, value: value);
  const LessonTile.carry(int destinationColumn)
    : this._(LessonTileKind.carry, column: destinationColumn);
  const LessonTile.exchange(int sourceColumn)
    : this._(LessonTileKind.exchange, column: sourceColumn);

  final LessonTileKind kind;
  final String? symbol;
  final int? value;
  final int? row;
  final int? index;
  final int? column;

  String get identity => '$kind:$symbol:$value:$row:$index:$column';
}

class LessonZone {
  const LessonZone._(this.kind, {this.row, this.column});
  const LessonZone.operation() : this._(LessonZoneKind.operation);
  const LessonZone.alignment(int row, int column)
    : this._(LessonZoneKind.alignment, row: row, column: column);
  const LessonZone.answer(int column)
    : this._(LessonZoneKind.answer, column: column);
  const LessonZone.carry(int column)
    : this._(LessonZoneKind.carry, column: column);
  const LessonZone.exchange(int column)
    : this._(LessonZoneKind.exchange, column: column);

  final LessonZoneKind kind;
  final int? row;
  final int? column;
}

class LessonDropFeedback {
  const LessonDropFeedback(this.title, this.detail, {required this.correct});
  final String title;
  final String detail;
  final bool correct;
}

class AddSubtractLessonState {
  static const List<int> alignmentNumbers = <int>[512340, 87660];
  int phase = 0;
  bool startDone = false;
  int startHints = 0;
  LessonDropFeedback? startFeedback;
  final List<List<int?>> alignmentPlaced = <List<int?>>[
    List<int?>.filled(7, null),
    List<int?>.filled(7, null),
  ];
  int alignmentHints = 0;
  LessonDropFeedback? alignmentFeedback;
  late final List<ArithmeticWork> additions =
      additionProblems.map(ArithmeticWork.new).toList();
  late final List<ArithmeticWork> subtractions =
      subtractionProblems.map(ArithmeticWork.new).toList();
  late final List<ArithmeticWork> practice =
      practiceProblems.map(ArithmeticWork.new).toList();
  final Map<ArithmeticWork, LessonDropFeedback?> exerciseFeedback =
      <ArithmeticWork, LessonDropFeedback?>{};
  int additionIndex = 0;
  int subtractionIndex = 0;
  int practiceIndex = 0;
  bool finished = false;
  LessonTile? selected;

  ArithmeticWork? get currentWork => switch (phase) {
    2 => additions[additionIndex],
    3 => subtractions[subtractionIndex],
    4 => practice[practiceIndex],
    _ => null,
  };
  LessonDropFeedback? get currentFeedback => switch (phase) {
    0 => startFeedback,
    1 => alignmentFeedback,
    2 || 3 || 4 => exerciseFeedback[currentWork],
    _ => null,
  };
  bool get alignmentDone {
    for (int row = 0; row < 2; row++) {
      final String digits = alignmentNumbers[row].toString();
      for (int i = 0; i < digits.length; i++) {
        if (alignmentPlaced[row][7 - digits.length + i] != i) return false;
      }
    }
    return true;
  }

  bool get practiceDone => practice.every((ArithmeticWork work) => work.done);
  int get practiceCompleteCount =>
      practice.where((ArithmeticWork work) => work.done).length;

  void navigate(int targetPhase) {
    phase = targetPhase.clamp(0, 5);
    selected = null;
  }

  void select(LessonTile tile) {
    selected = selected?.identity == tile.identity ? null : tile;
  }

  void clearSelection() {
    selected = null;
  }

  /// Shared validation for touch drag, mouse drag, tap, and keyboard actions.
  bool place(LessonTile tile, LessonZone zone) {
    selected = null;
    if (phase == 0) return _placeOperation(tile, zone);
    if (phase == 1) return _placeAlignment(tile, zone);
    final ArithmeticWork? work = currentWork;
    if (work == null || work.done) return false;
    return _placeInWork(work, tile, zone);
  }

  bool _placeOperation(LessonTile tile, LessonZone zone) {
    if (startDone ||
        tile.kind != LessonTileKind.operation ||
        zone.kind != LessonZoneKind.operation) {
      return false;
    }
    if (tile.symbol == '+') {
      startDone = true;
      startFeedback = const LessonDropFeedback(
        'Add to find the total.',
        'The library receives more books. We combine both amounts.',
        correct: true,
      );
      return true;
    }
    startFeedback = const LessonDropFeedback(
      'Think about what changes.',
      'The library receives more books. Are we combining amounts or finding what is left?',
      correct: false,
    );
    return false;
  }

  bool _placeAlignment(LessonTile tile, LessonZone zone) {
    if (tile.kind != LessonTileKind.alignment ||
        zone.kind != LessonZoneKind.alignment) {
      return false;
    }
    final int row = tile.row!;
    final int expected =
        7 - alignmentNumbers[row].toString().length + tile.index!;
    if (alignmentPlaced[row].contains(tile.index)) return false;
    if (zone.row != row || zone.column != expected) {
      alignmentFeedback = LessonDropFeedback(
        'Line up the place values.',
        'Place ${tile.value} in row ${row + 1}, ${placeNames[expected].toLowerCase()}. '
            'Ones go at the far right; keep each number in its own row.',
        correct: false,
      );
      return false;
    }
    if (alignmentPlaced[row][expected] != null) return false;
    alignmentPlaced[row][expected] = tile.index;
    alignmentFeedback = LessonDropFeedback(
      'Placed correctly.',
      '${tile.value} belongs in the ${placeNames[expected].toLowerCase()} column.',
      correct: true,
    );
    return true;
  }

  bool _placeInWork(ArithmeticWork work, LessonTile tile, LessonZone zone) {
    switch (work.mode) {
      case ArithmeticMode.carry:
        if (tile.kind != LessonTileKind.carry ||
            tile.column != work.column - 1 ||
            zone.kind != LessonZoneKind.carry ||
            !work.placeCarry(zone.column!)) {
          return _error(
            work,
            'Try the neighboring carry space.',
            'Exchange 10 ${unitNames[work.column]}s for 1 '
                '${unitNames[work.column - 1]}. Place it one column left.',
          );
        }
        exerciseFeedback[work] = LessonDropFeedback(
          'Regrouped.',
          '${work.total} ${unitNames[work.column]}s = 1 '
              '${unitNames[work.column - 1]} and ${work.total % 10} '
              '${unitNames[work.column]}s.',
          correct: true,
        );
        return true;
      case ArithmeticMode.exchange:
        if (tile.kind != LessonTileKind.exchange ||
            zone.kind != LessonZoneKind.exchange ||
            !work.exchange(tile.column!, zone.column!)) {
          return _error(
            work,
            'Exchange one place at a time.',
            'Use the nearest available place on the left. Move its unit '
                'into the immediately adjacent place on the right.',
          );
        }
        exerciseFeedback[work] = LessonDropFeedback(
          'The value stays the same.',
          '1 ${unitNames[tile.column!]} becomes 10 '
              '${unitNames[zone.column!]}s. The total is still '
              '${formatPlaceNumber(work.problem.first)}.',
          correct: true,
        );
        return true;
      case ArithmeticMode.answer:
        if (tile.kind != LessonTileKind.digit ||
            zone.kind != LessonZoneKind.answer ||
            zone.column != work.column) {
          return _error(
            work,
            'Use the highlighted answer cell.',
            'Place a digit in the ${placeNames[work.column].toLowerCase()} answer cell.',
          );
        }
        final int expected = work.expectedDigit;
        if (tile.value != expected) {
          return _error(
            work,
            'Check this column.',
            work.problem.operation == '+'
                ? 'Add ${work.top[work.column]} + ${work.bottom[work.column]}'
                    '${work.carries[work.column] == 1 ? ' + 1 carried' : ''}. '
                    'Write the digit for this column after regrouping.'
                : 'Subtract ${work.bottom[work.column]} from the updated top value, '
                    '${work.top[work.column]}.',
          );
        }
        work.placeDigit(expected, zone.column!);
        exerciseFeedback[work] =
            work.done
                ? LessonDropFeedback(
                  'Calculation completed!',
                  '${formatPlaceNumber(work.problem.first)} ${work.problem.operation} '
                      '${formatPlaceNumber(work.problem.second)} = '
                      '${formatPlaceNumber(work.problem.answer)}',
                  correct: true,
                )
                : LessonDropFeedback(
                  'Correct answer digit.',
                  '$expected belongs in the ${placeNames[work.column].toLowerCase()} answer cell.',
                  correct: true,
                );
        return true;
      case ArithmeticMode.checked:
        return _error(
          work,
          'Continue to the next column.',
          'Use Continue column before placing another digit.',
        );
      case ArithmeticMode.done:
        return false;
    }
  }

  bool _error(ArithmeticWork work, String title, String detail) {
    exerciseFeedback[work] = LessonDropFeedback(title, detail, correct: false);
    return false;
  }

  bool continueColumn() {
    final ArithmeticWork? work = currentWork;
    if (work == null || !work.continueColumn()) return false;
    exerciseFeedback[work] = null;
    selected = null;
    return true;
  }

  bool nextExercise() {
    final ArithmeticWork? work = currentWork;
    if (work == null || !work.done) return false;
    if (phase == 2 && additionIndex < additions.length - 1) {
      additionIndex++;
    } else if (phase == 3 && subtractionIndex < subtractions.length - 1) {
      subtractionIndex++;
    } else if (phase == 4 && practiceIndex < practice.length - 1) {
      practiceIndex++;
    } else {
      return false;
    }
    selected = null;
    return true;
  }

  void addHint() {
    if (phase == 0) {
      startHints++;
      startFeedback = const LessonDropFeedback(
        'Combine the amounts.',
        'The books received join the books already in the library.',
        correct: false,
      );
    } else if (phase == 1) {
      alignmentHints++;
      alignmentFeedback = const LessonDropFeedback(
        'Start at ones.',
        'Drag the last digit of each number into the far-right cell of its own row.',
        correct: false,
      );
    } else {
      currentWork?.hints++;
    }
  }

  String get calculationHint {
    final ArithmeticWork work = currentWork!;
    if (work.hints < 2) {
      return 'Use the updated top value and include any incoming carry.';
    }
    return 'This column’s answer digit is ${work.expectedDigit}.';
  }
}
