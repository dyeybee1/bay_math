import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/lesson_page.dart';
import '../../../core/widgets/widgets.dart';
import '../../student/presentation/lesson_viewer_screen.dart';
import '../data/teacher_lessons_providers.dart';
import '../widgets/bm_shared_widgets.dart';

/// A presentation-only lesson viewer for Teachers.
///
/// This screen intentionally has no dependency on the Student session or
/// lesson-progress repository. It reads only the existing RLS-scoped lesson
/// and page providers and delegates page visuals to [LessonPageView].
class TeacherLessonViewerScreen extends ConsumerWidget {
  const TeacherLessonViewerScreen({
    super.key,
    required this.lessonId,
    this.initialLesson,
  });

  final String lessonId;

  /// Supplied by the catalog to avoid re-fetching a lesson it already loaded.
  /// Direct URL navigation leaves this null and resolves through RLS.
  final Lesson? initialLesson;

  void _backToLessons(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go(AppRoutes.teacherLessons);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Lesson? lesson = initialLesson;
    if (lesson != null) {
      return _TeacherLessonPresentation(
        lesson: lesson,
        onBack: () => _backToLessons(context),
      );
    }

    final AsyncValue<Lesson?> lessonAsync = ref.watch(
      teacherVisibleLessonProvider(lessonId),
    );
    return lessonAsync.when(
      loading:
          () => _TeacherViewerState(
            onBack: () => _backToLessons(context),
            child: const AppLoadingIndicator(
              message: 'Preparing lesson preview...',
            ),
          ),
      error:
          (_, _) => _TeacherViewerState(
            onBack: () => _backToLessons(context),
            child: AppErrorState(
              message: 'This lesson could not be opened.',
              onRetry:
                  () => ref.invalidate(teacherVisibleLessonProvider(lessonId)),
            ),
          ),
      data:
          (Lesson? resolved) =>
              resolved == null
                  ? _TeacherViewerState(
                    onBack: () => _backToLessons(context),
                    child: const AppEmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Lesson unavailable',
                      description:
                          'This lesson may have been removed or is not available to your account.',
                    ),
                  )
                  : _TeacherLessonPresentation(
                    lesson: resolved,
                    onBack: () => _backToLessons(context),
                  ),
    );
  }
}

class _TeacherLessonPresentation extends ConsumerStatefulWidget {
  const _TeacherLessonPresentation({
    required this.lesson,
    required this.onBack,
  });

  final Lesson lesson;
  final VoidCallback onBack;

  @override
  ConsumerState<_TeacherLessonPresentation> createState() =>
      _TeacherLessonPresentationState();
}

class _TeacherLessonPresentationState
    extends ConsumerState<_TeacherLessonPresentation> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LessonPage>> pagesAsync = ref.watch(
      teacherLessonPagesProvider(widget.lesson.id),
    );

    return Scaffold(
      key: const Key('teacher_lesson_viewer'),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TeacherViewerHeader(lesson: widget.lesson, onBack: widget.onBack),
            Expanded(
              child: pagesAsync.when(
                loading:
                    () => const Center(
                      child: AppLoadingIndicator(
                        message: 'Preparing lesson content...',
                      ),
                    ),
                error:
                    (_, _) => Center(
                      child: AppErrorState(
                        message: 'The lesson content could not be loaded.',
                        onRetry:
                            () => ref.invalidate(
                              teacherLessonPagesProvider(widget.lesson.id),
                            ),
                      ),
                    ),
                data: (List<LessonPage> pages) {
                  if (pages.isEmpty) {
                    return const Center(
                      child: AppEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No lesson pages yet',
                        description:
                            'This lesson does not have any content to present.',
                      ),
                    );
                  }

                  final int safeIndex = _currentIndex.clamp(
                    0,
                    pages.length - 1,
                  );
                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: pages.length,
                          onPageChanged:
                              (int index) =>
                                  setState(() => _currentIndex = index),
                          itemBuilder:
                              (BuildContext context, int index) =>
                                  LessonPageView(
                                    page: pages[index],
                                    pageIndex: index,
                                    pageCount: pages.length,
                                  ),
                        ),
                      ),
                      _TeacherViewerNavigation(
                        currentIndex: safeIndex,
                        pageCount: pages.length,
                        onPrevious:
                            safeIndex == 0 ? null : () => _goTo(safeIndex - 1),
                        onNext:
                            safeIndex == pages.length - 1
                                ? null
                                : () => _goTo(safeIndex + 1),
                      ),
                    ],
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

class _TeacherViewerHeader extends StatelessWidget {
  const _TeacherViewerHeader({required this.lesson, required this.onBack});

  final Lesson lesson;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bool isBuiltIn = lesson.sourceType == ContentSourceType.builtIn;
    return Material(
      color: AppColors.card,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            OutlinedButton.icon(
              key: const Key('teacher_lesson_back'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Lessons'),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'TEACHING VIEW',
                    style: AppTextStyles.inter(
                      size: 10,
                      weight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.lexend(
                      size: 22,
                      weight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            BmSourceBadge(isBuiltIn: isBuiltIn),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.graySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Read only',
                style: AppTextStyles.inter(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherViewerNavigation extends StatelessWidget {
  const _TeacherViewerNavigation({
    required this.currentIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentIndex;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child:
            pageCount == 1
                ? Center(
                  child: Text(
                    '1 page',
                    style: AppTextStyles.inter(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.textSoft,
                    ),
                  ),
                )
                : Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: onPrevious,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Previous'),
                    ),
                    Expanded(
                      child: Text(
                        'Page ${currentIndex + 1} of $pageCount',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.inter(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Next'),
                      iconAlignment: IconAlignment.end,
                    ),
                  ],
                ),
      ),
    );
  }
}

class _TeacherViewerState extends StatelessWidget {
  const _TeacherViewerState({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Lessons'),
                ),
              ),
            ),
            Expanded(child: Center(child: child)),
          ],
        ),
      ),
    );
  }
}
