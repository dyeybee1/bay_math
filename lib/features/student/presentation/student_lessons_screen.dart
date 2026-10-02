import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export '../data/student_lessons_providers.dart'
    show studentCompletedLessonIdsProvider, studentVisibleLessonsProvider;

import '../../../app/constants/app_dimensions.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/widgets/widgets.dart';
import '../data/student_lessons_providers.dart';
import 'lesson_viewer_screen.dart';
import 'student_curriculum_order.dart';
import 'student_lesson_illustration.dart';

/// The student catalog keeps its existing lesson source, order, and viewer.
class StudentLessonsScreen extends ConsumerStatefulWidget {
  const StudentLessonsScreen({super.key});

  @override
  ConsumerState<StudentLessonsScreen> createState() =>
      _StudentLessonsScreenState();
}

class _StudentLessonsScreenState extends ConsumerState<StudentLessonsScreen> {
  bool _openingLesson = false;

  Future<void> _openLesson(Lesson lesson) async {
    if (_openingLesson) return;
    _openingLesson = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LessonViewerScreen(lesson: lesson),
        ),
      );
    } finally {
      if (mounted) {
        ref.invalidate(studentLessonStatusesProvider);
        _openingLesson = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Lesson>> lessonsAsync = ref.watch(
      studentVisibleLessonsProvider,
    );
    final List<Lesson>? lessons = lessonsAsync.asData?.value;
    final List<Lesson>? ordered =
        lessons == null ? null : orderStudentLessons(lessons);
    final AsyncValue<Map<String, String>> statusesAsync = ref.watch(
      studentLessonStatusesProvider,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FC),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LessonsBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                _LessonsHeader(lessonCount: ordered?.length),
                Expanded(
                  child: lessonsAsync.when(
                    loading:
                        () => const _LessonStateSurface(
                          child: AppLoadingIndicator(
                            message: 'Gathering your lessons…',
                          ),
                        ),
                    error:
                        (Object error, StackTrace _) => _LessonStateSurface(
                          child: AppErrorState(
                            icon: Icons.cloud_off_rounded,
                            message:
                                error is AppFailure
                                    ? error.message
                                    : 'Could not load your lessons.',
                            onRetry:
                                () => ref.invalidate(
                                  studentVisibleLessonsProvider,
                                ),
                          ),
                        ),
                    data: (List<Lesson> loaded) {
                      if (loaded.isEmpty) {
                        return const _LessonStateSurface(
                          child: AppEmptyState(
                            icon: Icons.auto_stories_outlined,
                            title: 'No lessons yet',
                            description:
                                'Check back once your teacher has assigned something.',
                          ),
                        );
                      }
                      return statusesAsync.when(
                        loading:
                            () => const _LessonStateSurface(
                              child: AppLoadingIndicator(
                                message: 'Checking lesson progress…',
                              ),
                            ),
                        error:
                            (Object error, StackTrace _) => _LessonStateSurface(
                              child: AppErrorState(
                                icon: Icons.cloud_off_rounded,
                                message:
                                    error is AppFailure
                                        ? error.message
                                        : 'Could not load lesson progress.',
                                onRetry:
                                    () => ref.invalidate(
                                      studentLessonStatusesProvider,
                                    ),
                              ),
                            ),
                        data:
                            (Map<String, String> statuses) => RefreshIndicator(
                              onRefresh: () async {
                                ref.invalidate(studentVisibleLessonsProvider);
                                ref.invalidate(studentLessonStatusesProvider);
                                ref.invalidate(
                                  studentCompletedLessonIdsProvider,
                                );
                              },
                              child: _LessonCatalog(
                                lessons: ordered!,
                                statuses: statuses,
                                onOpenLesson: _openLesson,
                              ),
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonsHeader extends StatelessWidget {
  const _LessonsHeader({required this.lessonCount});

  final int? lessonCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool short = MediaQuery.sizeOf(context).height < 680;
    return Material(
      color: Colors.white.withValues(alpha: .91),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDCE8F3))),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: short ? 8 : 11,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    key: const ValueKey<String>('lessons_back_button'),
                    tooltip: 'Back to home',
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(AppRoutes.studentHome);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF244A7B),
                      backgroundColor: const Color(0xFFE8F1FC),
                      minimumSize: const Size.square(
                        AppDimensions.minTouchTarget,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Lessons',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF193B5D),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                  ),
                  if (lessonCount != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 135),
                      child: Container(
                        key: const ValueKey<String>('lesson_count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD4E3F4)),
                        ),
                        child: Text(
                          '$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'}',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
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
  }
}

class _LessonCatalog extends StatelessWidget {
  const _LessonCatalog({
    required this.lessons,
    required this.statuses,
    required this.onOpenLesson,
  });

  final List<Lesson> lessons;
  final Map<String, String> statuses;
  final ValueChanged<Lesson> onOpenLesson;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool short = constraints.maxHeight < 590;
      final bool twoColumns =
          constraints.maxWidth >= 800 &&
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final double gap = short ? 12 : 16;
      final double padding = constraints.maxWidth < 600 ? 16 : 24;
      final int rowCount =
          twoColumns ? (lessons.length + 1) ~/ 2 : lessons.length;

      Widget card(int index) => _LessonCard(
        key: ValueKey<String>('lesson_card_${lessons[index].id}'),
        lesson: lessons[index],
        index: index,
        status: statuses[lessons[index].id],
        short: short,
        onTap: () => onOpenLesson(lessons[index]),
      );

      return ListView.builder(
        key: const ValueKey<String>('lesson_catalog'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(padding, short ? 12 : 20, padding, 32),
        itemCount: rowCount,
        itemBuilder: (BuildContext context, int row) {
          final int first = twoColumns ? row * 2 : row;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: row == rowCount - 1 ? 0 : gap),
                child:
                    twoColumns
                        ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(child: card(first)),
                              SizedBox(width: gap),
                              Expanded(
                                child:
                                    first + 1 < lessons.length
                                        ? card(first + 1)
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        )
                        : card(first),
              ),
            ),
          );
        },
      );
    },
  );
}

