import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';
import '../widgets/teacher_drilldown_widgets.dart';

/// Teacher Dashboard "Total Sections" tile drill-down.
class TeacherSectionsListScreen extends ConsumerWidget {
  const TeacherSectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SectionAverageScore>> sectionsAsync = ref.watch(
      dashboardAverageScoreBySectionProvider,
    );

    return TeacherDrilldownPage(
      title: 'Sections',
      subtitle: 'Manage and view your assigned classes',
      child: sectionsAsync.when(
        loading:
            () => const TeacherStatePanel(
              child: AppLoadingIndicator(message: 'Loading your sections…'),
            ),
        error:
            (Object error, StackTrace _) => TeacherStatePanel(
              child: AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not load the section list.',
                onRetry:
                    () =>
                        ref.invalidate(dashboardAverageScoreBySectionProvider),
              ),
            ),
        data: (List<SectionAverageScore> sections) {
          if (sections.isEmpty) {
            return const TeacherStatePanel(
              child: AppEmptyState(
                icon: Icons.groups_outlined,
                title: 'No sections assigned yet',
                description: 'Sections assigned to you will appear here.',
              ),
            );
          }

          final int studentCount = sections.fold<int>(
            0,
            (int total, SectionAverageScore section) =>
                total + section.studentCount,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TeacherListSummary(
                icon: Icons.groups_2_outlined,
                title:
                    '${sections.length} assigned section${sections.length == 1 ? '' : 's'}',
                description:
                    '$studentCount student${studentCount == 1 ? '' : 's'} across your current classes',
              ),
              const SizedBox(height: AppSpacing.lg),
              TeacherResponsiveGrid(
                children: <Widget>[
                  for (final SectionAverageScore section in sections)
                    _SectionCard(section: section),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final SectionAverageScore section;

  @override
  Widget build(BuildContext context) {
    final bool hasAssessmentData = section.averageQuizScorePercent != null;
    final String gradeNumber = section.gradeLevel.label.split(' ').last;

    return TeacherDrilldownCard(
      semanticLabel:
          '${section.gradeLevel.label}, section ${section.sectionName}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Text(
              'G$gradeNumber',
              style: AppTextStyles.lexend(
                size: 16,
                weight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  section.gradeLevel.label.toUpperCase(),
                  style: AppTextStyles.inter(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.textSoft,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _sectionLabel(section.sectionName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.lexend(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _MetadataLine(
                  icon: Icons.people_outline,
                  label:
                      '${section.studentCount} student${section.studentCount == 1 ? '' : 's'}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _MetadataLine(
                  icon:
                      hasAssessmentData
                          ? Icons.insights_outlined
                          : Icons.pending_actions_outlined,
                  label:
                      hasAssessmentData
                          ? 'Average score ${formatPercent(section.averageQuizScorePercent)}'
                          : 'No assessment data yet',
                  emphasized: hasAssessmentData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sectionLabel(String name) {
    final String trimmed = name.trim();
    return trimmed.toLowerCase().startsWith('section ')
        ? trimmed
        : 'Section $trimmed';
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final Color color = emphasized ? AppColors.accent : AppColors.textSoft;
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.inter(
              size: 12,
              weight: emphasized ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
