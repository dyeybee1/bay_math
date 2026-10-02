import 'package:flutter/material.dart';
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
import 'fractions_lesson_content.dart';
import 'fractions_lesson_state.dart';
import 'lesson_back_button.dart';
import 'lesson_viewer_screen.dart' show linkedQuizProvider;
import 'quiz_taking_screen.dart';

const Color _ink = Color(0xFF203047);
const Color _muted = Color(0xFF566B82);
const Color _blue = Color(0xFF2459B3);
const Color _paleBlue = Color(0xFFE9F1FC);
const Color _green = Color(0xFF237251);
const Color _paleGreen = Color(0xFFE6F4EC);
const Color _line = Color(0xFFDCE5EE);

class FractionsLessonScreen extends ConsumerStatefulWidget {
  const FractionsLessonScreen({
    super.key,
    required this.lesson,
    this.initialState,
  });

  final Lesson lesson;
  final FractionsLessonState? initialState;

  @override
  ConsumerState<FractionsLessonScreen> createState() =>
      _FractionsLessonScreenState();
}

class _FractionsLessonScreenState extends ConsumerState<FractionsLessonScreen> {
  late final FractionsLessonState lessonState =
      widget.initialState ?? FractionsLessonState();
  bool _saving = false;
  String? _saveError;

