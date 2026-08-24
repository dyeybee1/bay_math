import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/profile.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/students_repository.dart';

/// Account Management (0047) — Part 3 deliverable (fetch providers for the
/// Part 4 Account Management screen, which will let Admin archive/restore
/// both Teacher and Student accounts).
///
/// ---------------------------------------------------------------------
/// One merged provider vs two separate ones
/// ---------------------------------------------------------------------
///
/// Two separate providers, not one merged "all accounts" list. Every
/// existing multi-source provider file in this codebase
/// (`admin_dashboard_providers.dart`'s three independent tile/list
/// providers, kept separate specifically so "each panel is an independent
/// SQL round-trip with its own loading/error/refresh state, not one shared
/// `Future` that would force every panel to reload or fail together" — see
/// that file's own doc comment) makes the same choice this one does:
/// Teachers (`ProfilesRepository.fetchTeachers`) and Students
/// (`StudentsRepository.fetchAllWithSection`) are two unrelated repository
/// calls returning two different row shapes (`Profile` vs
/// `StudentWithSection`). Merging them into one `FutureProvider` would mean
/// inventing a unified view-model type purely to re-split it back apart in
/// the UI, and would make a slow/failed Teacher fetch block or fail the
/// Student list (and vice versa) for no benefit — Part 4's screen can
/// combine two independently-loading `AsyncValue`s with `.when` just as
/// easily as it could one merged one.
///
/// ---------------------------------------------------------------------
/// Realtime vs manual invalidation
/// ---------------------------------------------------------------------
///
/// Plain `FutureProvider`s, NOT `.autoDispose` (nothing here depends on
/// filter state to react to — same reasoning `adminSummaryTilesProvider`
/// et al. give for themselves), refreshed only by explicit
/// `ref.invalidate(...)` from `admin_shell_screen.dart`'s
/// `onDestinationSelected` on tab re-entry. `teachersListProvider`
/// (`teacher_approval_screen.dart`) instead mirrors
/// `_teachersRealtimeListenerProvider`, a Realtime subscription on
/// `profiles` — deliberately NOT duplicated here. That subscription exists
/// so the pending-approval queue updates the instant a Teacher
/// self-registers, without the Admin needing to leave and re-enter the
/// tab; Account Management has no equivalent "someone else is about to act
/// on this list any second" urgency — archive/restore are Admin-initiated
/// actions only, so the same re-entry-triggered refresh already used
/// everywhere else in this codebase (Dashboard, Teacher Accounts' own
/// manual Refresh button) is sufficient here too, and avoids a second
/// standing Realtime channel for a screen that doesn't need one.
///
/// ---------------------------------------------------------------------
/// Cross-provider invalidation
/// ---------------------------------------------------------------------
///
/// Both providers below only ever fetch; the actual
/// archiveTeacher/restoreTeacher/archiveStudent/restoreStudent calls stay
/// in Part 4's screen (same shape as `TeacherApprovalScreen._approve`/
/// `_reject`, which call the repository directly, not through a provider),
/// but Part 4 must invalidate [adminAccountsTeachersProvider] AND
/// `teachersListProvider` (`teacher_approval_screen.dart`) together on any
/// teacher archive/restore (both screens read overlapping `profiles` data
/// and neither auto-refreshes the other), and [adminAccountsStudentsProvider]
/// alone on any student archive/restore (Teacher Accounts has no student
/// data to go stale). `admin_shell_screen.dart`'s "Accounts" destination
/// below does the same pairing on tab re-entry, importing
/// `teacher_approval_screen.dart` directly for `teachersListProvider`
/// rather than this file re-exporting it — matching how that shell already
/// imports `admin_dashboard_providers.dart` and `teacher_approval_screen.dart`
/// separately for their own respective providers.

final FutureProvider<List<Profile>> adminAccountsTeachersProvider =
    FutureProvider<List<Profile>>((ref) {
  return ref.watch(profilesRepositoryProvider).fetchTeachers();
});

final FutureProvider<List<StudentWithSection>> adminAccountsStudentsProvider =
    FutureProvider<List<StudentWithSection>>((ref) {
  return ref.watch(studentsRepositoryProvider).fetchAllWithSection();
});
