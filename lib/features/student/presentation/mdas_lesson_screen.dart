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
import 'mdas_lesson_content.dart';
import 'mdas_lesson_state.dart';
import 'quiz_taking_screen.dart';

class MdasLessonScreen extends ConsumerStatefulWidget {
  const MdasLessonScreen({super.key, required this.lesson, this.initialState});
  final Lesson lesson;
  final MdasLessonState? initialState;

  @override
  ConsumerState<MdasLessonScreen> createState() => _MdasLessonScreenState();
}

class _MdasLessonScreenState extends ConsumerState<MdasLessonScreen> {
  late final MdasLessonState lessonState =
      widget.initialState ?? MdasLessonState();
  bool _saving = false;
  String? _saveError;
  String _interactionStatus =
      'Drag a labeled card, or tap it then tap its destination.';

  void _change(VoidCallback action) => setState(action);

  void _select(MdasCard card) => _change(() {
    lessonState.select(card);
    _interactionStatus =
        lessonState.selectedCard == null
            ? 'Selection cleared.'
            : 'Card selected. Tap its destination.';
  });

  void _drop(MdasCard card, MdasTarget target) => _change(() {
    lessonState.drop(card, target);
    _interactionStatus =
        'Drag a labeled card, or tap it then tap its destination.';
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
                        SizedBox(height: 8),
                        Text(
                          'Your answers stay here while you rotate.',
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

  Widget _panel(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE5EF)),
    ),
    child: child,
  );

