import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_dashboard.dart';
import '../../../core/models/section.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_dashboard_providers.dart';
import 'widgets/admin_drilldown_widgets.dart';

/// All screens pushed from clickable Admin dashboard metrics. They retain the
/// original providers, aggregation rules, and navigation depth while sharing
/// one compact desktop management-list presentation.

class AdminTeachersListScreen extends ConsumerWidget {
  const AdminTeachersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminTeacherListEntry>> teachersAsync = ref.watch(
      adminTeachersListProvider,
    );
    final List<AdminTeacherListEntry>? teachers = teachersAsync.value;

    return AdminDrilldownPage(
      title: 'Teachers',
      subtitle: 'Manage teacher accounts and review their assigned sections.',
      icon: Icons.school_outlined,
      summary:
          teachers == null
              ? null
              : AdminCountPill(
                label: _countLabel(teachers.length, 'Teacher'),
                icon: Icons.people_alt_outlined,
              ),
      child: teachersAsync.when(
        loading:
            () => const _LoadingPanel(message: 'Loading teacher directory'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load the teacher list.'),
              onRetry: () => ref.invalidate(adminTeachersListProvider),
            ),
        data: (List<AdminTeacherListEntry> teachers) {
          if (teachers.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.school_outlined,
              title: 'No teachers yet',
              description:
                  'Teacher accounts will appear here once they are approved.',
            );
          }
          return AdminDrilldownPanel(
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < teachers.length;
                  index++
                ) ...<Widget>[
                  _TeacherDirectoryRow(teacher: teachers[index]),
                  if (index != teachers.length - 1) const AdminListDivider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeacherDirectoryRow extends StatelessWidget {
  const _TeacherDirectoryRow({required this.teacher});

  final AdminTeacherListEntry teacher;

  @override
  Widget build(BuildContext context) {
    final String assignmentLabel =
        '${teacher.sectionCount} assigned section${teacher.sectionCount == 1 ? '' : 's'}';
    return AdminDirectoryRow(
      key: ValueKey<String>('admin_teacher_${teacher.teacherId}'),
      leading: AdminInitialsAvatar(fullName: teacher.fullName),
      title: teacher.fullName,
      subtitle: teacher.email,
      metadata: AdminMetadataLabel(
        icon: Icons.groups_2_outlined,
        label: assignmentLabel,
      ),
      trailing: const AdminViewDetailsAffordance(),
      semanticLabel:
          '${teacher.fullName}, ${teacher.email}, $assignmentLabel. View details',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminTeacherDetailsScreen(teacher: teacher),
            ),
          ),
    );
  }
}

class AdminTeacherDetailsScreen extends ConsumerWidget {
  const AdminTeacherDetailsScreen({super.key, required this.teacher});

  final AdminTeacherListEntry teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Section>> sectionsAsync = ref.watch(
      adminTeacherSectionsProvider(teacher.teacherId),
    );
    final List<Section>? sections = sectionsAsync.value;

    return AdminDrilldownPage(
      title: 'Teacher details',
      subtitle: 'Account information and current section assignments.',
      icon: Icons.badge_outlined,
      eyebrow: 'TEACHER DIRECTORY',
      summary:
          sections == null
              ? null
              : AdminCountPill(
                label: _countLabel(sections.length, 'Section'),
                icon: Icons.groups_2_outlined,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TeacherProfilePanel(teacher: teacher),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Assigned sections',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AdultWorkspaceColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          sectionsAsync.when(
            loading:
                () => const _LoadingPanel(message: 'Loading assigned sections'),
            error:
                (Object error, StackTrace _) => _ErrorPanel(
                  message: _message(error, 'Could not load assigned sections.'),
                  onRetry:
                      () => ref.invalidate(
                        adminTeacherSectionsProvider(teacher.teacherId),
                      ),
                ),
            data: (List<Section> sections) {
              if (sections.isEmpty) {
                return const _EmptyPanel(
                  icon: Icons.group_off_outlined,
                  title: 'No assigned sections',
                  description:
                      'This teacher does not have any assigned sections.',
                );
              }
              return AdminDrilldownPanel(
                child: Column(
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < sections.length;
                      index++
                    ) ...<Widget>[
                      _SectionAssignmentRow(section: sections[index]),
                      if (index != sections.length - 1)
                        const AdminListDivider(),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeacherProfilePanel extends StatelessWidget {
  const _TeacherProfilePanel({required this.teacher});

  final AdminTeacherListEntry teacher;

  @override
  Widget build(BuildContext context) {
    return AdminDrilldownPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          AdminInitialsAvatar(
            fullName: teacher.fullName,
            size: AppComponentSize.large,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  teacher.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AdultWorkspaceColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AdminMetadataLabel(
                  icon: Icons.mail_outline_rounded,
                  label: teacher.email,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionAssignmentRow extends StatelessWidget {
  const _SectionAssignmentRow({required this.section});

  final Section section;

  @override
  Widget build(BuildContext context) {
    return AdminDirectoryRow(
      leading: AdminInitialsAvatar(
        fullName: section.name,
        icon: Icons.groups_2_outlined,
      ),
      title: section.name,
      subtitle: section.gradeLevel.label,
      metadata: AdminMetadataLabel(
        icon: Icons.calendar_today_outlined,
        label:
            section.status == SectionStatus.active
                ? 'Active section'
                : 'Archived section',
      ),
    );
  }
}

class AdminSectionsListScreen extends ConsumerWidget {
  const AdminSectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSectionListEntry>> sectionsAsync = ref.watch(
      adminSectionsListProvider,
    );
    final List<AdminSectionListEntry>? sections = sectionsAsync.value;

    return AdminDrilldownPage(
      title: 'Sections',
      subtitle: 'Review active sections, teaching assignments, and enrollment.',
      icon: Icons.groups_outlined,
      summary:
          sections == null
              ? null
              : AdminCountPill(
                label: _countLabel(sections.length, 'Section'),
                icon: Icons.groups_outlined,
              ),
      child: sectionsAsync.when(
        loading: () => const _LoadingPanel(message: 'Loading sections'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load the section list.'),
              onRetry: () => ref.invalidate(adminSectionsListProvider),
            ),
        data: (List<AdminSectionListEntry> sections) {
          if (sections.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.groups_outlined,
              title: 'No sections yet',
              description:
                  'Active sections for the current school year will appear here.',
            );
          }
          return AdminDrilldownPanel(
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < sections.length;
                  index++
                ) ...<Widget>[
                  _SectionDirectoryRow(section: sections[index]),
                  if (index != sections.length - 1) const AdminListDivider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionDirectoryRow extends StatelessWidget {
  const _SectionDirectoryRow({required this.section});

  final AdminSectionListEntry section;

  @override
  Widget build(BuildContext context) {
    return AdminDirectoryRow(
      leading: AdminInitialsAvatar(
        fullName: section.sectionName,
        icon: Icons.groups_2_outlined,
      ),
      title: section.sectionName,
      subtitle: '${section.gradeLevel.label} · ${section.primaryTeacherName}',
      metadata: AdminMetadataLabel(
        icon: Icons.people_outline_rounded,
        label: _countLabel(section.studentCount, 'Student'),
      ),
    );
  }
}

class AdminQuizAttemptsByGradeScreen extends ConsumerWidget {
  const AdminQuizAttemptsByGradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GradeQuizAttempts>> dataAsync = ref.watch(
      adminQuizAttemptsByGradeProvider,
    );
    return AdminDrilldownPage(
      title: 'Quiz attempts',
      subtitle: 'Compare completed assessment activity across grade levels.',
      icon: Icons.fact_check_outlined,
      eyebrow: 'ASSESSMENT ACTIVITY',
      child: dataAsync.when(
        loading:
            () => const _LoadingPanel(message: 'Loading quiz attempt totals'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load quiz attempt totals.'),
              onRetry: () => ref.invalidate(adminQuizAttemptsByGradeProvider),
            ),
        data:
            (List<GradeQuizAttempts> grades) =>
                _GradeAttemptsPanel(grades: grades),
      ),
    );
  }
}

class _GradeAttemptsPanel extends StatelessWidget {
  const _GradeAttemptsPanel({required this.grades});

  final List<GradeQuizAttempts> grades;

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.assignment_outlined,
        title: 'No quiz attempts yet',
        description: 'Completed quiz attempts will appear here.',
      );
    }
    return AdminDrilldownPanel(
      child: Column(
        children: <Widget>[
          for (int index = 0; index < grades.length; index++) ...<Widget>[
            AdminDirectoryRow(
              leading: AdminInitialsAvatar(
                fullName: grades[index].gradeLevel.label,
                icon: Icons.school_outlined,
              ),
              title: grades[index].gradeLevel.label,
              subtitle: 'Open the section-level activity breakdown',
              metadata: AdminMetadataLabel(
                icon: Icons.task_alt_rounded,
                label: _countLabel(
                  grades[index].totalQuizAttempts,
                  'Quiz attempt',
                ),
              ),
              trailing: const AdminViewDetailsAffordance(
                label: 'View sections',
              ),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => AdminQuizAttemptsBySectionScreen(
                            gradeLevel: grades[index].gradeLevel,
                          ),
                    ),
                  ),
            ),
            if (index != grades.length - 1) const AdminListDivider(),
          ],
        ],
      ),
    );
  }
}

class AdminQuizAttemptsBySectionScreen extends ConsumerWidget {
  const AdminQuizAttemptsBySectionScreen({super.key, required this.gradeLevel});

  final GradeLevel gradeLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SectionQuizAttempts>> dataAsync = ref.watch(
      adminQuizAttemptsBySectionProvider(gradeLevel),
    );
    final List<SectionQuizAttempts>? sections = dataAsync.value;
    return AdminDrilldownPage(
      title: '${gradeLevel.label} quiz attempts',
      subtitle: 'Completed assessment activity grouped by section.',
      icon: Icons.assignment_turned_in_outlined,
      eyebrow: 'ASSESSMENT ACTIVITY',
      summary:
          sections == null
              ? null
              : AdminCountPill(label: _countLabel(sections.length, 'Section')),
      child: dataAsync.when(
        loading: () => const _LoadingPanel(message: 'Loading section activity'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load quiz attempt totals.'),
              onRetry:
                  () => ref.invalidate(
                    adminQuizAttemptsBySectionProvider(gradeLevel),
                  ),
            ),
        data: (List<SectionQuizAttempts> sections) {
          if (sections.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.assignment_outlined,
              title: 'No sections yet',
              description:
                  'Active sections for this grade level will appear here.',
            );
          }
          return AdminDrilldownPanel(
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < sections.length;
                  index++
                ) ...<Widget>[
                  AdminDirectoryRow(
                    leading: AdminInitialsAvatar(
                      fullName: sections[index].sectionName,
                      icon: Icons.groups_2_outlined,
                    ),
                    title: sections[index].sectionName,
                    subtitle: gradeLevel.label,
                    metadata: AdminMetadataLabel(
                      icon: Icons.task_alt_rounded,
                      label: _countLabel(
                        sections[index].totalQuizAttempts,
                        'Quiz attempt',
                      ),
                    ),
                  ),
                  if (index != sections.length - 1) const AdminListDivider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminScoreByGradeScreen extends ConsumerWidget {
  const AdminScoreByGradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GradeLevelAverageScore>> dataAsync = ref.watch(
      adminScoreByGradeProvider,
    );
    return AdminDrilldownPage(
      title: 'Average mathematics score',
      subtitle: 'Review grade-level performance and open section comparisons.',
      icon: Icons.query_stats_rounded,
      eyebrow: 'PERFORMANCE',
      child: dataAsync.when(
        loading:
            () => const _LoadingPanel(message: 'Loading grade-level scores'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load grade-level averages.'),
              onRetry: () => ref.invalidate(adminScoreByGradeProvider),
            ),
        data:
            (List<GradeLevelAverageScore> grades) =>
                _GradeScoresPanel(grades: grades),
      ),
    );
  }
}

class _GradeScoresPanel extends StatelessWidget {
  const _GradeScoresPanel({required this.grades});

  final List<GradeLevelAverageScore> grades;

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.query_stats_outlined,
        title: 'No score data yet',
        description: 'Grade-level averages will appear after quiz submissions.',
      );
    }
    return AdminDrilldownPanel(
      child: Column(
        children: <Widget>[
          for (int index = 0; index < grades.length; index++) ...<Widget>[
            AdminDirectoryRow(
              leading: AdminInitialsAvatar(
                fullName: grades[index].gradeLevel.label,
                icon: Icons.school_outlined,
              ),
              title: grades[index].gradeLevel.label,
              subtitle: _countLabel(grades[index].studentCount, 'Student'),
              metadata: _ScorePill(score: grades[index].averageScore),
              trailing: const AdminViewDetailsAffordance(
                label: 'View sections',
              ),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => AdminScoreBySectionScreen(
                            gradeLevel: grades[index].gradeLevel,
                          ),
                    ),
                  ),
            ),
            if (index != grades.length - 1) const AdminListDivider(),
          ],
        ],
      ),
    );
  }
}

class AdminScoreBySectionScreen extends ConsumerWidget {
  const AdminScoreBySectionScreen({super.key, required this.gradeLevel});

  final GradeLevel gradeLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSectionAverageScore>> dataAsync = ref.watch(
      adminScoreBySectionProvider(gradeLevel),
    );
    final List<AdminSectionAverageScore>? sections = dataAsync.value;
    return AdminDrilldownPage(
      title: '${gradeLevel.label} average scores',
      subtitle: 'Mathematics performance grouped by section.',
      icon: Icons.bar_chart_rounded,
      eyebrow: 'PERFORMANCE',
      summary:
          sections == null
              ? null
              : AdminCountPill(label: _countLabel(sections.length, 'Section')),
      child: dataAsync.when(
        loading: () => const _LoadingPanel(message: 'Loading section scores'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load section averages.'),
              onRetry:
                  () => ref.invalidate(adminScoreBySectionProvider(gradeLevel)),
            ),
        data: (List<AdminSectionAverageScore> sections) {
          if (sections.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.trending_up_outlined,
              title: 'No sections yet',
              description:
                  'Active sections for this grade level will appear here.',
            );
          }
          return AdminDrilldownPanel(
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < sections.length;
                  index++
                ) ...<Widget>[
                  AdminDirectoryRow(
                    leading: AdminInitialsAvatar(
                      fullName: sections[index].sectionName,
                      icon: Icons.groups_2_outlined,
                    ),
                    title: sections[index].sectionName,
                    subtitle: _countLabel(
                      sections[index].studentCount,
                      'Student',
                    ),
                    metadata: _ScorePill(
                      score: sections[index].averageScorePercent,
                    ),
                  ),
                  if (index != sections.length - 1) const AdminListDivider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminInterventionStudentsScreen extends ConsumerWidget {
  const AdminInterventionStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminInterventionStudent>> studentsAsync = ref.watch(
      adminInterventionStudentsProvider,
    );
    final List<AdminInterventionStudent>? students = studentsAsync.value;
    return AdminDrilldownPage(
      title: 'Students requiring intervention',
      subtitle: 'Review flagged students by grade level and section.',
      icon: Icons.health_and_safety_outlined,
      eyebrow: 'LEARNING SUPPORT',
      summary:
          students == null
              ? null
              : AdminCountPill(
                label: '${students.length} Flagged',
                icon: Icons.flag_outlined,
              ),
      child: studentsAsync.when(
        loading:
            () => const _LoadingPanel(message: 'Loading intervention list'),
        error:
            (Object error, StackTrace _) => _ErrorPanel(
              message: _message(error, 'Could not load the intervention list.'),
              onRetry: () => ref.invalidate(adminInterventionStudentsProvider),
            ),
        data: (List<AdminInterventionStudent> students) {
          if (students.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.verified_outlined,
              title: 'No students flagged',
              description: 'Students needing intervention will appear here.',
            );
          }
          final Map<GradeLevel, List<AdminInterventionStudent>> byGrade =
              <GradeLevel, List<AdminInterventionStudent>>{};
          for (final AdminInterventionStudent student in students) {
            (byGrade[student.gradeLevel] ??= <AdminInterventionStudent>[]).add(
              student,
            );
          }
          final List<GradeLevel> grades =
              byGrade.keys.toList()..sort(
                (GradeLevel a, GradeLevel b) => a.index.compareTo(b.index),
              );
          return AdminDrilldownPanel(
            child: Column(
              children: <Widget>[
                for (int index = 0; index < grades.length; index++) ...<Widget>[
                  _InterventionGradeRow(
                    grade: grades[index],
                    students: byGrade[grades[index]]!,
                  ),
                  if (index != grades.length - 1) const AdminListDivider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InterventionGradeRow extends StatelessWidget {
  const _InterventionGradeRow({required this.grade, required this.students});

  final GradeLevel grade;
  final List<AdminInterventionStudent> students;

  @override
  Widget build(BuildContext context) {
    return AdminDirectoryRow(
      leading: AdminInitialsAvatar(
        fullName: grade.label,
        icon: Icons.school_outlined,
      ),
      title: grade.label,
      subtitle: 'Open the section-level intervention breakdown',
      metadata: AdminMetadataLabel(
        icon: Icons.flag_outlined,
        label:
            '${students.length} student${students.length == 1 ? '' : 's'} flagged',
        color: Theme.of(context).colorScheme.error,
      ),
      trailing: const AdminViewDetailsAffordance(label: 'View sections'),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => AdminInterventionSectionsScreen(
                    gradeLevel: grade,
                    students: students,
                  ),
            ),
          ),
    );
  }
}

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
    for (final AdminInterventionStudent student in students) {
      (bySection[student.sectionName] ??= <AdminInterventionStudent>[]).add(
        student,
      );
    }
    final List<String> sectionNames = bySection.keys.toList()..sort();

    return AdminDrilldownPage(
      title: '${gradeLevel.label} sections',
      subtitle: 'Choose a section to review students who need support.',
      icon: Icons.groups_outlined,
      eyebrow: 'LEARNING SUPPORT',
      summary: AdminCountPill(
        label: _countLabel(sectionNames.length, 'Section'),
      ),
      child: AdminDrilldownPanel(
        child: Column(
          children: <Widget>[
            for (
              int index = 0;
              index < sectionNames.length;
              index++
            ) ...<Widget>[
              AdminDirectoryRow(
                leading: AdminInitialsAvatar(
                  fullName: sectionNames[index],
                  icon: Icons.groups_2_outlined,
                ),
                title: sectionNames[index],
                subtitle: gradeLevel.label,
                metadata: AdminMetadataLabel(
                  icon: Icons.flag_outlined,
                  label:
                      '${bySection[sectionNames[index]]!.length} student'
                      '${bySection[sectionNames[index]]!.length == 1 ? '' : 's'} flagged',
                  color: Theme.of(context).colorScheme.error,
                ),
                trailing: const AdminViewDetailsAffordance(
                  label: 'View students',
                ),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => AdminInterventionStudentNamesScreen(
                              sectionName: sectionNames[index],
                              students: bySection[sectionNames[index]]!,
                            ),
                      ),
                    ),
              ),
              if (index != sectionNames.length - 1) const AdminListDivider(),
            ],
          ],
        ),
      ),
    );
  }
}

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
    return AdminDrilldownPage(
      title: sectionName,
      subtitle: 'Students currently identified for additional support.',
      icon: Icons.person_search_outlined,
      eyebrow: 'LEARNING SUPPORT',
      summary: AdminCountPill(
        label: '${students.length} Flagged',
        icon: Icons.flag_outlined,
      ),
      child: AdminDrilldownPanel(
        child: Column(
          children: <Widget>[
            for (int index = 0; index < students.length; index++) ...<Widget>[
              _InterventionStudentRow(student: students[index]),
              if (index != students.length - 1) const AdminListDivider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _InterventionStudentRow extends StatelessWidget {
  const _InterventionStudentRow({required this.student});

  final AdminInterventionStudent student;

  @override
  Widget build(BuildContext context) {
    return AdminDirectoryRow(
      leading: AdminInitialsAvatar(fullName: student.fullName),
      title: student.fullName,
      subtitle: 'Average mathematics score',
      metadata: _ScorePill(score: student.averageScorePercent),
      trailing:
          student.missedOrUnfinishedCount >= 2
              ? AppBadge(
                label: '${student.missedOrUnfinishedCount} missed/unfinished',
                variant: AppBadgeVariant.warning,
              )
              : null,
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final num? score;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AdultWorkspaceColors.softBlue,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AdultWorkspaceColors.border),
        ),
        child: Text(
          formatPercent(score),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AdultWorkspaceColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminDrilldownPanel(
      child: SizedBox(
        height: 220,
        child: AppLoadingIndicator(message: message),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminDrilldownPanel(
      child: SizedBox(
        height: 240,
        child: AppErrorState(message: message, onRetry: onRetry),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AdminDrilldownPanel(
      child: SizedBox(
        height: 240,
        child: AppEmptyState(
          icon: icon,
          title: title,
          description: description,
        ),
      ),
    );
  }
}

String _countLabel(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';

String _message(Object error, String fallback) =>
    error is AppFailure ? error.message : fallback;
