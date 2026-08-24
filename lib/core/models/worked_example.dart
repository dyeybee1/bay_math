/// Which arithmetic operation a [WorkedExample] walks through — decides
/// which of a [WorkedExampleStep]'s carry/borrow field pair is populated
/// (addition uses carryIn/carryOut, subtraction uses borrowIn/borrowOut).
enum WorkedExampleOperation { addition, subtraction }

/// One column's worth of the step-by-step reveal (0030's `worked_example`
/// jsonb shape) — e.g. "in the Ones column, 2 - 2 = 0, write 0".
///
/// [carryIn]/[carryOut] and [borrowIn]/[borrowOut] are kept as two
/// separate, operation-specific field pairs rather than one unified name
/// (see 0031's migration header for the full reasoning) — only the pair
/// matching the parent [WorkedExample.operation] is ever populated for a
/// given example; the other pair stays null.
class WorkedExampleStep {
  const WorkedExampleStep({
    required this.columnLabel,
    required this.digitA,
    required this.digitB,
    this.carryIn,
    this.carryOut,
    this.borrowIn,
    this.borrowOut,
    required this.computationText,
    required this.resultDigit,
    required this.actionText,
  });

  final String columnLabel;
  final int digitA;
  final int digitB;
  final int? carryIn;
  final int? carryOut;
  final int? borrowIn;
  final int? borrowOut;
  final String computationText;
  final int resultDigit;
  final String actionText;

  factory WorkedExampleStep.fromJson(Map<String, dynamic> json) {
    return WorkedExampleStep(
      columnLabel: json['column_label'] as String,
      digitA: json['digit_a'] as int,
      digitB: json['digit_b'] as int,
      carryIn: json['carry_in'] as int?,
      carryOut: json['carry_out'] as int?,
      borrowIn: json['borrow_in'] as int?,
      borrowOut: json['borrow_out'] as int?,
      computationText: json['computation_text'] as String,
      resultDigit: json['result_digit'] as int,
      actionText: json['action_text'] as String,
    );
  }
}

/// A parsed `lesson_pages.worked_example` value (0030) — the interactive,
/// place-value-aligned alternative to a page's plain-text `body`. Fixed to
/// exactly 6 place-value columns (Hundred Thousands..Ones), matching this
/// project's "up to 1,000,000" scope for both existing lessons — a
/// deliberate POC-scope limitation, not built to generalize to other digit
/// counts (0030's column comment).
class WorkedExample {
  const WorkedExample({
    required this.operandA,
    required this.operandB,
    required this.operation,
    required this.result,
    required this.steps,
  });

  final String operandA;
  final String operandB;
  final WorkedExampleOperation operation;
  final String result;
  final List<WorkedExampleStep> steps;

  factory WorkedExample.fromJson(Map<String, dynamic> json) {
    return WorkedExample(
      operandA: json['operand_a'] as String,
      operandB: json['operand_b'] as String,
      operation: WorkedExampleOperation.values.byName(json['operation'] as String),
      result: json['result'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((step) => WorkedExampleStep.fromJson(step as Map<String, dynamic>))
          .toList(),
    );
  }
}
