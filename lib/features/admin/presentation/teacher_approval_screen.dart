import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_management_providers.dart';

/// Keeps the Teacher registration queue current when profiles change.
final Provider<void> _teachersRealtimeListenerProvider = Provider<void>((ref) {
  final RealtimeChannel channel =
      ref
          .read(supabaseClientProvider)
          .channel('admin-teachers-list')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: const PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'role',
              value: 'teacher',
            ),
            callback: (PostgresChangePayload payload) {
              ref.invalidate(teachersListProvider);
              ref.invalidate(processedTeachersListProvider);
            },
          )
          .subscribe();

  ref.onDispose(() => ref.read(supabaseClientProvider).removeChannel(channel));
});

/// The actionable approval queue. Filtering happens in PostgREST rather than
/// loading every Teacher account and hiding processed records in the widget.
final FutureProvider<List<Profile>> teachersListProvider =
    FutureProvider<List<Profile>>((Ref ref) {
      ref.watch(_teachersRealtimeListenerProvider);
      return ref
          .watch(profilesRepositoryProvider)
          .fetchTeachers(status: ProfileStatus.pending);
    });

/// Read-only approved/rejected registration history, also scoped server-side.
final FutureProvider<List<Profile>> processedTeachersListProvider =
    FutureProvider<List<Profile>>((Ref ref) {
      ref.watch(_teachersRealtimeListenerProvider);
      return ref.watch(profilesRepositoryProvider).fetchProcessedTeachers();
    });

enum _TeacherAccountsView { pending, history }

enum _HistoryFilter { all, approved, rejected }

class TeacherApprovalScreen extends ConsumerStatefulWidget {
  const TeacherApprovalScreen({super.key});

  @override
  ConsumerState<TeacherApprovalScreen> createState() =>
      _TeacherApprovalScreenState();
}

class _TeacherApprovalScreenState extends ConsumerState<TeacherApprovalScreen> {
  _TeacherAccountsView _view = _TeacherAccountsView.pending;
  _HistoryFilter _historyFilter = _HistoryFilter.all;
  final Set<String> _processingIds = <String>{};
  final Set<String> _resolvedIds = <String>{};

