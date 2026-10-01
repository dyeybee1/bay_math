import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';
import '../widgets/teacher_drilldown_widgets.dart';

/// Per-student roster reached from the Teacher Dashboard summary cards.
class TeacherDashboardRosterScreen extends ConsumerWidget {
  const TeacherDashboardRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DashboardRosterEntry>> rosterAsync = ref.watch(
      dashboardRosterProvider,
    );
    final GradeLevel? selectedGrade = ref.watch(selectedGradeLevelProvider);
    final String? selectedSectionId = ref.watch(selectedSectionIdProvider);
    final String scopeLabel = _scopeLabel(
      selectedGrade: selectedGrade,
      selectedSectionId: selectedSectionId,
      roster: rosterAsync.value,
    );

    return TeacherDrilldownPage(
      title: 'Students',
      subtitle: scopeLabel,
      child: rosterAsync.when(
        loading:
            () => const TeacherStatePanel(
              child: AppLoadingIndicator(message: 'Loading student roster…'),
            ),
        error:
            (Object error, StackTrace _) => TeacherStatePanel(
              child: AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not load the student roster.',
                onRetry: () => ref.invalidate(dashboardRosterProvider),
              ),
            ),
        data: (List<DashboardRosterEntry> roster) {
          if (roster.isEmpty) {
            return const TeacherStatePanel(
              child: AppEmptyState(
                icon: Icons.people_outline,
                title: 'No students in this scope',
                description:
                    'Students assigned to this section will appear here.',
              ),
            );
          }

          final int attentionCount =
              roster
                  .where(
                    (DashboardRosterEntry entry) => entry.needsIntervention,
                  )
                  .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TeacherListSummary(
                icon: Icons.people_outline,
                title:
                    '${roster.length} student${roster.length == 1 ? '' : 's'} in this view',
                description:
                    attentionCount == 0
                        ? 'All listed students are currently on track.'
                        : '$attentionCount may need additional support.',
                badge:
                    attentionCount == 0
                        ? null
                        : AppBadge(
                          label: '$attentionCount need attention',
                          variant: AppBadgeVariant.warning,
                          icon: Icons.flag_outlined,
                        ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (int index = 0; index < roster.length; index++) ...<Widget>[
                _RosterStudentCard(entry: roster[index]),
                if (index != roster.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }

  String _scopeLabel({
    required GradeLevel? selectedGrade,
    required String? selectedSectionId,
    required List<DashboardRosterEntry>? roster,
  }) {
    final String gradePart = selectedGrade?.label ?? 'All grades';
    if (selectedSectionId == null) return '$gradePart • All sections';

    final String sectionPart =
        roster == null || roster.isEmpty
            ? 'Selected section'
            : roster.first.sectionName;
    return '$gradePart • $sectionPart';
  }
}

class _RosterStudentCard extends StatelessWidget {
  const _RosterStudentCard({required this.entry});

  final DashboardRosterEntry entry;

  @override
  Widget build(BuildContext context) {
    return TeacherDrilldownCard(
      semanticLabel: '${entry.fullName}, ${entry.sectionName}',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget identity = Row(
            children: <Widget>[
              AppAvatar(
                initials: _initials(entry.fullName),
                semanticLabel: '${entry.fullName} avatar',
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.fullName,
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
                      '${_sectionLabel(entry.sectionName)} • '
                      '${entry.quizzesCompleted} quiz'
                      '${entry.quizzesCompleted == 1 ? '' : 'zes'} completed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        size: 12,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final Widget metrics = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _AverageMetric(value: entry.averageQuizScorePercent),
              if (entry.missedOrUnfinishedCount > 0)
                AppBadge(
                  label: '${entry.missedOrUnfinishedCount} missed/unfinished',
                  variant: AppBadgeVariant.neutral,
                  icon: Icons.schedule_outlined,
                ),
              if (entry.needsIntervention)
                const AppBadge(
                  label: 'Needs attention',
                  variant: AppBadgeVariant.warning,
                  icon: Icons.flag_outlined,
                ),
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identity,
                const SizedBox(height: AppSpacing.md),
                metrics,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.lg),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _AverageMetric extends StatelessWidget {
  const _AverageMetric({required this.value});

  final num? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value == null ? 'No assessment data' : formatPercent(value),
          style: AppTextStyles.inter(
            size: value == null ? 12 : 16,
            weight: FontWeight.w700,
            color: value == null ? AppColors.textSoft : AppColors.navy,
          ),
        ),
        if (value != null)
          Text(
            'Average score',
            style: AppTextStyles.inter(size: 11, color: AppColors.textSoft),
          ),
      ],
    );
  }
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

String _sectionLabel(String name) {
  final String trimmed = name.trim();
  return trimmed.toLowerCase().startsWith('section ')
      ? trimmed
      : 'Section $trimmed';
}
