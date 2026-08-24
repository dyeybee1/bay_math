import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';

/// Teacher-scoped "Students Needing Help" / "Students Requiring
/// Intervention" drill-down (0047) — three-level Grade Level -> Section ->
/// Student, the identical shape and interaction as the Admin Dashboard's
/// own intervention drill-down
/// ([AdminInterventionStudentsScreen]/[AdminInterventionSectionsScreen]/
/// [AdminInterventionStudentNamesScreen], 0041/0042), just teacher-scoped
/// data ([TeacherInterventionStudent] / [dashboardInterventionStudentsProvider]
/// instead of the admin equivalents) and pushed from two different entry
/// points: the "Students Needing Help" tile on [TeacherDashboardScreen]
/// (0037) and the "Students Requiring Intervention" tile on
/// [ProgressReportsScreen] (0046). Both entry points push the same
/// [TeacherInterventionStudentsScreen] — one shared drill-down, not two
/// near-identical copies — so a teacher sees the same grouping regardless
/// of which tile they tapped.
///
/// Student names are never shown at level 1 or 2, only counts — same
/// "reveal names only once a specific section is picked" rule the Admin
/// Dashboard's version uses, which matters even more here since a single
/// teacher can hold multiple grade levels and sections at once and this
/// grouping is precisely what keeps those students from blurring together.
/// All three levels share the one [dashboardInterventionStudentsProvider]
/// fetch; levels 2 and 3 just filter/group the already-fetched list
/// client-side rather than re-fetching.
class TeacherInterventionStudentsScreen extends ConsumerWidget {
  const TeacherInterventionStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TeacherInterventionStudent>> studentsAsync =
        ref.watch(dashboardInterventionStudentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Students Needing Intervention')),
      body: AppPageContainer(
        scrollable: true,
        child: studentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure
                ? error.message
                : 'Could not load the intervention list.',
            onRetry: () => ref.invalidate(dashboardInterventionStudentsProvider),
          ),
          data: (students) {
            if (students.isEmpty) {
              return const AppEmptyState(
                icon: Icons.report_problem_outlined,
                title: 'No students flagged',
                description: 'Students needing intervention will appear here.',
              );
            }

            // Group by grade level, preserving GradeLevel's declared
            // (grade4 -> grade5 -> grade6) order rather than whatever
            // order rows happen to arrive in.
            final Map<GradeLevel, List<TeacherInterventionStudent>> byGrade =
                <GradeLevel, List<TeacherInterventionStudent>>{};
            for (final TeacherInterventionStudent s in students) {
              (byGrade[s.gradeLevel] ??= <TeacherInterventionStudent>[]).add(s);
            }
            final List<GradeLevel> grades = byGrade.keys.toList()
              ..sort((a, b) => a.index.compareTo(b.index));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final GradeLevel grade in grades)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(grade.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TeacherInterventionSectionsScreen(
                          gradeLevel: grade,
                          students: byGrade[grade]!,
                        ),
                      ),
                    ),
                    child: Text(
                      '${byGrade[grade]!.length} student'
                      '${byGrade[grade]!.length == 1 ? '' : 's'} flagged',
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
}

/// Level 2 — sections within one grade level. Takes the already-filtered
/// student list for [gradeLevel] straight from level 1; no separate fetch.
class TeacherInterventionSectionsScreen extends StatelessWidget {
  const TeacherInterventionSectionsScreen({
    super.key,
    required this.gradeLevel,
    required this.students,
  });

  final GradeLevel gradeLevel;
  final List<TeacherInterventionStudent> students;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<TeacherInterventionStudent>> bySection =
        <String, List<TeacherInterventionStudent>>{};
    for (final TeacherInterventionStudent s in students) {
      (bySection[s.sectionName] ??= <TeacherInterventionStudent>[]).add(s);
    }
    final List<String> sectionNames = bySection.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text('${gradeLevel.label} — Sections')),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final String sectionName in sectionNames)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                size: AppComponentSize.small,
                header: Text(sectionName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeacherInterventionStudentNamesScreen(
                      sectionName: sectionName,
                      students: bySection[sectionName]!,
                    ),
                  ),
                ),
                child: Text(
                  '${bySection[sectionName]!.length} student'
                  '${bySection[sectionName]!.length == 1 ? '' : 's'} flagged',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Level 3 — the actual flagged students in one section. This is where
/// names finally appear; same per-student card shape
/// [TeacherDashboardRosterScreen] uses (name, average score,
/// missed/unfinished badge).
class TeacherInterventionStudentNamesScreen extends StatelessWidget {
  const TeacherInterventionStudentNamesScreen({
    super.key,
    required this.sectionName,
    required this.students,
  });

  final String sectionName;
  final List<TeacherInterventionStudent> students;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sectionName)),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final TeacherInterventionStudent s in students)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                size: AppComponentSize.small,
                header: Text(s.fullName),
                trailing: s.missedOrUnfinishedCount >= 2
                    ? AppBadge(
                        label: '${s.missedOrUnfinishedCount} missed/unfinished',
                        variant: AppBadgeVariant.warning,
                      )
                    : null,
                child: Text(
                  formatPercent(s.averageQuizScorePercent),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
