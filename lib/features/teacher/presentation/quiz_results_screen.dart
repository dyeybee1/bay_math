import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_quiz_results_providers.dart';
import 'quiz_results_table.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

/// Teacher-facing Quiz Results screen.
///
/// Auto-selects the teacher's **first section** + **Regular Quiz** on first
/// load so data appears immediately — no "pick both" gate. The Section and
/// Assessment Type dropdowns live inside the Filters popup on
/// [QuizResultsTable]; they refine the already-visible table rather than
/// acting as a pre-load prerequisite.
class QuizResultsScreen extends ConsumerStatefulWidget {
  const QuizResultsScreen({super.key});

  @override
  ConsumerState<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends ConsumerState<QuizResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Try to auto-select on the first frame — sections may already be cached.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectSection());
  }

  /// Picks the teacher's first section (by the order mySectionsProvider
  /// returns) if no section is selected yet. Called both from [initState]
  /// (for cache hits) and via [ref.listen] below (for the async case).
  void _autoSelectSection() {
    final List<MySection>? secs = ref.read(mySectionsProvider).value;
    if (secs == null) return; // not loaded yet — listener will retry
    final TeacherQuizResultsSelection sel =
        ref.read(teacherQuizResultsSelectionProvider);
    if (sel.sectionId != null) return; // already chosen
    for (final MySection my in secs) {
      if (my.section != null) {
        ref
            .read(teacherQuizResultsSelectionProvider.notifier)
            .update((s) => s.withSectionId(my.section!.id));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retry auto-select whenever the sections list resolves.
    ref.listen<AsyncValue<List<MySection>>>(mySectionsProvider, (_, next) {
      if (next.value != null) _autoSelectSection();
    });

    final TeacherQuizResultsSelection selection =
        ref.watch(teacherQuizResultsSelectionProvider);

    return AppPageContainer(
      scrollable: true,
      child: _MatrixBody(selection: selection),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MatrixBody — renders QuizResultsTable once data arrives.
// No mandatory-selection gate: shows a loading indicator until the
// auto-selected defaults produce a matrix.
// ─────────────────────────────────────────────────────────────────────────────

class _MatrixBody extends ConsumerWidget {
  const _MatrixBody({required this.selection});

  final TeacherQuizResultsSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While selection is still being bootstrapped (sectionId not yet known),
    // the matrix provider returns null immediately — show a loading indicator
    // rather than an error or empty state.
    if (selection.sectionId == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      );
    }

    final AsyncValue<QuizResultsMatrix?> matrix =
        ref.watch(teacherQuizResultsMatrixProvider);

    return matrix.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: AppErrorState(
          message:
              error is AppFailure ? error.message : 'Could not load quiz results.',
          onRetry: () => ref.invalidate(teacherQuizResultsMatrixProvider),
        ),
      ),
      data: (QuizResultsMatrix? data) {
        // null for one tick while a selection change propagates — treat as loading.
        if (data == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          );
        }

        // Resolve display strings for the table header subtitle.
        final List<MySection> mySections =
            ref.watch(mySectionsProvider).value ?? const <MySection>[];
        MySection? chosen;
        for (final MySection my in mySections) {
          if (my.teacherSection.sectionId == selection.sectionId) {
            chosen = my;
            break;
          }
        }
        final String gradeLabel = chosen?.section?.gradeLevel.label ?? '';
        final String sectionName = chosen?.section?.name ?? '';
        final String typeLabel = selection.assessmentType?.label ?? '';
        final String subtitle = <String>[
          if (gradeLabel.isNotEmpty) gradeLabel,
          if (sectionName.isNotEmpty) sectionName,
          if (typeLabel.isNotEmpty) typeLabel,
        ].join(' · ');

        // Empty states shown *inside* the widget, not as full-screen blockers.
        // Header + stat cards (showing 0s) remain visible.
        return QuizResultsTable(
          matrix: data,
          subtitle: subtitle,
          gradeLevelLabel: gradeLabel,
          sectionName: sectionName,
          assessmentTypeLabel: typeLabel,
        );
      },
    );
  }
}
