import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';

/// Phase 9 (Teacher Dashboard) — Part 4: the per-student roster drill-down,
/// reached by tapping any of the four summary tiles on
/// [TeacherDashboardScreen] (all four tiles open this same screen — the
/// approved design has no metric-specific filtered roster, e.g. no "only
/// students below 70%" variant).
///
/// Takes no constructor arguments, unlike `SectionWorkspaceScreen` (the
/// other pushed-detail-screen precedent in this codebase): that screen's
/// `section` argument is data with no other home, whereas the scope here
/// ([selectedGradeLevelProvider] / [selectedSectionIdProvider]) already
/// lives in global `StateProvider`s that both this screen and the
/// dashboard behind it watch directly — so the filter carries over
/// automatically on push and stays intact on pop, with nothing to thread
/// through a constructor.
class TeacherDashboardRosterScreen extends ConsumerWidget {
  const TeacherDashboardRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DashboardRosterEntry>> rosterAsync = ref.watch(dashboardRosterProvider);
    final GradeLevel? selectedGrade = ref.watch(selectedGradeLevelProvider);
    final String? selectedSectionId = ref.watch(selectedSectionIdProvider);

    final String headerText = _scopeLabel(
      selectedGrade: selectedGrade,
      selectedSectionId: selectedSectionId,
      roster: rosterAsync.value,
    );

    return Scaffold(
      appBar: AppBar(title: Text(headerText)),
      body: AppPageContainer(
        scrollable: true,
        child: rosterAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load the student roster.',
            onRetry: () => ref.invalidate(dashboardRosterProvider),
          ),
          data: (List<DashboardRosterEntry> roster) {
            if (roster.isEmpty) {
              return const AppEmptyState(
                icon: Icons.people_outline,
                title: 'No students yet',
                description: 'Students enrolled in this scope will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final DashboardRosterEntry entry in roster)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(entry.fullName),
                    subtitle: Text(entry.sectionName),
                    trailing: entry.needsIntervention
                        ? const AppBadge(label: 'Needs Help', variant: AppBadgeVariant.warning)
                        : null,
                    child: Text(
                      formatPercent(entry.averageQuizScorePercent),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Renders the current filter in plain language, e.g. "Grade 4 —
  /// Einstein", "Grade 4 — All Sections", or "All Grades — All Sections".
  /// The section's display name comes straight off the roster's own rows
  /// ([DashboardRosterEntry.sectionName]) rather than a second lookup —
  /// every in-scope row already carries it, and when [selectedSectionId]
  /// is set every row shares the same one section, so the first row's
  /// name is enough. Falls back to "Selected Section" only in the
  /// vanishingly unlikely case the roster loaded empty for a section that
  /// does still exist (e.g. filtered to a section with zero enrollments) —
  /// the loading/error states are handled separately above, so by the
  /// time this runs [roster] is either the real data or still null.
  String _scopeLabel({
    required GradeLevel? selectedGrade,
    required String? selectedSectionId,
    required List<DashboardRosterEntry>? roster,
  }) {
    final String gradePart = selectedGrade?.label ?? 'All Grades';

    if (selectedSectionId == null) {
      return '$gradePart — All Sections';
    }

    // Every row shares the same one section once `selectedSectionId` is
    // set, so the first row's own `sectionName` is enough — no second
    // lookup needed. Falls back to a generic label while loading (roster
    // still null) or in the edge case of a section with zero enrollments
    // (roster loaded but empty) — the empty/loading states themselves are
    // handled separately in the body below.
    final String sectionPart =
        (roster == null || roster.isEmpty) ? 'Selected Section' : roster.first.sectionName;
    return '$gradePart — $sectionPart';
  }
}
