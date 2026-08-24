import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/session_provider.dart';
import '../../../core/widgets/widgets.dart';

/// Shown to a Teacher whose `profiles.status` is `pending`. Reachable only
/// via the router's redirect (Phase 4.1 architecture §3) — never navigated
/// to directly, so it always reflects a real, current session state rather
/// than a static message that could go stale.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState session =
        ref.watch(sessionProvider).value ?? const SessionNone();
    final String? fullName =
        session is SessionTeacher ? session.profile.fullName : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Awaiting Approval')),
      body: AppPageContainer(
        child: AppEmptyState(
          icon: Icons.hourglass_top_outlined,
          title:
              fullName == null
                  ? 'Your account is awaiting approval'
                  : 'Welcome, $fullName — your account is awaiting approval',
          description:
              'An administrator needs to approve your account before you can sign in. '
              'This usually does not take long — check back soon.',
          actionLabel: 'Log Out',
          onAction: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ),
    );
  }
}
