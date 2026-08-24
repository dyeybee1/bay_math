import 'package:flutter/material.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/models/worked_example.dart';
import '../../../core/widgets/widgets.dart';

/// Fixed to exactly 6 place-value columns (0030's POC scope note — not
/// built to generalize to other digit counts). Order is left-to-right as
/// displayed; a step's own `column_label` (not its position in the JSON
/// `steps` array) is matched against [full] here, so this doesn't assume
/// any particular ordering of the steps in the data.
const List<({String full, String abbr})> _placeValueColumns = [
  (full: 'Hundred Thousands', abbr: 'HTh'),
  (full: 'Ten Thousands', abbr: 'TTh'),
  (full: 'Thousands', abbr: 'Th'),
  (full: 'Hundreds', abbr: 'H'),
  (full: 'Tens', abbr: 'T'),
  (full: 'Ones', abbr: 'O'),
];

/// Renders [operandA]/[operandB] right-aligned under 6 labeled place-value
/// columns, with the running result building up column-by-column as steps
/// in [revealedStepIndices] accumulate, plus a small carry/borrow digit
/// above the next column to the left once a step revealing a nonzero
/// carry-out/borrow-out is in [revealedStepIndices] — conventional
/// grade-school regrouping notation.
class PlaceValueGrid extends StatelessWidget {
  const PlaceValueGrid({
    super.key,
    required this.operandA,
    required this.operandB,
    required this.operatorSymbol,
    required this.steps,
    required this.revealedStepIndices,
  });

  /// Exactly 6 digit characters (e.g. "245000") — one per column above.
  final String operandA;
  final String operandB;

  /// '+' or '-'.
  final String operatorSymbol;
  final List<WorkedExampleStep> steps;

  /// Indices into [steps] (not column positions) that have been revealed
  /// so far this session — see `WorkedExamplePanel`.
  final Set<int> revealedStepIndices;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Map<String, int> stepIndexByColumnLabel = {
      for (int i = 0; i < steps.length; i++) steps[i].columnLabel: i,
    };

    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(28), // sign gutter
      for (int col = 0; col < _placeValueColumns.length; col++) col + 1: const FixedColumnWidth(44),
    };

    Widget signCell(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(text, style: textTheme.titleLarge),
          ),
        );

    Widget digitCell(String text, {Color? color, FontWeight? fontWeight}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Center(
            child: Text(
              text,
              style: textTheme.titleLarge?.copyWith(color: color, fontWeight: fontWeight),
            ),
          ),
        );

    Widget carryCell(int col) {
      // A carry/borrow shown above THIS column comes from the NEXT
      // column to the right revealing a nonzero carry_out/borrow_out.
      final int rightCol = col + 1;
      if (rightCol >= _placeValueColumns.length) return digitCell('');
      final int? rightStepIndex = stepIndexByColumnLabel[_placeValueColumns[rightCol].full];
      if (rightStepIndex == null || !revealedStepIndices.contains(rightStepIndex)) return digitCell('');
      final WorkedExampleStep rightStep = steps[rightStepIndex];
      final int carryOrBorrow = (rightStep.carryOut ?? rightStep.borrowOut ?? 0);
      if (carryOrBorrow <= 0) return digitCell('');
      return digitCell('$carryOrBorrow', color: colorScheme.tertiary, fontWeight: FontWeight.bold);
    }

    Widget headerCell(int col) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Center(
            child: Text(
              _placeValueColumns[col].abbr,
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        );

    Widget resultCell(int col) {
      final int? stepIndex = stepIndexByColumnLabel[_placeValueColumns[col].full];
      final bool revealed = stepIndex != null && revealedStepIndices.contains(stepIndex);
      if (!revealed) return digitCell('–', color: colorScheme.outline);
      final WorkedExampleStep step = steps[stepIndex];
      return digitCell(
        '${step.resultDigit}',
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
      );
    }

    return Table(
      columnWidths: columnWidths,
      children: <TableRow>[
        TableRow(children: <Widget>[
          signCell(''),
          for (int col = 0; col < _placeValueColumns.length; col++) carryCell(col),
        ]),
        TableRow(children: <Widget>[
          signCell(''),
          for (int col = 0; col < _placeValueColumns.length; col++) headerCell(col),
        ]),
        TableRow(children: <Widget>[
          signCell(''),
          for (int col = 0; col < _placeValueColumns.length; col++) digitCell(operandA[col]),
        ]),
        TableRow(children: <Widget>[
          signCell(operatorSymbol),
          for (int col = 0; col < _placeValueColumns.length; col++) digitCell(operandB[col]),
        ]),
        TableRow(children: <Widget>[
          signCell(''),
          for (int col = 0; col < _placeValueColumns.length; col++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Divider(color: colorScheme.onSurface, height: 1, thickness: 1.5),
            ),
        ]),
        TableRow(children: <Widget>[
          signCell(''),
          for (int col = 0; col < _placeValueColumns.length; col++) resultCell(col),
        ]),
      ],
    );
  }
}

