import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';
import '../widgets/teacher_drilldown_widgets.dart';

/// Grade-level entry point for the Teacher intervention drill-down.
class TeacherInterventionStudentsScreen extends ConsumerWidget {
  const TeacherInterventionStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TeacherInterventionStudent>> studentsAsync = ref
        .watch(dashboardInterventionStudentsProvider);

    return TeacherDrilldownPage(
      title: 'Students Needing Intervention',
      subtitle: 'Students who may need additional support',
      child: studentsAsync.when(
        loading:
            () => const TeacherStatePanel(
              child: AppLoadingIndicator(
                message: 'Loading intervention overview…',
              ),
            ),
        error:
            (Object error, StackTrace _) => TeacherStatePanel(
              child: AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not load the intervention list.',
                onRetry:
                    () => ref.invalidate(dashboardInterventionStudentsProvider),
              ),
            ),
        data: (List<TeacherInterventionStudent> students) {
          if (students.isEmpty) {
            return const TeacherStatePanel(
              child: AppEmptyState(
                icon: Icons.verified_outlined,
                title: 'No students need intervention',
                description: 'All students are currently on track.',
              ),
            );
          }

          final Map<GradeLevel, List<TeacherInterventionStudent>> byGrade =
              _groupByGrade(students);
          final List<GradeLevel> grades =
              byGrade.keys.toList()..sort(
                (GradeLevel a, GradeLevel b) => a.index.compareTo(b.index),
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TeacherListSummary(
                icon: Icons.support_outlined,
                title:
                    '${students.length} student${students.length == 1 ? '' : 's'} may need support',
                description:
                    'Grouped by grade so you can focus on one class at a time.',
                badge: const AppBadge(
                  label: 'Review suggested',
                  variant: AppBadgeVariant.warning,
                  icon: Icons.flag_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TeacherResponsiveGrid(
                children: <Widget>[
                  for (final GradeLevel grade in grades)
                    _InterventionGroupCard(
                      title: grade.label,
                      count: byGrade[grade]!.length,
                      icon: Icons.school_outlined,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => TeacherInterventionSectionsScreen(
                                    gradeLevel: grade,
                                    students: byGrade[grade]!,
                                  ),
                            ),
                          ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Section groups within one grade level.
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
    for (final TeacherInterventionStudent student in students) {
      (bySection[student.sectionName] ??= <TeacherInterventionStudent>[]).add(
        student,
      );
    }
    final List<String> sectionNames = bySection.keys.toList()..sort();

    return TeacherDrilldownPage(
      title: gradeLevel.label,
      subtitle: 'Choose a section to review students needing support',
      child:
          students.isEmpty
              ? const TeacherStatePanel(
                child: AppEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No students need intervention',
                  description:
                      'All students in this grade are currently on track.',
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TeacherListSummary(
                    icon: Icons.school_outlined,
                    title:
                        '${students.length} student${students.length == 1 ? '' : 's'} across ${sectionNames.length} section${sectionNames.length == 1 ? '' : 's'}',
                    description:
                        'Select a section to see the students and available support indicators.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TeacherResponsiveGrid(
                    children: <Widget>[
                      for (final String sectionName in sectionNames)
                        _InterventionGroupCard(
                          title: _sectionLabel(sectionName),
                          count: bySection[sectionName]!.length,
                          icon: Icons.groups_2_outlined,
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) =>
                                          TeacherInterventionStudentNamesScreen(
                                            sectionName: sectionName,
                                            students: bySection[sectionName]!,
                                          ),
                                ),
                              ),
                        ),
                    ],
                  ),
                ],
              ),
    );
  }
}

/// Actual students requiring support in a selected section.
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
    final String gradeLabel =
        students.isEmpty ? 'Selected grade' : students.first.gradeLevel.label;

    return TeacherDrilldownPage(
      title: _sectionLabel(sectionName),
      subtitle:
          '$gradeLabel • ${students.length} student${students.length == 1 ? '' : 's'} may need support',
      child:
          students.isEmpty
              ? const TeacherStatePanel(
                child: AppEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No students need intervention',
                  description:
                      'All students in this section are currently on track.',
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TeacherListSummary(
                    icon: Icons.person_search_outlined,
                    title:
                        '${students.length} student${students.length == 1 ? '' : 's'} need${students.length == 1 ? 's' : ''} attention',
                    description:
                        'Review the available indicators below and plan the next support step.',
                    badge: const AppBadge(
                      label: 'Needs attention',
                      variant: AppBadgeVariant.warning,
                      icon: Icons.flag_outlined,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (
                    int index = 0;
                    index < students.length;
                    index++
                  ) ...<Widget>[
                    _InterventionStudentCard(student: students[index]),
                    if (index != students.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
    );
  }
}

class _InterventionGroupCard extends StatelessWidget {
  const _InterventionGroupCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TeacherDrilldownCard(
      onTap: onTap,
      semanticLabel:
          '$title, $count student${count == 1 ? '' : 's'} need attention',
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Icon(icon, color: AppColors.amber, size: 23),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.lexend(
                    size: 17,
                    weight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$count student${count == 1 ? '' : 's'} '
                  '${count == 1 ? 'needs' : 'need'} attention',
                  style: AppTextStyles.inter(
                    size: 12,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSoft),
        ],
      ),
    );
  }
}

class _InterventionStudentCard extends StatelessWidget {
  const _InterventionStudentCard({required this.student});

  final TeacherInterventionStudent student;

  @override
  Widget build(BuildContext context) {
    final List<String> reasons = <String>[
      if (student.averageQuizScorePercent case final num average
          when average < 70)
        'Average score is below 70%',
      if (student.missedOrUnfinishedCount >= 2)
        '${student.missedOrUnfinishedCount} missed or unfinished quizzes',
    ];

    return TeacherDrilldownCard(
      semanticLabel: '${student.fullName}, needs attention',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppAvatar(
                initials: _initials(student.fullName),
                semanticLabel: '${student.fullName} avatar',
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.lexend(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${student.gradeLevel.label} • ${_sectionLabel(student.sectionName)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        size: 12,
                        color: AppColors.textSoft,
                      ),
                    ),
                    if (reasons.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Needs support in:',
                        style: AppTextStyles.inter(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final String reason in reasons.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Icon(
                                  Icons.circle,
                                  size: 5,
                                  color: AppColors.amber,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: AppTextStyles.inter(
                                    size: 12,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final Widget status = Column(
            crossAxisAlignment:
                constraints.maxWidth < 680
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppBadge(
                label: 'Needs attention',
                variant: AppBadgeVariant.warning,
                icon: Icons.flag_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                student.averageQuizScorePercent == null
                    ? 'No completed assessments'
                    : 'Average ${formatPercent(student.averageQuizScorePercent)}',
                style: AppTextStyles.inter(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identity,
                const SizedBox(height: AppSpacing.md),
                status,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.lg),
              status,
            ],
          );
        },
      ),
    );
  }
}

Map<GradeLevel, List<TeacherInterventionStudent>> _groupByGrade(
  List<TeacherInterventionStudent> students,
) {
  final Map<GradeLevel, List<TeacherInterventionStudent>> grouped =
      <GradeLevel, List<TeacherInterventionStudent>>{};
  for (final TeacherInterventionStudent student in students) {
    (grouped[student.gradeLevel] ??= <TeacherInterventionStudent>[]).add(
      student,
    );
  }
  return grouped;
}

String _sectionLabel(String name) {
  final String trimmed = name.trim();
  return trimmed.toLowerCase().startsWith('section ')
      ? trimmed
      : 'Section $trimmed';
}

String _initials(String name) {
  final List<String> parts =
      name
          .trim()
          .split(RegExp(r'\s+'))
          .where((String part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