  void _change(VoidCallback change) => setState(change);

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
        color: const Color(0xFFF2F6FB),
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
                          color: _blue,
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
      color: const Color(0xFFF2F6FB),
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
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(18),
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
          const Icon(Icons.calculate_rounded, size: 31, color: _blue),
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
          Container(width: 1, height: 32, color: _line),
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
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                ),
              ),
              Text(
                'Types of Fractions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
    padding: EdgeInsets.symmetric(horizontal: short ? 12 : 20),
    child: Row(
      children: List<Widget>.generate(fractionsPhases.length, (int index) {
        final bool active = lessonState.phase == index && !lessonState.recap;
        final bool enabled = lessonState.phaseUnlocked(index);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              button: true,
              enabled: enabled,
              label: 'Phase ${index + 1}: ${fractionsPhases[index]}',
              child: InkWell(
                onTap:
                    enabled
                        ? () => _change(() => lessonState.navigate(index))
                        : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? _paleBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? _blue : const Color(0xFFEDF1F6),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : _muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          fractionsPhases[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: short ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: enabled ? (active ? _blue : _muted) : _line,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _board(bool short) {
    final FractionActivity task = lessonState.current;
    final bool recap = lessonState.recap;
    final String title =
        recap
            ? (lessonState.finished
                ? 'Lesson finished!'
                : 'Three written forms')
            : switch (task.spec.type) {
              FractionActivityType.parts => 'Meet the two fraction parts',
              FractionActivityType.proper => 'Less than one whole',
              FractionActivityType.improper => 'One whole or more',
              FractionActivityType.build => 'Build ${task.spec.label}',
              FractionActivityType.identify =>
                lessonState.phase == 5
                    ? 'Try it on your own'
                    : 'Identify the written form',
            };
    final String key =
        '${lessonState.phase}:${lessonState.indices[lessonState.phase]}:$recap';
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              short ? 13 : 20,
              short ? 10 : 17,
              short ? 13 : 20,
              5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recap
                      ? 'LESSON RECAP'
                      : '${fractionsPhases[lessonState.phase].toUpperCase()} · ACTIVITY ${lessonState.indices[lessonState.phase] + 1} OF ${lessonState.tasks[lessonState.phase].length}',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: short ? 20 : 23,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey<String>('fractions_board_$key'),
              padding: EdgeInsets.fromLTRB(
                short ? 13 : 20,
                4,
                short ? 13 : 20,
                14,
              ),
              child: recap ? _recapBoard() : _activityBoard(task, short),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityBoard(FractionActivity task, bool short) => switch (task
      .spec
      .type) {
    FractionActivityType.parts => _partsBoard(task),
    FractionActivityType.proper ||
    FractionActivityType.improper => _amountBoard(task, short),
    FractionActivityType.build => _buildBoard(task, short),
    FractionActivityType.identify => _identifyBoard(task, short),
  };

  Widget _partsBoard(FractionActivity task) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _model(
        task.spec,
        highlight:
            task.denominatorFound
                ? _ModelHighlight.whole
                : task.numeratorFound
                ? _ModelHighlight.shaded
                : _ModelHighlight.none,
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          _FractionNotation(
            spec: task.spec,
            numeratorPressed:
                task.done
                    ? null
                    : () => _change(() => lessonState.chooseNumber(3)),
            denominatorPressed:
                task.done
                    ? null
                    : () => _change(() => lessonState.chooseNumber(5)),
            numeratorAccepted: task.numeratorFound,
            denominatorAccepted: task.denominatorFound,
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Top number',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('How many shaded parts?', style: TextStyle(color: _muted)),
                SizedBox(height: 10),
                Text(
                  'Bottom number',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'How many equal parts make one whole?',
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _amountBoard(FractionActivity task, bool short) {
    final FractionActivitySpec spec = task.spec;
    final bool proper = spec.type == FractionActivityType.proper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(child: _FractionNotation(spec: spec)),
        const SizedBox(height: 9),
        _model(spec),
        SizedBox(height: short ? 12 : 18),
        const Text(
          'How much is shaded?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            _choice(
              'Less than 1',
              selected: task.answer == 'less',
              onPressed:
                  task.done
                      ? null
                      : () => _change(() => lessonState.chooseAmount('less')),
            ),
            const SizedBox(width: 7),
            if (!proper) ...<Widget>[
              _choice(
                'Equal to 1',
                selected: task.answer == 'equal',
                onPressed:
                    task.done
                        ? null
                        : () =>
                            _change(() => lessonState.chooseAmount('equal')),
              ),
              const SizedBox(width: 7),
            ],
            _choice(
              proper ? '1 or more' : 'Greater than 1',
              selected: task.answer == 'greater',
              onPressed:
                  task.done
                      ? null
                      : () => _change(
                        () => lessonState.chooseAmount(
                          proper ? 'one-or-more' : 'greater',
                        ),
                      ),
            ),
          ],
        ),
        if (task.done) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '${spec.numerator} ${spec.numerator < spec.denominator
                ? '<'
                : spec.numerator == spec.denominator
                ? '='
                : '>'} ${spec.denominator} · ${proper ? 'Proper fraction' : 'Improper fraction'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBoard(FractionActivity task, bool short) {
    final FractionActivitySpec spec = task.spec;
    final int? wholeId =
        task.remainingWholes == 0
            ? null
            : List<int>.generate(
              spec.wholes,
              (int i) => i,
            ).firstWhere((int i) => !task.usedWholeTiles.contains(i));
    final int? pieceId =
        task.remainingPieces == 0
            ? null
            : List<int>.generate(
              spec.numerator,
              (int i) => i,
            ).firstWhere((int i) => !task.usedPieces.contains(i));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(child: _FractionNotation(spec: spec, compact: true)),
        SizedBox(height: short ? 5 : 10),
        if (!task.modelBuilt) ...<Widget>[
          _stepLabel('1', 'Pick up a tile · drag or tap to select'),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double stripWidth = _buildSlotWidth(constraints, spec) - 18;
              return Row(
                children: <Widget>[
                  if (wholeId != null)
                    _tileSource(
                      FractionTile(FractionTileKind.whole, wholeId),
                      spec,
                      '1 whole · ${task.remainingWholes} left',
                      stripWidth,
                    )
                  else
                    const Expanded(child: _SupplyDone('✓ Wholes placed')),
                  const SizedBox(width: 8),
                  if (pieceId != null)
                    _tileSource(
                      FractionTile(FractionTileKind.piece, pieceId),
                      spec,
                      '1/${spec.denominator} piece · ${task.remainingPieces} left',
                      stripWidth,
                    )
                  else
                    const Expanded(child: _SupplyDone('✓ Pieces placed')),
                ],
              );
            },
          ),
          const Center(
            child: Icon(Icons.arrow_downward_rounded, size: 20, color: _blue),
          ),
          _stepLabel('2', 'Place in a matching blue outline'),
          const SizedBox(height: 5),
        ],
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = _buildSlotWidth(constraints, spec);
            return Wrap(
              spacing: 8,
              runSpacing: 7,
              children: <Widget>[
                for (int i = 0; i < spec.wholes; i++)
                  task.wholeSlots.contains(i)
                      ? _builtSlot(
                        spec.denominator,
                        spec.denominator,
                        width,
                        '1 whole ✓',
                      )
                      : _destination(
                        FractionDestination(
                          FractionDestinationKind.whole,
                          id: i,
                        ),
                        spec.denominator,
                        0,
                        width,
                        'Drop 1 whole',
                      ),
                task.modelBuilt
                    ? _builtSlot(
                      spec.denominator,
                      task.piecesPlaced,
                      width,
                      '${spec.numerator}/${spec.denominator} ✓',
                    )
                    : _destination(
                      const FractionDestination(FractionDestinationKind.piece),
                      spec.denominator,
                      task.piecesPlaced,
                      width,
                      'Drop 1/${spec.denominator} pieces',
                    ),
              ],
            );
          },
        ),
        if (task.modelBuilt) ...<Widget>[
          SizedBox(height: short ? 10 : 15),
          const Text(
            'Which part is the whole number?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _partChoice(
                spec,
                whole: true,
                selected: task.answer == 'whole',
                onPressed:
                    task.done
                        ? null
                        : () =>
                            _change(() => lessonState.chooseWholePart(true)),
              ),
              const SizedBox(width: 8),
              _partChoice(
                spec,
                whole: false,
                selected: false,
                onPressed:
                    task.done
                        ? null
                        : () =>
                            _change(() => lessonState.chooseWholePart(false)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  double _buildSlotWidth(
    BoxConstraints constraints,
    FractionActivitySpec spec,
  ) => ((constraints.maxWidth - spec.wholes * 8) / (spec.wholes + 1)).clamp(
    90.0,
    150.0,
  );

  Widget _identifyBoard(FractionActivity task, bool short) {
    final FractionActivitySpec spec = task.spec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(child: _FractionNotation(spec: spec)),
        SizedBox(height: short ? 8 : 12),
        if (task.modelVisible)
          _model(spec)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _paleBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Try using the written number first.'),
                ),
                OutlinedButton(
                  onPressed: () => _change(lessonState.showModel),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(106, 52),
                  ),
                  child: const Text('Show model'),
                ),
              ],
            ),
          ),
        SizedBox(height: short ? 11 : 16),
        const Text(
          'What type is this written form?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            for (final FractionType type in FractionType.values) ...<Widget>[
              if (type != FractionType.proper) const SizedBox(width: 7),
              _choice(
                '${type.name[0].toUpperCase()}${type.name.substring(1)} ${type == FractionType.mixed ? 'number' : 'fraction'}',
                selected: task.answer == type.name,
                onPressed:
                    task.done
                        ? null
                        : () => _change(() => lessonState.chooseType(type)),
              ),
            ],
          ],
        ),
        if (lessonState.phase == 4 &&
            lessonState.indices[4] == 2 &&
            task.done) ...<Widget>[
          const SizedBox(height: 9),
          const Text(
            '9/4 and 2 1/4 show the same amount. 9/4 is an improper fraction; 2 1/4 is a mixed number.',
            style: TextStyle(
              fontSize: 12,
              color: _green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _model(
    FractionActivitySpec spec, {
    _ModelHighlight highlight = _ModelHighlight.none,
    bool compact = false,
  }) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final List<int> parts = spec.shadedPartsByStrip;
      final double width = ((constraints.maxWidth - (parts.length - 1) * 10) /
              parts.length)
          .clamp(100.0, compact ? 155.0 : 210.0);
      return Semantics(
        label:
            '${spec.label}, ${parts.length} equal-sized whole ${parts.length == 1 ? 'strip' : 'strips'}, ${spec.totalParts} shaded parts of size one ${spec.denominator}th',
        child: Wrap(
          spacing: 10,
          runSpacing: 7,
          children: <Widget>[
            for (final int shaded in parts)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _FractionStrip(
                    denominator: spec.denominator,
                    shaded: shaded,
                    width: width,
                    height: compact ? 30 : 44,
                    highlight: highlight,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shaded == spec.denominator
                        ? '1 whole'
                        : '$shaded/${spec.denominator} of a whole',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );

  Widget _stepLabel(String number, String label) => Row(
    children: <Widget>[
      Container(
        width: 21,
        height: 21,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _tileSource(
    FractionTile tile,
    FractionActivitySpec spec,
    String label,
    double stripWidth,
  ) {
    final bool selected =
        lessonState.selectedTile?.kind == tile.kind &&
        lessonState.selectedTile?.id == tile.id;
    final Widget card = Container(
      height: 74,
      decoration: BoxDecoration(
        color: selected ? _paleBlue : Colors.white,
        border: Border.all(color: selected ? _blue : _line, width: 2),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.drag_indicator_rounded, color: _blue, size: 19),
              const SizedBox(width: 4),
              if (tile.kind == FractionTileKind.whole)
                _FractionStrip(
                  denominator: spec.denominator,
                  shaded: spec.denominator,
                  width: stripWidth,
                  height: 27,
                )
              else
                Semantics(
                  label: 'One piece of ${spec.denominator} equal pieces',
                  child: Container(
                    width: stripWidth / spec.denominator,
                    height: 27,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA4D6BD),
                      border: Border.all(color: _ink, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Drag · $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label. Drag or tap to select.',
        child: Draggable<FractionTile>(
          data: tile,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 190, child: card),
          ),
          childWhenDragging: Opacity(opacity: .4, child: card),
          child: InkWell(
            key: ValueKey<String>(
              'fraction_source_${tile.kind.name}_${tile.id}',
            ),
            onTap: () => _change(() => lessonState.selectTile(tile)),
            borderRadius: BorderRadius.circular(11),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _destination(
    FractionDestination destination,
    int denominator,
    int shaded,
    double width,
    String label,
  ) => DragTarget<FractionTile>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails:
        (DragTargetDetails<FractionTile> details) =>
            _change(() => lessonState.drop(details.data, destination)),
    builder:
        (
          BuildContext context,
          List<FractionTile?> candidates,
          List<dynamic> _,
        ) => Semantics(
          button: true,
          label:
              destination.kind == FractionDestinationKind.whole
                  ? 'Empty whole slot ${destination.id + 1}. $label.'
                  : 'Divided strip. $label. $shaded shaded so far.',
          child: InkWell(
            key: ValueKey<String>(
              'fraction_destination_${destination.kind.name}_${destination.id}',
            ),
            onTap: () => _change(() => lessonState.placeSelected(destination)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: width,
              height: 81,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty ? _paleBlue : Colors.white,
                border: Border.all(color: _blue, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _FractionStrip(
                    denominator: denominator,
                    shaded: shaded,
                    width: width - 18,
                    height: 27,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
  );

  Widget _builtSlot(int denominator, int shaded, double width, String label) =>
      Container(
        width: width,
        height: 81,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _paleGreen,
          border: Border.all(color: _green, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _FractionStrip(
              denominator: denominator,
              shaded: shaded,
              width: width - 18,
              height: 27,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ],
        ),
      );

  Widget _choice(
    String label, {
    required bool selected,
    required VoidCallback? onPressed,
  }) => Expanded(
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 58),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        backgroundColor: selected ? _paleGreen : Colors.white,
        foregroundColor: selected ? _green : _ink,
        side: BorderSide(
          color: selected ? _green : _line,
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        disabledForegroundColor: selected ? _green : _muted,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          selected ? '✓ $label' : label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );

  Widget _partChoice(
    FractionActivitySpec spec, {
    required bool whole,
    required bool selected,
    required VoidCallback? onPressed,
  }) => Expanded(
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 76),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: selected ? _paleGreen : Colors.white,
        side: BorderSide(
          color: selected ? _green : _line,
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (whole)
            Text(
              '${spec.wholes}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            )
          else
            _FractionNotation(
              spec: FractionActivitySpec(
                FractionActivityType.build,
                spec.numerator,
                spec.denominator,
              ),
              compact: true,
            ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              whole
                  ? '${selected ? '✓ ' : ''}Whole-number part'
                  : 'Fraction part',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _recapBoard() {
    const List<FractionActivitySpec> examples = <FractionActivitySpec>[
      FractionActivitySpec(FractionActivityType.proper, 3, 5),
      FractionActivitySpec(FractionActivityType.improper, 7, 4),
      FractionActivitySpec(FractionActivityType.identify, 3, 4, wholes: 1),
    ];
    const List<String> labels = <String>[
      'Proper fraction',
      'Improper fraction',
      'Mixed number',
    ];
    const List<String> rules = <String>[
      'Numerator < denominator',
      'Numerator ≥ denominator',
      'Whole number + proper fraction',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(3, (int i) {
            final FractionActivitySpec spec = examples[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFD),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        labels[i],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _FractionNotation(spec: spec, compact: true),
                      const SizedBox(height: 6),
                      for (final int shaded
                          in spec.shadedPartsByStrip) ...<Widget>[
                        _FractionStrip(
                          denominator: spec.denominator,
                          shaded: shaded,
                          width: 117,
                          height: 23,
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        rules[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        const Text(
          '5/5 is an improper fraction equal to one whole.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _green,
          ),
        ),
      ],
    );
  }

  Widget _guide(bool short) {
    final FractionActivity task = lessonState.current;
    final bool recap = lessonState.recap;
    final String instruction =
        recap
            ? 'You completed all four practice activities.'
            : switch (task.spec.type) {
              FractionActivityType.parts =>
                task.done
                    ? 'You identified both numbers.'
                    : 'Tap the ${task.numeratorFound ? 'denominator' : 'numerator'}.',
              FractionActivityType.proper || FractionActivityType.improper =>
                'Tap the amount shown by the shaded parts.',
              FractionActivityType.build =>
                task.modelBuilt
                    ? 'Tap the whole-number part below your model.'
                    : 'Drag ${task.spec.wholes} whole${task.spec.wholes == 1 ? '' : 's'} and ${task.spec.numerator} piece${task.spec.numerator == 1 ? '' : 's'} of 1/${task.spec.denominator} into the model.',
              FractionActivityType.identify =>
                'Tap the type of the number shown.',
            };
    final String explanation =
        recap
            ? 'Review the models, finish the lesson, or open the optional quiz.'
            : switch (task.spec.type) {
              FractionActivityType.parts =>
                'Top: shaded parts. Bottom: equal parts in one whole.',
              FractionActivityType.proper =>
                'A proper fraction has a numerator smaller than its denominator.',
              FractionActivityType.improper =>
                'An improper fraction has a numerator equal to or greater than its denominator.',
              FractionActivityType.build =>
                'A mixed number combines complete wholes with a proper fraction.',
              FractionActivityType.identify =>
                'Classify the written form you see.',
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
                    width: short ? 39 : 48,
                    height: short ? 39 : 48,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) => const Icon(
                          Icons.auto_stories_rounded,
                          size: 40,
                          color: _blue,
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'See the parts. Name the fraction.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: short ? 7 : 12),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey<String>('fractions_guide_$key'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'YOUR TURN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      instruction,
                      style: TextStyle(
                        fontSize: short ? 16 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      explanation,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    if (task.feedback != null && !recap) ...<Widget>[
                      const SizedBox(height: 11),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                task.feedback!.correct
                                    ? _paleGreen
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
                    if (lessonState.selectedTile != null && !recap) ...<Widget>[
                      const SizedBox(height: 8),
                      const Text(
                        'Tile selected. Tap its matching blue outline.',
                        style: TextStyle(fontSize: 12, color: _blue),
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

  Widget _guideActions(FractionActivity task, bool recap) {
    if (recap) {
      return Column(
        children: <Widget>[
          _action(
            _saving
                ? 'Saving...'
                : _saveError == null
                ? lessonState.finished
                    ? 'Lesson finished ✓'
                    : 'Finish Lesson ✓'
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
          style: const TextStyle(fontSize: 11, color: _muted),
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
                    'Take Quiz 5 · Optional',
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
                    : '${fractionsPhases[lessonState.phase]} · Activity ${lessonState.indices[lessonState.phase] + 1} / ${lessonState.tasks[lessonState.phase].length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 300,
                child: LinearProgressIndicator(
                  value: (lessonState.phase + 1) / fractionsPhases.length,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
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

enum _ModelHighlight { none, shaded, whole }

class _FractionStrip extends StatelessWidget {
  const _FractionStrip({
    required this.denominator,
    required this.shaded,
    required this.width,
    required this.height,
    this.highlight = _ModelHighlight.none,
  });

  final int denominator;
  final int shaded;
  final double width;
  final double height;
  final _ModelHighlight highlight;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$shaded of $denominator equal parts shaded in one whole',
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: highlight == _ModelHighlight.whole ? _blue : _ink,
          width: highlight == _ModelHighlight.whole ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: List<Widget>.generate(denominator, (int index) {
          final bool filled = index < shaded;
          return Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? const Color(0xFFA4D6BD) : Colors.white,
                border: Border(
                  right:
                      index < denominator - 1
                          ? const BorderSide(color: _ink, width: 1)
                          : BorderSide.none,
                  top:
                      filled && highlight == _ModelHighlight.shaded
                          ? const BorderSide(color: _green, width: 3)
                          : BorderSide.none,
                ),
              ),
              child:
                  filled && height >= 40
                      ? const Icon(Icons.check_rounded, size: 14, color: _green)
                      : null,
            ),
          );
        }),
      ),
    ),
  );
}

class _FractionNotation extends StatelessWidget {
  const _FractionNotation({
    required this.spec,
    this.compact = false,
    this.numeratorPressed,
    this.denominatorPressed,
    this.numeratorAccepted = false,
    this.denominatorAccepted = false,
  });

  final FractionActivitySpec spec;
  final bool compact;
  final VoidCallback? numeratorPressed;
  final VoidCallback? denominatorPressed;
  final bool numeratorAccepted;
  final bool denominatorAccepted;

  @override
  Widget build(BuildContext context) {
    final bool interactive =
        numeratorPressed != null || denominatorPressed != null;
    final double size = compact ? 22 : 29;
    Widget number(
      int value,
      bool accepted,
      VoidCallback? onPressed,
      String name,
    ) {
      final Widget child = Container(
        width: interactive ? 72 : 53,
        height: interactive ? 52 : (compact ? 29 : 37),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              accepted
                  ? _paleGreen
                  : (interactive ? _paleBlue : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border:
              interactive ? Border.all(color: accepted ? _green : _blue) : null,
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: accepted ? _green : _ink,
          ),
        ),
      );
      return interactive
          ? Semantics(
            button: true,
            label: 'Tap $value, the $name',
            child: InkWell(onTap: onPressed, child: child),
          )
          : child;
    }

    return Semantics(
      label: '${spec.label}, ${spec.wholes > 0 ? 'mixed number' : 'fraction'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (spec.wholes > 0) ...<Widget>[
            Text(
              '${spec.wholes}',
              style: TextStyle(
                fontSize: compact ? 26 : 34,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 9),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              number(
                spec.numerator,
                numeratorAccepted,
                numeratorPressed,
                'numerator',
              ),
              Container(
                width: interactive ? 78 : 56,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: _ink,
              ),
              number(
                spec.denominator,
                denominatorAccepted,
                denominatorPressed,
                'denominator',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupplyDone extends StatelessWidget {
  const _SupplyDone(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 74,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _paleGreen,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w800, color: _green),
    ),
  );
}