enum _LessonStatus { completed, inProgress, notStarted }

class _LessonCard extends StatefulWidget {
  const _LessonCard({
    super.key,
    required this.lesson,
    required this.index,
    required this.status,
    required this.short,
    required this.onTap,
  });

  final Lesson lesson;
  final int index;
  final String? status;
  final bool short;
  final VoidCallback onTap;

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _entered = false;
  Timer? _entranceTimer;

  @override
  void initState() {
    super.initState();
    _entered = widget.index >= 6;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entranceTimer?.cancel();
      _entranceTimer = null;
      _entered = true;
    } else if (!_entered && _entranceTimer == null) {
      _entranceTimer = Timer(
        Duration(milliseconds: 40 + widget.index * 45),
        () {
          _entranceTimer = null;
          if (mounted) setState(() => _entered = true);
        },
      );
    }
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool emphasized = _hovered || _focused || _pressed;
    final StudentLessonVisual visual = StudentLessonVisual.forLesson(
      widget.lesson,
    );
    final _LessonStatus status = switch (widget.status) {
      'completed' => _LessonStatus.completed,
      'in_progress' => _LessonStatus.inProgress,
      _ => _LessonStatus.notStarted,
    };
    final String statusLabel = switch (status) {
      _LessonStatus.completed => 'Completed',
      _LessonStatus.inProgress => 'In progress',
      _LessonStatus.notStarted => 'Not started',
    };
    final Color statusColor = switch (status) {
      _LessonStatus.completed => const Color(0xFF277257),
      _LessonStatus.inProgress => const Color(0xFF885823),
      _LessonStatus.notStarted => const Color(0xFF60768E),
    };
    final Color statusTint = switch (status) {
      _LessonStatus.completed => const Color(0xFFE5F5EC),
      _LessonStatus.inProgress => const Color(0xFFFFF2DF),
      _LessonStatus.notStarted => const Color(0xFFF0F4F8),
    };
    final IconData statusIcon = switch (status) {
      _LessonStatus.completed => Icons.check_circle_rounded,
      _LessonStatus.inProgress => Icons.timelapse_rounded,
      _LessonStatus.notStarted => Icons.circle_outlined,
    };
    final Duration duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 190);
    final String number = (widget.index + 1).toString().padLeft(2, '0');

    return Semantics(
      button: true,
      label: 'Lesson $number. ${widget.lesson.title}. $statusLabel.',
      child: AnimatedOpacity(
        opacity: reduceMotion || _entered ? 1 : 0,
        duration: duration,
        child: AnimatedSlide(
          offset:
              reduceMotion
                  ? Offset.zero
                  : !_entered
                  ? const Offset(0, .08)
                  : _hovered || _focused
                  ? const Offset(0, -.018)
                  : Offset.zero,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _pressed && !reduceMotion ? .99 : 1,
            duration: duration,
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Colors.white, visual.tint],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color:
                      emphasized
                          ? visual.accent.withValues(alpha: .58)
                          : visual.border,
                  width: emphasized ? 1.5 : 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(
                      0xFF386B9F,
                    ).withValues(alpha: emphasized ? .15 : .07),
                    blurRadius: emphasized ? 23 : 14,
                    offset: Offset(0, emphasized ? 8 : 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey<String>('lesson_tap_${widget.lesson.id}'),
                  borderRadius: BorderRadius.circular(22),
                  onTap: widget.onTap,
                  onHover: (bool value) => setState(() => _hovered = value),
                  onFocusChange:
                      (bool value) => setState(() => _focused = value),
                  onHighlightChanged:
                      (bool value) => setState(() => _pressed = value),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: widget.short ? 164 : 180,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        widget.short ? 15 : 18,
                        17,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'LESSON $number',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color: visual.accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 155,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusTint,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      statusIcon,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        statusLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  widget.lesson.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    color: visual.titleColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: widget.short ? 19 : 20,
                                    height: 1.16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              StudentLessonIllustration(
                                visual: visual,
                                size: widget.short ? 82 : 96,
                                hovered: emphasized,
                                reduceMotion: reduceMotion,
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 21,
                              color: visual.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonsBackdrop extends StatefulWidget {
  const _LessonsBackdrop();

  @override
  State<_LessonsBackdrop> createState() => _LessonsBackdropState();
}

class _LessonsBackdropState extends State<_LessonsBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context) || !_appActive) {
      _motion.stop();
      if (MediaQuery.disableAnimationsOf(context)) _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (mounted) _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _motion,
          builder:
              (BuildContext context, Widget? child) => CustomPaint(
                painter: _BackdropPainter(_motion.value),
                child: const SizedBox.expand(),
              ),
        ),
      ),
    ),
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFEDF5FF),
            Color(0xFFF4F1FF),
            Color(0xFFEDF8F5),
          ],
        ).createShader(Offset.zero & size),
    );
    final Paint dot =
        Paint()..color = const Color(0xFF7299C5).withValues(alpha: .095);
    for (double x = 18; x < size.width; x += 28) {
      for (double y = 18; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withValues(alpha: .13),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(
      Offset(size.width * .13 + phase * 26, size.height * .18),
      200,
      const Color(0xFF6EAAEC),
    );
    glow(
      Offset(size.width * .83 - phase * 24, size.height * .66),
      240,
      const Color(0xFFAB8AE5),
    );
    glow(
      Offset(size.width * .49, size.height * .90 - phase * 22),
      180,
      const Color(0xFF70BEA8),
    );
    const List<String> symbols = <String>['+', '÷', '×', '='];
    for (int i = 0; i < symbols.length; i++) {
      final TextPainter text = TextPainter(
        text: TextSpan(
          text: symbols[i],
          style: TextStyle(
            color: const Color(0xFF7998B9).withValues(alpha: .14),
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          size.width * (.13 + i * .23),
          size.height * (.24 + (i % 2) * .43) +
              math.sin(phase * math.pi + i) * 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _LessonStateSurface extends StatelessWidget {
  const _LessonStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: child,
    ),
  );
}