  Widget _header(bool short) => Container(
    height: short ? 62 : 70,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                'Multiplication, Division, and MDAS',
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
    padding: EdgeInsets.symmetric(horizontal: short ? 10 : 16),
    child: Row(
      children: List<Widget>.generate(7, (int index) {
        final bool active = lessonState.phase == index;
        final bool enabled = lessonState.phaseUnlocked(index);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap:
                  enabled
                      ? () => _change(() => lessonState.navigate(index))
                      : null,
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
                      width: 23,
                      height: 23,
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
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        mdasPhases[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: short ? 10 : 12,
                          fontWeight: FontWeight.w700,
                          color:
                              enabled
                                  ? active
                                      ? AppColors.primary
                                      : AppColors.textSecondary
                                  : const Color(0xFFABB5C2),
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

  Widget _board(bool short) {
    final MdasActivity task = lessonState.current;
    final bool recap = lessonState.recap;
    final String title =
        recap
            ? (lessonState.finished
                ? 'Lesson finished!'
                : 'You connected the ideas')
            : switch (task.spec.type) {
              MdasTaskType.multiply => 'Build equal groups',
              MdasTaskType.divide => 'Move objects into equal groups',
              MdasTaskType.facts => 'Connect the related facts',
              MdasTaskType.priority => 'Learn the MDAS order',
              MdasTaskType.first => 'Choose the first operation',
              MdasTaskType.solve => 'Solve one step at a time',
              MdasTaskType.story => 'Solve the picture problem',
              MdasTaskType.answer => 'Try it on your own',
            };
    final String subtitle =
        recap
            ? 'Review the groups, related facts, and operation order.'
            : switch (task.spec.type) {
              MdasTaskType.multiply =>
                'Each bundle contains the same number of objects.',
              MdasTaskType.divide =>
                'Move the outlined objects into the blue group box.',
              MdasTaskType.facts =>
                'The same picture supports multiplication and division.',
              MdasTaskType.priority =>
                'Two priority rows. Equal priority inside each row.',
              MdasTaskType.first || MdasTaskType.solve =>
                'Read the whole expression, then choose an operation.',
              MdasTaskType.story =>
                'Tap the operation, then the correct answer.',
              MdasTaskType.answer => 'Use what you learned about equal groups.',
            };
    final String key =
        '${lessonState.phase}:${lessonState.indices[lessonState.phase]}:$recap';
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
                  recap
                      ? 'LESSON RECAP'
                      : '${mdasPhases[lessonState.phase].toUpperCase()} · ACTIVITY ${lessonState.indices[lessonState.phase] + 1} OF ${lessonState.tasks[lessonState.phase].length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: short ? 20 : 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey<String>('board_$key'),
              padding: EdgeInsets.fromLTRB(
                short ? 12 : 20,
                4,
                short ? 12 : 20,
                14,
              ),
              child: recap ? _recapBoard() : _activityBoard(task, short),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityBoard(MdasActivity task, bool short) => switch (task
      .spec
      .type) {
    MdasTaskType.multiply => _multiplyBoard(task, short),
    MdasTaskType.divide => _divideBoard(task, short),
    MdasTaskType.facts => _factsBoard(task, short),
    MdasTaskType.priority => _priorityBoard(task),
    MdasTaskType.first || MdasTaskType.solve => _expressionBoard(task, short),
    MdasTaskType.story || MdasTaskType.answer => _storyBoard(task, short),
  };

  Widget _equation(String text, {bool small = false}) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: small ? 7 : 10, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F0FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: small ? 20 : 26,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    ),
  );

  Widget _dots(int count, {double size = 7, Color color = AppColors.primary}) =>
      Wrap(
        spacing: 2,
        runSpacing: 2,
        alignment: WrapAlignment.center,
        children: List<Widget>.generate(
          count,
          (_) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );

  Widget _multiplyBoard(MdasActivity task, bool short) {
    final int a = task.spec.a, b = task.spec.b;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _equation('$a × $b = ${task.done ? a * b : '?'}', small: short),
        const SizedBox(height: 5),
        Text(
          '${task.placedBundles.length} / $b groups · Total so far: ${task.runningTotal}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.center,
          children: List<Widget>.generate(
            b,
            (int id) => SizedBox(
              width: b >= 8 ? 68 : 84,
              height: 61,
              child:
                  task.filledTrays.contains(id)
                      ? _filledGroup(a, 'Group ${id + 1}')
                      : _target(
                        MdasTarget(MdasTargetKind.tray, id: id),
                        'Group ${id + 1}\nDrop here',
                        'Tray ${id + 1}, place a group of $a',
                      ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.center,
          children: List<Widget>.generate(
            b,
            (int id) =>
                task.placedBundles.contains(id)
                    ? const SizedBox.shrink()
                    : _draggable(
                      MdasCard(MdasCardKind.bundle, id: id),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _dots(a, size: 6),
                          const Text(
                            '☷ Drag',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      'Drag bundle ${id + 1} containing $a objects',
                      width: b >= 8 ? 68 : 84,
                      height: 58,
                    ),
          ),
        ),
        if (task.done)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _successLine(
              '${List<String>.filled(b, '$a').join(' + ')} = ${a * b}',
            ),
          ),
      ],
    );
  }

  Widget _filledGroup(int count, String label) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F3EA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF9ACBAF)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Center(
            child: _dots(count, size: 6, color: const Color(0xFF276445)),
          ),
        ),
        Text(
          '✓ $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF276445),
          ),
        ),
      ],
    ),
  );

