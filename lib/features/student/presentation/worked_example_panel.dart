import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/worked_example.dart';
import '../../../core/widgets/widgets.dart';

const List<({String full, String abbr})> _placeValueColumns = [
  (full: 'Hundred Thousands', abbr: 'HTh'),
  (full: 'Ten Thousands', abbr: 'TTh'),
  (full: 'Thousands', abbr: 'Th'),
  (full: 'Hundreds', abbr: 'H'),
  (full: 'Tens', abbr: 'T'),
  (full: 'Ones', abbr: 'O'),
];

/// Six-column place-value board used by the existing worked-example model.
/// Its data matching and reveal semantics are unchanged; the redesign only
/// improves hierarchy, contrast, and tablet readability.
class PlaceValueGrid extends StatelessWidget {
  const PlaceValueGrid({
    super.key,
    required this.operandA,
    required this.operandB,
    required this.operatorSymbol,
    required this.steps,
    required this.revealedStepIndices,
  });

  final String operandA;
  final String operandB;
  final String operatorSymbol;
  final List<WorkedExampleStep> steps;
  final Set<int> revealedStepIndices;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Map<String, int> stepIndexByColumnLabel = <String, int>{
      for (int i = 0; i < steps.length; i++) steps[i].columnLabel: i,
    };
    final Map<int, TableColumnWidth> columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(34),
      for (int column = 0; column < _placeValueColumns.length; column++)
        column + 1: const FixedColumnWidth(48),
    };

    Widget signCell(String text) {
      return SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: GoogleFonts.lexend(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget digitCell(
      String text, {
      Color? color,
      FontWeight? fontWeight,
      Color? background,
    }) {
      return Container(
        height: 36,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.lexend(
            color: color ?? AppColors.textPrimary,
            fontSize: 19,
            fontWeight: fontWeight ?? FontWeight.w600,
          ),
        ),
      );
    }

    Widget carryCell(int column) {
      final int rightColumn = column + 1;
      if (rightColumn >= _placeValueColumns.length) return digitCell('');

      final int? rightStepIndex =
          stepIndexByColumnLabel[_placeValueColumns[rightColumn].full];
      if (rightStepIndex == null ||
          !revealedStepIndices.contains(rightStepIndex)) {
        return digitCell('');
      }

      final WorkedExampleStep rightStep = steps[rightStepIndex];
      final int carryOrBorrow = rightStep.carryOut ?? rightStep.borrowOut ?? 0;
      if (carryOrBorrow <= 0) return digitCell('');

      return digitCell(
        '$carryOrBorrow',
        color: AppColors.tertiary,
        fontWeight: FontWeight.w800,
        background: AppColors.tertiaryContainer,
      );
    }

    Widget headerCell(int column) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _placeValueColumns[column].abbr,
          style: GoogleFonts.inter(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    Widget resultCell(int column) {
      final int? stepIndex =
          stepIndexByColumnLabel[_placeValueColumns[column].full];
      final bool revealed =
          stepIndex != null && revealedStepIndices.contains(stepIndex);
      if (!revealed) {
        return digitCell(
          '–',
          color: colorScheme.outline,
          background: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
        );
      }

      final WorkedExampleStep step = steps[stepIndex];
      return digitCell(
        '${step.resultDigit}',
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        background: AppColors.primaryContainer,
      );
    }

    return Semantics(
      label: 'Place value calculation grid',
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: columnWidths,
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              signCell(''),
              for (int column = 0; column < _placeValueColumns.length; column++)
                carryCell(column),
            ],
          ),
          TableRow(
            children: <Widget>[
              signCell(''),
              for (int column = 0; column < _placeValueColumns.length; column++)
                headerCell(column),
            ],
          ),
          TableRow(
            children: <Widget>[
              signCell(''),
              for (int column = 0; column < _placeValueColumns.length; column++)
                digitCell(operandA[column]),
            ],
          ),
          TableRow(
            children: <Widget>[
              signCell(operatorSymbol),
              for (int column = 0; column < _placeValueColumns.length; column++)
                digitCell(operandB[column]),
            ],
          ),
          TableRow(
            children: <Widget>[
              signCell(''),
              for (int column = 0; column < _placeValueColumns.length; column++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Divider(
                    color: colorScheme.onSurface,
                    height: 8,
                    thickness: 1.5,
                  ),
                ),
            ],
          ),
          TableRow(
            children: <Widget>[
              signCell(''),
              for (int column = 0; column < _placeValueColumns.length; column++)
                resultCell(column),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive step-by-step worked example. Reveal state, step ordering, and
/// the requirement to reveal the current step before advancing are preserved.
class WorkedExamplePanel extends StatefulWidget {
  const WorkedExamplePanel({super.key, required this.workedExample});

  final WorkedExample workedExample;

  @override
  State<WorkedExamplePanel> createState() => _WorkedExamplePanelState();
}

class _WorkedExamplePanelState extends State<WorkedExamplePanel> {
  int _currentStepIndex = 0;
  final Set<int> _revealedStepIndices = <int>{};

  WorkedExampleStep get _currentStep =>
      widget.workedExample.steps[_currentStepIndex];

  bool get _isCurrentStepRevealed =>
      _revealedStepIndices.contains(_currentStepIndex);

  void _reveal() {
    setState(() => _revealedStepIndices.add(_currentStepIndex));
  }

  void _goToStep(int index) {
    setState(() => _currentStepIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final WorkedExample example = widget.workedExample;
    final int stepCount = example.steps.length;
    final bool isFirstStep = _currentStepIndex == 0;
    final bool isLastStep = _currentStepIndex == stepCount - 1;
    final String operatorSymbol =
        example.operation == WorkedExampleOperation.addition ? '+' : '−';

    final Widget board = _PlaceValueBoard(
      example: example,
      operatorSymbol: operatorSymbol,
      revealedStepIndices: _revealedStepIndices,
    );
    final Widget stepSurface = _WorkedStepSurface(
      step: _currentStep,
      currentStepIndex: _currentStepIndex,
      stepCount: stepCount,
      isRevealed: _isCurrentStepRevealed,
      onReveal: _reveal,
      onPrevious: isFirstStep ? null : () => _goToStep(_currentStepIndex - 1),
      onNext:
          isLastStep || !_isCurrentStepRevealed
              ? null
              : () => _goToStep(_currentStepIndex + 1),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 780) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 5, child: board),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 4, child: stepSurface),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            board,
            const SizedBox(height: AppSpacing.md),
            stepSurface,
          ],
        );
      },
    );
  }
}

