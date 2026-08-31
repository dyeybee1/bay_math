import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
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

/// Desktop-first Administrator shell. Destination indices and refresh behavior
/// remain stable; only the presentation and user-facing Statistics label have
/// changed.
class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _selectedIndex = 0;

  static const List<_AdminDestination> _destinations = <_AdminDestination>[
    _AdminDestination(
      icon: Icons.query_stats_outlined,
      selectedIcon: Icons.query_stats_rounded,
      label: 'Statistics',
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
    _AdminDestination(
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      label: 'Quiz Results',
    ),
    _AdminDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Performance Reports',
    ),
  ];

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);

    // Preserve every existing refresh boundary and destination index.
    if (index == 1) {
      ref.invalidate(teachersListProvider);
    }
    if (index == 0) {
      ref.invalidate(adminSummaryTilesProvider);
      ref.invalidate(adminScoreByGradeProvider);
      ref.invalidate(adminProficiencyDistributionProvider);
    }
    if (index == 4) {
      ref.invalidate(adminAccountsTeachersProvider);
      ref.invalidate(adminAccountsStudentsProvider);
      ref.invalidate(teachersListProvider);
    }
    if (index == 5) {
      ref.invalidate(adminQuizResultsProvider);
      ref.invalidate(adminQuizResultsSchoolYearsProvider);
    }
    if (index == 6) {
      ref.invalidate(adminPerformanceReportsProvider);
      ref.invalidate(adminPerformanceReportsTopicsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionState session =
        ref.watch(sessionProvider).value ?? const SessionNone();
    final String fullName =
        session is SessionAdmin ? session.profile.fullName : 'Admin';

    return Scaffold(
      backgroundColor: AdultWorkspaceColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactNavigation = constraints.maxWidth < 1180;
            final bool compactUtility = constraints.maxWidth < 760;

            return Column(
              children: <Widget>[
                _AdminUtilityBar(
                  fullName: fullName,
                  compact: compactUtility,
                  onLogout: () => ref.read(sessionProvider.notifier).signOut(),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _AdminSidebar(
                        destinations: _destinations,
                        selectedIndex: _selectedIndex,
                        compact: compactNavigation,
                        onSelected: _selectDestination,
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AdultWorkspaceColors.border,
                      ),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminUtilityBar extends StatelessWidget {
  const _AdminUtilityBar({
    required this.fullName,
    required this.compact,
    required this.onLogout,
  });

  final String fullName;
  final bool compact;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final List<String> parts =
        fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((String part) => part.isNotEmpty)
            .toList();
    final String initials =
        parts.isEmpty
            ? ''
            : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : (parts.first.substring(0, 1) + parts.last.substring(0, 1))
                .toUpperCase();

    return Container(
      key: const Key('admin_utility_bar'),
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdultWorkspaceColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AdultWorkspaceColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'ADMINISTRATOR WORKSPACE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AdultWorkspaceColors.primaryMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.05,
            ),
          ),
          const Spacer(),
          Semantics(
            label: 'Signed in as $fullName, Administrator',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AdultWorkspaceColors.paleBlue,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AdultWorkspaceColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppAvatar(initials: initials),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              color: AdultWorkspaceColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Administrator',
                            style: TextStyle(
                              color: AdultWorkspaceColors.secondaryText,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            key: const Key('admin_logout_button'),
            onPressed: onLogout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            color: AdultWorkspaceColors.navy,
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.compact,
    required this.onSelected,
  });

  final List<_AdminDestination> destinations;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin_sidebar'),
      width: compact ? 88 : 228,
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          compact ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.lg,
          compact ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.md,
        ),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
            child: Semantics(
              image: true,
              label: 'BayMath, Learn, Practice, Master',
              child: Image.asset(
                'assets/images/baymath_logo.png',
                key: const Key('admin_brand_logo'),
                width: compact ? 70 : 168,
                height: 52,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!compact) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ADMINISTRATION',
                style: TextStyle(
                  color: AdultWorkspaceColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (int index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _AdminNavigationItem(
                key: Key('admin_navigation_$index'),
                destination: destinations[index],
                selected: selectedIndex == index,
                compact: compact,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminNavigationItem extends StatelessWidget {
  const _AdminNavigationItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _AdminDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
      decoration: BoxDecoration(
        color: selected ? AdultWorkspaceColors.paleBlue : Colors.transparent,
        borderRadius: AppRadius.mediumAll,
        border: Border.all(
          color:
              selected
                  ? AdultWorkspaceColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment:
            compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  selected ? AdultWorkspaceColors.primary : Colors.transparent,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 19,
              color:
                  selected ? Colors.white : AdultWorkspaceColors.primaryMuted,
            ),
          ),
          if (!compact) ...<Widget>[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color:
                      selected
                          ? AdultWorkspaceColors.ink
                          : AdultWorkspaceColors.secondaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final Widget button = Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumAll,
          hoverColor: AdultWorkspaceColors.softBlue.withValues(alpha: 0.75),
          focusColor: AdultWorkspaceColors.primary.withValues(alpha: 0.12),
          splashColor: AdultWorkspaceColors.primary.withValues(alpha: 0.1),
          child: content,
        ),
      ),
    );

    return compact
        ? Tooltip(message: destination.label, child: button)
        : button;
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
