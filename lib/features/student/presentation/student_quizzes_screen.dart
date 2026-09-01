import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_attempt.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import '../../../core/repositories/quizzes_repository.dart';
import '../../../core/widgets/widgets.dart';
import 'quiz_results_screen.dart';
import 'quiz_taking_screen.dart';

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
/// the Start/Resume/Review label per row. Not requested for External
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
  static const Color pageBackground = Color(0xFFF3F7FC);
  static const Color assessment = Color(0xFF705CA3);
  static const Color assessmentContainer = Color(0xFFEDE8F7);
  static const Color activity = Color(0xFF39735B);
  static const Color activityContainer = Color(0xFFE1F0E8);
}

/// Landscape-first assessment catalog for the Student tablet experience.
///
/// Quiz visibility, ordering, attempt state, refresh, and every destination
/// remain unchanged; this screen only reshapes their presentation.
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

                      return RefreshIndicator(
                        onRefresh:
                            () async =>
                                ref.invalidate(studentVisibleQuizzesProvider),
                        child: _AssessmentCatalog(quizzes: quizzes),
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

class _QuizCatalogHeader extends StatelessWidget {
  const _QuizCatalogHeader();

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
                          color: _QuizCatalogPalette.assessmentContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.fact_check_rounded,
                          color: _QuizCatalogPalette.assessment,
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
                              'Quizzes & Activities',
                              style: GoogleFonts.lexend(
                                color: AppColors.textPrimary,
                                fontSize: isCompactHeight ? 22 : 24,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Practice what you've learned and take your assessments.",
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
                      if (constraints.maxWidth >= 900) ...<Widget>[
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
                                Icons.bolt_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'BAYMATH PRACTICE',
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

class _AssessmentCatalog extends StatelessWidget {
  const _AssessmentCatalog({required this.quizzes});

  final List<Quiz> quizzes;

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
        final double gap = isShort ? 12 : AppSpacing.md;
        final int rowCount =
            useTwoColumns ? (quizzes.length + 1) ~/ 2 : quizzes.length;

        return ListView.builder(
          key: const ValueKey<String>('assessment_catalog'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isShort ? 12 : AppSpacing.md,
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
                      maxWidth: StudentQuizzesScreen._maxContentWidth,
                    ),
                    child: _AssessmentCatalogIntro(itemCount: quizzes.length),
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
                  child:
                      useTwoColumns
                          ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Expanded(
                                  child: _AssessmentTile(
                                    key: ValueKey<String>(
                                      'assessment_card_${quizzes[quizIndex].id}',
                                    ),
                                    quiz: quizzes[quizIndex],
                                    compact: isShort,
                                  ),
                                ),
                                SizedBox(width: gap),
                                Expanded(
                                  child:
                                      quizIndex + 1 < quizzes.length
                                          ? _AssessmentTile(
                                            key: ValueKey<String>(
                                              'assessment_card_${quizzes[quizIndex + 1].id}',
                                            ),
                                            quiz: quizzes[quizIndex + 1],
                                            compact: isShort,
                                          )
                                          : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          )
                          : _AssessmentTile(
                            key: ValueKey<String>(
                              'assessment_card_${quizzes[quizIndex].id}',
                            ),
                            quiz: quizzes[quizIndex],
                            compact: isShort,
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

class _AssessmentCatalogIntro extends StatelessWidget {
  const _AssessmentCatalogIntro({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Text(
          'ASSESSMENT CATALOG',
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
          '$itemCount ${itemCount == 1 ? 'activity' : 'activities'}',
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

    return _AssessmentCardSurface(
      quiz: quiz,
      presentation: presentation,
      compact: compact,
      action: attemptAsync.when(
        loading:
            () => _AssessmentActionLoading(
              accentColor: presentation.color,
              compact: compact,
            ),
        error:
            (Object _, StackTrace _) => AppButton(
              key: ValueKey<String>('assessment_retry_${quiz.id}'),
              label: 'Retry',
              size: AppComponentSize.large,
              variant: AppButtonVariant.outlined,
              leadingIcon: Icons.refresh_rounded,
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
                  ? 'Resume'
                  : 'Start';

          return AppButton(
            key: ValueKey<String>('assessment_action_${quiz.id}'),
            label: label,
            size: AppComponentSize.large,
            variant:
                isSubmitted
                    ? AppButtonVariant.outlined
                    : AppButtonVariant.primary,
            trailingIcon:
                isSubmitted
                    ? Icons.visibility_rounded
                    : Icons.arrow_forward_rounded,
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
      action: _ExternalActionCue(
        enabled: quiz.externalUrl != null,
        color: presentation.color,
        containerColor: presentation.containerColor,
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
    this.supportingLabel,
    this.onTap,
  });

  final Quiz quiz;
  final _AssessmentPresentation presentation;
  final bool compact;
  final Widget action;
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
            colorScheme.surface,
            presentation.containerColor.withValues(alpha: 0.2),
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
                color: presentation.color,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(widget.compact ? 14 : AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _AssessmentIconTile(
                  presentation: presentation,
                  compact: widget.compact,
                ),
                SizedBox(width: widget.compact ? 12 : AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        presentation.label,
                        style: GoogleFonts.inter(
                          color: presentation.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.quiz.title,
                        style: GoogleFonts.lexend(
                          color: AppColors.textPrimary,
                          fontSize: widget.compact ? 16 : 17,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (widget.supportingLabel != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          widget.supportingLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: widget.compact ? 12.5 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: widget.compact ? 10 : AppSpacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.compact ? 104 : 112,
                  ),
                  child: widget.action,
                ),
              ],
            ),
          ),
        ],
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
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
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
                        focusColor: presentation.containerColor.withValues(
                          alpha: 0.35,
                        ),
                        hoverColor: presentation.containerColor.withValues(
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

class _AssessmentIconTile extends StatelessWidget {
  const _AssessmentIconTile({
    required this.presentation,
    required this.compact,
  });

  final _AssessmentPresentation presentation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 50 : 54;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: presentation.containerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        presentation.icon,
        color: presentation.color,
        size: compact ? 25 : 27,
      ),
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

class _ExternalActionCue extends StatelessWidget {
  const _ExternalActionCue({
    required this.enabled,
    required this.color,
    required this.containerColor,
  });

  final bool enabled;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor =
        enabled ? color : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color:
            enabled
                ? containerColor
                : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Open',
            style: GoogleFonts.inter(
              color: effectiveColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.open_in_new_rounded, color: effectiveColor, size: 19),
        ],
      ),
    );
  }
}

class _AssessmentPresentation {
  const _AssessmentPresentation({
    required this.label,
    required this.icon,
    required this.color,
    required this.containerColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color containerColor;

  factory _AssessmentPresentation.forQuiz(Quiz quiz) {
    if (quiz.quizType == QuizType.externalActivity) {
      return const _AssessmentPresentation(
        label: 'EXTERNAL ACTIVITY',
        icon: Icons.launch_rounded,
        color: _QuizCatalogPalette.activity,
        containerColor: _QuizCatalogPalette.activityContainer,
      );
    }

    return switch (quiz.assessmentType) {
      AssessmentType.preTest => const _AssessmentPresentation(
        label: 'PRE-TEST',
        icon: Icons.flag_outlined,
        color: _QuizCatalogPalette.assessment,
        containerColor: _QuizCatalogPalette.assessmentContainer,
      ),
      AssessmentType.postTest => const _AssessmentPresentation(
        label: 'POST-TEST',
        icon: Icons.workspace_premium_outlined,
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
      ),
      null => const _AssessmentPresentation(
        label: 'QUIZ',
        icon: Icons.quiz_rounded,
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
      ),
    };
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
