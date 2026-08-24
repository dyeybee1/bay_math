import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_dashboard.dart';
import '../../../core/models/section.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_dashboard_providers.dart';

/// Admin Dashboard tile drill-downs (0041) — five pushed screens reached
/// by tapping a summary tile on [AdminDashboardScreen]. Total Students has
/// no drill-down (out of scope, not requested); the other five each get
/// one of the three shapes below:
///   - Flat list: [AdminTeachersListScreen], [AdminSectionsListScreen] —
///     one screen, one `AsyncValue`.
///   - Two-level grade -> section: [AdminQuizAttemptsByGradeScreen] pushes
///     [AdminQuizAttemptsBySectionScreen]; [AdminScoreByGradeScreen]
///     pushes [AdminScoreBySectionScreen]. Neither level ever shows
///     per-student rows, per spec.
///   - Three-level grade -> section -> student: [AdminInterventionStudentsScreen]
///     pushes [AdminInterventionSectionsScreen] pushes
///     [AdminInterventionStudentNamesScreen] (0042) — student names are
///     only revealed at the third level, never at level 1 or 2.
///
/// Each screen owns its own [Scaffold]/[AppBar] — unlike the shell
/// destinations ([AdminDashboardScreen] itself, [SectionsScreen], etc.),
/// these are pushed on top of the shell via [Navigator.push], the same
/// "standalone pushed screen" shape [TeacherDashboardRosterScreen] uses
/// for its own drill-down, not the "no own Scaffold, shell supplies it"
/// shape the IndexedStack destinations use.

// -----------------------------------------------------------------------
// Total Teachers
// -----------------------------------------------------------------------

