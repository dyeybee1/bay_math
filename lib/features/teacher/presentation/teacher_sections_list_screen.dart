import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';

/// Teacher Dashboard "Total Sections" tile drill-down (0048) — a flat list
/// of the calling teacher's own sections (e.g. "4-A", "4-B"), sections
/// only, no per-student rows. Mirrors [AdminSectionsListScreen]'s shape
/// (`admin_dashboard_drilldown_screens.dart`) — same "flat list, one
/// `AsyncValue`" screen, just teacher-scoped.
///
/// No new fetch/provider was needed: [dashboardAverageScoreBySectionProvider]
/// (0037 Function 2) already returns exactly this — one [SectionAverageScore]
/// row per section the teacher is assigned to, complete with
/// [SectionAverageScore.studentCount] — it's the same data already backing
/// the "Average per Section" chart on this dashboard, just rendered as a
/// list here instead of bars. Reusing it keeps "Total Sections" (the tile)
/// and this list in obvious agreement, and avoids a second RPC for data
/// that already exists.
class TeacherSectionsListScreen extends ConsumerWidget {
  const TeacherSectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SectionAverageScore>> sectionsAsync =
        ref.watch(dashboardAverageScoreBySectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sections')),
      body: AppPageContainer(
        scrollable: true,
        child: sectionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load the section list.',
            onRetry: () => ref.invalidate(dashboardAverageScoreBySectionProvider),
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return const AppEmptyState(
                icon: Icons.groups_outlined,
                title: 'No sections yet',
                description: 'Sections you are assigned to will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final SectionAverageScore s in sections)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(s.sectionName),
                    subtitle: Text(s.gradeLevel.label),
                    child: Text(
                      '${s.studentCount} student${s.studentCount == 1 ? '' : 's'} • '
                      '${formatPercent(s.averageQuizScorePercent)} avg',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
