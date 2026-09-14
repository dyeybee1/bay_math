import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

export '../data/student_lessons_providers.dart'
    show studentVisibleLessonsProvider;

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/widgets/widgets.dart';
import '../data/student_lessons_providers.dart';
import 'lesson_viewer_screen.dart';
import 'student_curriculum_order.dart';

abstract final class _LessonsPalette {
  static const Color pageBackground = Color(0xFFF3F7FC);
  static const Color learningGreen = Color(0xFF39735B);
  static const Color learningGreenContainer = Color(0xFFE1F0E8);
}

/// Landscape-first lesson catalog for the Student tablet experience.
///
/// Lesson fetching, refresh, retry, and viewer navigation remain unchanged.
/// The Student catalog applies the canonical curriculum order before pairing
/// lessons into responsive rows.
class StudentLessonsScreen extends ConsumerWidget {
  const StudentLessonsScreen({super.key});

  static const double _maxContentWidth = AppDimensions.maxContentWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Lesson>> lessonsAsync = ref.watch(
      studentVisibleLessonsProvider,
    );
    final int? lessonCount =
        lessonsAsync.asData == null
            ? null
            : orderStudentLessons(lessonsAsync.asData!.value).length;

    return Scaffold(
      backgroundColor: _LessonsPalette.pageBackground,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LessonsBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                _LessonsHeader(lessonCount: lessonCount),
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
                    data: (List<Lesson> lessons) {
                      if (lessons.isEmpty) {
                        return const _LessonStateSurface(
                          child: AppEmptyState(
                            icon: Icons.auto_stories_outlined,
                            title: 'No lessons yet',
                            description:
                                'Check back once your teacher has assigned something.',
                          ),
                        );
                      }

                      final List<Lesson> orderedLessons = orderStudentLessons(
                        lessons,
                      );

                      return RefreshIndicator(
                        onRefresh:
                            () async =>
                                ref.invalidate(studentVisibleLessonsProvider),
                        child: _LessonCatalog(
                          lessons: orderedLessons,
                          onOpenLesson: (Lesson lesson) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => LessonViewerScreen(lesson: lesson),
                              ),
                            );
                          },
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

class _LessonsBackdrop extends StatelessWidget {
  const _LessonsBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: _LessonsPalette.pageBackground),
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/stat_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.97),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StudentLessonsScreen._maxContentWidth,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isCompactHeight =
                    MediaQuery.sizeOf(context).height < 680;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: isCompactHeight ? 7 : 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        key: const ValueKey<String>('lessons_back_button'),
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.onPrimaryContainer,
                          backgroundColor: colorScheme.primaryContainer,
                          minimumSize: const Size.square(
                            AppDimensions.minTouchTarget,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        width: isCompactHeight ? 42 : 46,
                        height: isCompactHeight ? 42 : 46,
                        decoration: BoxDecoration(
                          color: _LessonsPalette.learningGreenContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: _LessonsPalette.learningGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Lessons',
                              style: GoogleFonts.lexend(
                                color: AppColors.textPrimary,
                                fontSize: isCompactHeight ? 24 : 26,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Choose your next math lesson.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: isCompactHeight ? 15 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (lessonCount != null &&
                          constraints.maxWidth >= 720) ...<Widget>[
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.auto_awesome_motion_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '$lessonCount ${lessonCount == 1 ? 'LESSON' : 'LESSONS'}',
                                style: GoogleFonts.inter(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCatalog extends StatelessWidget {
  const _LessonCatalog({required this.lessons, required this.onOpenLesson});

  final List<Lesson> lessons;
  final ValueChanged<Lesson> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isShort = constraints.maxHeight < 590;
        final bool useTwoColumns = constraints.maxWidth >= 880;
        final double horizontalPadding =
            constraints.maxWidth >= 1500 ? AppSpacing.xl : AppSpacing.lg;
        final double verticalPadding = isShort ? 12 : AppSpacing.md;
        final double gap = isShort ? 12 : AppSpacing.md;
        final int rowCount =
            useTwoColumns ? (lessons.length + 1) ~/ 2 : lessons.length;

        return ListView.builder(
          key: const ValueKey<String>('lesson_catalog'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            isShort ? AppSpacing.lg : AppSpacing.xl,
          ),
          itemCount: rowCount,
          itemBuilder: (BuildContext context, int rowIndex) {
            final int lessonIndex = useTwoColumns ? rowIndex * 2 : rowIndex;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StudentLessonsScreen._maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: rowIndex == rowCount - 1 ? 0 : gap,
                  ),
                  child:
                      useTwoColumns
                          ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Expanded(
                                  child: _LessonCard(
                                    key: ValueKey<String>(
                                      'lesson_card_$lessonIndex',
                                    ),
                                    lesson: lessons[lessonIndex],
                                    index: lessonIndex,
                                    compact: isShort,
                                    onTap:
                                        () =>
                                            onOpenLesson(lessons[lessonIndex]),
                                  ),
                                ),
                                SizedBox(width: gap),
                                Expanded(
                                  child:
                                      lessonIndex + 1 < lessons.length
                                          ? _LessonCard(
                                            key: ValueKey<String>(
                                              'lesson_card_${lessonIndex + 1}',
                                            ),
                                            lesson: lessons[lessonIndex + 1],
                                            index: lessonIndex + 1,
                                            compact: isShort,
                                            onTap:
                                                () => onOpenLesson(
                                                  lessons[lessonIndex + 1],
                                                ),
                                          )
                                          : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          )
                          : _LessonCard(
                            key: ValueKey<String>('lesson_card_$lessonIndex'),
                            lesson: lessons[lessonIndex],
                            index: lessonIndex,
                            compact: isShort,
                            onTap: () => onOpenLesson(lessons[lessonIndex]),
                          ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LessonCard extends StatefulWidget {
  const _LessonCard({
    super.key,
    required this.lesson,
    required this.index,
    required this.compact,
    required this.onTap,
  });

  final Lesson lesson;
  final int index;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isEmphasized => _isHovered || _isFocused || _isPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _LessonVisual visual = _LessonVisual.forTitle(widget.lesson.title);
    final String lessonNumber = (widget.index + 1).toString().padLeft(2, '0');
    final Color labelColor =
        Color.lerp(visual.color, AppColors.textPrimary, 0.22)!;

    return Semantics(
      button: true,
      label:
          'Lesson $lessonNumber. ${widget.lesson.title}. ${widget.lesson.body}',
      child: AnimatedScale(
        scale: _isPressed ? 0.992 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: widget.compact ? 142 : 148,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  _isEmphasized
                      ? visual.color.withValues(alpha: 0.52)
                      : colorScheme.outlineVariant,
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.onPrimaryContainer.withValues(
                  alpha: _isEmphasized ? 0.1 : 0.075,
                ),
                blurRadius: _isEmphasized ? 18 : 15,
                offset: Offset(0, _isEmphasized ? 6 : 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (bool value) => setState(() => _isHovered = value),
              onFocusChange: (bool value) => setState(() => _isFocused = value),
              onHighlightChanged:
                  (bool value) => setState(() => _isPressed = value),
              focusColor: visual.containerColor.withValues(alpha: 0.35),
              hoverColor: visual.containerColor.withValues(alpha: 0.25),
              highlightColor: visual.containerColor.withValues(alpha: 0.18),
              splashColor: visual.color.withValues(alpha: 0.12),
              child: Ink(
                color: colorScheme.surface,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 18,
                      bottom: 18,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: visual.color,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: widget.compact ? 12 : 13,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _LessonVisualTile(
                                key: ValueKey<String>(
                                  'lesson_topic_visual_${widget.index}',
                                ),
                                visual: visual,
                                compact: widget.compact,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'LESSON $lessonNumber',
                                key: ValueKey<String>(
                                  'lesson_label_${widget.index}',
                                ),
                                style: GoogleFonts.inter(
                                  color: labelColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.75,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height:
                                widget.compact ? AppSpacing.xs : AppSpacing.sm,
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Text(
                                widget.lesson.title,
                                key: ValueKey<String>(
                                  'lesson_title_${widget.index}',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lexend(
                                  color: AppColors.textPrimary,
                                  fontSize: widget.compact ? 19 : 20,
                                  fontWeight: FontWeight.w600,
                                  height: widget.compact ? 1.14 : 1.16,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonVisualTile extends StatelessWidget {
  const _LessonVisualTile({
    super.key,
    required this.visual,
    required this.compact,
  });

  final _LessonVisual visual;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 46 : 48;
    final double glyphExtent = compact ? 32 : 34;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: visual.containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: visual.color.withValues(alpha: 0.18)),
          ),
          child: Center(
            child: SizedBox.square(
              dimension: glyphExtent,
              child: Center(
                child:
                    visual.symbol == null
                        ? Icon(visual.icon, color: visual.color, size: 26)
                        : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            visual.symbol!,
                            maxLines: 1,
                            style: GoogleFonts.lexend(
                              color: visual.color,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1,
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

class _LessonVisual {
  const _LessonVisual({
    required this.color,
    required this.containerColor,
    this.icon,
    this.symbol,
  }) : assert(icon != null || symbol != null);

  final Color color;
  final Color containerColor;
  final IconData? icon;
  final String? symbol;

  static _LessonVisual forTitle(String title) {
    final String normalizedTitle = title.toLowerCase();

    if (normalizedTitle.contains('time')) {
      return const _LessonVisual(
        color: _LessonsPalette.learningGreen,
        containerColor: _LessonsPalette.learningGreenContainer,
        icon: Icons.schedule_rounded,
      );
    }
    if (normalizedTitle.contains('probability')) {
      return const _LessonVisual(
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        icon: Icons.casino_outlined,
      );
    }
    if (normalizedTitle.contains('ratio') ||
        normalizedTitle.contains('proportion')) {
      return const _LessonVisual(
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        icon: Icons.balance_rounded,
      );
    }
    if (normalizedTitle.contains('circle')) {
      return const _LessonVisual(
        color: _LessonsPalette.learningGreen,
        containerColor: _LessonsPalette.learningGreenContainer,
        icon: Icons.donut_large_rounded,
      );
    }
    if (normalizedTitle.contains('volume') ||
        normalizedTitle.contains('surface area') ||
        normalizedTitle.contains('solid figure')) {
      return const _LessonVisual(
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        icon: Icons.view_in_ar_rounded,
      );
    }
    if (normalizedTitle.contains('area') ||
        normalizedTitle.contains('perimeter') ||
        normalizedTitle.contains('plane figure')) {
      return const _LessonVisual(
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        icon: Icons.category_rounded,
      );
    }
    if (normalizedTitle.contains('factor') ||
        normalizedTitle.contains('multiple') ||
        normalizedTitle.contains('divisibility') ||
        normalizedTitle.contains('prime') ||
        normalizedTitle.contains('composite number')) {
      return const _LessonVisual(
        color: _LessonsPalette.learningGreen,
        containerColor: _LessonsPalette.learningGreenContainer,
        icon: Icons.grid_view_rounded,
      );
    }
    if (normalizedTitle.contains('fraction') &&
        normalizedTitle.contains('decimal')) {
      return const _LessonVisual(
        color: _LessonsPalette.learningGreen,
        containerColor: _LessonsPalette.learningGreenContainer,
        symbol: '\u00BD \u2194 .5',
      );
    }
    if (normalizedTitle.contains('fraction')) {
      return const _LessonVisual(
        color: _LessonsPalette.learningGreen,
        containerColor: _LessonsPalette.learningGreenContainer,
        symbol: '\u00BD',
      );
    }
    if (normalizedTitle.contains('decimal')) {
      return const _LessonVisual(
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        symbol: '0.5',
      );
    }
    if (normalizedTitle.contains('place value')) {
      return const _LessonVisual(
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        symbol: '123',
      );
    }
    if (normalizedTitle.contains('compar')) {
      return const _LessonVisual(
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        symbol: '< >',
      );
    }
    if (normalizedTitle.contains('multipli') ||
        normalizedTitle.contains('divid') ||
        normalizedTitle.contains('mdas') ||
        normalizedTitle.contains('gmdas') ||
        normalizedTitle.contains('gemdas') ||
        normalizedTitle.contains('exponent')) {
      return const _LessonVisual(
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        symbol: '\u00D7 \u00F7',
      );
    }
    if (normalizedTitle.contains('add') ||
        normalizedTitle.contains('subtract')) {
      return const _LessonVisual(
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        symbol: '+ \u2212',
      );
    }

    return const _LessonVisual(
      color: AppColors.primary,
      containerColor: AppColors.primaryContainer,
      icon: Icons.functions_rounded,
    );
  }
}

class _LessonStateSurface extends StatelessWidget {
  const _LessonStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        margin: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
