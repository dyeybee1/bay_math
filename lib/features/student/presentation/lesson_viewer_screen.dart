import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
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
import 'quiz_taking_screen.dart';
import 'worked_example_panel.dart';

/// Presentation-only icon per `section_type` (0028's column comment) — a
/// small constant map, never a gate on access. Anything not in this map
/// (including null, or a future type a teacher/admin invents later) falls
/// back to [_defaultSectionIcon], exactly as designed.
const Map<String, IconData> _sectionTypeIcons = {
  'introduction': Icons.flag_outlined,
  'vocabulary': Icons.menu_book_outlined,
  'explanation': Icons.lightbulb_outline,
  'examples': Icons.calculate_outlined,
};
const IconData _defaultSectionIcon = Icons.description_outlined;

IconData _iconForSectionType(String? sectionType) =>
    _sectionTypeIcons[sectionType] ?? _defaultSectionIcon;

/// [lessonId]'s ordered pages — RLS (`lesson_pages_select`, 0028) already
/// scopes this to whatever the caller can see via the parent lesson; see
/// `LessonsRepository.fetchPages`'s doc comment.
final lessonPagesProvider = FutureProvider.family<List<LessonPage>, String>((ref, lessonId) {
  final LessonsRepository? repo = ref.watch(studentLessonsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchPages(lessonId);
});

/// The quiz [Lesson.linkedQuizId] (0032) points at, or null if that link
/// is absent/invisible-to-this-caller/deleted — see
/// `QuizzesRepository.fetchById`'s doc comment for why this is null-safe
/// rather than throwing. Purely a "Take Quiz" suggestion at the end of the
/// guided viewer; never a gate on anything.
final linkedQuizProvider = FutureProvider.family<Quiz?, String>((ref, quizId) {
  final QuizzesRepository? repo = ref.watch(studentQuizzesRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchById(quizId);
});

/// One section at a time, Previous/Next, with a hamburger-triggered
/// outline drawer overlaying the current slide (never navigating away
/// from it — closing the drawer always returns to the same page).
///
/// Progress semantics (per spec): the ✓/►/□ status shown in the outline
/// is derived purely from [_currentIndex] during THIS viewing session —
/// it is never persisted and always resets to page 0 on re-entry. The
/// only persisted signal is `lesson_progress` (`in_progress` on first
/// entering this screen, `completed` on reaching the final page), written
/// via [LessonProgressRepository].
class LessonViewerScreen extends ConsumerStatefulWidget {
  const LessonViewerScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends ConsumerState<LessonViewerScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  /// Guards against calling `markInProgress` more than once per screen
  /// visit — harmless either way (the repository itself is idempotent),
  /// but there is no reason to re-issue the call on every rebuild.
  bool _hasMarkedInProgress = false;

  /// Same rationale as [_hasMarkedInProgress], for `markCompleted`.
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
    final LessonProgressRepository? repo = ref.read(lessonProgressRepositoryProvider);
    if (session == null || repo == null) return;

    // Fire-and-forget: a failure here shouldn't block the student from
    // reading the lesson they already successfully loaded. Analytics-only
    // signal (schema §7.3) — never an access gate.
    repo.markInProgress(studentId: session.studentId, lessonId: widget.lesson.id);
  }

  void _markCompletedIfOnFinalPage(int index, int pageCount) {
    if (_hasMarkedCompleted) return;
    if (pageCount == 0 || index != pageCount - 1) return;
    _hasMarkedCompleted = true;

    final StudentSession? session = ref.read(studentSessionProvider);
    final LessonProgressRepository? repo = ref.read(lessonProgressRepositoryProvider);
    if (session == null || repo == null) return;

    repo.markCompleted(studentId: session.studentId, lessonId: widget.lesson.id);
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
    final AsyncValue<List<LessonPage>> pagesAsync = ref.watch(lessonPagesProvider(widget.lesson.id));

    // Trigger the two progress side effects as soon as page data is
    // available — checked directly against the already-watched value
    // (rather than via `ref.listen`, whose `fireImmediately` isn't
    // available on `WidgetRef` in this Riverpod version) and guarded by
    // the two `_hasMarked...` flags above so this is a no-op on every
    // rebuild after the first.
    final List<LessonPage>? loadedPages = pagesAsync.value;
    if (loadedPages != null && loadedPages.isNotEmpty) {
      _markInProgressOnce();
      _markCompletedIfOnFinalPage(_currentIndex, loadedPages.length);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        bottom: pagesAsync.maybeWhen(
          data: (pages) => pages.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / pages.length,
                  ),
                ),
          orElse: () => null,
        ),
      ),
      drawer: pagesAsync.maybeWhen(
        data: (pages) => pages.isEmpty
            ? null
            : _OutlineDrawer(
                pages: pages,
                currentIndex: _currentIndex,
                onSelect: (index) {
                  Navigator.of(context).pop(); // close the drawer first
                  _goToPage(index);
                },
              ),
        orElse: () => null,
      ),
      body: AppPageContainer(
        child: pagesAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load this lesson.',
            onRetry: () => ref.invalidate(lessonPagesProvider(widget.lesson.id)),
          ),
          data: (pages) {
            if (pages.isEmpty) {
              return const AppEmptyState(
                icon: Icons.menu_book_outlined,
                title: "This lesson doesn't have any content yet",
                description: 'Check back later.',
              );
            }

            return Column(
              children: <Widget>[
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                      _markCompletedIfOnFinalPage(index, pages.length);
                    },
                    itemBuilder: (context, index) => _LessonPageSlide(
                      page: pages[index],
                      trailing: (index == pages.length - 1 && widget.lesson.linkedQuizId != null)
                          ? _TakeQuizCard(quizId: widget.lesson.linkedQuizId!)
                          : null,
                    ),
                  ),
                ),
                _LessonPageFooter(
                  currentIndex: _currentIndex,
                  pageCount: pages.length,
                  onPrevious: () => _goToPage(_currentIndex - 1),
                  onNext: () => _goToPage(_currentIndex + 1),
                  onFinish: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LessonPageSlide extends StatelessWidget {
  const _LessonPageSlide({required this.page, this.trailing});

  final LessonPage page;

  /// Rendered below the page's own content — used to show [_TakeQuizCard]
  /// on the lesson's final page only; null everywhere else.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Icon(
              _iconForSectionType(page.sectionType),
              size: AppDimensions.iconExtraLarge,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(page.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          if (page.workedExample != null)
            WorkedExamplePanel(workedExample: page.workedExample!)
          else
            Text(page.body, style: Theme.of(context).textTheme.bodyLarge),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The optional "Take Quiz" suggestion shown at the end of a lesson whose
/// [Lesson.linkedQuizId] (0032) is set. Quietly renders nothing while
/// loading, on error, or if the quiz turns out to be null (not visible to
/// this student, or deleted) — this is a convenience shortcut, not
/// essential content, so it never shows an error state of its own.
class _TakeQuizCard extends ConsumerWidget {
  const _TakeQuizCard({required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Quiz?> quizAsync = ref.watch(linkedQuizProvider(quizId));

    return quizAsync.maybeWhen(
      data: (quiz) {
        if (quiz == null) return const SizedBox.shrink();
        return AppCard(
          header: const Text('Want to check your understanding?'),
          leading: const Icon(Icons.quiz_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(quiz.title, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Optional — not required to complete this lesson.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Take Quiz',
                leadingIcon: Icons.quiz_outlined,
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => QuizTakingScreen(quiz: quiz)),
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
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final int currentIndex;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final bool isFirst = currentIndex == 0;
    final bool isLast = currentIndex == pageCount - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: AppButton(
              label: 'Previous',
              variant: AppButtonVariant.outlined,
              leadingIcon: Icons.arrow_back,
              onPressed: isFirst ? null : onPrevious,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppButton(
              label: isLast ? 'Done' : 'Next',
              trailingIcon: isLast ? null : Icons.arrow_forward,
              onPressed: isLast ? onFinish : onNext,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay drawer (never a navigation away from the current slide) listing
/// every page with a ✓/►/□ status glyph derived purely from comparing that
/// page's index to [currentIndex] — session-only, never persisted, always
/// resets to page 0 on re-entry (per spec).
class _OutlineDrawer extends StatelessWidget {
  const _OutlineDrawer({
    required this.pages,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<LessonPage> pages;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Lesson Outline', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (int index = 0; index < pages.length; index++)
              ListTile(
                leading: Text(
                  index < currentIndex
                      ? '✓'
                      : index == currentIndex
                          ? '►'
                          : '□',
                ),
                title: Text(pages[index].title),
                selected: index == currentIndex,
                onTap: () => onSelect(index),
              ),
          ],
        ),
      ),
    );
  }
}
