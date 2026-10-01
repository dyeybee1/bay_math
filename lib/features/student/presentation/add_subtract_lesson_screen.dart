import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/lesson_progress_repository.dart';
import '../data/student_lessons_providers.dart';
import '../data/student_statistics_providers.dart';
import 'add_subtract_lesson_content.dart';
import 'add_subtract_lesson_math.dart';
import 'add_subtract_lesson_state.dart';
import 'lesson_viewer_screen.dart' show linkedQuizProvider;
import 'quiz_taking_screen.dart';

class AddSubtractLessonScreen extends ConsumerStatefulWidget {
  const AddSubtractLessonScreen({
    super.key,
    required this.lesson,
    this.initialState,
  });
  final Lesson lesson;
  final AddSubtractLessonState? initialState;

  @override
  ConsumerState<AddSubtractLessonScreen> createState() =>
      _AddSubtractLessonScreenState();
}

class _AddSubtractLessonScreenState
    extends ConsumerState<AddSubtractLessonScreen> {
  late final AddSubtractLessonState lessonState =
      widget.initialState ?? AddSubtractLessonState();
  bool _saving = false;
  String? _saveError;
  String _interactionStatus =
      'Drag a tile, or tap a tile then tap its destination.';

  void _change(VoidCallback action) {
    setState(action);
  }

  void _select(LessonTile tile) {
    setState(() {
      lessonState.select(tile);
      _interactionStatus =
          lessonState.selected == null
              ? 'Selection cleared. Choose a tile to try again.'
              : 'Tile selected. Tap its destination.';
    });
  }

  void _place(LessonTile tile, LessonZone zone) {
    setState(() {
      lessonState.place(tile, zone);
      _interactionStatus =
          'Drag a tile, or tap a tile then tap its destination.';
    });
  }

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
                'Your session expired. Sign in again to save your lesson.',
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
      await SemanticsService.sendAnnouncement(
        View.of(context),
        'Lesson finished and progress saved',
        TextDirection.ltr,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save your lesson. Tap Retry to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (size.height > size.width) {
      return const Center(
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
              SizedBox(height: 24),
              Text(
                'Turn your tablet sideways',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Text(
                'This lesson uses landscape so you have room to move the digits.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final bool short = size.height < 690;
    return ColoredBox(
      color: const Color(0xFFF4F7FB),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _header(short),
            _phaseTabs(short),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  short ? 14 : 20,
                  short ? 10 : 16,
                  short ? 14 : 20,
                  short ? 10 : 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 18, child: _surface(_board(short), short)),
                    SizedBox(width: short ? 12 : 16),
                    Expanded(flex: 10, child: _surface(_guide(short), short)),
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

  Widget _surface(Widget child, bool short) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(short ? 18 : 22),
      border: Border.all(color: const Color(0xFFDCE5EE)),
    ),
    child: child,
  );

  Widget _header(bool short) => Container(
    height: short ? 62 : 72,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Back to lessons',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
        const SizedBox(width: 8),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'BayMath',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: short ? 17 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 18),
        Container(width: 1, height: 34, color: AppColors.outlineVariant),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'GRADE 4 · GUIDED LESSON',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: short ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _phaseTabs(bool short) => Container(
    height: short ? 56 : 62,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
    ),
    child: Row(
      children: <Widget>[
        for (int i = 0; i < addSubtractPhases.length; i++)
          Expanded(
            child: Semantics(
              selected: lessonState.phase == i,
              child: TextButton(
                onPressed: () => _change(() => lessonState.navigate(i)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor:
                      lessonState.phase == i
                          ? AppColors.primaryContainer
                          : Colors.transparent,
                  foregroundColor:
                      lessonState.phase == i
                          ? AppColors.primary
                          : AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              lessonState.phase == i
                                  ? AppColors.primary
                                  : const Color(0xFFEDF1F6),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                lessonState.phase == i
                                    ? Colors.white
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        addSubtractPhases[i],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _board(bool short) {
    final int phase = lessonState.phase;
    final ArithmeticWork? work = lessonState.currentWork;
    final String title = switch (phase) {
      0 => 'More books for the library',
      1 => 'Line up by place value',
      2 || 3 || 4 =>
        work!.problem.operation == '+'
            ? 'Build the sum'
            : 'Build the difference',
      _ => lessonState.finished ? 'Lesson finished!' : 'Remember the method',
    };
    final String subtitle = switch (phase) {
      0 => 'Choose the operation that finds the total.',
      1 => 'Each digit has a place. Start with ones at the right.',
      4 => 'Your turn. Use the place-value board to solve.',
      2 || 3 => 'Line up the digits. Start at ones.',
      _ => 'Addition and subtraction work column by column.',
    };
    final String tag = switch (phase) {
      0 => 'Start',
      1 => 'Arrange',
      2 => 'Example ${lessonState.additionIndex + 1}/3',
      3 => 'Example ${lessonState.subtractionIndex + 1}/2',
      4 => 'Practice ${lessonState.practiceIndex + 1}/4',
      _ => 'Recap',
    };
    return Padding(
      padding: EdgeInsets.all(short ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      addSubtractPhases[phase].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: short ? 21 : 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: short ? 4 : 8),
          Expanded(
            child: LayoutBuilder(
              builder:
                  (BuildContext context, BoxConstraints constraints) =>
                      SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: switch (phase) {
                                0 => _startBoard(),
                                1 => _alignmentBoard(),
                                2 || 3 || 4 => _calculationBoard(work!),
                                _ => _recapBoard(),
                              },
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startBoard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: AppColors.primary,
          size: 35,
        ),
      ),
      const SizedBox(height: 12),
      const Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: 'The library has '),
            TextSpan(
              text: '245,000 books.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: '\nIt receives '),
            TextSpan(
              text: '132,500 more.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 19, height: 1.5),
      ),
      const SizedBox(height: 15),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Flexible(
            child: FittedBox(
              child: Text(
                '245,000',
                style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            height: 68,
            child: _dropZone(
              const LessonZone.operation(),
              lessonState.startDone ? '+' : '?',
              'Operation between 245,000 and 132,500',
              active: !lessonState.startDone,
              filled: lessonState.startDone,
              fontSize: 34,
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: FittedBox(
              child: Text(
                '132,500',
                style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Which operation combines the two amounts?',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    ],
  );

  Widget _alignmentBoard() {
    final List<int> top = placeDigits(
      AddSubtractLessonState.alignmentNumbers[0],
    );
    final List<int> bottom = placeDigits(
      AddSubtractLessonState.alignmentNumbers[1],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _placeLabels(),
        for (int row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: <Widget>[
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child:
                          col <
                                  7 -
                                      AddSubtractLessonState
                                          .alignmentNumbers[row]
                                          .toString()
                                          .length
                              ? Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FB),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              )
                              : _dropZone(
                                LessonZone.alignment(row, col),
                                lessonState.alignmentPlaced[row][col] == null
                                    ? '·'
                                    : '${row == 0 ? top[col] : bottom[col]}',
                                'Row ${row + 1}, ${placeNames[col]}',
                                filled:
                                    lessonState.alignmentPlaced[row][col] !=
                                    null,
                                fontSize: 25,
                              ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 5),
        for (int row = 0; row < 2; row++) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${row == 0 ? 'Top' : 'Bottom'}: '
              '${formatPlaceNumber(AddSubtractLessonState.alignmentNumbers[row])}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              for (
                int i = 0;
                i <
                    AddSubtractLessonState.alignmentNumbers[row]
                        .toString()
                        .length;
                i++
              )
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child:
                      lessonState.alignmentPlaced[row].contains(i)
                          ? Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '✓',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 22,
                              ),
                            ),
                          )
                          : SizedBox(
                            width: 52,
                            child: _sourceTile(
                              LessonTile.alignment(
                                row,
                                i,
                                int.parse(
                                  AddSubtractLessonState.alignmentNumbers[row]
                                      .toString()[i],
                                ),
                              ),
                              AddSubtractLessonState.alignmentNumbers[row]
                                  .toString()[i],
                              'Digit ${AddSubtractLessonState.alignmentNumbers[row].toString()[i]}, '
                              'row ${row + 1}, tile ${i + 1}',
                              fontSize: 23,
                            ),
                          ),
                ),
            ],
          ),
          if (row == 0) const SizedBox(height: 7),
        ],
      ],
    );
  }

  Widget _placeLabels({int? active}) => Row(
    children: <Widget>[
      for (int i = 0; i < 7; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 26,
              child: Center(
                child: Text(
                  placeNames[i],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == active ? FontWeight.w800 : FontWeight.w500,
                    color:
                        i == active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _calculationBoard(ArithmeticWork work) {
    final bool addition = work.problem.operation == '+';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '${formatPlaceNumber(work.problem.first)} ${work.problem.operation} '
              '${formatPlaceNumber(work.problem.second)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const Text(
              'Work from right to left ←',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _placeLabels(active: work.done ? null : work.column),
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child:
                      addition ? _carryCell(work, i) : _exchangeCell(work, i),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _operandCell(work, i, top: true),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _operandCell(work, i, top: false),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child:
                      i < work.firstColumn
                          ? const SizedBox(height: 52)
                          : _dropZone(
                            LessonZone.answer(i),
                            work.results[i]?.toString() ?? '?',
                            'Answer ${placeNames[i]}, ${work.results[i] ?? 'empty'}',
                            active: i == work.column && !work.done,
                            filled: work.results[i] != null,
                            fontSize: 26,
                          ),
                ),
              ),
          ],
        ),
        if (work.exchanges > 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Regrouping changes the units, not the total value.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        if (work.done)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${formatPlaceNumber(work.problem.first)} ${work.problem.operation} '
                '${formatPlaceNumber(work.problem.second)} = '
                '${formatPlaceNumber(work.problem.answer)}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _carryCell(ArithmeticWork work, int column) {
    if (work.mode == ArithmeticMode.carry && column == work.column - 1) {
      return _dropZone(
        LessonZone.carry(column),
        '↓',
        'Carry destination: 1 ${unitNames[column]}',
        active: true,
        fontSize: 19,
      );
    }
    return Container(
      height: 52,
      alignment: Alignment.center,
      child:
          work.carries[column] == 0
              ? const SizedBox.shrink()
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '1 ${unitNames[column]}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
    );
  }

  Widget _exchangeCell(ArithmeticWork work, int column) {
    if (work.mode != ArithmeticMode.exchange) return const SizedBox(height: 52);
    if (column < work.column && work.top[column] > 0) {
      return _sourceTile(
        LessonTile.exchange(column),
        '1 ${unitNames[column]}',
        'Exchange 1 ${unitNames[column]}',
        fontSize: 10,
        highlighted: column == work.donorColumn,
      );
    }
    return _dropZone(
      LessonZone.exchange(column),
      '+10',
      'Exchange destination: ${placeNames[column]}',
      active: column == work.donorColumn! + 1,
      fontSize: 17,
    );
  }

  Widget _operandCell(ArithmeticWork work, int column, {required bool top}) {
    final int digit = top ? work.top[column] : work.bottom[column];
    final int original = top ? work.originalTop[column] : digit;
    final bool changed = top && digit != original;
    final bool blank =
        digit == 0 &&
        column <
            7 -
                (top ? work.problem.first : work.problem.second)
                    .toString()
                    .length;
    final bool active = column == work.column && !work.done;
    return Semantics(
      label:
          '${top ? 'Top' : 'Bottom'} ${placeNames[column]}: '
          '${blank ? 'blank' : digit}${changed ? ', changed from $original' : ''}',
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primaryContainer : const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Center(
              child: Text(
                blank ? '' : '$digit',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.primary : const Color(0xFF18355E),
                ),
              ),
            ),
            if (changed)
              Positioned(
                top: 1,
                left: 4,
                child: Text(
                  '$original',
                  style: const TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recapBoard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final (int, String) step in <(int, String)>[
        (1, 'Align digits by place value.'),
        (2, 'Work from ones toward the left.'),
        (3, 'Exchange when needed.'),
        (4, 'Check using the inverse operation.'),
      ])
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '${step.$1}    ${step.$2}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'CHECK THE FIRST ADDITION EXAMPLE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: 5),
            FittedBox(
              child: Text(
                '377,500 − 132,500 = 245,000',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Subtracting one addend returns the other addend.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _sourceTile(
    LessonTile tile,
    String text,
    String label, {
    double fontSize = 23,
    bool highlighted = false,
  }) {
    final bool selected = lessonState.selected?.identity == tile.identity;
    Widget tileView({bool preview = false}) => Container(
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color:
            preview || selected
                ? AppColors.primaryContainer
                : highlighted
                ? AppColors.tertiaryContainer
                : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color:
              preview || selected
                  ? AppColors.primary
                  : highlighted
                  ? AppColors.tertiary
                  : const Color(0xFFBBCEE8),
          width: 2,
        ),
        boxShadow:
            preview
                ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
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
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _select(tile);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: 'Drag or select $label',
        button: true,
        child: Draggable<LessonTile>(
          key: ValueKey<String>('tile_${tile.identity}'),
          data: tile,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 76,
              height: 58,
              child: tileView(preview: true),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: tileView()),
          onDragEnd: (DraggableDetails details) {
            if (!details.wasAccepted) {
              _change(
                () =>
                    _interactionStatus =
                        'Tile returned. Drop it inside a destination or tap to place.',
              );
            }
          },
          child: InkWell(
            onTap: () => _select(tile),
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(11),
            child: tileView(),
          ),
        ),
      ),
    );
  }

  Widget _dropZone(
    LessonZone zone,
    String text,
    String label, {
    bool active = false,
    bool filled = false,
    double fontSize = 22,
  }) {
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          final LessonTile? selected = lessonState.selected;
          if (selected != null) _place(selected, zone);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DragTarget<LessonTile>(
        key: ValueKey<String>('drop_${zone.kind}_${zone.row}_${zone.column}'),
        onWillAcceptWithDetails: (_) => !filled,
        onAcceptWithDetails:
            (DragTargetDetails<LessonTile> details) =>
                _place(details.data, zone),
        builder: (
          BuildContext context,
          List<LessonTile?> candidates,
          List<dynamic> rejected,
        ) {
          final bool hovered = candidates.isNotEmpty;
          return Semantics(
            label: '$label${active ? ', active destination' : ''}',
            button: true,
            child: InkWell(
              onTap: () {
                final LessonTile? selected = lessonState.selected;
                if (selected != null) _place(selected, zone);
              },
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      filled
                          ? AppColors.secondaryContainer
                          : hovered
                          ? const Color(0xFFD7E8FF)
                          : active
                          ? AppColors.primaryContainer
                          : const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color:
                        filled
                            ? AppColors.secondary
                            : hovered || active
                            ? AppColors.primary
                            : const Color(0xFFBECFE6),
                    width: 2,
                  ),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: filled ? AppColors.secondary : AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _guide(bool short) {
    final int phase = lessonState.phase;
    final ArithmeticWork? work = lessonState.currentWork;
    final String instruction = switch (phase) {
      0 =>
        lessonState.startDone
            ? 'Add to find the total.'
            : 'Drag the operation into the empty box.',
      1 =>
        lessonState.alignmentDone
            ? 'Both numbers are lined up.'
            : 'Drag the digits into their matching columns.',
      2 || 3 || 4 => switch (work!.mode) {
        ArithmeticMode.carry => 'Exchange 10 ${unitNames[work.column]}s.',
        ArithmeticMode.exchange => 'Exchange from the nearest available place.',
        ArithmeticMode.answer =>
          'Solve the ${placeNames[work.column].toLowerCase()} column.',
        ArithmeticMode.checked => 'This column is complete.',
        ArithmeticMode.done => 'You finished this calculation.',
      },
      _ =>
        lessonState.finished
            ? 'You finished this lesson.'
            : lessonState.practiceDone
            ? 'You completed all four practice items.'
            : 'Practice before finishing.',
    };
    final String detail = switch (phase) {
      0 => 'You may also tap a tile, then tap its destination.',
      1 =>
        'Keep the top number in row 1 and the bottom number in row 2. '
            'Blank leading cells stay blank.',
      2 || 3 || 4 => switch (work!.mode) {
        ArithmeticMode.carry =>
          'Drag 1 ${unitNames[work.column - 1]} '
              'into the carry space on the left.',
        ArithmeticMode.exchange =>
          'Drag 1 ${unitNames[work.donorColumn!]} '
              'into the adjacent ${placeNames[work.donorColumn! + 1].toLowerCase()} space.',
        ArithmeticMode.answer =>
          phase == 4
              ? 'Compute first, then drag the answer digit. Ask for a hint if needed.'
              : 'Drag a digit into the highlighted answer cell.',
        ArithmeticMode.checked => 'Continue one column to the left.',
        ArithmeticMode.done =>
          'Review the completed board, then try the next example.',
      },
      _ =>
        '${lessonState.practiceCompleteCount} of 4 practice items completed. '
            'Review any part again.',
    };
    final LessonDropFeedback? feedback = lessonState.currentFeedback;
    return Padding(
      padding: EdgeInsets.all(short ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset(
                  'assets/images/comparing_numbers_owl.jpg',
                  width: short ? 38 : 52,
                  height: short ? 38 : 52,
                  fit: BoxFit.cover,
                  semanticLabel: 'BayMath owl guide',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your BayMath guide',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Drag. Exchange. Solve.',
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
          SizedBox(height: short ? 5 : 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'YOUR TURN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    instruction,
                    style: TextStyle(
                      fontSize: short ? 16 : 18,
                      height: 1.26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: short ? 12 : 14,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (feedback != null &&
                      work?.mode != ArithmeticMode.answer) ...<Widget>[
                    const SizedBox(height: 8),
                    _feedback(feedback),
                  ],
                  if (phase == 0 && !lessonState.startDone) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 90,
                          child: _sourceTile(
                            const LessonTile.operation('+'),
                            '+',
                            'addition',
                            fontSize: 35,
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 90,
                          child: _sourceTile(
                            const LessonTile.operation('−'),
                            '−',
                            'subtraction',
                            fontSize: 35,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (phase == 1) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'PLACE VALUE EXAMPLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'In 456,789, the 5 means 5 ten thousands = 50,000.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (work != null) _workGuideContent(work),
                  if (feedback != null &&
                      work?.mode == ArithmeticMode.answer) ...<Widget>[
                    const SizedBox(height: 8),
                    _feedback(feedback),
                  ],
                  if (_saveError != null && phase == 5) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _saveError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          _guideActions(),
          if (work != null && !short)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Center(
                child: Text(
                  '${phase == 4 ? 'Practice' : 'Example'} '
                  '${phase == 2
                      ? lessonState.additionIndex + 1
                      : phase == 3
                      ? lessonState.subtractionIndex + 1
                      : lessonState.practiceIndex + 1} '
                  'of ${phase == 2
                      ? 3
                      : phase == 3
                      ? 2
                      : 4} · '
                  '${work.done ? 'Completed' : placeNames[work.column]}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedback(LessonDropFeedback feedback) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color:
            feedback.correct
                ? AppColors.secondaryContainer
                : AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${feedback.correct ? '✓' : '↻'} ${feedback.title}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            feedback.detail,
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
        ],
      ),
    ),
  );

  Widget _workGuideContent(ArithmeticWork work) {
    if (work.mode == ArithmeticMode.carry) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.tertiaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '${work.top[work.column]} + ${work.bottom[work.column]}'
              '${work.carries[work.column] == 1 ? ' + 1 carried' : ''} = ${work.total}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '10 ${unitNames[work.column]}s → 1 ${unitNames[work.column - 1]}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 5),
            _sourceTile(
              LessonTile.carry(work.column - 1),
              '1 ${unitNames[work.column - 1]}',
              '1 ${unitNames[work.column - 1]} carry',
              fontSize: 18,
            ),
          ],
        ),
      );
    }
    if (work.mode == ArithmeticMode.exchange) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.tertiaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '${work.top[work.column]} ${unitNames[work.column]}s is not '
              'enough to subtract ${work.bottom[work.column]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              '1 ${unitNames[work.donorColumn!]} → '
              '10 ${unitNames[work.donorColumn! + 1]}s',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const Text(
              'Move one place right with each exchange.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    }
    if (work.mode == ArithmeticMode.answer) {
      return Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '${work.top[work.column]} ${work.problem.operation} '
              '${work.bottom[work.column]}'
              '${work.problem.operation == '+' && work.carries[work.column] == 1 ? ' + 1 carried' : ''} = ?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 7),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'REUSABLE ANSWER DIGITS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.7,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          for (int row = 0; row < 2; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: <Widget>[
                  for (int col = 0; col < 5; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _sourceTile(
                          LessonTile.digit(row * 5 + col),
                          '${row * 5 + col}',
                          'answer digit ${row * 5 + col}',
                          fontSize: 23,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (work.hints > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Hint · ${lessonState.calculationHint}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _guideActions() {
    final int phase = lessonState.phase;
    final ArithmeticWork? work = lessonState.currentWork;
    if (phase == 0) {
      return lessonState.startDone
          ? _action(
            'Line up the digits →',
            () => _change(() => lessonState.navigate(1)),
          )
          : _hintAction();
    }
    if (phase == 1) {
      return lessonState.alignmentDone
          ? _action(
            'Explore addition →',
            () => _change(() => lessonState.navigate(2)),
          )
          : _hintAction();
    }
    if (work != null) {
      if (work.mode == ArithmeticMode.checked) {
        return _action(
          'Continue column ←',
          () => _change(lessonState.continueColumn),
        );
      }
      if (work.mode == ArithmeticMode.done) {
        final int index =
            phase == 2
                ? lessonState.additionIndex
                : phase == 3
                ? lessonState.subtractionIndex
                : lessonState.practiceIndex;
        final int total =
            phase == 2
                ? 3
                : phase == 3
                ? 2
                : 4;
        return _action(
          index < total - 1
              ? phase == 4
                  ? 'Next practice item →'
                  : 'Next example →'
              : phase == 2
              ? 'Explore subtraction →'
              : phase == 3
              ? 'Practice on your own →'
              : 'See the recap →',
          () => _change(
            index < total - 1
                ? lessonState.nextExercise
                : () => lessonState.navigate(phase + 1),
          ),
        );
      }
      if (work.mode == ArithmeticMode.answer) return _hintAction();
      return const SizedBox.shrink();
    }
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
        const SizedBox(height: 7),
        if (lessonState.practiceDone)
          _quizAction()
        else
          _action(
            'Return to practice',
            () => _change(() => lessonState.navigate(4)),
            secondary: true,
          ),
      ],
    );
  }

  Widget _hintAction() => TextButton(
    onPressed: () => _change(lessonState.addHint),
    style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
    child: Text(
      lessonState.phase >= 2 && (lessonState.currentWork?.hints ?? 0) > 0
          ? 'Another hint'
          : 'Show a hint',
    ),
  );

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
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _footer(bool short) {
    final int phase = lessonState.phase;
    return Container(
      height: short ? 66 : 76,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 160,
            child: _action(
              '← Previous part',
              phase == 0
                  ? null
                  : () => _change(() => lessonState.navigate(phase - 1)),
              secondary: true,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Part ${phase + 1} of 6 · ${addSubtractPhases[phase]}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 290,
                  child: LinearProgressIndicator(
                    value: (phase + 1) / 6,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Text(
                  _interactionStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 160,
            child: _action(
              'Next part →',
              phase == 5
                  ? null
                  : () => _change(() => lessonState.navigate(phase + 1)),
            ),
          ),
        ],
      ),
    );
  }
}