  Future<void> _approve(Profile teacher) async {
    final SessionState session = await ref.read(sessionProvider.future);
    if (session is! SessionAdmin) return;
    if (!mounted) return;

    setState(() => _processingIds.add(teacher.id));
    try {
      await ref
          .read(profilesRepositoryProvider)
          .approveTeacher(
            teacherId: teacher.id,
            approvedByAdminId: session.profile.id,
          );
      if (!mounted) return;
      setState(() {
        _processingIds.remove(teacher.id);
        _resolvedIds.add(teacher.id);
      });
      _invalidateTeacherLists();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher approved successfully.')),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _processingIds.remove(teacher.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _reject(Profile teacher) async {
    setState(() => _processingIds.add(teacher.id));
    try {
      await ref.read(profilesRepositoryProvider).rejectTeacher(teacher.id);
      if (!mounted) return;
      setState(() {
        _processingIds.remove(teacher.id);
        _resolvedIds.add(teacher.id);
      });
      _invalidateTeacherLists();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher request rejected.')),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _processingIds.remove(teacher.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  void _invalidateTeacherLists() {
    ref.invalidate(teachersListProvider);
    ref.invalidate(processedTeachersListProvider);
    ref.invalidate(adminAccountsTeachersProvider);
  }

  void _showPending() {
    setState(() => _view = _TeacherAccountsView.pending);
  }

  void _showHistory() {
    setState(() => _view = _TeacherAccountsView.history);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: 'Teacher Accounts',
            subtitle: 'Review and manage Teacher registration requests.',
            action:
                _view == _TeacherAccountsView.pending
                    ? AppButton(
                      key: const Key('teacher_accounts_history_action'),
                      label: 'History',
                      leadingIcon: Icons.history_rounded,
                      variant: AppButtonVariant.outlined,
                      size: AppComponentSize.small,
                      onPressed: _showHistory,
                    )
                    : AppButton(
                      key: const Key('teacher_accounts_pending_action'),
                      label: 'Pending requests',
                      leadingIcon: Icons.arrow_back_rounded,
                      variant: AppButtonVariant.text,
                      size: AppComponentSize.small,
                      onPressed: _showPending,
                    ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                _view == _TeacherAccountsView.pending
                    ? _buildPendingView()
                    : _buildHistoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingView() {
    final AsyncValue<List<Profile>> teachers = ref.watch(teachersListProvider);

    return teachers.when(
      loading:
          () => const _TeacherAccountsPanel(
            key: ValueKey<String>('pending-loading'),
            title: 'Pending Requests',
            icon: Icons.pending_actions_rounded,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: AppLoadingIndicator(message: 'Loading pending requests'),
            ),
          ),
      error:
          (Object error, StackTrace _) => _TeacherAccountsPanel(
            key: const ValueKey<String>('pending-error'),
            title: 'Pending Requests',
            icon: Icons.pending_actions_rounded,
            child: AppErrorState(
              message:
                  error is AppFailure
                      ? error.message
                      : 'Could not load pending Teacher requests.',
              onRetry: () => ref.invalidate(teachersListProvider),
            ),
          ),
      data: (List<Profile> list) {
        final List<Profile> visible =
            list
                .where(
                  (Profile teacher) =>
                      teacher.status == ProfileStatus.pending &&
                      !_resolvedIds.contains(teacher.id),
                )
                .toList();
        return _TeacherAccountsPanel(
          key: const ValueKey<String>('pending-data'),
          title: 'Pending Requests',
          count: visible.length,
          icon: Icons.pending_actions_rounded,
          onRefresh: () => ref.invalidate(teachersListProvider),
          child:
              visible.isEmpty
                  ? const AppEmptyState(
                    icon: Icons.mark_email_read_outlined,
                    title: 'No pending Teacher requests.',
                    description:
                        'New Teacher registrations will appear here for review.',
                  )
                  : Column(
                    children: <Widget>[
                      for (final Profile teacher in visible)
                        _PendingTeacherCard(
                          key: Key('pending_teacher_${teacher.id}'),
                          teacher: teacher,
                          isProcessing: _processingIds.contains(teacher.id),
                          onReject: () => _reject(teacher),
                          onApprove: () => _approve(teacher),
                        ),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    final AsyncValue<List<Profile>> teachers = ref.watch(
      processedTeachersListProvider,
    );

    return teachers.when(
      loading:
          () => const _TeacherAccountsPanel(
            key: ValueKey<String>('history-loading'),
            title: 'Registration History',
            icon: Icons.history_rounded,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: AppLoadingIndicator(
                message: 'Loading registration history',
              ),
            ),
          ),
      error:
          (Object error, StackTrace _) => _TeacherAccountsPanel(
            key: const ValueKey<String>('history-error'),
            title: 'Registration History',
            icon: Icons.history_rounded,
            child: AppErrorState(
              message:
                  error is AppFailure
                      ? error.message
                      : 'Could not load Teacher registration history.',
              onRetry: () => ref.invalidate(processedTeachersListProvider),
            ),
          ),
      data: (List<Profile> list) {
        final List<Profile> processed =
            list
                .where(
                  (Profile teacher) =>
                      teacher.status == ProfileStatus.approved ||
                      teacher.status == ProfileStatus.rejected,
                )
                .toList();
        final List<Profile> filtered = switch (_historyFilter) {
          _HistoryFilter.all => processed,
          _HistoryFilter.approved =>
            processed
                .where(
                  (Profile teacher) => teacher.status == ProfileStatus.approved,
                )
                .toList(),
          _HistoryFilter.rejected =>
            processed
                .where(
                  (Profile teacher) => teacher.status == ProfileStatus.rejected,
                )
                .toList(),
        };

        return _TeacherAccountsPanel(
          key: const ValueKey<String>('history-data'),
          title: 'Registration History',
          count: processed.length,
          icon: Icons.history_rounded,
          onRefresh: () => ref.invalidate(processedTeachersListProvider),
          toolbar: _HistoryFilters(
            selected: _historyFilter,
            onSelected:
                (_HistoryFilter filter) =>
                    setState(() => _historyFilter = filter),
          ),
          child:
              processed.isEmpty
                  ? const AppEmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'No processed Teacher requests yet.',
                  )
                  : filtered.isEmpty
                  ? AppEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No ${_historyFilter.name} Teacher requests.',
                    description:
                        'Choose another status filter to view history.',
                  )
                  : Column(
                    children: <Widget>[
                      for (final Profile teacher in filtered)
                        _HistoryTeacherCard(
                          key: Key('history_teacher_${teacher.id}'),
                          teacher: teacher,
                        ),
                    ],
                  ),
        );
      },
    );
  }
}

class _TeacherAccountsPanel extends StatelessWidget {
  const _TeacherAccountsPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.count,
    this.onRefresh,
    this.toolbar,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final int? count;
  final VoidCallback? onRefresh;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AdultWorkspaceColors.paleBlue,
                    borderRadius: AppRadius.mediumAll,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AdultWorkspaceColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: AdultWorkspaceColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (count != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    key: Key('teacher_accounts_count_$count'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (onRefresh != null)
                  IconButton(
                    key: const Key('teacher_accounts_refresh'),
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
          ),
          if (toolbar != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: toolbar,
            ),
          Divider(height: 1, color: colors.outlineVariant),
          Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: child),
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({required this.selected, required this.onSelected});

  final _HistoryFilter selected;
  final ValueChanged<_HistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('teacher_history_filters'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final _HistoryFilter filter in _HistoryFilter.values)
          ChoiceChip(
            key: Key('teacher_history_filter_${filter.name}'),
            label: Text(_titleCase(filter.name)),
            selected: selected == filter,
            onSelected: (bool value) {
              if (value) onSelected(filter);
            },
          ),
      ],
    );
  }
}

class _PendingTeacherCard extends StatelessWidget {
  const _PendingTeacherCard({
    super.key,
    required this.teacher,
    required this.isProcessing,
    required this.onReject,
    required this.onApprove,
  });

  final Profile teacher;
  final bool isProcessing;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return _TeacherRequestCard(
      teacher: teacher,
      status: const AppBadge(
        label: 'Pending',
        icon: Icons.schedule_rounded,
        variant: AppBadgeVariant.warning,
      ),
      metadata: 'Requested ${_formatDate(teacher.createdAt)}',
      trailing: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.end,
        children: <Widget>[
          AppButton(
            key: Key('reject_teacher_${teacher.id}'),
            label: 'Reject',
            leadingIcon: Icons.close_rounded,
            variant: AppButtonVariant.outlined,
            size: AppComponentSize.small,
            onPressed: isProcessing ? null : onReject,
          ),
          AppButton(
            key: Key('approve_teacher_${teacher.id}'),
            label: 'Approve',
            leadingIcon: Icons.check_rounded,
            size: AppComponentSize.small,
            isLoading: isProcessing,
            onPressed: onApprove,
          ),
        ],
      ),
    );
  }
}

class _HistoryTeacherCard extends StatelessWidget {
  const _HistoryTeacherCard({super.key, required this.teacher});

