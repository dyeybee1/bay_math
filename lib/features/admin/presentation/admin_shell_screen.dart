import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/session_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_management_providers.dart';
import '../data/admin_dashboard_providers.dart';
import '../data/admin_quiz_results_providers.dart';
import '../data/performance_reports_providers.dart';
import 'account_management_screen.dart';
import 'admin_dashboard_screen.dart';
import 'performance_reports_screen.dart';
import 'quiz_results_screen.dart';
import 'school_years_screen.dart';
import 'sections_screen.dart';
import 'teacher_approval_screen.dart';

/// Admin app shell. Phase 2 scope: Teacher approval, School Years, and
/// Sections management (Phase 4 architecture, Part 7) — three destinations
/// behind a single [NavigationRail], appropriate for the Desktop/Web-only
/// Admin experience (`AppLayoutType.desktopLayout`). Dashboard (0039,
/// Phase 5 Parts 1-5) was added as a fourth destination, and is now the
/// first/landing tab — see [_destinations] and [_selectedIndex] below.
/// Accounts (0047 Account Management + Archive, Part 4) was added as a
/// fifth destination, appended after Sections rather than inserted earlier
/// in the list, specifically so it doesn't shift Dashboard/Teacher
/// Accounts/School Years/Sections's existing indices — see the
/// `onDestinationSelected` index checks below. Quiz Results (0051, Part 3)
/// was added as a sixth destination for the same reason, appended after
/// Accounts rather than inserted earlier. Performance Reports (0052,
/// Part 4) was added as a seventh destination, appended after Quiz Results
/// for the identical reason — its approved mockup shows it sitting between
/// "Quiz Results" and "Settings" in the sidebar, but this shell has no
/// "Settings" destination at all yet (there is a Logout `IconButton` in
/// the `AppBar`'s `actions`, not a `NavigationRail` destination), so
/// "between Quiz Results and Settings" and "appended after Quiz Results"
/// are the same position today — this note exists so a future Settings
/// destination gets inserted AFTER Performance Reports, not between Quiz
/// Results and it, to actually match the mockup once Settings exists. The
/// audit log viewer remains a later-phase destination, not added here.
class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  // Dashboard is index 0 (see _destinations below) and is the intended
  // landing tab for an Admin session — this was already 0 before
  // Dashboard existed (Teacher Accounts was index 0 then), and stays 0
  // now that Dashboard has been inserted as the first destination, so no
  // literal value change was needed here, only this note explaining why
  // it's still correct.
  int _selectedIndex = 0;

  static const List<_AdminDestination> _destinations = <_AdminDestination>[
    _AdminDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    _AdminDestination(
      icon: Icons.how_to_reg_outlined,
      selectedIcon: Icons.how_to_reg,
      label: 'Teacher Accounts',
    ),
    _AdminDestination(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'School Years',
    ),
    _AdminDestination(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Sections',
    ),
    _AdminDestination(
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
      label: 'Accounts',
    ),
    // Appended, not inserted — see this class's own doc comment on why
    // destinations are always appended (keeps indices 0-4 above stable).
    _AdminDestination(
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      label: 'Quiz Results',
    ),
    // Appended after Quiz Results, not inserted before it — same reason
    // as every other addition above. Icon picked from the same
    // Material-icons set already used for every other destination here
    // (no new icon package introduced): `Icons.bar_chart_outlined` /
    // `Icons.bar_chart` is this set's own bar-chart glyph, consistent with
    // the mockup's bar-chart-style icon for this item, and distinct from
    // `Icons.fact_check_outlined` (Quiz Results) and
    // `Icons.dashboard_outlined` (Dashboard) already in use above.
    _AdminDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Performance Reports',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final SessionState session =
        ref.watch(sessionProvider).value ?? const SessionNone();
    final String fullName =
        session is SessionAdmin ? session.profile.fullName : 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('BAYMATH — Admin'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Row(
                children: <Widget>[
                  AppAvatar(initials: _initialsFor(fullName)),
                  const SizedBox(width: 8),
                  Text(fullName),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
              // Both branches below follow the same reasoning:
              // teachersListProvider and the three admin*Provider
              // Dashboard providers (0039 Phase 4) are all plain
              // FutureProviders, not `.autoDispose` — none of them
              // auto-refetch on their own, and IndexedStack below keeps
              // every destination's widget alive the whole time (never
              // disposed just for being off-screen), so re-entering a tab
              // is the one natural moment to force a fresh fetch instead.
              //
              // Teacher Accounts shifted from index 0 to index 1 when
              // Dashboard was inserted as the new first destination —
              // this check is updated to match.
              if (index == 1) {
                ref.invalidate(teachersListProvider);
              }
              // Dashboard is the new index 0. Same reasoning as above,
              // applied to all three of its independent fetch providers
              // (`admin_dashboard_providers.dart`, Phase 4) — each is its
              // own round-trip with its own loading/error state (see that
              // file's own doc comment for why there's no combined
              // provider to invalidate instead), so all three are
              // invalidated together here on tab re-entry.
              if (index == 0) {
                ref.invalidate(adminSummaryTilesProvider);
                ref.invalidate(adminScoreByGradeProvider);
                ref.invalidate(adminProficiencyDistributionProvider);
              }
              // Accounts (0047, Part 4) is index 4, appended after
              // Sections so it doesn't shift any index above. Invalidates
              // both of its own fetch providers (`account_management_providers.dart`)
              // AND teachersListProvider — Teacher Accounts (index 1) reads
              // overlapping `profiles` data and would otherwise go stale
              // after an archive/restore performed from this screen, the
              // same cross-provider reasoning documented on
              // `adminAccountsTeachersProvider`.
              if (index == 4) {
                ref.invalidate(adminAccountsTeachersProvider);
                ref.invalidate(adminAccountsStudentsProvider);
                ref.invalidate(teachersListProvider);
              }
              // Quiz Results (0051, Part 3) is index 5, appended after
              // Accounts so it doesn't shift any index above. Invalidates
              // both of its own fetch providers
              // (`admin_quiz_results_providers.dart`) on tab re-entry —
              // same reasoning as indices 0/1/4 above. Note
              // adminQuizResultsProvider is `.autoDispose` and already
              // re-fetches on its own whenever the filter selection
              // changes (see that provider's own doc comment), but
              // re-entering this tab with an UNCHANGED filter selection
              // would otherwise keep showing whatever was fetched once,
              // forever — this invalidate is what forces a fresh look at
              // the data on every re-entry, not just on every filter
              // change.
              if (index == 5) {
                ref.invalidate(adminQuizResultsProvider);
                ref.invalidate(adminQuizResultsSchoolYearsProvider);
              }
              // Performance Reports (0052, Part 4) is index 6, appended
              // after Quiz Results so it doesn't shift any index above.
              // Same reasoning as index 5: adminPerformanceReportsProvider
              // is `.autoDispose` and already re-fetches on every filter
              // change on its own (see `performance_reports_providers.dart`'s
              // own doc comment), but re-entering this tab with an
              // UNCHANGED filter selection would otherwise keep showing
              // whatever was fetched once, forever — this invalidate
              // forces a fresh look on every re-entry. Only this screen's
              // OWN providers are invalidated here — not
              // adminQuizResultsSchoolYearsProvider, even though this
              // screen's own "Date Range" dropdown reads it too, since
              // that provider is owned by (and already invalidated on
              // re-entry to) Quiz Results, index 5 above; invalidating it
              // a second time here would blur that ownership boundary for
              // no real benefit (school years change rarely, and index 5
              // already keeps it fresh).
              if (index == 6) {
                ref.invalidate(adminPerformanceReportsProvider);
                ref.invalidate(adminPerformanceReportsTopicsProvider);
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              for (final _AdminDestination d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const <Widget>[
                AdminDashboardScreen(),
                TeacherApprovalScreen(),
                SchoolYearsScreen(),
                SectionsScreen(),
                AccountManagementScreen(),
                AdminQuizResultsScreen(),
                AdminPerformanceReportsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String fullName) {
    final List<String> parts =
        fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
