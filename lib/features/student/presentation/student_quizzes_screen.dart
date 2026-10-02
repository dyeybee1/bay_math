import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_attempt.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import '../../../core/repositories/quizzes_repository.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/student_avatar.dart';
import 'quiz_results_screen.dart';
import 'quiz_taking_screen.dart';
import 'student_curriculum_order.dart';
import 'student_quiz_topic_art.dart';

/// Every quiz visible to the signed-in student — RLS
/// (`quizzes_student_select`, 0015) resolves built-in + section-assigned
/// visibility automatically; this is the same query
/// `QuizzesRepository.fetchVisibleToTeacher()` already runs for a Teacher,
/// just issued from the student-scoped client instead.
final studentVisibleQuizzesProvider = FutureProvider<List<Quiz>>((ref) {
  final QuizzesRepository? repo = ref.watch(studentQuizzesRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchVisibleToTeacher();
});

/// The student's most recent attempt for one Internal Quiz, if any — drives
/// the Start/Continue/Review label per row. Not requested for External
/// Activities (they're not attempt-tracked, per Phase 6 scope).
final studentLatestAttemptForQuizProvider =
    FutureProvider.family<QuizAttempt?, String>((ref, quizId) {
      final StudentSession? session = ref.watch(studentSessionProvider);
      final QuizAttemptsRepository? repo = ref.watch(
        quizAttemptsRepositoryProvider,
      );
      if (session == null || repo == null) {
        throw const SessionExpiredFailure();
      }
      return repo.fetchLatestForQuiz(
        studentId: session.studentId,
        quizId: quizId,
      );
    });

abstract final class _QuizCatalogPalette {
  static const Color pageBackground = Color(0xFFF4F7FD);
  static const Color blue = Color(0xFF2859DB);
  static const Color muted = Color(0xFF74819A);
}

/// Landscape-first assessment catalog for the Student tablet experience.
///
/// Quiz visibility, attempt state, refresh, and every destination remain
/// unchanged. The Student catalog applies assessment and curriculum order
/// before rendering the cards.
class StudentQuizzesScreen extends ConsumerWidget {
  const StudentQuizzesScreen({super.key});

  static const double _maxContentWidth = 1400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Quiz>> quizzesAsync = ref.watch(
      studentVisibleQuizzesProvider,
    );

    return Scaffold(
      backgroundColor: _QuizCatalogPalette.pageBackground,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _QuizCatalogBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                const _QuizCatalogHeader(),
                Expanded(
                  child: quizzesAsync.when(
                    loading:
                        () => const _QuizStateSurface(
                          child: AppLoadingIndicator(
                            message: 'Gathering your activities…',
                          ),
                        ),
                    error:
                        (Object error, StackTrace _) => _QuizStateSurface(
                          child: AppErrorState(
                            icon: Icons.cloud_off_rounded,
                            message:
                                error is AppFailure
                                    ? error.message
                                    : 'Could not load your quizzes.',
                            onRetry:
                                () => ref.invalidate(
                                  studentVisibleQuizzesProvider,
                                ),
                          ),
                        ),
                    data: (List<Quiz> quizzes) {
                      if (quizzes.isEmpty) {
                        return const _QuizStateSurface(
                          child: AppEmptyState(
                            icon: Icons.quiz_outlined,
                            title: 'No quizzes yet',
                            description:
                                'Check back once your teacher has assigned something.',
                          ),
                        );
                      }

                      final List<Quiz> orderedQuizzes = orderStudentQuizzes(
                        quizzes,
                      );

                      return RefreshIndicator(
                        onRefresh:
                            () async =>
                                ref.invalidate(studentVisibleQuizzesProvider),
                        child: _AssessmentCatalog(quizzes: orderedQuizzes),
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

class _QuizCatalogBackdrop extends StatelessWidget {
  const _QuizCatalogBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: _QuizCatalogPalette.pageBackground),
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

class _QuizCatalogHeader extends ConsumerWidget {
  const _QuizCatalogHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Student? profile = ref.watch(ownStudentProfileProvider).value;
    final GradeLevel? grade = ref.watch(ownStudentGradeLevelProvider).value;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.97),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StudentQuizzesScreen._maxContentWidth,
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
                        key: const ValueKey<String>('quizzes_back_button'),
                        tooltip: 'Back to student home',
                        onPressed: () async {
                          final bool popped =
                              await Navigator.of(context).maybePop();
                          if (!popped && context.mounted) {
                            context.go(AppRoutes.studentHome);
                          }
                        },
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
                      if (constraints.maxWidth >= 760) ...<Widget>[
                        Container(
                          width: 39,
                          height: 39,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _QuizCatalogPalette.blue,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.calculate_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'BayMath',
                          style: GoogleFonts.lexend(
                            color: _QuizCatalogPalette.blue,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          width: 1,
                          height: 34,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Quizzes & Activities',
                              style: GoogleFonts.lexend(
                                color: AppColors.textPrimary,
                                fontSize: isCompactHeight ? 21 : 23,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Practice what you've learned, one activity at a time.",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: isCompactHeight ? 11 : 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (grade != null &&
                          constraints.maxWidth >= 700) ...<Widget>[
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF3FF),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            grade.label,
                            style: GoogleFonts.inter(
                              color: _QuizCatalogPalette.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.sm),
                      StudentAvatar(
                        fullName: profile?.fullName ?? 'Student',
                        avatarId: profile?.avatarId,
                        size: 38,
                      ),
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

enum _CatalogFilter { all, quizzes, assessments, completed }

class _AssessmentCatalog extends ConsumerStatefulWidget {
  const _AssessmentCatalog({required this.quizzes});

  final List<Quiz> quizzes;

  @override
  ConsumerState<_AssessmentCatalog> createState() => _AssessmentCatalogState();
}

class _AssessmentCatalogState extends ConsumerState<_AssessmentCatalog> {
  _CatalogFilter _filter = _CatalogFilter.all;

  @override
  Widget build(BuildContext context) {
    final Map<String, AsyncValue<QuizAttempt?>> attempts =
        <String, AsyncValue<QuizAttempt?>>{};
    if (_filter == _CatalogFilter.completed) {
      for (final Quiz quiz in widget.quizzes) {
        if (quiz.quizType == QuizType.internal) {
          attempts[quiz.id] = ref.watch(
            studentLatestAttemptForQuizProvider(quiz.id),
          );
        }
      }
    }

    final bool checkingCompletion =
        _filter == _CatalogFilter.completed &&
        attempts.values.any(
          (AsyncValue<QuizAttempt?> value) => value.isLoading,
        );
    final bool completionError =
        _filter == _CatalogFilter.completed &&
        attempts.values.any((AsyncValue<QuizAttempt?> value) => value.hasError);
    final List<Quiz> visible = widget.quizzes
        .where((Quiz quiz) {
          return switch (_filter) {
            _CatalogFilter.all => true,
            _CatalogFilter.quizzes =>
              quiz.quizType == QuizType.internal && quiz.assessmentType == null,
            _CatalogFilter.assessments => quiz.assessmentType != null,
            _CatalogFilter.completed =>
              attempts[quiz.id]?.asData?.value?.isSubmitted ?? false,
          };
        })
        .toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < 1120 || constraints.maxHeight < 590;
        final bool useTwoColumns = constraints.maxWidth >= 880;
        final double horizontalPadding =
            constraints.maxWidth >= 1500
                ? AppSpacing.xl
                : constraints.maxWidth < 1120
                ? AppSpacing.md
                : AppSpacing.lg;
        final double gap = compact ? 13 : 15;
        final bool showState =
            checkingCompletion || completionError || visible.isEmpty;
        final int rowCount =
            showState
                ? 1
                : useTwoColumns
                ? (visible.length + 1) ~/ 2
                : visible.length;

        return ListView.builder(
          key: const ValueKey<String>('assessment_catalog'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 16 : 20,
            horizontalPadding,
            AppSpacing.xl,
          ),
          itemCount: rowCount + 1,
          itemBuilder: (BuildContext context, int rowIndex) {
            if (rowIndex == 0) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: StudentQuizzesScreen._maxContentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CatalogToolbar(
                      selected: _filter,
                      countLabel:
                          checkingCompletion
                              ? 'Checking completion…'
                              : completionError
                              ? 'Completion unavailable'
                              : '${visible.length} ${visible.length == 1 ? 'activity' : 'activities'}',
                      onSelected:
                          (_CatalogFilter value) =>
                              setState(() => _filter = value),
                    ),
                  ),
                ),
              );
            }

            if (showState) {
              return SizedBox(
                height: 210,
                child:
                    checkingCompletion
                        ? const _QuizStateSurface(
                          child: AppLoadingIndicator(
                            message: 'Checking completed activities…',
                          ),
                        )
                        : completionError
                        ? _QuizStateSurface(
                          child: AppErrorState(
                            icon: Icons.cloud_off_rounded,
                            message: 'Could not check completed activities.',
                            onRetry: () {
                              for (final Quiz quiz in widget.quizzes) {
                                if (attempts[quiz.id]?.hasError ?? false) {
                                  ref.invalidate(
                                    studentLatestAttemptForQuizProvider(
                                      quiz.id,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        )
                        : _QuizStateSurface(
                          child: AppEmptyState(
                            icon:
                                _filter == _CatalogFilter.completed
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.filter_alt_off_outlined,
                            title:
                                _filter == _CatalogFilter.completed
                                    ? 'No completed activities yet'
                                    : 'No activities in this view',
                            description:
                                _filter == _CatalogFilter.completed
                                    ? 'Completed quizzes will appear here.'
                                    : 'Choose another filter to see more activities.',
                          ),
                        ),
              );
            }

            final int quizIndex =
                useTwoColumns ? (rowIndex - 1) * 2 : rowIndex - 1;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StudentQuizzesScreen._maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: rowIndex == rowCount ? 0 : gap,
                  ),
                  child: _CardEnter(
                    index: rowIndex - 1,
                    child:
                        useTwoColumns
                            ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: _AssessmentTile(
                                    key: ValueKey<String>(
                                      'assessment_card_${visible[quizIndex].id}',
                                    ),
                                    quiz: visible[quizIndex],
                                    compact: compact,
                                  ),
                                ),
                                SizedBox(width: gap),
                                Expanded(
                                  child:
                                      quizIndex + 1 < visible.length
                                          ? _AssessmentTile(
                                            key: ValueKey<String>(
                                              'assessment_card_${visible[quizIndex + 1].id}',
                                            ),
                                            quiz: visible[quizIndex + 1],
                                            compact: compact,
                                          )
                                          : const SizedBox.shrink(),
                                ),
                              ],
                            )
                            : _AssessmentTile(
                              key: ValueKey<String>(
                                'assessment_card_${visible[quizIndex].id}',
                              ),
                              quiz: visible[quizIndex],
                              compact: compact,
                            ),
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

class _CatalogToolbar extends StatelessWidget {
  const _CatalogToolbar({
    required this.selected,
    required this.countLabel,
    required this.onSelected,
  });

  final _CatalogFilter selected;
  final String countLabel;
  final ValueChanged<_CatalogFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ASSESSMENT CATALOG',
          style: GoogleFonts.inter(
            color: const Color(0xFF6A80A8),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          countLabel,
          key: const ValueKey<String>('assessment_visible_count'),
          style: GoogleFonts.inter(
            color: _QuizCatalogPalette.muted,
            fontSize: 11,
          ),
        ),
      ],
    );
    final Widget filters = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: <Widget>[
          for (final _CatalogFilter filter in _CatalogFilter.values)
            _CatalogFilterButton(
              filter: filter,
              selected: selected == filter,
              onPressed: () => onSelected(filter),
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder:
          (BuildContext context, BoxConstraints constraints) =>
              constraints.maxWidth >= 760
                  ? Row(children: <Widget>[Expanded(child: heading), filters])
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      heading,
                      const SizedBox(height: 12),
                      filters,
                    ],
                  ),
    );
  }
}

class _CatalogFilterButton extends StatelessWidget {
  const _CatalogFilterButton({
    required this.filter,
    required this.selected,
    required this.onPressed,
  });

  final _CatalogFilter filter;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label = switch (filter) {
      _CatalogFilter.all => 'All activities',
      _CatalogFilter.quizzes => 'Quizzes',
      _CatalogFilter.assessments => 'Assessments',
      _CatalogFilter.completed => 'Completed',
    };
    return Semantics(
      selected: selected,
      button: true,
      child: TextButton(
        key: ValueKey<String>('assessment_filter_${filter.name}'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor:
              selected ? _QuizCatalogPalette.blue : const Color(0xFF6C7F9D),
          backgroundColor: selected ? Colors.white : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _CardEnter extends StatelessWidget {
  const _CardEnter({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 230 + (index.clamp(0, 6) * 30)),
      curve: Curves.easeOutCubic,
      builder:
          (BuildContext context, double progress, Widget? animatedChild) =>
              Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 7),
                  child: animatedChild,
                ),
              ),
      child: child,
    );
  }
}

class _AssessmentTile extends ConsumerWidget {
  const _AssessmentTile({super.key, required this.quiz, required this.compact});

  final Quiz quiz;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _AssessmentPresentation presentation =
        _AssessmentPresentation.forQuiz(quiz);

    if (quiz.quizType == QuizType.externalActivity) {
      return _ExternalActivityCard(
        quiz: quiz,
        presentation: presentation,
        compact: compact,
      );
    }

    return _InternalAssessmentCard(
      quiz: quiz,
      presentation: presentation,
      compact: compact,
    );
  }
}

class _InternalAssessmentCard extends ConsumerWidget {
  const _InternalAssessmentCard({
    required this.quiz,
    required this.presentation,
    required this.compact,
  });

  final Quiz quiz;
  final _AssessmentPresentation presentation;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<QuizAttempt?> attemptAsync = ref.watch(
      studentLatestAttemptForQuizProvider(quiz.id),
    );
    final AsyncData<QuizAttempt?>? attemptData = attemptAsync.asData;
    final QuizAttempt? currentAttempt = attemptData?.value;
    final _AssessmentStatus? status =
        attemptData == null
            ? null
            : currentAttempt == null
            ? _AssessmentStatus.notStarted
            : currentAttempt.isSubmitted
            ? _AssessmentStatus.completed
            : currentAttempt.attemptStatus == QuizAttemptStatus.active
            ? _AssessmentStatus.inProgress
            : null;

    return _AssessmentCardSurface(
      quiz: quiz,
      presentation: presentation,
      compact: compact,
      status: status,
      action: attemptAsync.when(
        loading:
            () => _AssessmentActionLoading(
              accentColor: presentation.color,
              compact: compact,
            ),
        error:
            (Object _, StackTrace _) => _CatalogActionButton(
              key: ValueKey<String>('assessment_retry_${quiz.id}'),
              label: 'Retry',
              icon: Icons.refresh_rounded,
              leadingIcon: true,
              isAssessment: quiz.assessmentType != null,
              onPressed:
                  () => ref.invalidate(
                    studentLatestAttemptForQuizProvider(quiz.id),
                  ),
            ),
        data: (QuizAttempt? attempt) {
          final bool isSubmitted = attempt?.isSubmitted ?? false;
          final bool isActiveUnsubmitted =
              attempt != null &&
              !isSubmitted &&
              attempt.attemptStatus == QuizAttemptStatus.active;

          final String label =
              attempt == null
                  ? 'Start'
                  : isSubmitted
                  ? 'Review'
                  : isActiveUnsubmitted
                  ? 'Continue'
                  : 'Start';

          return _CatalogActionButton(
            key: ValueKey<String>('assessment_action_${quiz.id}'),
            label: label,
            icon:
                isSubmitted
                    ? Icons.visibility_rounded
                    : Icons.arrow_forward_rounded,
            isAssessment: quiz.assessmentType != null,
            semanticLabel: '$label ${quiz.title}',
            onPressed: () {
              if (isSubmitted) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => QuizResultsScreen(
                          quiz: quiz,
                          attemptId: attempt!.id,
                        ),
                  ),
                );
              } else {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => QuizTakingScreen(quiz: quiz),
                      ),
                    )
                    .then(
                      (_) => ref.invalidate(
                        studentLatestAttemptForQuizProvider(quiz.id),
                      ),
                    );
              }
            },
          );
        },
      ),
    );
  }
}

class _ExternalActivityCard extends StatelessWidget {
  const _ExternalActivityCard({
    required this.quiz,
    required this.presentation,
    required this.compact,
  });

  final Quiz quiz;
  final _AssessmentPresentation presentation;
  final bool compact;

  Future<void> _openActivity(BuildContext context) async {
    if (quiz.externalUrl == null) return;

    final Uri uri = Uri.parse(quiz.externalUrl!);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this activity.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AssessmentCardSurface(
      quiz: quiz,
      presentation: presentation,
      compact: compact,
      supportingLabel: quiz.externalPlatformHint?.label ?? 'External Activity',
      onTap: quiz.externalUrl == null ? null : () => _openActivity(context),
      action: _CatalogActionButton(
        key: ValueKey<String>('assessment_action_${quiz.id}'),
        label: 'Open',
        icon: Icons.open_in_new_rounded,
        isAssessment: false,
        semanticLabel: 'Open ${quiz.title}',
        onPressed:
            quiz.externalUrl == null ? null : () => _openActivity(context),
      ),
    );
  }
}

class _CatalogActionButton extends StatelessWidget {
  const _CatalogActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isAssessment,
    required this.onPressed,
    this.leadingIcon = false,
    this.semanticLabel,
  });

  static const Color _assessmentBackground = Color(0xFF2859DB);
  static const Color _quizBackground = Color(0xFFEEF3FF);
  static const Color _quizForeground = Color(0xFF3F65B9);

  final String label;
  final IconData icon;
  final bool isAssessment;
  final VoidCallback? onPressed;
  final bool leadingIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color background =
        isAssessment ? _assessmentBackground : _quizBackground;
    final Color foreground = isAssessment ? Colors.white : _quizForeground;
    final Widget actionIcon = Icon(icon, size: 18);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isAssessment && onPressed != null
                  ? const <BoxShadow>[
                    BoxShadow(color: Color(0xFF1E46B5), offset: Offset(0, 3)),
                  ]
                  : null,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background.withValues(alpha: 0.6),
            disabledForegroundColor: foreground.withValues(alpha: 0.7),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leadingIcon) ...<Widget>[
                actionIcon,
                const SizedBox(width: 10),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (!leadingIcon) ...<Widget>[
                const SizedBox(width: 10),
                actionIcon,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _AssessmentStatus { notStarted, inProgress, completed }

class _AssessmentStatusBadge extends StatelessWidget {
  const _AssessmentStatusBadge(this.status);

  final _AssessmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (
      String label,
      Color foreground,
      Color background,
      IconData? icon,
    ) = switch (status) {
      _AssessmentStatus.notStarted => (
        'Not started',
        const Color(0xFF73819A),
        const Color(0xFFF0F3F8),
        null,
      ),
      _AssessmentStatus.inProgress => (
        'In progress',
        const Color(0xFFA17B33),
        const Color(0xFFFFF4D9),
        Icons.timelapse_rounded,
      ),
      _AssessmentStatus.completed => (
        'Completed',
        const Color(0xFF468968),
        const Color(0xFFE8F6ED),
        Icons.check_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCardSurface extends StatefulWidget {
  const _AssessmentCardSurface({
    required this.quiz,
    required this.presentation,
    required this.compact,
    required this.action,
    this.status,
    this.supportingLabel,
    this.onTap,
  });

  final Quiz quiz;
  final _AssessmentPresentation presentation;
  final bool compact;
  final Widget action;
  final _AssessmentStatus? status;
  final String? supportingLabel;
  final VoidCallback? onTap;

  @override
  State<_AssessmentCardSurface> createState() => _AssessmentCardSurfaceState();
}

class _AssessmentCardSurfaceState extends State<_AssessmentCardSurface> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isEmphasized => _isHovered || _isFocused || _isPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _AssessmentPresentation presentation = widget.presentation;
    final BorderRadius borderRadius = BorderRadius.circular(20);

    final Widget content = Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            widget.quiz.assessmentType == null
                ? colorScheme.surface
                : presentation.spec.tint.withValues(alpha: 0.77),
            colorScheme.surface,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < 440;
          final Widget action = ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.compact ? 83 : 104),
            child: widget.action,
          );
          final Widget artAndTitle = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              QuizTopicArt(spec: presentation.spec, compact: widget.compact),
              SizedBox(width: widget.compact ? 10 : 15),
              Expanded(
                child: _AssessmentCardInfo(
                  quiz: widget.quiz,
                  presentation: presentation,
                  compact: widget.compact,
                  status: widget.status,
                  supportingLabel: widget.supportingLabel,
                ),
              ),
              if (!narrow) ...<Widget>[
                SizedBox(width: widget.compact ? 9 : 12),
                action,
              ],
            ],
          );
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  widget.compact
                      ? widget.quiz.assessmentType == null
                          ? 125
                          : 130
                      : 142,
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 12 : 16,
                    vertical: widget.compact ? 14 : 16,
                  ),
                  child:
                      narrow
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              artAndTitle,
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: action,
                              ),
                            ],
                          )
                          : artAndTitle,
                ),
                if (widget.status == _AssessmentStatus.completed)
                  const Positioned(
                    left: 24,
                    right: 24,
                    bottom: 0,
                    child: SizedBox(
                      height: 3,
                      child: ColoredBox(color: Color(0xFF8BC9A4)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label:
          widget.onTap == null
              ? null
              : '${presentation.label}. ${widget.quiz.title}. Open activity.',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.99 : 1,
          duration:
              MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: borderRadius,
              border: Border.all(
                color:
                    _isEmphasized
                        ? presentation.color.withValues(alpha: 0.5)
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
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child:
                  widget.onTap == null
                      ? content
                      : InkWell(
                        onTap: widget.onTap,
                        onFocusChange:
                            (bool value) => setState(() => _isFocused = value),
                        onHighlightChanged:
                            (bool value) => setState(() => _isPressed = value),
                        focusColor: presentation.spec.tint.withValues(
                          alpha: 0.35,
                        ),
                        hoverColor: presentation.spec.tint.withValues(
                          alpha: 0.2,
                        ),
                        splashColor: presentation.color.withValues(alpha: 0.12),
                        child: content,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssessmentCardInfo extends StatelessWidget {
  const _AssessmentCardInfo({
    required this.quiz,
    required this.presentation,
    required this.compact,
    required this.status,
    required this.supportingLabel,
  });

  final Quiz quiz;
  final _AssessmentPresentation presentation;
  final bool compact;
  final _AssessmentStatus? status;
  final String? supportingLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          presentation.label,
          style: GoogleFonts.inter(
            color: presentation.color,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          quiz.title,
          style: GoogleFonts.lexend(
            color: AppColors.textPrimary,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (status != null) ...<Widget>[
          const SizedBox(height: 8),
          _AssessmentStatusBadge(status!),
        ],
        if (supportingLabel != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            supportingLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _AssessmentActionLoading extends StatelessWidget {
  const _AssessmentActionLoading({
    required this.accentColor,
    required this.compact,
  });

  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading assessment action',
      child: Container(
        height: 48,
        width: compact ? 104 : 112,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssessmentPresentation {
  const _AssessmentPresentation({required this.label, required this.spec});

  final String label;
  final QuizTopicArtSpec spec;
  Color get color => spec.accent;

  factory _AssessmentPresentation.forQuiz(Quiz quiz) {
    final QuizTopicArtSpec spec = QuizTopicArtSpec.forQuiz(quiz);
    if (quiz.quizType == QuizType.externalActivity) {
      return _AssessmentPresentation(label: 'EXTERNAL ACTIVITY', spec: spec);
    }

    if (quiz.assessmentType == AssessmentType.preTest) {
      return _AssessmentPresentation(label: 'PRE-TEST', spec: spec);
    }
    if (quiz.assessmentType == AssessmentType.postTest) {
      return _AssessmentPresentation(label: 'POST-TEST', spec: spec);
    }
    final RegExpMatch? numbered = RegExp(
      r'^Quiz\s+(\d+)\s*:',
      caseSensitive: false,
    ).firstMatch(quiz.title.trim());
    return _AssessmentPresentation(
      label: numbered == null ? 'QUIZ' : 'QUIZ ${numbered.group(1)}',
      spec: spec,
    );
  }
}

class _QuizStateSurface extends StatelessWidget {
  const _QuizStateSurface({required this.child});

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