  final Profile teacher;

  @override
  Widget build(BuildContext context) {
    final bool approved = teacher.status == ProfileStatus.approved;
    final String processedDate = _formatDate(
      approved ? teacher.approvedAt ?? teacher.updatedAt : teacher.updatedAt,
    );
    final List<String> metadata = <String>['Processed $processedDate'];
    if (approved && teacher.approvedByName != null) {
      metadata.add('Approved by ${teacher.approvedByName}');
    }

    return _TeacherRequestCard(
      teacher: teacher,
      status: AppBadge(
        label: approved ? 'Approved' : 'Rejected',
        icon:
            approved
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
        variant: approved ? AppBadgeVariant.success : AppBadgeVariant.error,
      ),
      metadata: metadata.join('  •  '),
    );
  }
}

class _TeacherRequestCard extends StatelessWidget {
  const _TeacherRequestCard({
    required this.teacher,
    required this.status,
    required this.metadata,
    this.trailing,
  });

  final Profile teacher;
  final Widget status;
  final String metadata;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget identity = Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AdultWorkspaceColors.softBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(teacher.fullName),
                    style: textTheme.labelLarge?.copyWith(
                      color: AdultWorkspaceColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        teacher.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: AdultWorkspaceColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        teacher.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        metadata,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: AdultWorkspaceColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 680) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  identity,
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      status,
                      if (trailing != null) ...<Widget>[
                        const Spacer(),
                        Flexible(child: trailing!),
                      ],
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.md),
                status,
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  trailing!,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _initials(String fullName) {
  final List<String> parts =
      fullName
          .trim()
          .split(RegExp(r'\s+'))
          .where((String part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _formatDate(DateTime value) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime local = value.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