class _PlaceValueBoard extends StatelessWidget {
  const _PlaceValueBoard({
    required this.example,
    required this.operatorSymbol,
    required this.revealedStepIndices,
  });

  final WorkedExample example;
  final String operatorSymbol;
  final Set<int> revealedStepIndices;

  @override
  Widget build(BuildContext context) {
    final String operationLabel =
        example.operation == WorkedExampleOperation.addition
            ? 'ADDITION BOARD'
            : 'SUBTRACTION BOARD';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      operationLabel,
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Build the answer one place at a time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: PlaceValueGrid(
                operandA: example.operandA,
                operandB: example.operandB,
                operatorSymbol: operatorSymbol,
                steps: example.steps,
                revealedStepIndices: revealedStepIndices,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              const Icon(
                Icons.touch_app_rounded,
                color: AppColors.textSecondary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reveal each step to fill the answer row.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkedStepSurface extends StatelessWidget {
  const _WorkedStepSurface({
    required this.step,
    required this.currentStepIndex,
    required this.stepCount,
    required this.isRevealed,
    required this.onReveal,
    required this.onPrevious,
    required this.onNext,
  });

  final WorkedExampleStep step;
  final int currentStepIndex;
  final int stepCount;
  final bool isRevealed;
  final VoidCallback onReveal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'STEP ${currentStepIndex + 1} OF $stepCount',
                  style: GoogleFonts.inter(
                    color: AppColors.tertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                step.columnLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (currentStepIndex + 1) / stepCount,
              minHeight: 6,
              backgroundColor: AppColors.tertiaryContainer,
              color: AppColors.tertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.all(AppSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              step.computationText,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                isRevealed
                    ? Container(
                      key: ValueKey<int>(currentStepIndex),
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              step.actionText,
                              style: GoogleFonts.inter(
                                color: AppColors.onSecondaryContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : AppButton(
                      key: ValueKey<int>(currentStepIndex),
                      label: 'Reveal this step',
                      size: AppComponentSize.large,
                      variant: AppButtonVariant.secondary,
                      leadingIcon: Icons.visibility_rounded,
                      isFullWidth: true,
                      onPressed: onReveal,
                    ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Back',
                  size: AppComponentSize.large,
                  variant: AppButtonVariant.outlined,
                  leadingIcon: Icons.arrow_back_rounded,
                  onPressed: onPrevious,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Next step',
                  size: AppComponentSize.large,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: onNext,
                ),
              ),
            ],
          ),
          if (onNext == null && !isRevealed) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Reveal the work before moving on.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
