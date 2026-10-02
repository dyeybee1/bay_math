import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/lesson_progress_repository.dart';
import '../data/student_lessons_providers.dart';
import '../data/student_statistics_providers.dart';
import 'lesson_viewer_screen.dart' show linkedQuizProvider;
import 'lesson_back_button.dart';
import 'place_value_lesson_content.dart';
import 'place_value_lesson_state.dart';
import 'quiz_taking_screen.dart';

class PlaceValueLessonScreen extends ConsumerStatefulWidget {
  const PlaceValueLessonScreen({
    super.key,
    required this.lesson,
    this.initialState,
  });
  final Lesson lesson;
  final PlaceValueLessonState? initialState;

  @override
  ConsumerState<PlaceValueLessonScreen> createState() =>
      _PlaceValueLessonScreenState();
}

class _PlaceValueLessonScreenState
    extends ConsumerState<PlaceValueLessonScreen> {
  late final PlaceValueLessonState lessonState =
      widget.initialState ?? PlaceValueLessonState();
  bool _saving = false;
  String? _saveError;
  String _status = 'Drag a card, or tap a card then tap its destination.';

  void _change(VoidCallback action) => setState(action);

  void _select(PlaceCard card) => _change(() {
    lessonState.select(card);
    _status =
        lessonState.selected == null
            ? 'Selection cleared.'
            : 'Card selected. Tap its destination.';
  });

  void _drop(PlaceCard card, PlaceTarget target) => _change(() {
    lessonState.drop(card, target);
    _status = 'Drag a card, or tap a card then tap its destination.';
  });

  Future<void> _finish() async {
    if (!lessonState.practiceDone || lessonState.finished || _saving) return;
    final StudentSession? session = ref.read(studentSessionProvider);
    final LessonProgressRepository? repository = ref.read(
      lessonProgressRepositoryProvider,
    );
    if (session == null || repository == null) {
      setState(
        () =>
            _saveError =
                'Your session expired. Sign in again to save the lesson.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await repository.markCompleted(
        studentId: session.studentId,
        lessonId: widget.lesson.id,
      );
      if (!mounted) return;
      ref.invalidate(studentCompletedLessonIdsProvider);
      ref.invalidate(studentStatisticsProvider);
      setState(() {
        lessonState.finished = true;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save the lesson. Tap Retry to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (size.height > size.width) {
      return ColoredBox(
        color: const Color(0xFFF3F7FC),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _header(true),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.screen_rotation_rounded,
                          size: 76,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Turn your tablet sideways',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'This lesson needs room to move and match cards.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final bool short = size.height < 690;
    return ColoredBox(
      color: const Color(0xFFF3F7FC),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _header(short),
            _phaseBar(short),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(short ? 12 : 18),
                child: Row(
                  children: <Widget>[
                    Expanded(flex: 17, child: _board(short)),
                    SizedBox(width: short ? 12 : 18),
                    Expanded(flex: 10, child: _guide(short)),
                  ],
                ),
              ),
            ),
            _footer(short),
          ],
        ),
      ),
    );
  }

  Widget _header(bool short) => Container(
    height: short ? 62 : 70,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    color: Colors.white,
    child: Row(
      children: <Widget>[
        const LessonBackButton(),
        const SizedBox(width: 8),
        if (MediaQuery.sizeOf(context).width >= 600) ...<Widget>[
          const Icon(
            Icons.calculate_rounded,
            size: 31,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          const Text(
            'BayMath',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 32, color: const Color(0xFFDCE5EF)),
          const SizedBox(width: 16),
        ],
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'GRADE 4 · GUIDED LESSON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Place Value of Whole Numbers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _phaseBar(bool short) => Container(
    height: short ? 56 : 62,
    color: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: short ? 12 : 18),
    child: Row(
      children: List<Widget>.generate(6, (int index) {
        final bool active = lessonState.phase == index;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => _change(() => lessonState.navigate(index)),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFD9E7F7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            active
                                ? AppColors.primary
                                : const Color(0xFFEDF1F6),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color:
                              active ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        placeValuePhases[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: short ? 11 : 13,
                          fontWeight: FontWeight.w700,
                          color:
                              active
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _panel(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE5EF)),
    ),
    child: child,
  );

  Widget _board(bool short) {
    final PlaceActivity? task = lessonState.current;
    final bool recap = lessonState.phase == 5 && lessonState.recap;
    final String title =
        lessonState.phase == 0
            ? 'One digit. Two different values.'
            : recap
            ? (lessonState.finished
                ? 'Lesson finished!'
                : 'Connect the three forms')
            : switch (task!.spec.type) {
              PlaceTaskType.align => 'Build the number by place',
              PlaceTaskType.identify => 'Find the place and the value',
              PlaceTaskType.standard => 'Write the words using digits',
              PlaceTaskType.reverse => 'Build the number from its values',
              PlaceTaskType.expanded => 'Match every digit with its value',
              PlaceTaskType.repeat => 'Same digit, different value',
            };
    final String subtitle =
        lessonState.phase == 0
            ? 'Move 5 between hundreds and tens.'
            : recap
            ? 'Each view describes the same number.'
            : switch (task!.spec.type) {
              PlaceTaskType.align =>
                'Place each digit of 528,946 under its column.',
              PlaceTaskType.identify =>
                'Use the highlighted digit in ${placeFormat(task.spec.number)}.',
              PlaceTaskType.standard => 'Keep every zero that holds a place.',
              PlaceTaskType.reverse =>
                'Read each expanded term and find its digit.',
              PlaceTaskType.expanded =>
                'A digit’s contribution is digit × place unit.',
              PlaceTaskType.repeat =>
                'Look at the first and second highlighted digits.',
            };
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              short ? 12 : 20,
              short ? 10 : 18,
              short ? 12 : 20,
              4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  placeValuePhases[lessonState.phase].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: short ? 20 : 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                short ? 12 : 20,
                6,
                short ? 12 : 20,
                16,
              ),
              child:
                  lessonState.phase == 0
                      ? _exploreBoard()
                      : recap
                      ? _recapBoard()
                      : _activityBoard(task!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exploreBoard() {
    final int? column = lessonState.exploreColumn;
    final int unit = column == null ? 0 : placeValueUnits[column];
    return Column(
      children: <Widget>[
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            for (final int col in <int>[4, 5])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: <Widget>[
                      Text(
                        placeValueNames[col],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 70,
                        child: _target(
                          PlaceTarget(PlaceTargetKind.explore, column: col),
                          column == col ? '5' : '·',
                          '${placeValueNames[col]} place',
                          filled: column == col,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (column == null)
          const Text(
            'Where will you place 5?',
            style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
          )
        else ...<Widget>[
          Text(
            '5 × ${placeFormat(unit)} = ${placeFormat(5 * unit)}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List<Widget>.generate(
              5,
              (int i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        placeFormat(unit),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'per group',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Five ${placeValueNames[column].toLowerCase()}. Total value: ${placeFormat(5 * unit)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _activityBoard(PlaceActivity task) {
    switch (task.spec.type) {
      case PlaceTaskType.align:
        return Column(
          children: <Widget>[
            const SizedBox(height: 16),
            _numberBoard(task, digitTargets: true),
            if (task.done) _answerBanner('528,946'),
          ],
        );
      case PlaceTaskType.identify:
        final int col = task.highlightedColumn;
        return Column(
          children: <Widget>[
            _numberBoard(task, highlight: <int>{col}),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: _labeledTarget(
                    'Place',
                    const PlaceTarget(PlaceTargetKind.place),
                    task.place == null
                        ? 'Column name'
                        : placeValueNames[task.place!],
                    task.place != null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _labeledTarget(
                    'Value',
                    const PlaceTarget(PlaceTargetKind.value),
                    task.value == null ? 'Amount' : placeFormat(task.value!),
                    task.value != null,
                  ),
                ),
              ],
            ),
            if (task.done)
              _answerBanner(
                '${task.digits[col]} × ${placeFormat(placeValueUnits[col])} = ${placeFormat(task.value!)}',
              ),
          ],
        );
      case PlaceTaskType.standard:
      case PlaceTaskType.reverse:
        return Column(
          children: <Widget>[
            _readingCard(
              task.spec.type == PlaceTaskType.reverse
                  ? placeExpandedTerms(
                    task.spec.number,
                  ).map(placeFormat).join(' + ')
                  : placeValueWords[task.spec.number]!,
            ),
            const SizedBox(height: 16),
            _numberBoard(task, digitTargets: true, periods: true),
            if (task.done) _answerBanner(placeFormat(task.spec.number)),
          ],
        );
      case PlaceTaskType.expanded:
        return Column(
          children: <Widget>[
            _numberBoard(task, amountTargets: true),
            if (task.done) ...<Widget>[
              _answerBanner(
                '${placeExpandedTerms(task.spec.number, includeZeros: !task.simplified).map(placeFormat).join(' + ')} = ${placeFormat(task.spec.number)}',
              ),
              if (task.hasZero)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Zero contributes 0. Its digit stays in the standard-form number.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        );
      case PlaceTaskType.repeat:
        final List<int> cols = task.repeatedColumns;
        final List<int> values = task.repeatedValues;
        return Column(
          children: <Widget>[
            _numberBoard(task, highlight: cols.toSet()),
            const SizedBox(height: 14),
            Row(
              children: List<Widget>.generate(
                2,
                (int i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == 0 ? 5 : 0,
                      left: i == 1 ? 5 : 0,
                    ),
                    child: _labeledTarget(
                      '${i == 0 ? 'First' : 'Second'} ${task.digits[cols[i]]} · ${placeValueNames[cols[i]]}',
                      PlaceTarget(PlaceTargetKind.repeated, slot: i),
                      task.repeated[i] == null
                          ? 'Value'
                          : placeFormat(task.repeated[i]!),
                      task.repeated[i] != null,
                    ),
                  ),
                ),
              ),
            ),
            if (task.repeated.every((int? value) => value != null)) ...<Widget>[
              const SizedBox(height: 12),
              _labeledTarget(
                'Greater value',
                const PlaceTarget(PlaceTargetKind.greater),
                task.greater == null ? 'Drop a value' : placeFormat(values[0]),
                task.greater != null,
              ),
            ],
            if (task.done)
              _answerBanner(
                '${placeFormat(values[0])} is ten times ${placeFormat(values[1])}.',
              ),
          ],
        );
    }
  }

  Widget _labeledTarget(
    String label,
    PlaceTarget target,
    String value,
    bool filled,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 5),
      SizedBox(
        height: 60,
        child: _target(target, value, label, filled: filled, fontSize: 15),
      ),
    ],
  );

  Widget _numberBoard(
    PlaceActivity task, {
    bool digitTargets = false,
    bool amountTargets = false,
    bool periods = false,
    Set<int> highlight = const <int>{},
  }) {
    final Set<int> valid = task.positions.toSet();
    Widget row(List<Widget> children) => Row(
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: children[i]),
        ],
      ],
    );
    return Column(
      children: <Widget>[
        if (periods) ...<Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Text('Millions', textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text('Thousands', textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text('Ones', textAlign: TextAlign.center),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        row(
          List<Widget>.generate(
            7,
            (int col) => SizedBox(
              height: 39,
              child: Center(
                child: Text(
                  placeValueNames[col],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight:
                        highlight.contains(col)
                            ? FontWeight.w800
                            : FontWeight.w500,
                    color:
                        highlight.contains(col)
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        row(
          List<Widget>.generate(7, (int col) {
            if (!valid.contains(col)) return const SizedBox(height: 58);
            if (digitTargets) {
              final int? digit = task.filled[col];
              return SizedBox(
                height: 58,
                child: _target(
                  PlaceTarget(PlaceTargetKind.digit, column: col),
                  digit == null ? '·' : '$digit',
                  '${placeValueNames[col]} digit',
                  filled: digit != null,
                ),
              );
            }
            return Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    highlight.contains(col)
                        ? const Color(0xFFFFF0CE)
                        : const Color(0xFFF0F4FA),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color:
                      highlight.contains(col)
                          ? const Color(0xFFBB791A)
                          : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                '${task.digits[col]}',
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            );
          }),
        ),
        if (amountTargets) ...<Widget>[
          const SizedBox(height: 8),
          row(
            List<Widget>.generate(7, (int col) {
              if (!valid.contains(col)) return const SizedBox(height: 58);
              final int? amount = task.filled[col];
              return SizedBox(
                height: 58,
                child: _target(
                  PlaceTarget(PlaceTargetKind.contribution, column: col),
                  amount == null ? '?' : placeFormat(amount),
                  '${placeValueNames[col]} contribution',
                  filled: amount != null,
                  fontSize: 14,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _recapBoard() => Column(
    children: <Widget>[
      _readingCard('528,946'),
      const SizedBox(height: 12),
      _readingCard(placeValueWords[528946]!),
      const SizedBox(height: 12),
      _answerBanner(placeExpandedTerms(528946).map(placeFormat).join(' + ')),
      const SizedBox(height: 12),
      const Text(
        'Place is position. Value is digit × place unit.',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _readingCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F0FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
  );

  Widget _answerBanner(String text) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F3EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xFF276445),
        ),
      ),
    ),
  );

  Widget _card(
    PlaceCard card,
    String text,
    String label, {
    double fontSize = 21,
    double? width,
  }) {
    final bool selected = lessonState.selected?.identity == card.identity;
    Widget visual({bool preview = false}) => Container(
      constraints: BoxConstraints(minWidth: width ?? 52, minHeight: 52),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: preview || selected ? const Color(0xFFE8F0FF) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color:
              preview || selected ? AppColors.primary : const Color(0xFFBBCEE8),
          width: 2,
        ),
        boxShadow:
            preview
                ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .25),
                    blurRadius: 12,
                  ),
                ]
                : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
    return SizedBox(
      width: width ?? 52,
      child: Focus(
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _select(card);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          label: 'Drag or select $label',
          button: true,
          child: Draggable<PlaceCard>(
            key: ValueKey<String>('place_card_${card.identity}'),
            data: card,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width ?? 76,
                height: 58,
                child: visual(preview: true),
              ),
            ),
            childWhenDragging: Opacity(opacity: .35, child: visual()),
            onDragEnd: (DraggableDetails details) {
              if (!details.wasAccepted) {
                _change(
                  () => _status = 'Card returned. Try an empty destination.',
                );
              }
            },
            child: InkWell(
              onTap: () => _select(card),
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(11),
              child: visual(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _target(
    PlaceTarget target,
    String text,
    String label, {
    bool filled = false,
    double fontSize = 23,
  }) => Focus(
    onKeyEvent: (FocusNode node, KeyEvent event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        final PlaceCard? card = lessonState.selected;
        if (card != null) _drop(card, target);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: DragTarget<PlaceCard>(
      key: ValueKey<String>('place_target_${target.identity}'),
      onWillAcceptWithDetails: (_) => !filled,
      onAcceptWithDetails:
          (DragTargetDetails<PlaceCard> details) => _drop(details.data, target),
      builder: (
        BuildContext context,
        List<PlaceCard?> candidates,
        List<dynamic> rejected,
      ) {
        final bool hovered = candidates.isNotEmpty;
        return Semantics(
          label: '$label${filled ? ', completed' : ', empty destination'}',
          button: true,
          child: InkWell(
            onTap: () {
              final PlaceCard? card = lessonState.selected;
              if (card != null) _drop(card, target);
            },
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    filled
                        ? const Color(0xFFE4F3EA)
                        : hovered
                        ? const Color(0xFFD7E8FF)
                        : const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color:
                      filled
                          ? const Color(0xFF80B79A)
                          : hovered
                          ? AppColors.primary
                          : const Color(0xFFBECFE6),
                  width: 2,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: filled ? const Color(0xFF276445) : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _guide(bool short) {
    final PlaceActivity? task = lessonState.current;
    final bool recap = lessonState.phase == 5 && lessonState.recap;
    final String instruction =
        lessonState.phase == 0
            ? 'Drag 5 into a place. Watch its value change.'
            : recap
            ? 'You completed four practice activities.'
            : switch (task!.spec.type) {
              PlaceTaskType.align => 'Drag each digit into its column.',
              PlaceTaskType.identify =>
                'Match a column name to Place and an amount to Value.',
              PlaceTaskType.standard || PlaceTaskType.reverse =>
                'Drag digits into the place-value board.',
              PlaceTaskType.expanded =>
                'Drag each value under its matching digit.',
              PlaceTaskType.repeat =>
                task.repeated.every((int? value) => value != null)
                    ? 'Drag the greater value into the answer box.'
                    : 'Match a value to each highlighted digit.',
            };
    final PlaceFeedback? feedback = lessonState.feedback;
    return _panel(
      Padding(
        padding: EdgeInsets.all(short ? 10 : 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/comparing_numbers_owl.jpg',
                    width: short ? 37 : 48,
                    height: short ? 37 : 48,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) => const Icon(
                          Icons.auto_stories_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your BayMath guide',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Move. Match. Understand.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: short ? 6 : 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'YOUR TURN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      instruction,
                      style: TextStyle(
                        fontSize: short ? 16 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!recap) ...<Widget>[
                      const SizedBox(height: 5),
                      const Text(
                        'Drag with your finger, or tap a card then tap its destination.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _bank(task),
                    ],
                    if (feedback != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                feedback.correct
                                    ? const Color(0xFFE4F3EA)
                                    : const Color(0xFFFFF3DD),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${feedback.correct ? '✓' : '↻'} ${feedback.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                feedback.detail,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (task != null && task.hints > 0) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        lessonState.hintFor(task),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF765018),
                        ),
                      ),
                    ],
                    if (_saveError != null && recap) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _saveError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _guideActions(task, recap),
          ],
        ),
      ),
    );
  }

  Widget _bank(PlaceActivity? task) {
    if (task == null) {
      return Center(
        child: _card(
          const PlaceCard(PlaceCardKind.explore, 5),
          '5',
          'digit 5',
          width: 85,
        ),
      );
    }
    if (task.done) return const SizedBox.shrink();
    if (task.spec.type == PlaceTaskType.align) {
      final List<int> digits =
          task.spec.number.toString().split('').map(int.parse).toList();
      return Wrap(
        spacing: 5,
        runSpacing: 5,
        alignment: WrapAlignment.center,
        children: List<Widget>.generate(
          digits.length,
          (int i) =>
              task.usedCards.contains(i)
                  ? const SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Color(0xFF276445),
                      ),
                    ),
                  )
                  : _card(
                    PlaceCard(PlaceCardKind.alignment, digits[i], id: i),
                    '${digits[i]}',
                    'digit ${digits[i]} card ${i + 1}',
                  ),
        ),
      );
    }
    if (task.spec.type == PlaceTaskType.standard ||
        task.spec.type == PlaceTaskType.reverse) {
      return _digitBank();
    }
    if (task.spec.type == PlaceTaskType.identify) {
      final int col = task.highlightedColumn;
      final int digit = task.digits[col];
      final int correctValue = digit * placeValueUnits[col];
      return Column(
        children: <Widget>[
          if (task.place == null)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children:
                  <int>[col, (col + 1) % 7, (col + 2) % 7]
                      .map(
                        (int c) => _card(
                          PlaceCard(PlaceCardKind.place, c, column: c),
                          placeValueNames[c],
                          placeValueNames[c],
                          fontSize: 12,
                          width: 86,
                        ),
                      )
                      .toList(),
            ),
          if (task.value == null) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children:
                  <int>{digit, correctValue, digit * 10}
                      .map(
                        (int value) => _card(
                          PlaceCard(PlaceCardKind.value, value),
                          placeFormat(value),
                          'value ${placeFormat(value)}',
                          fontSize: 16,
                          width: 78,
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      );
    }
    if (task.spec.type == PlaceTaskType.expanded) {
      return Wrap(
        spacing: 5,
        runSpacing: 5,
        alignment: WrapAlignment.center,
        children: <Widget>[
          for (final int col in <int>[
            ...task.positions.where((int c) => task.digits[c] == 0),
            ...task.positions.reversed.where((int c) => task.digits[c] != 0),
          ])
            if (!task.usedCards.contains(col))
              _card(
                PlaceCard(
                  PlaceCardKind.contribution,
                  task.digits[col] * placeValueUnits[col],
                  id: col,
                ),
                placeFormat(task.digits[col] * placeValueUnits[col]),
                '${placeFormat(task.digits[col] * placeValueUnits[col])} contribution card for ${placeValueNames[col]}',
                fontSize: 15,
                width: 82,
              ),
        ],
      );
    }
    final List<int> values = task.repeatedValues;
    if (task.repeated.every((int? value) => value != null)) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children:
            values
                .map(
                  (int value) => _card(
                    PlaceCard(PlaceCardKind.greater, value),
                    placeFormat(value),
                    'compare value ${placeFormat(value)}',
                    fontSize: 16,
                    width: 102,
                  ),
                )
                .toList(),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children:
          <int>{
                ...values,
                task.digits[task.repeatedColumns[0]],
                task.digits[task.repeatedColumns[0]] * 1000,
              }
              .map(
                (int value) => _card(
                  PlaceCard(PlaceCardKind.value, value),
                  placeFormat(value),
                  'value ${placeFormat(value)}',
                  fontSize: 16,
                  width: 94,
                ),
              )
              .toList(),
    );
  }

  Widget _digitBank() => Wrap(
    spacing: 5,
    runSpacing: 5,
    alignment: WrapAlignment.center,
    children: List<Widget>.generate(
      10,
      (int digit) => _card(
        PlaceCard(PlaceCardKind.digit, digit),
        '$digit',
        'reusable digit $digit',
        width: 53,
      ),
    ),
  );

  Widget _guideActions(PlaceActivity? task, bool recap) {
    if (recap) {
      return Column(
        children: <Widget>[
          _action(
            _saving
                ? 'Saving...'
                : _saveError == null
                ? 'Finish lesson ✓'
                : 'Retry saving lesson',
            lessonState.practiceDone && !lessonState.finished && !_saving
                ? _finish
                : null,
          ),
          const SizedBox(height: 6),
          _quizAction(),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _action(
                  'Review practice',
                  () => _change(lessonState.reviewPractice),
                  secondary: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _action(
                  'Review place & value',
                  () => _change(() => lessonState.navigate(1)),
                  secondary: true,
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (lessonState.phase == 0) {
      return _action(
        'Explore place and value →',
        () => _change(() => lessonState.navigate(1)),
      );
    }
    if (task == null) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        if (task.done &&
            task.hasZero &&
            task.spec.type == PlaceTaskType.expanded &&
            !task.simplified)
          _action(
            'Omit the + 0 terms',
            () => _change(() => task.simplified = true),
            secondary: true,
          ),
        if (task.done) ...<Widget>[
          const SizedBox(height: 5),
          _action(
            lessonState.phase == 5 && lessonState.indices[5] == 3
                ? 'See the recap →'
                : lessonState.indices[lessonState.phase] ==
                    lessonState.tasks[lessonState.phase].length - 1
                ? 'Next part →'
                : 'Next activity →',
            () => _change(lessonState.nextActivity),
          ),
        ] else
          TextButton(
            onPressed: () => _change(lessonState.addHint),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(task.hints == 0 ? 'Need a hint?' : 'Another hint'),
          ),
        Text(
          '${lessonState.phase == 5 ? 'Practice' : 'Activity'} '
          '${lessonState.indices[lessonState.phase] + 1} of ${lessonState.tasks[lessonState.phase].length}',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _action(
    String label,
    VoidCallback? onPressed, {
    bool secondary = false,
  }) {
    final ButtonStyle style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(double.infinity, 52),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 5),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
    return secondary
        ? OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1),
          ),
        )
        : FilledButton(
          onPressed: onPressed,
          style: style,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1),
          ),
        );
  }

  Widget _quizAction() {
    final String? quizId = widget.lesson.linkedQuizId;
    if (quizId == null) return const SizedBox.shrink();
    final AsyncValue<Quiz?> quizAsync = ref.watch(linkedQuizProvider(quizId));
    return quizAsync.maybeWhen(
      data:
          (Quiz? quiz) =>
              quiz == null
                  ? const SizedBox.shrink()
                  : _action(
                    'Take Quiz · Optional',
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => QuizTakingScreen(quiz: quiz),
                      ),
                    ),
                    secondary: true,
                  ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _footer(bool short) => Container(
    height: short ? 66 : 76,
    color: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: short ? 16 : 24, vertical: 7),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 155,
          child: _action(
            '← Previous part',
            lessonState.phase == 0
                ? null
                : () =>
                    _change(() => lessonState.navigate(lessonState.phase - 1)),
            secondary: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Part ${lessonState.phase + 1} of 6 · ${placeValuePhases[lessonState.phase]}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 300,
                child: LinearProgressIndicator(
                  value: (lessonState.phase + 1) / 6,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Text(
                _status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 155,
          child: _action(
            'Next part →',
            lessonState.phase == 5
                ? null
                : () =>
                    _change(() => lessonState.navigate(lessonState.phase + 1)),
          ),
        ),
      ],
    ),
  );
}