class AdminTeachersListScreen extends ConsumerWidget {
  const AdminTeachersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminTeacherListEntry>> teachersAsync =
        ref.watch(adminTeachersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      body: AppPageContainer(
        scrollable: true,
        child: teachersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load the teacher list.',
            onRetry: () => ref.invalidate(adminTeachersListProvider),
          ),
          data: (teachers) {
            if (teachers.isEmpty) {
              return const AppEmptyState(
                icon: Icons.school_outlined,
                title: 'No teachers yet',
                description: 'Approved teachers will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final AdminTeacherListEntry t in teachers)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(t.fullName),
                    subtitle: Text(t.email),
                    child: Text(
                      '${t.sectionCount} section${t.sectionCount == 1 ? '' : 's'}',
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

// -----------------------------------------------------------------------
// Total Sections
// -----------------------------------------------------------------------

class AdminSectionsListScreen extends ConsumerWidget {
  const AdminSectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSectionListEntry>> sectionsAsync =
        ref.watch(adminSectionsListProvider);

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
            onRetry: () => ref.invalidate(adminSectionsListProvider),
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return const AppEmptyState(
                icon: Icons.groups_outlined,
                title: 'No sections yet',
                description: 'Active sections for the current school year will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final AdminSectionListEntry s in sections)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(s.sectionName),
                    subtitle: Text('${s.gradeLevel.label} • ${s.primaryTeacherName}'),
                    child: Text(
                      '${s.studentCount} student${s.studentCount == 1 ? '' : 's'}',
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

// -----------------------------------------------------------------------
// Total Quiz Attempts — level 1 (grade) -> level 2 (section)
// -----------------------------------------------------------------------

class AdminQuizAttemptsByGradeScreen extends ConsumerWidget {
  const AdminQuizAttemptsByGradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GradeQuizAttempts>> dataAsync =
        ref.watch(adminQuizAttemptsByGradeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Attempts by Grade Level')),
      body: AppPageContainer(
        scrollable: true,
        child: dataAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load quiz attempt totals.',
            onRetry: () => ref.invalidate(adminQuizAttemptsByGradeProvider),
          ),
          data: (grades) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final GradeQuizAttempts g in grades)
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  size: AppComponentSize.small,
                  header: Text(g.gradeLevel.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminQuizAttemptsBySectionScreen(gradeLevel: g.gradeLevel),
                    ),
                  ),
                  child: Text(
                    '${g.totalQuizAttempts} quiz attempt${g.totalQuizAttempts == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminQuizAttemptsBySectionScreen extends ConsumerWidget {
  const AdminQuizAttemptsBySectionScreen({super.key, required this.gradeLevel});

  final GradeLevel gradeLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SectionQuizAttempts>> dataAsync =
        ref.watch(adminQuizAttemptsBySectionProvider(gradeLevel));

    return Scaffold(
      appBar: AppBar(title: Text('${gradeLevel.label} — Quiz Attempts by Section')),
      body: AppPageContainer(
        scrollable: true,
        child: dataAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load quiz attempt totals.',
            onRetry: () => ref.invalidate(adminQuizAttemptsBySectionProvider(gradeLevel)),
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return const AppEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No sections yet',
                description: 'Active sections for this grade level will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final SectionQuizAttempts s in sections)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(s.sectionName),
                    child: Text(
                      '${s.totalQuizAttempts} quiz attempt${s.totalQuizAttempts == 1 ? '' : 's'}',
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

// -----------------------------------------------------------------------
// Average Mathematics Score — level 1 (grade) -> level 2 (section)
// -----------------------------------------------------------------------
//
// Level 1 reuses adminScoreByGradeProvider (0039) unchanged — it already
// returns exactly the "one row per grade, average + student count" shape
// this level needs; no new provider was required for it.

class AdminScoreByGradeScreen extends ConsumerWidget {
  const AdminScoreByGradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GradeLevelAverageScore>> dataAsync =
        ref.watch(adminScoreByGradeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Average Score by Grade Level')),
      body: AppPageContainer(
        scrollable: true,
        child: dataAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load grade-level averages.',
            onRetry: () => ref.invalidate(adminScoreByGradeProvider),
          ),
          data: (grades) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final GradeLevelAverageScore g in grades)
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  size: AppComponentSize.small,
                  header: Text(g.gradeLevel.label),
                  subtitle: Text('${g.studentCount} student${g.studentCount == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminScoreBySectionScreen(gradeLevel: g.gradeLevel),
                    ),
                  ),
                  child: Text(
                    formatPercent(g.averageScore),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminScoreBySectionScreen extends ConsumerWidget {
  const AdminScoreBySectionScreen({super.key, required this.gradeLevel});

  final GradeLevel gradeLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSectionAverageScore>> dataAsync =
        ref.watch(adminScoreBySectionProvider(gradeLevel));

    return Scaffold(
      appBar: AppBar(title: Text('${gradeLevel.label} — Average Score by Section')),
      body: AppPageContainer(
        scrollable: true,
        child: dataAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load section averages.',
            onRetry: () => ref.invalidate(adminScoreBySectionProvider(gradeLevel)),
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return const AppEmptyState(
                icon: Icons.trending_up_outlined,
                title: 'No sections yet',
                description: 'Active sections for this grade level will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final AdminSectionAverageScore s in sections)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    size: AppComponentSize.small,
                    header: Text(s.sectionName),
                    subtitle: Text('${s.studentCount} student${s.studentCount == 1 ? '' : 's'}'),
                    child: Text(
                      formatPercent(s.averageScorePercent),
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

// -----------------------------------------------------------------------
// Students Requiring Intervention — three-level drill-down: Grade Level
// -> Section -> Student. Student names are never shown at level 1 or 2,
// only counts — per spec, a name is only revealed once a specific
// section has been picked. All three levels share the one
// `adminInterventionStudentsProvider` fetch (0041, grade_level added in
// 0042); levels 2 and 3 just filter/group the already-fetched list
// client-side rather than re-fetching, since the flagged list is
// typically small and level 1 already has the full list in hand.
// -----------------------------------------------------------------------

class AdminInterventionStudentsScreen extends ConsumerWidget {
  const AdminInterventionStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminInterventionStudent>> studentsAsync =
        ref.watch(adminInterventionStudentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Students Requiring Intervention')),
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
            onRetry: () => ref.invalidate(adminInterventionStudentsProvider),
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
            final Map<GradeLevel, List<AdminInterventionStudent>> byGrade =
                <GradeLevel, List<AdminInterventionStudent>>{};
            for (final AdminInterventionStudent s in students) {
              (byGrade[s.gradeLevel] ??= <AdminInterventionStudent>[]).add(s);
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
                        builder: (_) => AdminInterventionSectionsScreen(
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
class AdminInterventionSectionsScreen extends StatelessWidget {
  const AdminInterventionSectionsScreen({
    super.key,
    required this.gradeLevel,
    required this.students,
  });

  final GradeLevel gradeLevel;
  final List<AdminInterventionStudent> students;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<AdminInterventionStudent>> bySection =
        <String, List<AdminInterventionStudent>>{};
    for (final AdminInterventionStudent s in students) {
      (bySection[s.sectionName] ??= <AdminInterventionStudent>[]).add(s);
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
                    builder: (_) => AdminInterventionStudentNamesScreen(
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
/// names finally appear; same per-student card shape the old flat list
/// used (name, average score, missed/unfinished badge).
class AdminInterventionStudentNamesScreen extends StatelessWidget {
  const AdminInterventionStudentNamesScreen({
    super.key,
    required this.sectionName,
    required this.students,
  });

  final String sectionName;
  final List<AdminInterventionStudent> students;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sectionName)),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final AdminInterventionStudent s in students)
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
                  formatPercent(s.averageScorePercent),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