/// The interactive, step-by-step alternative to plain `body` text for a
/// page whose `lesson_pages.worked_example` (0030) is non-null — a
/// [PlaceValueGrid] on top, and below it a numbered step indicator with a
/// Reveal action and Previous/Next controls to step through one column's
/// computation at a time.
///
/// Only one step's result is added to the grid at a time (per spec: never
/// show all steps at once) — [_revealedStepIndices] tracks every step
/// visited-and-revealed so far, so navigating back to an already-revealed
/// step still shows its result/action text without needing to re-reveal
/// it, while a step that hasn't been reached yet starts hidden.
class WorkedExamplePanel extends StatefulWidget {
  const WorkedExamplePanel({super.key, required this.workedExample});

  final WorkedExample workedExample;

  @override
  State<WorkedExamplePanel> createState() => _WorkedExamplePanelState();
}

class _WorkedExamplePanelState extends State<WorkedExamplePanel> {
  int _currentStepIndex = 0;
  final Set<int> _revealedStepIndices = {};

  WorkedExampleStep get _currentStep => widget.workedExample.steps[_currentStepIndex];
  bool get _isCurrentStepRevealed => _revealedStepIndices.contains(_currentStepIndex);

  void _reveal() => setState(() => _revealedStepIndices.add(_currentStepIndex));

  void _goToStep(int index) => setState(() => _currentStepIndex = index);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final WorkedExample example = widget.workedExample;
    final int stepCount = example.steps.length;
    final bool isFirstStep = _currentStepIndex == 0;
    final bool isLastStep = _currentStepIndex == stepCount - 1;
    final String operatorSymbol = example.operation == WorkedExampleOperation.addition ? '+' : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: PlaceValueGrid(
            operandA: example.operandA,
            operandB: example.operandB,
            operatorSymbol: operatorSymbol,
            steps: example.steps,
            revealedStepIndices: _revealedStepIndices,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Step ${_currentStepIndex + 1} of $stepCount — ${_currentStep.columnLabel}',
          style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(_currentStep.computationText, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (_isCurrentStepRevealed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Text(
              _currentStep.actionText,
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          )
        else
          AppButton(
            label: 'Reveal',
            variant: AppButtonVariant.secondary,
            leadingIcon: Icons.visibility_outlined,
            onPressed: _reveal,
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton(
                label: 'Previous',
                variant: AppButtonVariant.outlined,
                leadingIcon: Icons.arrow_back,
                onPressed: isFirstStep ? null : () => _goToStep(_currentStepIndex - 1),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Next',
                trailingIcon: Icons.arrow_forward,
                // Forces the student to actually reveal the current
                // step's work before moving on — matches the "reveal,
                // then step through" flow in the mockup.
                onPressed: (isLastStep || !_isCurrentStepRevealed)
                    ? null
                    : () => _goToStep(_currentStepIndex + 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