  Widget _divideBoard(MdasActivity task, bool short) {
    final int total = task.spec.a, groupSize = task.spec.b;
    final int waiting = (task.remainingObjects - groupSize).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _equation(
          '$total ÷ $groupSize = ${task.done ? task.groupsMade : '?'}',
          small: short,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Objects left: ${task.remainingObjects}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (task.done)
                      const Text(
                        '✓ No objects left',
                        style: TextStyle(color: Color(0xFF276445)),
                      )
                    else
                      LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) => _draggable(
                              MdasCard(MdasCardKind.group, id: task.groupsMade),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Text(
                                    '☷',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  _dots(groupSize, size: 7),
                                  Text(
                                    'Drag these $groupSize objects',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              'Drag these $groupSize objects',
                              width: constraints.maxWidth,
                              height: 85,
                            ),
                      ),
                    if (waiting > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: _dots(
                          waiting,
                          size: 5,
                          color: const Color(0xFF97AAC2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 48),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
              ),
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  const Text(
                    'Make an equal group',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 103,
                    child:
                        task.done
                            ? _filledGroup(
                              groupSize,
                              '${task.groupsMade} equal groups',
                            )
                            : _target(
                              const MdasTarget(MdasTargetKind.newGroup),
                              '${List<String>.filled(groupSize, '○').join(' ')}\nDrop here\nMake 1 group of $groupSize',
                              'Blue destination, drop $groupSize objects here',
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Groups made: ${task.groupsMade}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        if (task.groupsMade > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: List<Widget>.generate(
                task.groupsMade,
                (int i) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F3EA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✓ Group ${i + 1}: $groupSize',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF276445),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _factsBoard(MdasActivity task, bool short) {
    const List<String> operators = <String>['×', '×', '÷', '÷'];
    return Column(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(
            4,
            (int i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  height: 45,
                  child: _filledGroup(6, '6 objects'),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Four groups of six · 24 objects total',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        for (int row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int part = 0; part < 3; part++) ...<Widget>[
                  if (part > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        part == 1 ? operators[row] : '=',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 75,
                    height: short ? 52 : 57,
                    child:
                        task.facts.containsKey(row * 3 + part)
                            ? _accepted('${task.facts[row * 3 + part]}')
                            : _target(
                              MdasTarget(
                                MdasTargetKind.fact,
                                id: row * 3 + part,
                              ),
                              '?',
                              'Equation ${row + 1}, number ${part + 1}',
                            ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _priorityBoard(MdasActivity task) => Column(
    children: <Widget>[
      for (int row = 0; row < 2; row++)
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  row == 0 ? const Color(0xFFE8F0FF) : const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  row == 0
                      ? 'First: multiplication and division'
                      : 'Then: addition and subtraction',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < 2; i++) ...<Widget>[
                      SizedBox(
                        width: 75,
                        height: 54,
                        child:
                            task.priorities.containsKey(row * 2 + i)
                                ? _accepted(task.priorities[row * 2 + i]!)
                                : _target(
                                  MdasTarget(
                                    MdasTargetKind.priority,
                                    id: row * 2 + i,
                                    row: row,
                                  ),
                                  '?',
                                  '${row == 0 ? 'First' : 'Then'} row, slot ${i + 1}',
                                ),
                      ),
                      if (i == 0) const SizedBox(width: 9),
                    ],
                    const SizedBox(width: 14),
                    const Text(
                      '← left to right →',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const Text(
        'Both operations within a row have equal priority.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _expressionBoard(MdasActivity task, bool short) {
    final List<Object> expression = task.expression;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _rules(),
        const SizedBox(height: 10),
        _equation(mdasExpression(expression), small: short),
        const SizedBox(height: 10),
        if (!task.done && task.step == MdasStep.choose) ...<Widget>[
          const Text(
            'Tap the operation to solve first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (int i = 1; i < expression.length; i += 2) ...<Widget>[
                if (i > 1) const SizedBox(width: 8),
                Expanded(
                  child: _choice(
                    '${expression[i - 1]} ${expression[i]} ${expression[i + 1]}',
                    () => _change(() => lessonState.chooseOperation(i)),
                    key: ValueKey<String>('mdas_operation_$i'),
                  ),
                ),
              ],
            ],
          ),
        ] else if (!task.done && task.step == MdasStep.result) ...<Widget>[
          _successLine(
            '✓ Solve ${expression[task.activeOperation - 1]} ${expression[task.activeOperation]} ${expression[task.activeOperation + 1]} first',
          ),
          const SizedBox(height: 8),
          Text(
            '${expression[task.activeOperation - 1]} ${expression[task.activeOperation]} ${expression[task.activeOperation + 1]} = ?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          _answerChoices(task.activeResult),
        ] else if (task.done)
          _successLine(
            task.spec.type == MdasTaskType.first
                ? '✓ Solve ${expression[task.selectedOperation! - 1]} ${expression[task.selectedOperation!]} ${expression[task.selectedOperation! + 1]} first'
                : '✓ Final answer: ${expression.first}',
          ),
        if (task.history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Column(
              children:
                  task.history
                      .map(
                        (String line) => Text(
                          '✓ $line',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF276445),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
      ],
    );
  }

  Widget _rules() => Wrap(
    spacing: 5,
    runSpacing: 4,
    alignment: WrapAlignment.center,
    children:
        <String>[
              'First: × and ÷',
              'Then: + and −',
              'Within each pair: left → right',
            ]
            .map(
              (String text) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
  );

  Widget _storyBoard(MdasActivity task, bool short) {
    final bool story = task.spec.type == MdasTaskType.story;
    final bool multiply = task.spec.operation == '×';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (story) ...<Widget>[
          Text(
            multiply
                ? 'A vendor has 8 boxes with 12 mangoes in each box. How many mangoes are there in all?'
                : 'Share 56 pencils equally among 7 students. How many pencils will each student receive?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.center,
          children: List<Widget>.generate(
            story
                ? multiply
                    ? 8
                    : 7
                : multiply
                ? task.spec.b
                : task.spec.a ~/ task.spec.b,
            (int i) => Container(
              width: story ? 92 : 73,
              height: story ? 54 : 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBDD2EC)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      story
                          ? multiply
                              ? '▣ Box ${i + 1}'
                              : 'Student ${i + 1}'
                          : 'Group ${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      story
                          ? multiply
                              ? '12 mangoes each'
                              : task.step == MdasStep.result
                              ? '✏ 8 pencils'
                              : 'Share equally'
                          : '${multiply ? task.spec.a : task.spec.b} objects',
                      style: const TextStyle(
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
        const SizedBox(height: 10),
        _equation(
          '${task.spec.a} ${story && task.step == MdasStep.choose ? '?' : task.spec.operation} ${task.spec.b} = ${task.done ? task.answer : '?'}',
          small: short,
        ),
        const SizedBox(height: 8),
        if (!task.done && story && task.step == MdasStep.choose)
          Row(
            children: <Widget>[
              Expanded(
                child: _choice(
                  '×  Multiply',
                  () => _change(() => lessonState.chooseStoryOperation('×')),
                  key: const Key('mdas_story_multiply'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _choice(
                  '÷  Divide',
                  () => _change(() => lessonState.chooseStoryOperation('÷')),
                  key: const Key('mdas_story_divide'),
                ),
              ),
            ],
          )
        else if (!task.done)
          _answerChoices(task.expectedAnswer),
        if (task.done && story && !multiply)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sharing asks how much each known group receives. Grouping asks how many groups fit into the total.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _answerChoices(int correct) {
    final List<int> options =
        <int>{
            correct,
            correct + 2,
            (correct - 2).clamp(0, 999999),
            correct + 6,
          }.toList()
          ..sort((int a, int b) => b.compareTo(a));
    return Row(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _choice(
              '${options[i]}',
              () => _change(() => lessonState.chooseAnswer(options[i])),
              key: ValueKey<String>('mdas_answer_${options[i]}'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _choice(String text, VoidCallback onPressed, {Key? key}) => SizedBox(
    height: 58,
    child: OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: const BorderSide(color: Color(0xFFBDD2EC), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );

  Widget _accepted(String text) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFE4F3EA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF9ACBAF)),
    ),
    child: Text(
      '✓ $text',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: Color(0xFF276445),
      ),
    ),
  );

  Widget _successLine(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F3EA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF276445),
      ),
    ),
  );

  Widget _recapBoard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _recapCard(
        'Equal groups',
        '6 × 4 = 24. Four groups of six.\n24 ÷ 6 = 4. Four groups fit into 24.',
      ),
      const SizedBox(height: 8),
      _recapCard(
        'Related facts',
        '6 × 4 = 24 · 4 × 6 = 24\n24 ÷ 6 = 4 · 24 ÷ 4 = 6',
      ),
      const SizedBox(height: 8),
      _recapCard(
        'MDAS order',
        'First: × and ÷, left to right.\nThen: + and −, left to right.\n24 ÷ 6 × 2 = 4 × 2 = 8.',
      ),
    ],
  );

  Widget _recapCard(String title, String detail) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4FA),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 3),
        Text(detail, style: const TextStyle(fontSize: 13, height: 1.25)),
      ],
    ),
  );

  Widget _draggable(
    MdasCard card,
    Widget content,
    String label, {
    required double width,
    required double height,
  }) {
    final bool selected = lessonState.selectedCard?.identity == card.identity;
    Widget visual({bool preview = false}) => Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: preview || selected ? const Color(0xFFE8F0FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              preview || selected ? AppColors.primary : const Color(0xFFB7CBE6),
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
      child: content,
    );
    return Focus(
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
        label: label,
        button: true,
        child: Draggable<MdasCard>(
          key: ValueKey<String>('mdas_card_${card.identity}'),
          data: card,
          feedback: Material(
            key: ValueKey<String>('mdas_drag_feedback_${card.identity}'),
            color: Colors.transparent,
            child: visual(preview: true),
          ),
          childWhenDragging: Opacity(opacity: .35, child: visual()),
          child: InkWell(
            onTap: () => _select(card),
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(10),
            child: visual(),
          ),
        ),
      ),
    );
  }

  Widget _target(MdasTarget target, String text, String label) => Focus(
    onKeyEvent: (FocusNode node, KeyEvent event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        final MdasCard? card = lessonState.selectedCard;
        if (card != null) _drop(card, target);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: DragTarget<MdasCard>(
      key: ValueKey<String>('mdas_target_${target.identity}'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails:
          (DragTargetDetails<MdasCard> details) => _drop(details.data, target),
      builder: (
        BuildContext context,
        List<MdasCard?> candidates,
        List<dynamic> rejected,
      ) {
        final bool hovered = candidates.isNotEmpty;
        return Semantics(
          label: label,
          button: true,
          child: InkWell(
            onTap: () {
              final MdasCard? card = lessonState.selectedCard;
              if (card != null) _drop(card, target);
            },
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color:
                    hovered ? const Color(0xFFD7E8FF) : const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hovered ? AppColors.primary : const Color(0xFF9FBBDE),
                  width: 2,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
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
    final MdasActivity task = lessonState.current;
    final bool recap = lessonState.recap;
    final String instruction =
        recap
            ? 'You completed all four practice activities.'
            : switch (task.spec.type) {
              MdasTaskType.multiply =>
                'Drag one group of ${task.spec.a} into each tray.',
              MdasTaskType.divide =>
                'Move the outlined group of ${task.spec.b} objects into the blue box.',
              MdasTaskType.facts =>
                'Drag the number cards to complete all four equations.',
              MdasTaskType.priority =>
                'Drag each operation into its priority row.',
              MdasTaskType.first || MdasTaskType.solve =>
                task.step == MdasStep.choose
                    ? 'Tap the operation to solve first.'
                    : 'Tap the correct answer.',
              MdasTaskType.story =>
                task.step == MdasStep.choose
                    ? 'Tap multiplication or division.'
                    : 'Tap the correct answer.',
              MdasTaskType.answer => 'Tap the correct answer.',
            };
    final String explanation =
        recap
            ? 'Review an activity or finish the lesson.'
            : switch (task.spec.type) {
              MdasTaskType.multiply =>
                '${task.spec.a} × ${task.spec.b} means ${task.spec.b} groups of ${task.spec.a} in this lesson.',
              MdasTaskType.divide =>
                'Each move takes ${task.spec.b} objects from the total. Count the groups you make.',
              MdasTaskType.facts =>
                'Four groups of six make 24. For division, start with the total.',
              MdasTaskType.priority =>
                'The letters name operations. Each pair shares one priority level.',
              MdasTaskType.first || MdasTaskType.solve =>
                'Within a priority pair, solve from left to right.',
              MdasTaskType.story =>
                task.spec.operation == '÷'
                    ? 'Sharing asks how many each student receives. Grouping asks how many groups fit.'
                    : 'Use the boxes to find the total.',
              MdasTaskType.answer => 'Use equal groups or a related fact.',
            };
    final String key =
        '${lessonState.phase}:${lessonState.indices[lessonState.phase]}:$recap';
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Move. Choose. Understand.',
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
            SizedBox(height: short ? 7 : 12),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey<String>('guide_$key'),
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
                    const SizedBox(height: 6),
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!recap) ...<Widget>[
                      const SizedBox(height: 10),
                      _guideCards(task),
                    ],
                    if (task.feedback != null && !recap) ...<Widget>[
                      const SizedBox(height: 9),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                task.feedback!.correct
                                    ? const Color(0xFFE4F3EA)
                                    : const Color(0xFFFFF3DD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${task.feedback!.correct ? '✓' : '↻'} ${task.feedback!.text}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_saveError != null && recap)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
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

  Widget _guideCards(MdasActivity task) {
    if (task.done) return const SizedBox.shrink();
    if (task.spec.type == MdasTaskType.facts) {
      return Wrap(
        spacing: 7,
        runSpacing: 7,
        alignment: WrapAlignment.center,
        children:
            <int>[24, 6, 4]
                .map(
                  (int value) => _draggable(
                    MdasCard(MdasCardKind.number, number: value),
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    'Drag reusable number $value',
                    width: 73,
                    height: 58,
                  ),
                )
                .toList(),
      );
    }
    if (task.spec.type == MdasTaskType.priority) {
      return Wrap(
        spacing: 7,
        runSpacing: 7,
        alignment: WrapAlignment.center,
        children:
            <String>['−', '÷', '+', '×']
                .where(
                  (String symbol) => !task.priorities.containsValue(symbol),
                )
                .map(
                  (String symbol) => _draggable(
                    MdasCard(MdasCardKind.operation, operation: symbol),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            '☷ Drag',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    'Drag operation $symbol',
                    width: 65,
                    height: 58,
                  ),
                )
                .toList(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _guideActions(MdasActivity task, bool recap) {
    if (recap) {
      return Column(
        children: <Widget>[
          _action(
            _saving
                ? 'Saving...'
                : _saveError == null
                ? 'Finish Lesson ✓'
                : 'Retry saving lesson',
            lessonState.practiceDone && !lessonState.finished && !_saving
                ? _finish
                : null,
          ),
          const SizedBox(height: 6),
          _quizAction(),
          const SizedBox(height: 6),
          _action(
            'Review Practice',
            () => _change(lessonState.reviewPractice),
            secondary: true,
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        if (task.done)
          _action('Continue →', () => _change(lessonState.next))
        else
          TextButton(
            onPressed: () => _change(lessonState.requestHint),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(task.hints == 0 ? 'Need a hint?' : 'Another hint'),
          ),
        Text(
          'Activity ${lessonState.indices[lessonState.phase] + 1} of ${lessonState.tasks[lessonState.phase].length}',
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
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child:
          secondary
              ? OutlinedButton(
                onPressed: onPressed,
                style: style,
                child: Text(label),
              )
              : FilledButton(
                onPressed: onPressed,
                style: style,
                child: Text(label),
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
            '← Previous',
            lessonState.phase == 0 &&
                    lessonState.indices[0] == 0 &&
                    !lessonState.recap
                ? null
                : () => _change(lessonState.previous),
            secondary: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                lessonState.recap
                    ? 'Practice completed'
                    : '${mdasPhases[lessonState.phase]} · Activity ${lessonState.indices[lessonState.phase] + 1} / ${lessonState.tasks[lessonState.phase].length}',
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
                  value: (lessonState.phase + 1) / 7,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Text(
                _interactionStatus,
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
            'Next →',
            lessonState.recap || !lessonState.current.done
                ? null
                : () => _change(lessonState.next),
          ),
        ),
      ],
    ),
  );
}
