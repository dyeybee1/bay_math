import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import 'quiz_taking_screen.dart';
import 'comparing_numbers_lesson_content.dart';
import 'comparing_numbers_lesson_math.dart';
import 'comparing_numbers_lesson_state.dart';

class ComparingNumbersLessonScreen extends ConsumerStatefulWidget {
  const ComparingNumbersLessonScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<ComparingNumbersLessonScreen> createState() =>
      _ComparingNumbersLessonScreenState();
}

class _ComparingNumbersLessonScreenState
    extends ConsumerState<ComparingNumbersLessonScreen> {
  final ComparingNumbersLessonState lessonState = ComparingNumbersLessonState();
  bool _saving = false;
  String? _saveError;

  void _change(VoidCallback action) {
    setState(action);
  }

  Future<void> _finish() async {
    if (!lessonState.practiceDone || _saving || lessonState.finished) return;
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
                'This lesson uses landscape so you have room to compare the numbers.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final bool short = size.height < 690;
    final int phase = lessonState.phase;
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
            _footer(phase, short),
          ],
        ),
      ),
    );
  }

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
        for (int i = 0; i < comparingPhases.length; i++)
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
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
                        width: 23,
                        height: 23,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                lessonState.phase == i
                                    ? Colors.white
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        comparingPhases[i],
                        style: const TextStyle(
                          fontSize: 13,
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

  Widget _surface(Widget child, bool short) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(short ? 18 : 22),
      border: Border.all(color: const Color(0xFFDCE5EE)),
    ),
    child: child,
  );

  Widget _board(bool short) {
    final int phase = lessonState.phase;
    final ComparisonExercise item = lessonState.currentExercise;
    final bool recap = phase == 4 && lessonState.practiceDone;
    final String title = switch (phase) {
      0 => 'Which number is greater?',
      1 => 'Compare from left to right',
      2 => 'Find the deciding place',
      3 =>
        item.index == 0
            ? 'What if every digit matches?'
            : 'More digits, greater number',
      _ =>
        recap
            ? (lessonState.finished
                ? 'Lesson finished!'
                : 'Keep these three steps')
            : 'Your turn to compare',
    };
    final String subtitle = switch (phase) {
      0 => 'Tap a number. We will explore how you know.',
      1 => 'Only the first different place decides the answer.',
      2 => 'Look from the left. Tap a digit in the first different column.',
      3 =>
        item.index == 0
            ? 'Compare each place in these two numbers.'
            : 'Count digits first. Commas are separators.',
      _ =>
        recap
            ? 'You completed the three practice comparisons.'
            : 'Choose the symbol. Ask for a hint when you need one.',
    };
    final String tag = switch (phase) {
      0 => 'First try',
      1 => 'Watch & explore',
      2 => 'Example ${item.index + 1}/2',
      3 => item.index == 0 ? 'Equal numbers' : 'Different digit counts',
      _ => recap ? 'Practice complete' : 'Practice ${item.index + 1}/3',
    };
    return Padding(
      padding: EdgeInsets.all(short ? 16 : 22),
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
                      comparingPhases[phase].toUpperCase(),
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
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: switch (phase) {
                    0 => _introBoard(),
                    1 => _placeBoard(
                      ComparingNumbersLessonState.guidedCases[0],
                      item,
                      showEquation: item.readyForSymbol,
                    ),
                    2 => _placeBoard(
                      lessonState.currentCase,
                      item,
                      selectable: !item.readyForSymbol,
                      showEquation: item.solved,
                    ),
                    3 =>
                      item.index == 0
                          ? _placeBoard(
                            lessonState.currentCase,
                            item,
                            showEquation: item.solved,
                          )
                          : _digitCountBoard(lessonState.currentCase, item),
                    _ =>
                      recap
                          ? _recapBoard()
                          : _practiceBoard(lessonState.currentCase, item),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introBoard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: _numberTile(
              85000,
              'Tap to choose',
              onTap:
                  lessonState.introSolved
                      ? null
                      : () => _change(() => lessonState.chooseIntro(85000)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: _numberTile(
              58000,
              'Tap to choose',
              onTap:
                  lessonState.introSolved
                      ? null
                      : () => _change(() => lessonState.chooseIntro(58000)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      lessonState.introSolved
          ? _equation(const ComparisonCase(85000, 58000))
          : const Text(
            '>     <     =',
            style: TextStyle(
              fontSize: 30,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
      if (!lessonState.introSolved)
        const Text(
          'Three symbols. One comparison.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
    ],
  );

  Widget _numberTile(int number, String caption, {VoidCallback? onTap}) {
    final Widget content = Container(
      constraints: const BoxConstraints(minHeight: 94),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCCDCF3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatNumber(number),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF18355E),
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'Choose ${formatNumber(number)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }

  Widget _placeBoard(
    ComparisonCase example,
    ComparisonExercise item, {
    bool selectable = false,
    bool showEquation = false,
  }) {
    final int count = example.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'First: ${formatNumber(example.first)}     Second: ${formatNumber(example.second)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (int i = 0; i < count; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    example.place(i),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          i == item.cursor ||
                                  i == example.decidingIndex &&
                                      item.readyForSymbol
                              ? FontWeight.w800
                              : FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        for (int row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _digitTile(example, item, row, i, selectable),
                    ),
                  ),
              ],
            ),
          ),
        if (lessonState.phase == 2 && item.readyForSymbol)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Deciding ${example.place(example.decidingIndex).toLowerCase()} place: '
              '${example.firstDigits[example.decidingIndex]} compared with '
              '${example.secondDigits[example.decidingIndex]}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        if (lessonState.phase == 1 || lessonState.phase == 3 && item.index == 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _columnMessage(example, item),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        if (showEquation)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _equation(example),
          ),
      ],
    );
  }

  Widget _digitTile(
    ComparisonCase example,
    ComparisonExercise item,
    int row,
    int index,
    bool selectable,
  ) {
    final String digit =
        row == 0 ? example.firstDigits[index] : example.secondDigits[index];
    final bool active =
        lessonState.phase == 1 || lessonState.phase == 3
            ? index == item.cursor
            : item.readyForSymbol && index == example.decidingIndex;
    final bool matched =
        (lessonState.phase == 1 || lessonState.phase == 3) &&
        index < item.cursor;
    final bool deciding =
        active &&
        item.readyForSymbol &&
        example.decidingIndex >= 0 &&
        (lessonState.phase == 2 || item.checked);
    final Color background =
        matched
            ? AppColors.secondaryContainer
            : deciding
            ? AppColors.tertiaryContainer
            : active
            ? AppColors.primaryContainer
            : const Color(0xFFF0F4FA);
    final Widget tile = Container(
      constraints: BoxConstraints(minHeight: selectable ? 56 : 52),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: active ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Text(
              digit == ' ' ? '·' : digit,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.primary : const Color(0xFF18355E),
              ),
            ),
          ),
          if (matched)
            const Positioned(
              top: 2,
              right: 3,
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
    final String label =
        '${example.place(index)}, ${row == 0 ? 'first' : 'second'} number, '
        'digit ${digit == ' ' ? 'blank' : digit}${matched
            ? ', same'
            : deciding
            ? ', deciding place'
            : active
            ? ', active'
            : ''}';
    if (!selectable) return Semantics(label: label, child: tile);
    return Semantics(
      button: true,
      label: 'Select $label',
      child: InkWell(
        onTap: () => _change(() => lessonState.choosePlace(index)),
        borderRadius: BorderRadius.circular(11),
        child: tile,
      ),
    );
  }

  String _columnMessage(ComparisonCase example, ComparisonExercise item) {
    if (!item.checked) {
      return lessonState.phase == 3
          ? 'Check every place before choosing equal.'
          : 'Compare the highlighted digits.';
    }
    if (item.readyForSymbol) {
      return lessonState.phase == 1
          ? '5 > 0 · The tens place decides. Stop here.'
          : 'All six digit pairs match.';
    }
    return '${example.firstDigits[item.cursor]} = ${example.secondDigits[item.cursor]} '
        '· ✓ Same. Move one place right.';
  }

  Widget _digitCountBoard(ComparisonCase example, ComparisonExercise item) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final int number in <int>[example.first, example.second])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: <Widget>[
                          FittedBox(
                            child: Text(
                              formatNumber(number),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF18355E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            item.counted
                                ? '${number.toString().length} digits'
                                : 'How many digits?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (item.solved) ...<Widget>[
            const SizedBox(height: 10),
            _equation(example),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('999,998'),
                Text('999,999'),
                Text('1,000,000'),
              ],
            ),
            const Divider(color: AppColors.primary, thickness: 2),
            const Text(
              'Zoomed number line · Neighboring ticks differ by 1',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      );

  Widget _practiceBoard(ComparisonCase example, ComparisonExercise item) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _numberTile(example.first, 'First number')),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9),
                child: Text(
                  'and',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Expanded(child: _numberTile(example.second, 'Second number')),
            ],
          ),
          if (item.solved)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _equation(example),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color:
                          i < item.index || i == item.index && item.solved
                              ? AppColors.secondary
                              : AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _recapBoard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final (int, String) step in <(int, String)>[
        (1, 'Count the digits first.'),
        (2, 'If counts match, compare from the left.'),
        (3, 'Stop at the first different digit.'),
      ])
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${step.$1}    ${step.$2}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      const Text(
        '>     <     =',
        style: TextStyle(
          fontSize: 32,
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Text(
        'If all digits match, the numbers are equal.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _equation(ComparisonCase example) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(formatNumber(example.first)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Semantics(
            label: switch (example.symbol) {
              '>' => 'greater than',
              '<' => 'less than',
              _ => 'equal to',
            },
            child: Text(
              example.symbol,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
        ),
        Text(formatNumber(example.second)),
      ],
    ),
  );

  Widget _guide(bool short) {
    final int phase = lessonState.phase;
    final ComparisonExercise item = lessonState.currentExercise;
    final bool recap = phase == 4 && lessonState.practiceDone;
    final String instruction = switch (phase) {
      0 =>
        lessonState.introSolved
            ? 'Let’s learn how to compare.'
            : 'Which number is greater? Tap one number.',
      1 =>
        item.readyForSymbol
            ? 'Stop at the first different digit.'
            : item.checked
            ? 'These digits are the same.'
            : 'Start at the leftmost place. Compare the two highlighted digits.',
      2 =>
        item.readyForSymbol
            ? item.solved
                ? 'You compared the numbers.'
                : 'Choose the symbol to compare the numbers.'
            : 'Tap the first place where the digits are different.',
      3 =>
        item.index == 0
            ? item.solved
                ? 'Every digit matches.'
                : item.readyForSymbol
                ? 'Choose the symbol for these matching numbers.'
                : item.checked
                ? 'This pair matches. Check the next place.'
                : 'Compare the two highlighted digits.'
            : item.solved
            ? '1,000,000 has more digits.'
            : item.counted
            ? 'Which symbol compares these numbers?'
            : 'Count the digits in each number.',
      _ =>
        recap
            ? lessonState.finished
                ? 'You finished this lesson.'
                : 'You are ready to finish.'
            : item.solved
            ? 'You explained this comparison.'
            : 'Which symbol belongs between the numbers?',
    };
    final String detail = switch (phase) {
      0 => 'You will compare whole numbers up to 1,000,000 using >, <, and =.',
      1 =>
        item.readyForSymbol
            ? '5 tens is greater than 0 tens. The later digits do not change this comparison.'
            : item.checked
            ? 'Now move one column to the right.'
            : 'Tap “Compare this place” to check this pair.',
      2 =>
        item.readyForSymbol
            ? 'Use the two highlighted digits.'
            : 'You may tap a digit in either number. Both choices select its column.',
      3 =>
        item.index == 0
            ? 'Continue until you have checked all six columns.'
            : item.counted
            ? 'Compare 6 digits with 7 digits.'
            : 'Do not count the commas.',
      _ =>
        recap
            ? 'Review any part again, or choose the optional quiz.'
            : 'Take your time. There is no timer.',
    };
    final ComparisonFeedback? feedback = switch (phase) {
      0 => lessonState.introFeedback,
      1 =>
        item.readyForSymbol
            ? const ComparisonFeedback(
              'The deciding place is tens.',
              '723,450 is greater than 723,405.',
              correct: true,
            )
            : null,
      4 when recap => const ComparisonFeedback(
        'Three comparisons completed.',
        '',
        correct: true,
      ),
      _ => item.feedback,
    };
    return Padding(
      padding: EdgeInsets.all(short ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/comparing_numbers_owl.jpg',
                  width: short ? 42 : 52,
                  height: short ? 42 : 52,
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
                      'Read. Try. Learn.',
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
          SizedBox(height: short ? 10 : 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    phase == 1 ? 'LEARN THE METHOD' : 'YOUR TURN',
                    style: const TextStyle(
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
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: short ? 12 : 14,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if ((phase == 2 || phase == 3 || phase == 4 && !recap) &&
                      item.readyForSymbol &&
                      !item.solved) ...<Widget>[
                    const SizedBox(height: 10),
                    _symbols(),
                  ],
                  if (feedback != null) ...<Widget>[
                    const SizedBox(height: 10),
                    _feedback(feedback),
                  ],
                  if (phase == 0 && lessonState.introHints > 0 ||
                      phase >= 2 && !recap && item.hints > 0) ...<Widget>[
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Hint · ${lessonState.hint}',
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                  if (_saveError != null && recap) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _saveError!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          _guideActions(),
          if (phase == 2 || phase == 3 || phase == 4 && !recap)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Center(
                child: Text(
                  'Example ${item.index + 1} of '
                  '${phase == 4 ? 3 : 2}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedback(ComparisonFeedback feedback) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color:
            feedback.correct
                ? AppColors.secondaryContainer
                : AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${feedback.correct ? '✓' : '↻'} ${feedback.title}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          if (feedback.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              feedback.detail,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _symbols() => Row(
    children: <Widget>[
      for (final (String, String) option in <(String, String)>[
        ('>', 'Greater than'),
        ('<', 'Less than'),
        ('=', 'Equal to'),
      ])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Semantics(
              button: true,
              label: option.$2,
              child: OutlinedButton(
                onPressed:
                    () => _change(() => lessonState.answerSymbol(option.$1)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 58),
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      option.$1,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        option.$2,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _guideActions() {
    final int phase = lessonState.phase;
    final ComparisonExercise item = lessonState.currentExercise;
    final bool recap = phase == 4 && lessonState.practiceDone;
    if (phase == 0) {
      return lessonState.introSolved
          ? _action(
            'Explore the method →',
            () => _change(() => lessonState.navigate(1)),
          )
          : _hintAction();
    }
    if (phase == 1) {
      if (item.readyForSymbol) {
        return Column(
          children: <Widget>[
            _action(
              'Try together →',
              () => _change(() => lessonState.navigate(2)),
            ),
            const SizedBox(height: 7),
            _action(
              'Replay example',
              () => _change(lessonState.replayLearn),
              secondary: true,
            ),
          ],
        );
      }
      return _action(
        item.checked ? 'Next place →' : 'Compare this place',
        () => _change(
          item.checked ? lessonState.nextColumn : lessonState.compareColumn,
        ),
      );
    }
    if (phase == 2) {
      return item.solved
          ? _action(
            item.index == 0 ? 'Next example →' : 'Explore special cases →',
            () => _change(
              item.index == 0
                  ? lessonState.nextExercise
                  : () => lessonState.navigate(3),
            ),
          )
          : _hintAction();
    }
    if (phase == 3) {
      if (item.index == 0) {
        if (item.solved) {
          return _action(
            'Different digit counts →',
            () => _change(lessonState.nextExercise),
          );
        }
        if (item.readyForSymbol) return _hintAction();
        return _action(
          item.checked ? 'Next place →' : 'Compare this place',
          () => _change(
            item.checked ? lessonState.nextColumn : lessonState.compareColumn,
          ),
        );
      }
      return item.solved
          ? _action(
            'Practice on your own →',
            () => _change(() => lessonState.navigate(4)),
          )
          : item.counted
          ? _hintAction()
          : _action('Count the digits', () => _change(lessonState.countDigits));
    }
    if (recap) {
      return Column(
        children: <Widget>[
          if (!lessonState.finished)
            _action(
              _saving
                  ? 'Saving...'
                  : _saveError == null
                  ? 'Finish lesson ✓'
                  : 'Retry saving lesson',
              _saving ? null : _finish,
            ),
          if (!lessonState.finished) const SizedBox(height: 7),
          _quizAction(),
          const SizedBox(height: 7),
          _action(
            'Review the method',
            () => _change(() => lessonState.navigate(1)),
            secondary: true,
          ),
        ],
      );
    }
    return item.solved
        ? _action(
          item.index < 2 ? 'Next question →' : 'See the recap →',
          () => _change(lessonState.nextExercise),
        )
        : _hintAction();
  }

  Widget _hintAction() => TextButton(
    onPressed: () => _change(lessonState.addHint),
    style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
    child: Text(
      lessonState.phase >= 2 && lessonState.currentExercise.hints > 0
          ? 'Another hint'
          : 'Need a hint?',
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

  Widget _footer(int phase, bool short) => Container(
    height: short ? 66 : 76,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.outlineVariant)),
    ),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 150,
          child: _action(
            '← Previous',
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
                'Part ${phase + 1} of 5 · ${comparingPhases[phase]}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: 300,
                child: LinearProgressIndicator(
                  value: (phase + 1) / 5,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 150,
          child: _action(
            'Next part →',
            phase == 4
                ? null
                : () => _change(() => lessonState.navigate(phase + 1)),
          ),
        ),
      ],
    ),
  );
}
