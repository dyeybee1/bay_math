import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';

/// Subscribes to Supabase Realtime changes on `profiles` (insert, update,
/// delete — any of them) so [teachersListProvider] refreshes automatically
/// the instant a Teacher self-registers, elsewhere approves/rejects, etc.
/// — no manual refresh or tab-switch needed.
///
/// Requires Realtime to actually be enabled for the `profiles` table on
/// the Supabase project (Dashboard > Database > Replication, or
/// `alter publication supabase_realtime add table public.profiles;`) —
/// without that, this subscribes successfully but silently never fires,
/// no error either side.
///
/// A stable singleton, same reasoning as `_authStateListenerProvider` in
/// session_provider.dart: it must NOT live inside `teachersListProvider`'s
/// own build function in a way that gets recreated every time that
/// provider is invalidated, or the same subscription-pileup bug fixed
/// there would reappear here.
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
            callback: (payload) => ref.invalidate(teachersListProvider),
          )
          .subscribe();

  ref.onDispose(() => ref.read(supabaseClientProvider).removeChannel(channel));
});

/// All Teacher accounts, newest first — pending ones surfaced with
/// Approve/Reject actions. Phase 4 architecture, Part 7: "Teacher approval,
/// Teacher rejection."
final FutureProvider<List<Profile>> teachersListProvider =
    FutureProvider<List<Profile>>((ref) {
      // Ensures the realtime listener above exists for as long as this list is
      // being watched — cheap, since a plain Provider's body only ever runs
      // once regardless of how many times it's watched.
      ref.watch(_teachersRealtimeListenerProvider);
      return ref.watch(profilesRepositoryProvider).fetchTeachers();
    });

class TeacherApprovalScreen extends ConsumerWidget {
  const TeacherApprovalScreen({super.key});

  Future<void> _approve(
    WidgetRef ref,
    BuildContext context,
    Profile teacher,
  ) async {
    final SessionState session =
        ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionAdmin) return;

    try {
      await ref
          .read(profilesRepositoryProvider)
          .approveTeacher(
            teacherId: teacher.id,
            approvedByAdminId: session.profile.id,
          );
      ref.invalidate(teachersListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher.fullName} approved.')),
        );
      }
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _reject(
    WidgetRef ref,
    BuildContext context,
    Profile teacher,
  ) async {
    try {
      await ref.read(profilesRepositoryProvider).rejectTeacher(teacher.id);
      ref.invalidate(teachersListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher.fullName} rejected.')),
        );
      }
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  AppBadgeVariant _variantFor(ProfileStatus status) => switch (status) {
    ProfileStatus.pending => AppBadgeVariant.warning,
    ProfileStatus.approved => AppBadgeVariant.success,
    ProfileStatus.rejected => AppBadgeVariant.error,
    ProfileStatus.suspended => AppBadgeVariant.neutral,
    // No dedicated "archived"/muted variant exists on AppBadgeVariant
    // (success/warning/error/info/neutral — see app_badge.dart); neutral
    // is the same choice already made for suspended above, so archived
    // (also a non-error, no-longer-active state) reuses it rather than
    // reaching for error/warning, which would visually imply the account
    // was rejected or needs attention.
    ProfileStatus.archived => AppBadgeVariant.neutral,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Profile>> teachers = ref.watch(teachersListProvider);

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: 'Teacher Accounts',
            subtitle: 'Approve or reject Teacher self-registrations.',
            action: AppButton(
              label: 'Refresh',
              leadingIcon: Icons.refresh,
              variant: AppButtonVariant.text,
              size: AppComponentSize.small,
              onPressed: () => ref.invalidate(teachersListProvider),
            ),
          ),
          teachers.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: AppLoadingIndicator(),
                ),
            error:
                (error, _) => AppErrorState(
                  message:
                      error is AppFailure
                          ? error.message
                          : 'Could not load teachers.',
                  onRetry: () => ref.invalidate(teachersListProvider),
                ),
            data: (List<Profile> list) {
              if (list.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.people_outline,
                  title: 'No teacher accounts yet',
                  description: 'Teacher self-registrations will appear here.',
                );
              }
              return Column(
                children: <Widget>[
                  for (final Profile teacher in list)
                    AppCard(
                      header: Text(teacher.fullName),
                      subtitle: Text(teacher.email),
                      trailing: AppBadge(
                        label: teacher.status.name,
                        variant: _variantFor(teacher.status),
                      ),
                      footer:
                          teacher.status == ProfileStatus.pending
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  AppButton(
                                    label: 'Reject',
                                    variant: AppButtonVariant.outlined,
                                    size: AppComponentSize.small,
                                    onPressed:
                                        () => _reject(ref, context, teacher),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  AppButton(
                                    label: 'Approve',
                                    size: AppComponentSize.small,
                                    onPressed:
                                        () => _approve(ref, context, teacher),
                                  ),
                                ],
                              )
                              : null,
                      child: const SizedBox.shrink(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
