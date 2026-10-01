import 'add_subtract_lesson_content.dart';

enum ArithmeticMode { carry, exchange, answer, checked, done }

List<int> placeDigits(int value) => value
    .toString()
    .padLeft(7, '0')
    .split('')
    .map(int.parse)
    .toList(growable: false);

String formatPlaceNumber(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (Match match) => ',',
);

/// One calculation's original operands and mutable column-by-column work.
/// Every subtraction exchange moves value between adjacent columns.
class ArithmeticWork {
  ArithmeticWork(this.problem)
    : originalTop = placeDigits(problem.first),
      top = placeDigits(problem.first),
      bottom = placeDigits(problem.second),
      results = List<int?>.filled(7, null),
      carries = List<int>.filled(7, 0),
      firstColumn =
          7 -
          <int>[
            problem.first,
            problem.second,
            problem.answer,
          ].reduce((int a, int b) => a > b ? a : b).toString().length {
    _setMode();
  }

  final ArithmeticProblem problem;
  final List<int> originalTop;
  final List<int> top;
  final List<int> bottom;
  final List<int?> results;
  final List<int> carries;
  final int firstColumn;
  int column = 6;
  int? donorColumn;
  int exchanges = 0;
  int hints = 0;
  late ArithmeticMode mode;

  bool get done => mode == ArithmeticMode.done;
  int get total => top[column] + bottom[column] + carries[column];
  int get expectedDigit =>
      problem.operation == '+' ? total % 10 : top[column] - bottom[column];
  int get conservedTopValue => List<int>.generate(
    7,
    (int i) => top[i] * pow10(6 - i),
  ).reduce((int a, int b) => a + b);

  void _setMode() {
    if (problem.operation == '+') {
      donorColumn = null;
      mode = total >= 10 ? ArithmeticMode.carry : ArithmeticMode.answer;
    } else if (top[column] < bottom[column]) {
      mode = ArithmeticMode.exchange;
      donorColumn = column - 1;
      while (donorColumn! >= 0 && top[donorColumn!] == 0) {
        donorColumn = donorColumn! - 1;
      }
    } else {
      mode = ArithmeticMode.answer;
      donorColumn = null;
    }
  }

  bool placeCarry(int destinationColumn) {
    if (mode != ArithmeticMode.carry || destinationColumn != column - 1) {
      return false;
    }
    carries[destinationColumn] = 1;
    mode = ArithmeticMode.answer;
    return true;
  }

  bool exchange(int fromColumn, int toColumn) {
    if (mode != ArithmeticMode.exchange ||
        fromColumn != donorColumn ||
        toColumn != fromColumn + 1 ||
        top[fromColumn] <= 0) {
      return false;
    }
    top[fromColumn]--;
    top[toColumn] += 10;
    exchanges++;
    if (toColumn == column) {
      donorColumn = null;
      mode = ArithmeticMode.answer;
    } else {
      donorColumn = toColumn;
    }
    assert(conservedTopValue == problem.first);
    return true;
  }

  bool placeDigit(int value, int destinationColumn) {
    if (mode != ArithmeticMode.answer ||
        destinationColumn != column ||
        value != expectedDigit) {
      return false;
    }
    results[column] = value;
    mode = column == firstColumn ? ArithmeticMode.done : ArithmeticMode.checked;
    return true;
  }

  bool continueColumn() {
    if (mode != ArithmeticMode.checked) return false;
    column--;
    hints = 0;
    _setMode();
    return true;
  }
}

int pow10(int exponent) {
  int result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
