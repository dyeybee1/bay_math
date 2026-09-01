import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'lesson_viewer_screen.dart';
import 'student_curriculum_order.dart';

/// Every lesson visible to the signed-in student — RLS
/// (`lessons_student_select`, 0015) resolves built-in + section-assigned
/// visibility automatically; this is the same query
/// `LessonsRepository.fetchVisibleToTeacher()` already runs for a Teacher,
/// just issued from the student-scoped client instead (see
/// `studentLessonsRepositoryProvider`'s doc comment for why that reuse is
/// safe).
final studentVisibleLessonsProvider = FutureProvider<List<Lesson>>((ref) {
  final repo = ref.watch(studentLessonsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchVisibleToTeacher();
});

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

  static const double _maxContentWidth = 1400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Lesson>> lessonsAsync = ref.watch(
      studentVisibleLessonsProvider,
    );

    return Scaffold(
      backgroundColor: _LessonsPalette.pageBackground,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LessonsBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                const _LessonsHeader(),
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
  const _LessonsHeader();

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
                    horizontal:
                        constraints.maxWidth < 1120
                            ? AppSpacing.md
                            : AppSpacing.lg,
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
                                fontSize: isCompactHeight ? 22 : 24,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Choose a topic and start learning.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: isCompactHeight ? 13 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (constraints.maxWidth >= 860) ...<Widget>[
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.explore_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'BAYMATH LEARNING',
                                style: GoogleFonts.inter(
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
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
            constraints.maxWidth >= 1500
                ? AppSpacing.xl
                : constraints.maxWidth < 1120
                ? AppSpacing.md
                : AppSpacing.lg;
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
          itemCount: rowCount + 1,
          itemBuilder: (BuildContext context, int rowIndex) {
            if (rowIndex == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: isShort ? 10 : 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: StudentLessonsScreen._maxContentWidth,
                    ),
                    child: _CatalogIntro(lessonCount: lessons.length),
                  ),
                ),
              );
            }

            final int lessonIndex =
                useTwoColumns ? (rowIndex - 1) * 2 : rowIndex - 1;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StudentLessonsScreen._maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: rowIndex == rowCount ? 0 : gap,
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

class _CatalogIntro extends StatelessWidget {
  const _CatalogIntro({required this.lessonCount});

  final int lessonCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Text(
          'YOUR LEARNING PATH',
          style: GoogleFonts.inter(
            color: colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$lessonCount ${lessonCount == 1 ? 'topic' : 'topics'}',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    final _LessonAccent accent = _LessonAccent.forIndex(widget.index);
    final String lessonNumber = (widget.index + 1).toString().padLeft(2, '0');

    return Semantics(
      button: true,
      label:
          'Lesson $lessonNumber. ${widget.lesson.title}. ${widget.lesson.body}',
      child: AnimatedScale(
        scale: _isPressed ? 0.99 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  _isEmphasized
                      ? accent.color.withValues(alpha: 0.52)
                      : colorScheme.outlineVariant,
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.onPrimaryContainer.withValues(
                  alpha: _isEmphasized ? 0.12 : 0.07,
                ),
                blurRadius: _isEmphasized ? 20 : 14,
                offset: Offset(0, _isEmphasized ? 7 : 5),
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
              focusColor: accent.containerColor.withValues(alpha: 0.35),
              hoverColor: accent.containerColor.withValues(alpha: 0.25),
              splashColor: accent.color.withValues(alpha: 0.12),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      colorScheme.surface,
                      accent.containerColor.withValues(alpha: 0.22),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 18,
                      bottom: 18,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: accent.color,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(
                        widget.compact ? 14 : AppSpacing.md,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _LessonNumberTile(
                            number: lessonNumber,
                            accent: accent,
                            compact: widget.compact,
                          ),
                          SizedBox(width: widget.compact ? 12 : AppSpacing.md),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'LESSON $lessonNumber',
                                  style: GoogleFonts.inter(
                                    color: accent.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.lesson.title,
                                  style: GoogleFonts.lexend(
                                    color: AppColors.textPrimary,
                                    fontSize: widget.compact ? 16 : 17,
                                    fontWeight: FontWeight.w600,
                                    height: 1.24,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  widget.lesson.body,
                                  maxLines: widget.compact ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: widget.compact ? 13 : 13.5,
                                    fontWeight: FontWeight.w400,
                                    height: 1.42,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Align(
                            alignment: Alignment.center,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: AppDimensions.minTouchTarget,
                              height: AppDimensions.minTouchTarget,
                              decoration: BoxDecoration(
                                color:
                                    _isEmphasized
                                        ? accent.color
                                        : accent.containerColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 21,
                                color:
                                    _isEmphasized
                                        ? colorScheme.onPrimary
                                        : accent.color,
                              ),
                            ),
                          ),
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

class _LessonNumberTile extends StatelessWidget {
  const _LessonNumberTile({
    required this.number,
    required this.accent,
    required this.compact,
  });

  final String number;
  final _LessonAccent accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 50 : 54;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.containerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            Icons.auto_stories_rounded,
            color: accent.color.withValues(alpha: 0.18),
            size: compact ? 34 : 38,
          ),
          Text(
            number,
            style: GoogleFonts.lexend(
              color: accent.color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonAccent {
  const _LessonAccent({required this.color, required this.containerColor});

  final Color color;
  final Color containerColor;

  static _LessonAccent forIndex(int index) {
    return switch (index % 3) {
      1 => const _LessonAccent(
        color: _LessonsPalette.learningGreen,
        containerColor: _LessonsPalette.learningGreenContainer,
      ),
      2 => const _LessonAccent(
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
      ),
      _ => const _LessonAccent(
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
      ),
    };
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
