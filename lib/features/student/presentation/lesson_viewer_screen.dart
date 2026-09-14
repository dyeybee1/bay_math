import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/lesson_page.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/lesson_progress_repository.dart';
import '../../../core/repositories/lessons_repository.dart';
import '../../../core/repositories/quizzes_repository.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/lesson/lesson_content_block_view.dart';
import '../data/student_statistics_providers.dart';
import 'quiz_taking_screen.dart';
import 'worked_example_panel.dart';

abstract final class _LessonViewerPalette {
  static const Color pageBackground = Color(0xFFF3F7FC);
  static const Color vocabulary = Color(0xFF39735B);
  static const Color vocabularyContainer = Color(0xFFE1F0E8);
  static const Color explanation = Color(0xFF516C9B);
  static const Color explanationContainer = Color(0xFFE5EBF5);
  static const Color summary = Color(0xFF705CA3);
  static const Color summaryContainer = Color(0xFFEDE8F7);
}

class _SectionPresentation {
  const _SectionPresentation({
    required this.label,
    required this.icon,
    required this.color,
    required this.containerColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color containerColor;
}

_SectionPresentation _presentationFor(String? sectionType) {
  return switch (sectionType) {
    'introduction' => const _SectionPresentation(
      label: 'Lesson introduction',
      icon: Icons.flag_rounded,
      color: AppColors.primary,
      containerColor: AppColors.primaryContainer,
    ),
    'vocabulary' => const _SectionPresentation(
      label: 'Math vocabulary',
      icon: Icons.menu_book_rounded,
      color: _LessonViewerPalette.vocabulary,
      containerColor: _LessonViewerPalette.vocabularyContainer,
    ),
    'explanation' => const _SectionPresentation(
      label: 'Learn the idea',
      icon: Icons.lightbulb_rounded,
      color: _LessonViewerPalette.explanation,
      containerColor: _LessonViewerPalette.explanationContainer,
    ),
    'examples' => const _SectionPresentation(
      label: 'Worked example',
      icon: Icons.calculate_rounded,
      color: AppColors.tertiary,
      containerColor: AppColors.tertiaryContainer,
    ),
    'summary' => const _SectionPresentation(
      label: 'Key takeaways',
      icon: Icons.task_alt_rounded,
      color: _LessonViewerPalette.summary,
      containerColor: _LessonViewerPalette.summaryContainer,
    ),
    'composer_heading' => const _SectionPresentation(
      label: 'Lesson heading',
      icon: Icons.title_rounded,
      color: AppColors.primary,
      containerColor: AppColors.primaryContainer,
    ),
    'composer_paragraph' => const _SectionPresentation(
      label: 'Lesson explanation',
      icon: Icons.notes_rounded,
      color: _LessonViewerPalette.explanation,
      containerColor: _LessonViewerPalette.explanationContainer,
    ),
    'composer_image' => const _SectionPresentation(
      label: 'Lesson image',
      icon: Icons.image_outlined,
      color: _LessonViewerPalette.vocabulary,
      containerColor: _LessonViewerPalette.vocabularyContainer,
    ),
    'composer_key_idea' => const _SectionPresentation(
      label: 'Key idea',
      icon: Icons.lightbulb_rounded,
      color: _LessonViewerPalette.vocabulary,
      containerColor: _LessonViewerPalette.vocabularyContainer,
    ),
    'composer_worked_example' => const _SectionPresentation(
      label: 'Worked example',
      icon: Icons.calculate_rounded,
      color: AppColors.tertiary,
      containerColor: AppColors.tertiaryContainer,
    ),
    'composer_link' => const _SectionPresentation(
      label: 'Learning resource',
      icon: Icons.link_rounded,
      color: AppColors.primary,
      containerColor: AppColors.primaryContainer,
    ),
    _ => const _SectionPresentation(
      label: 'Lesson note',
      icon: Icons.description_rounded,
      color: AppColors.primary,
      containerColor: AppColors.primaryContainer,
    ),
  };
}

/// [lessonId]'s ordered pages. RLS already scopes these through the parent
/// lesson; this provider remains intentionally unchanged by the redesign.
final lessonPagesProvider = FutureProvider.family<List<LessonPage>, String>((
  ref,
  lessonId,
) {
  final LessonsRepository? repo = ref.watch(studentLessonsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchPages(lessonId);
});

/// The optional quiz linked to a lesson. It remains a convenience shortcut,
/// never a requirement for lesson completion.
final linkedQuizProvider = FutureProvider.family<Quiz?, String>((ref, quizId) {
  final QuizzesRepository? repo = ref.watch(studentQuizzesRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchById(quizId);
});

/// Landscape-only guided lesson workspace.
///
/// Page order, progress persistence, completion timing, swiping, drawer
/// selection, and final actions are unchanged. This screen only reshapes the
/// presentation around those existing behaviors.
class LessonViewerScreen extends ConsumerStatefulWidget {
  const LessonViewerScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends ConsumerState<LessonViewerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _hasMarkedInProgress = false;
  bool _hasMarkedCompleted = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _markInProgressOnce() {
    if (_hasMarkedInProgress) return;
    _hasMarkedInProgress = true;

    final StudentSession? session = ref.read(studentSessionProvider);
    final LessonProgressRepository? repo = ref.read(
      lessonProgressRepositoryProvider,
    );
    if (session == null || repo == null) return;

    repo.markInProgress(
      studentId: session.studentId,
      lessonId: widget.lesson.id,
    );
  }

  void _markCompletedIfOnFinalPage(int index, int pageCount) {
    if (_hasMarkedCompleted) return;
    if (pageCount == 0 || index != pageCount - 1) return;
    _hasMarkedCompleted = true;

    final StudentSession? session = ref.read(studentSessionProvider);
    final LessonProgressRepository? repo = ref.read(
      lessonProgressRepositoryProvider,
    );
    if (session == null || repo == null) return;

    repo
        .markCompleted(studentId: session.studentId, lessonId: widget.lesson.id)
        .then((_) {
          if (mounted) ref.invalidate(studentStatisticsProvider);
        });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LessonPage>> pagesAsync = ref.watch(
      lessonPagesProvider(widget.lesson.id),
    );
    final List<LessonPage>? loadedPages = pagesAsync.value;

    if (loadedPages != null && loadedPages.isNotEmpty) {
      _markInProgressOnce();
      _markCompletedIfOnFinalPage(_currentIndex, loadedPages.length);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _LessonViewerPalette.pageBackground,
      drawer:
          loadedPages == null || loadedPages.isEmpty
              ? null
              : _OutlineDrawer(
                lessonTitle: widget.lesson.title,
                pages: loadedPages,
                currentIndex: _currentIndex,
                onSelect: (int index) {
                  Navigator.of(context).pop();
                  _goToPage(index);
                },
              ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LessonBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                _LessonHeader(
                  lesson: widget.lesson,
                  currentIndex: _currentIndex,
                  pageCount: loadedPages?.length,
                  onOpenOutline:
                      loadedPages == null || loadedPages.isEmpty
                          ? null
                          : () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(
                  child: pagesAsync.when(
                    loading:
                        () => const _LessonStateSurface(
                          child: AppLoadingIndicator(
                            size: AppComponentSize.large,
                            message: 'Preparing your lesson...',
                          ),
                        ),
                    error:
                        (Object error, StackTrace _) => _LessonStateSurface(
                          child: AppErrorState(
                            message:
                                error is AppFailure
                                    ? error.message
                                    : 'Could not load this lesson.',
                            onRetry:
                                () => ref.invalidate(
                                  lessonPagesProvider(widget.lesson.id),
                                ),
                          ),
                        ),
                    data: (List<LessonPage> pages) {
                      if (pages.isEmpty) {
                        return const _LessonStateSurface(
                          child: AppEmptyState(
                            icon: Icons.menu_book_outlined,
                            title: "This lesson doesn't have any content yet",
                            description: 'Check back later.',
                          ),
                        );
                      }

                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: pages.length,
                              onPageChanged: (int index) {
                                setState(() => _currentIndex = index);
                                _markCompletedIfOnFinalPage(
                                  index,
                                  pages.length,
                                );
                              },
                              itemBuilder: (BuildContext context, int index) {
                                return _LessonPageSlide(
                                  page: pages[index],
                                  pageIndex: index,
                                  pageCount: pages.length,
                                  trailing:
                                      index == pages.length - 1 &&
                                              widget.lesson.linkedQuizId != null
                                          ? _TakeQuizCard(
                                            quizId: widget.lesson.linkedQuizId!,
                                          )
                                          : null,
                                );
                              },
                            ),
                          ),
                          _LessonPageFooter(
                            currentIndex: _currentIndex,
                            pageCount: pages.length,
                            currentTitle: lessonPageNavigationLabel(
                              pages[_currentIndex],
                            ),
                            onPrevious: () => _goToPage(_currentIndex - 1),
                            onNext: () => _goToPage(_currentIndex + 1),
                            onFinish: () => Navigator.of(context).pop(),
                          ),
                        ],
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

class _LessonBackdrop extends StatelessWidget {
  const _LessonBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: _LessonViewerPalette.pageBackground),
          Opacity(
            opacity: 0.52,
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

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({
    required this.lesson,
    required this.currentIndex,
    required this.pageCount,
    required this.onOpenOutline,
  });

  final Lesson lesson;
  final int currentIndex;
  final int? pageCount;
  final VoidCallback? onOpenOutline;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String contextLabel =
        lesson.gradeLevel == null
            ? 'GUIDED LESSON'
            : '${lesson.gradeLevel!.label.toUpperCase()}  |  GUIDED LESSON';
    final double progress =
        pageCount == null || pageCount == 0
            ? 0
            : (currentIndex + 1) / pageCount!;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.98),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Semantics(
                      button: true,
                      label: 'Open lesson outline',
                      child: IconButton(
                        tooltip: 'Lesson outline',
                        onPressed: onOpenOutline,
                        icon: const Icon(Icons.menu_book_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          backgroundColor: colorScheme.primaryContainer,
                          disabledBackgroundColor:
                              colorScheme.surfaceContainerHighest,
                          minimumSize: const Size.square(
                            AppDimensions.minTouchTarget,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            contextLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        key: ValueKey<int>(currentIndex),
                        constraints: const BoxConstraints(minWidth: 104),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Text(
                          pageCount == null || pageCount == 0
                              ? 'Loading...'
                              : 'Step ${currentIndex + 1} of $pageCount',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
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
          Semantics(
            label:
                pageCount == null || pageCount == 0
                    ? 'Lesson progress unavailable'
                    : 'Lesson progress: step ${currentIndex + 1} of $pageCount',
            child: LinearProgressIndicator(
              value: pageCount == null || pageCount == 0 ? null : progress,
              minHeight: 5,
              backgroundColor: colorScheme.primaryContainer,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonStateSurface extends StatelessWidget {
  const _LessonStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
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

class _LessonPageSlide extends StatelessWidget {
  const _LessonPageSlide({
    required this.page,
    required this.pageIndex,
    required this.pageCount,
    this.trailing,
  });

  final LessonPage page;
  final int pageIndex;
  final int pageCount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final _SectionPresentation presentation = _presentationFor(
      page.sectionType,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isShort = constraints.maxHeight < 440;
        final bool isExpanded =
            constraints.maxWidth >= 1500 && constraints.maxHeight >= 850;
        final double horizontalPadding =
            isExpanded ? AppSpacing.xl : AppSpacing.md;
        final double verticalPadding = isShort ? AppSpacing.sm : AppSpacing.md;
        final double minContentHeight =
            constraints.maxHeight - (verticalPadding * 2);

        if (isComposerLessonPage(page)) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minContentHeight > 0 ? minContentHeight : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Semantics(
                    container: true,
                    label:
                        '${presentation.label}. Step ${pageIndex + 1} of $pageCount.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        LessonContentBlockView(page: page, compact: isShort),
                        if (trailing != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minContentHeight > 0 ? minContentHeight : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Semantics(
                  container: true,
                  label:
                      '${presentation.label}. Step ${pageIndex + 1} of $pageCount.',
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: presentation.color.withValues(alpha: 0.2),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.onPrimaryContainer.withValues(
                            alpha: 0.09,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _LessonSectionHeader(
                            page: page,
                            pageIndex: pageIndex,
                            pageCount: pageCount,
                            presentation: presentation,
                            compact: isShort,
                          ),
                          Padding(
                            padding: EdgeInsets.all(
                              isShort ? AppSpacing.md : AppSpacing.lg,
                            ),
                            child:
                                page.workedExample == null
                                    ? _LessonBodySurface(
                                      body: page.body,
                                      sectionType: page.sectionType,
                                      presentation: presentation,
                                    )
                                    : WorkedExamplePanel(
                                      workedExample: page.workedExample!,
                                    ),
                          ),
                          if (trailing != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              child: trailing,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LessonSectionHeader extends StatelessWidget {
  const _LessonSectionHeader({
    required this.page,
    required this.pageIndex,
    required this.pageCount,
    required this.presentation,
    required this.compact,
  });

  final LessonPage page;
  final int pageIndex;
  final int pageCount;
  final _SectionPresentation presentation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.lg,
        vertical: compact ? 12 : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: presentation.containerColor.withValues(alpha: 0.62),
        border: Border(
          bottom: BorderSide(color: presentation.color.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 48 : 54,
            height: compact ? 48 : 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: presentation.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              presentation.icon,
              color: Colors.white,
              size: compact ? 24 : 27,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  presentation.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: presentation.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  page.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(
                    color: AppColors.textPrimary,
                    fontSize: compact ? 21 : 25,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: presentation.color.withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              '${pageIndex + 1}/$pageCount',
              style: GoogleFonts.inter(
                color: presentation.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonBodySurface extends StatelessWidget {
  const _LessonBodySurface({
    required this.body,
    required this.sectionType,
    required this.presentation,
  });

  final String body;
  final String? sectionType;
  final _SectionPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final bool isIntroduction = sectionType == 'introduction';
    final bool isSummary = sectionType == 'summary';
    final bool isExample = sectionType == 'examples';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: presentation.containerColor.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: presentation.color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isIntroduction || isSummary) ...<Widget>[
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: presentation.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: SelectableText(
              body,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: isIntroduction ? 18 : 16,
                fontWeight:
                    isIntroduction || isSummary
                        ? FontWeight.w600
                        : FontWeight.w500,
                height: isExample ? 1.62 : 1.58,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeQuizCard extends ConsumerWidget {
  const _TakeQuizCard({required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Quiz?> quizAsync = ref.watch(linkedQuizProvider(quizId));

    return quizAsync.maybeWhen(
      data: (Quiz? quiz) {
        if (quiz == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.quiz_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Ready to check your understanding?',
                      style: GoogleFonts.lexend(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quiz.title}  |  Optional',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'Take Quiz',
                size: AppComponentSize.large,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizTakingScreen(quiz: quiz),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LessonPageFooter extends StatelessWidget {
  const _LessonPageFooter({
    required this.currentIndex,
    required this.pageCount,
    required this.currentTitle,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final int currentIndex;
  final int pageCount;
  final String currentTitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final bool isFirst = currentIndex == 0;
    final bool isLast = currentIndex == pageCount - 1;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.98),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 170,
                  child: AppButton(
                    label: 'Previous',
                    size: AppComponentSize.large,
                    variant: AppButtonVariant.outlined,
                    leadingIcon: Icons.arrow_back_rounded,
                    onPressed: isFirst ? null : onPrevious,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _FooterProgress(
                    currentIndex: currentIndex,
                    pageCount: pageCount,
                    currentTitle: currentTitle,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 170,
                  child: AppButton(
                    label: isLast ? 'Done' : 'Next',
                    size: AppComponentSize.large,
                    leadingIcon: isLast ? Icons.check_rounded : null,
                    trailingIcon: isLast ? null : Icons.arrow_forward_rounded,
                    onPressed: isLast ? onFinish : onNext,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterProgress extends StatelessWidget {
  const _FooterProgress({
    required this.currentIndex,
    required this.pageCount,
    required this.currentTitle,
  });

  final int currentIndex;
  final int pageCount;
  final String currentTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            currentTitle,
            key: ValueKey<int>(currentIndex),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / pageCount,
                  minHeight: 6,
                  backgroundColor: AppColors.primaryContainer,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${currentIndex + 1}/$pageCount',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlineDrawer extends StatelessWidget {
  const _OutlineDrawer({
    required this.lessonTitle,
    required this.pages,
    required this.currentIndex,
    required this.onSelect,
  });

  final String lessonTitle;
  final List<LessonPage> pages;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double drawerWidth =
        MediaQuery.sizeOf(context).width.clamp(340, 430).toDouble();

    return Drawer(
      width: drawerWidth,
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    AppColors.onPrimaryContainer,
                    AppColors.primary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'LESSON OUTLINE',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lessonTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: pages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final bool isComplete = index < currentIndex;
                  final bool isCurrent = index == currentIndex;
                  final _SectionPresentation presentation = _presentationFor(
                    pages[index].sectionType,
                  );

                  return Material(
                    color:
                        isCurrent
                            ? presentation.containerColor.withValues(
                              alpha: 0.72,
                            )
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onSelect(index),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isCurrent
                                    ? presentation.color.withValues(alpha: 0.22)
                                    : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    isComplete || isCurrent
                                        ? presentation.color
                                        : colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isComplete
                                    ? Icons.check_rounded
                                    : isCurrent
                                    ? Icons.play_arrow_rounded
                                    : presentation.icon,
                                color:
                                    isComplete || isCurrent
                                        ? Colors.white
                                        : colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Step ${index + 1}',
                                    style: GoogleFonts.inter(
                                      color:
                                          isCurrent
                                              ? presentation.color
                                              : AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lessonPageNavigationLabel(pages[index]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight:
                                          isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
