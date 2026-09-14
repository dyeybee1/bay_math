import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/teacher_section.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/students_repository.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_management_providers.dart';
import 'teacher_approval_screen.dart'
    show processedTeachersListProvider, teachersListProvider;

/// Account Management (0047) — Part 4: the real screen, replacing the
/// Part 3 placeholder (`_AccountsPlaceholderScreen`, since removed) in
/// `admin_shell_screen.dart`.

/// One `teacher_sections` assignment, paired with its resolved [Section] —
/// same pairing shape as `sections_screen.dart`'s `AssignedTeacher`, just
/// resolving the opposite direction (this file cares about a Teacher's
/// sections; that one cares about a Section's teachers).
class _TeacherSectionSummary {
  const _TeacherSectionSummary({
    required this.section,
    required this.isPrimary,
  });
  final Section section;
  final bool isPrimary;
}

/// Every Teacher's current section assignment(s), keyed by teacher id.
/// Resolves `TeacherSectionsRepository.fetchAll()` (added this part —
/// see that repository's own doc comment) against
/// `SectionsRepository.fetchByIds` in one batched join — the same shape
/// as `sections_screen.dart`'s `assignedTeachersProvider`, just resolving
/// every teacher's sections at once instead of one section's teachers at
/// a time, since this screen needs every row's summary up front.
///
/// Lives in this screen file rather than `account_management_providers.dart`
/// — that file's own doc comment explains it holds only the two Part 3
/// fetch providers (`adminAccountsTeachersProvider`/
/// `adminAccountsStudentsProvider`); this one is presentation-shaped
/// (a join keyed for this screen's row-building, not a plain repository
/// passthrough) and has exactly one consumer, matching
/// `admin_dashboard_providers.dart`'s own stated placement rule:
/// "one-shot fetch providers live next to the screen that watches them."
final FutureProvider<Map<String, List<_TeacherSectionSummary>>>
_teacherSectionAssignmentsProvider =
    FutureProvider<Map<String, List<_TeacherSectionSummary>>>((ref) async {
      final List<TeacherSection> assignments =
          await ref.watch(teacherSectionsRepositoryProvider).fetchAll();
      if (assignments.isEmpty) return const {};

      final List<Section> sections = await ref
          .watch(sectionsRepositoryProvider)
          .fetchByIds(assignments.map((a) => a.sectionId).toSet().toList());
      final Map<String, Section> sectionsById = {
        for (final Section s in sections) s.id: s,
      };

      final Map<String, List<_TeacherSectionSummary>> byTeacherId = {};
      for (final TeacherSection a in assignments) {
        final Section? section = sectionsById[a.sectionId];
        // Defensive only — `teacher_sections.section_id` is a non-nullable FK,
        // so a missing lookup here would mean the join above failed, not that
        // the assignment is legitimately sectionless.
        if (section == null) continue;
        byTeacherId
            .putIfAbsent(a.teacherId, () => <_TeacherSectionSummary>[])
            .add(
              _TeacherSectionSummary(section: section, isPrimary: a.isPrimary),
            );
      }
      return byTeacherId;
    });

enum _AccountRole { teacher, student }

enum _StatusFilter { active, archived }

/// One combined Teacher-or-Student row for this screen's list — built
/// client-side from the two independent Part 3 providers plus
/// [_teacherSectionAssignmentsProvider], per this feature's own Part 3
/// doc comment ("Part 4's screen can combine two independently-loading
/// `AsyncValue`s ... just as easily as it could one merged one").
class _AccountRow {
  const _AccountRow({
    required this.id,
    required this.name,
    required this.role,
    required this.sections,
    required this.isArchived,
    required this.statusLabel,
    required this.statusVariant,
  });

  final String id;
  final String name;
  final _AccountRole role;

  /// Every section this account is tied to — 0 or 1 for a Student (the
  /// section from their MOST RECENT enrollment, regardless of that
  /// enrollment's own status — see `StudentWithSection.section`'s own doc
  /// comment; so an archived student's last section still shows up here),
  /// 0 or more for a Teacher (every `teacher_sections` assignment). Kept
  /// as a full list rather than collapsed to one value so grade-level/
  /// section filtering and the "+N more" detail below never silently drop
  /// a Teacher's other assignments.
  final List<_TeacherSectionSummary> sections;

  final bool isArchived;
  final String statusLabel;
  final AppBadgeVariant statusVariant;

  /// The section shown as this row's primary Grade Level/Section value —
  /// the assignment flagged primary, or the first one if none is (a
  /// Student's single section, when present, always satisfies "the only
  /// one," so this works unchanged for both roles).
  _TeacherSectionSummary? get _representative {
    if (sections.isEmpty) return null;
    return sections.firstWhere(
      (s) => s.isPrimary,
      orElse: () => sections.first,
    );
  }

  String get gradeLevelLabel =>
      _representative?.section.gradeLevel.label ?? '—';
  String get sectionLabel => _representative?.section.name ?? 'Unassigned';

  /// Every section name besides the representative one — populates the
  /// "+N" detail tooltip so a multi-section Teacher's other assignments
  /// stay visible rather than disappearing behind the single summary
  /// value above.
  List<String> get additionalSectionLabels =>
      sections.length <= 1
          ? const <String>[]
          : [
            for (final _TeacherSectionSummary s in sections)
              if (!identical(s, _representative))
                '${s.section.gradeLevel.label} — ${s.section.name}',
          ];

  /// Student-only. Whether `app.restore_student` (0050) will actually
  /// succeed for this row: a last-known section is on record (per
  /// `StudentsRepository.fetchAllWithSection`'s most-recent-enrollment
  /// resolution, part 1) AND that section is still active. Always false
  /// for teacher rows — teacher restore eligibility is unrelated and
  /// unaffected by this feature. Callers only need this when [isArchived]
  /// is already true, but it's well-defined either way.
  bool get studentCanRestore =>
      role == _AccountRole.student &&
      sections.isNotEmpty &&
      sections.first.section.status == SectionStatus.active;
}

AppBadgeVariant _teacherStatusVariant(ProfileStatus status) => switch (status) {
  ProfileStatus.pending => AppBadgeVariant.warning,
  ProfileStatus.approved => AppBadgeVariant.success,
  ProfileStatus.rejected => AppBadgeVariant.error,
  ProfileStatus.suspended => AppBadgeVariant.neutral,
  ProfileStatus.archived => AppBadgeVariant.neutral,
};

AppBadgeVariant _studentStatusVariant(StudentStatus status) => switch (status) {
  StudentStatus.active => AppBadgeVariant.success,
  StudentStatus.archived => AppBadgeVariant.neutral,
};

class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  ConsumerState<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState
    extends ConsumerState<AccountManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  _AccountRole? _roleFilter;
  GradeLevel? _gradeFilter;
  String? _sectionFilter;
  _StatusFilter _statusFilter = _StatusFilter.active;

  /// Account ids with an archive/restore call currently in flight — drives
  /// the per-row loading state on that row's action button only, not the
  /// whole screen.
  final Set<String> _pendingIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _searchQuery.trim().isNotEmpty ||
      _roleFilter != null ||
      _gradeFilter != null ||
      _sectionFilter != null;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _roleFilter = null;
      _gradeFilter = null;
      _sectionFilter = null;
    });
  }

  List<_AccountRow> _buildRows(
    List<Profile> teachers,
    List<StudentWithSection> students,
    Map<String, List<_TeacherSectionSummary>> teacherSections,
  ) {
    return <_AccountRow>[
      for (final Profile t in teachers)
        _AccountRow(
          id: t.id,
          name: t.fullName,
          role: _AccountRole.teacher,
          sections: teacherSections[t.id] ?? const <_TeacherSectionSummary>[],
          isArchived: t.status == ProfileStatus.archived,
          statusLabel: t.status.name,
          statusVariant: _teacherStatusVariant(t.status),
        ),
      for (final StudentWithSection s in students)
        _AccountRow(
          id: s.student.id,
          name: s.student.fullName,
          role: _AccountRole.student,
          sections:
              s.section == null
                  ? const <_TeacherSectionSummary>[]
                  : <_TeacherSectionSummary>[
                    _TeacherSectionSummary(
                      section: s.section!,
                      isPrimary: true,
                    ),
                  ],
          isArchived: s.student.status == StudentStatus.archived,
          statusLabel: s.student.status.name,
          statusVariant: _studentStatusVariant(s.student.status),
        ),
    ];
  }

  List<_AccountRow> _applyFilters(List<_AccountRow> rows) {
    final String query = _searchQuery.trim().toLowerCase();
    return rows.where((_AccountRow row) {
      if (_roleFilter != null && row.role != _roleFilter) return false;
      final bool wantsArchived = _statusFilter == _StatusFilter.archived;
      if (row.isArchived != wantsArchived) return false;
      if (_gradeFilter != null &&
          !row.sections.any((s) => s.section.gradeLevel == _gradeFilter)) {
        return false;
      }
      if (_sectionFilter != null &&
          !row.sections.any((s) => s.section.id == _sectionFilter)) {
        return false;
      }
      if (query.isNotEmpty && !row.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Distinct sections referenced by any row at all (independent of the
  /// currently applied filters) — keeps the Section filter's own option
  /// list stable as the admin changes other filters, narrowed only by
  /// [_gradeFilter] for a cascading Grade Level -> Section relationship.
  List<Section> _sectionFilterOptions(List<_AccountRow> allRows) {
    final Map<String, Section> byId = {};
    for (final _AccountRow row in allRows) {
      for (final _TeacherSectionSummary s in row.sections) {
        if (_gradeFilter == null || s.section.gradeLevel == _gradeFilter) {
          byId[s.section.id] = s.section;
        }
      }
    }
    final List<Section> options =
        byId.values.toList()..sort((a, b) {
          final int gradeCompare = a.gradeLevel.index.compareTo(
            b.gradeLevel.index,
          );
          return gradeCompare != 0 ? gradeCompare : a.name.compareTo(b.name);
        });
    return options;
  }

  Future<void> _archiveTeacher(Profile teacher) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Archive ${teacher.fullName}?',
      type: AppDialogType.warning,
      message:
          "This archives ${teacher.fullName}'s Teacher account. They won't be able to access "
          'Teacher or Admin screens until restored.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Archive',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _pendingIds.add(teacher.id));
    try {
      await ref.read(profilesRepositoryProvider).archiveTeacher(teacher.id);
      ref.invalidate(adminAccountsTeachersProvider);
      ref.invalidate(teachersListProvider);
      ref.invalidate(processedTeachersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher.fullName} archived.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(teacher.id));
    }
  }

  Future<void> _restoreTeacher(Profile teacher) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Restore ${teacher.fullName}?',
      type: AppDialogType.confirmation,
      message:
          "This restores ${teacher.fullName}'s account to approved status, with full Teacher "
          'access.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Restore',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _pendingIds.add(teacher.id));
    try {
      await ref.read(profilesRepositoryProvider).restoreTeacher(teacher.id);
      ref.invalidate(adminAccountsTeachersProvider);
      ref.invalidate(teachersListProvider);
      ref.invalidate(processedTeachersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher.fullName} restored.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(teacher.id));
    }
  }

  Future<void> _deleteTeacherPermanently(Profile teacher) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete this account permanently?',
      type: AppDialogType.error,
      message:
          'All data that is intentionally tied to this account and configured for permanent deletion may also be removed. This action cannot be undone.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Delete permanently',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _pendingIds.add(teacher.id));
    try {
      await ref
          .read(profilesRepositoryProvider)
          .deleteTeacherPermanently(teacher.id);
      ref.invalidate(adminAccountsTeachersProvider);
      ref.invalidate(_teacherSectionAssignmentsProvider);
      ref.invalidate(teachersListProvider);
      ref.invalidate(processedTeachersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher account deleted permanently.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(teacher.id));
    }
  }

  /// Opens the Edit User dialog for [teacher] and awaits its dismissal.
  /// All of the actual save logic (validation, calling `updateTeacherFullName`
  /// / `updateTeacherEmail`, provider invalidation, success/error feedback)
  /// lives inside [_EditTeacherDialog] itself, since — unlike the
  /// confirm-then-act pattern used by archive/restore above — this dialog
  /// must stay open and show inline state (loading, error) while its own
  /// network calls are in flight, rather than popping immediately with a
  /// bool and doing the work afterward.
  ///
  /// [_pendingIds] is still owned here (not inside the dialog) because it
  /// also drives the Archive/Restore button state on this same row via
  /// [_AccountRowCard] — the dialog only reports pending/not-pending via
  /// [onPendingChanged] and never touches [_pendingIds] directly.
  Future<void> _editTeacher(Profile teacher) async {
    await showDialog<void>(
      context: context,
      builder:
          (_) => _EditTeacherDialog(
            teacher: teacher,
            onPendingChanged: (bool pending) {
              if (!mounted) return;
              setState(() {
                if (pending) {
                  _pendingIds.add(teacher.id);
                } else {
                  _pendingIds.remove(teacher.id);
                }
              });
            },
          ),
    );
  }

  Future<void> _archiveStudent(Student student) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Archive ${student.fullName}?',
      type: AppDialogType.warning,
      message:
          "This archives ${student.fullName}'s account AND ends their current section "
          "enrollment. They won't be able to sign in until restored.",
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Archive',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _pendingIds.add(student.id));
    try {
      await ref.read(studentsRepositoryProvider).archiveStudent(student.id);
      ref.invalidate(adminAccountsStudentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.fullName} archived and unenrolled.'),
          ),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(student.id));
    }
  }

  /// [studentWithSection] is the row's already-resolved pairing (see
  /// `_AccountRowCard._handleRestore`) so this dialog can name the exact
  /// section the student will land back in without a second lookup. The
  /// Restore action on the row is disabled whenever
  /// `_AccountRow.studentCanRestore` is false (see `_buildRestoreButton`),
  /// so `section` is normally non-null here — the `section == null`
  /// fallback text below only matters for the rare race where another
  /// admin archives the section in the few seconds between this screen
  /// loading and the click, which the RPC itself still catches (the
  /// `AppFailure` handling below is kept as that defense-in-depth
  /// fallback, not removed).
  Future<void> _restoreStudent(StudentWithSection studentWithSection) async {
    final Student student = studentWithSection.student;
    final Section? section = studentWithSection.section;

    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Restore ${student.fullName}?',
      type: AppDialogType.confirmation,
      message:
          section != null
              ? 'This restores ${student.fullName} and re-enrolls them directly into '
                  '${section.name}.'
              : "This restores ${student.fullName}'s account.",
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Restore',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _pendingIds.add(student.id));
    try {
      await ref.read(studentsRepositoryProvider).restoreStudent(student.id);
      ref.invalidate(adminAccountsStudentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.fullName} restored.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(student.id));
    }
  }

  Future<void> _deleteStudentPermanently(Student student) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete this account permanently?',
      type: AppDialogType.error,
      message:
          'All data that is intentionally tied to this account and configured for permanent deletion may also be removed. This action cannot be undone.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Delete permanently',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _pendingIds.add(student.id));
    try {
      await ref
          .read(studentsRepositoryProvider)
          .deleteStudentPermanently(student.id);
      ref.invalidate(adminAccountsStudentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account deleted permanently.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(student.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Profile>> teachersAsync = ref.watch(
      adminAccountsTeachersProvider,
    );
    final AsyncValue<List<StudentWithSection>> studentsAsync = ref.watch(
      adminAccountsStudentsProvider,
    );
    final AsyncValue<Map<String, List<_TeacherSectionSummary>>>
    teacherSectionsAsync = ref.watch(_teacherSectionAssignmentsProvider);

    final bool dataReady =
        teachersAsync.value != null &&
        studentsAsync.value != null &&
        teacherSectionsAsync.value != null;
    final List<_AccountRow> allRows =
        dataReady
            ? _buildRows(
              teachersAsync.value!,
              studentsAsync.value!,
              teacherSectionsAsync.value!,
            )
            : const <_AccountRow>[];

    return ColoredBox(
      key: const Key('admin_accounts_screen'),
      color: AdultWorkspaceColors.canvas,
      child: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _AccountsPageHeader(),
            if (dataReady) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _AccountOverview(rows: allRows),
            ],
            const SizedBox(height: AppSpacing.lg),
            _FilterBar(
              searchController: _searchController,
              onSearchChanged:
                  (String value) => setState(() => _searchQuery = value),
              roleFilter: _roleFilter,
              onRoleChanged:
                  (_AccountRole? value) => setState(() => _roleFilter = value),
              gradeFilter: _gradeFilter,
              onGradeChanged:
                  (GradeLevel? value) => setState(() {
                    _gradeFilter = value;
                    // A previously-picked section may not belong to the newly
                    // selected grade anymore — clear it rather than silently
                    // keeping an invisible, no-longer-offered filter applied.
                    _sectionFilter = null;
                  }),
              sectionOptions:
                  dataReady
                      ? _sectionFilterOptions(allRows)
                      : const <Section>[],
              sectionFilter: _sectionFilter,
              onSectionChanged:
                  (String? value) => setState(() => _sectionFilter = value),
              statusFilter: _statusFilter,
              onStatusChanged:
                  (_StatusFilter value) =>
                      setState(() => _statusFilter = value),
              activeCount:
                  dataReady
                      ? allRows
                          .where((_AccountRow row) => !row.isArchived)
                          .length
                      : null,
              archivedCount:
                  dataReady
                      ? allRows
                          .where((_AccountRow row) => row.isArchived)
                          .length
                      : null,
              canClear: _hasFilters,
              onClear: _clearFilters,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildBody(teachersAsync, studentsAsync, teacherSectionsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Profile>> teachersAsync,
    AsyncValue<List<StudentWithSection>> studentsAsync,
    AsyncValue<Map<String, List<_TeacherSectionSummary>>> teacherSectionsAsync,
  ) {
    if (teachersAsync.isLoading ||
        studentsAsync.isLoading ||
        teacherSectionsAsync.isLoading) {
      return const _AccountsStateSurface(
        child: AppLoadingIndicator(message: 'Loading account directory'),
      );
    }
    if (teachersAsync.hasError) {
      return _AccountsStateSurface(
        child: AppErrorState(
          message:
              teachersAsync.error is AppFailure
                  ? (teachersAsync.error! as AppFailure).message
                  : 'Could not load teachers.',
          onRetry: () => ref.invalidate(adminAccountsTeachersProvider),
        ),
      );
    }
    if (studentsAsync.hasError) {
      return _AccountsStateSurface(
        child: AppErrorState(
          message:
              studentsAsync.error is AppFailure
                  ? (studentsAsync.error! as AppFailure).message
                  : 'Could not load students.',
          onRetry: () => ref.invalidate(adminAccountsStudentsProvider),
        ),
      );
    }
    if (teacherSectionsAsync.hasError) {
      return _AccountsStateSurface(
        child: AppErrorState(
          message:
              teacherSectionsAsync.error is AppFailure
                  ? (teacherSectionsAsync.error! as AppFailure).message
                  : 'Could not load section assignments.',
          onRetry: () => ref.invalidate(_teacherSectionAssignmentsProvider),
        ),
      );
    }

    final List<_AccountRow> allRows = _buildRows(
      teachersAsync.value!,
      studentsAsync.value!,
      teacherSectionsAsync.value!,
    );
    final List<_AccountRow> rows = _applyFilters(allRows);

    if (rows.isEmpty) {
      final bool directoryIsEmpty = allRows.isEmpty;
      final bool statusIsEmpty = !directoryIsEmpty && !_hasFilters;
      final String emptyTitle =
          directoryIsEmpty
              ? 'No accounts yet'
              : statusIsEmpty
              ? _statusFilter == _StatusFilter.active
                  ? 'No active accounts yet'
                  : 'No archived accounts.'
              : 'No accounts match your filters';
      final String emptyDescription =
          directoryIsEmpty
              ? 'Teacher and Student accounts will appear here.'
              : statusIsEmpty
              ? _statusFilter == _StatusFilter.active
                  ? 'Active teacher and student accounts will appear here.'
                  : 'Accounts you archive will appear here for recovery.'
              : 'Try a different search term or clear the filters.';
      return _AccountsStateSurface(
        child: AppEmptyState(
          icon: Icons.manage_accounts_outlined,
          title: emptyTitle,
          description: emptyDescription,
          actionLabel:
              statusIsEmpty || directoryIsEmpty ? null : 'Clear filters',
          onAction: statusIsEmpty || directoryIsEmpty ? null : _clearFilters,
        ),
      );
    }

    return _AccountDirectory(
      rows: rows,
      statusFilter: _statusFilter,
      pendingIds: _pendingIds,
      onArchiveTeacher: _archiveTeacher,
      onRestoreTeacher: _restoreTeacher,
      onDeleteTeacher: _deleteTeacherPermanently,
      onArchiveStudent: _archiveStudent,
      onRestoreStudent: _restoreStudent,
      onDeleteStudent: _deleteStudentPermanently,
      onEditTeacher: _editTeacher,
      teachers: teachersAsync.value!,
      students: studentsAsync.value!,
    );
  }
}

/// The "Edit User" dialog for a single approved Teacher — Full Name and
/// Email Address only (see this feature's task framing: no Role/Phone/
/// Grade/Section fields here).
///
/// Built as its own [ConsumerStatefulWidget] rather than via
/// `AppDialog.show(...)` directly (the pattern every other dialog in this
/// file uses) because this one needs to stay open and show live state
/// (inline field errors, a loading Save button, a failure snackbar while
/// keeping edits intact) while its own async calls are in flight — a
/// single static `content`/`actions` pair built once at call time, as
/// `AppDialog.show` expects, can't react to that. Wrapping [AppDialog]
/// itself inside a stateful widget keeps the same visual shell (icon,
/// title, content, actions) while allowing `setState` to drive it.
///
/// Note: the reference design calls for a top-right "X" close affordance,
/// which `AppDialog` has no slot for (title/message/content/actions only).
/// Cancel plus the dialog's default `barrierDismissible: true` (tapping
/// outside closes it) cover the same "back out without saving" need, so
/// no X button is rendered here — flagged as a deliberate deviation from
/// the reference image description rather than an oversight.
class _AccountsPageHeader extends StatelessWidget {
  const _AccountsPageHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'ACCOUNT DIRECTORY',
              style: TextStyle(
                color: AdultWorkspaceColors.primaryMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Accounts',
              key: const Key('accounts_page_title'),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Manage teacher and student accounts across BayMath.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AdultWorkspaceColors.secondaryText,
                height: 1.45,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 680) return heading;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AdultWorkspaceColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 17,
                    color: AdultWorkspaceColors.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'IDENTITY & ACCESS',
                    style: TextStyle(
                      color: AdultWorkspaceColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.85,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountOverview extends StatelessWidget {
  const _AccountOverview({required this.rows});

  final List<_AccountRow> rows;

  @override
  Widget build(BuildContext context) {
    final List<_OverviewMetric> metrics = <_OverviewMetric>[
      _OverviewMetric(
        label: 'Total accounts',
        value: rows.length,
        icon: Icons.people_alt_outlined,
      ),
      _OverviewMetric(
        label: 'Teachers',
        value:
            rows
                .where((_AccountRow row) => row.role == _AccountRole.teacher)
                .length,
        icon: Icons.school_outlined,
      ),
      _OverviewMetric(
        label: 'Students',
        value:
            rows
                .where((_AccountRow row) => row.role == _AccountRole.student)
                .length,
        icon: Icons.person_outline_rounded,
      ),
      _OverviewMetric(
        label: 'Archived',
        value: rows.where((_AccountRow row) => row.isArchived).length,
        icon: Icons.inventory_2_outlined,
        muted: true,
      ),
    ];

    return Container(
      key: const Key('accounts_overview'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AdultWorkspaceColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AdultWorkspaceColors.navy.withValues(alpha: 0.035),
            offset: const Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 840) {
            return Wrap(
              children: <Widget>[
                for (final _OverviewMetric metric in metrics)
                  SizedBox(
                    width: constraints.maxWidth / 2,
                    child: _OverviewMetricTile(metric: metric),
                  ),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  int index = 0;
                  index < metrics.length;
                  index++
                ) ...<Widget>[
                  Expanded(child: _OverviewMetricTile(metric: metrics[index])),
                  if (index != metrics.length - 1)
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AdultWorkspaceColors.border,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverviewMetric {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.muted = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool muted;
}

class _OverviewMetricTile extends StatelessWidget {
  const _OverviewMetricTile({required this.metric});

  final _OverviewMetric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  metric.muted
                      ? AdultWorkspaceColors.fieldFill
                      : AdultWorkspaceColors.softBlue,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Icon(
              metric.icon,
              size: 18,
              color:
                  metric.muted
                      ? AdultWorkspaceColors.secondaryText
                      : AdultWorkspaceColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${metric.value}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AdultWorkspaceColors.ink,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdultWorkspaceColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsStateSurface extends StatelessWidget {
  const _AccountsStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AdultWorkspaceColors.border),
      ),
      child: child,
    );
  }
}

class _EditTeacherDialog extends ConsumerStatefulWidget {
  const _EditTeacherDialog({
    required this.teacher,
    required this.onPendingChanged,
  });

  final Profile teacher;

  /// Reports save-in-flight state up to the screen so the same row's
  /// Archive/Restore/Edit buttons can reflect it via the screen's existing
  /// `_pendingIds` set — this widget never touches that set directly.
  final ValueChanged<bool> onPendingChanged;

  @override
  ConsumerState<_EditTeacherDialog> createState() => _EditTeacherDialogState();
}

class _EditTeacherDialogState extends ConsumerState<_EditTeacherDialog> {
  late final TextEditingController _fullNameController = TextEditingController(
    text: widget.teacher.fullName,
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.teacher.email,
  );

  String? _fullNameError;
  String? _emailError;
  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Basic client-side validation only — neither field may be blank, and
  /// email must contain '@'. Real validation (uniqueness, exact format)
  /// stays server-side in `app.update_teacher_full_name`/
  /// `app.update_teacher_email` (0049); this just avoids sending an
  /// obviously-invalid value over the network.
  bool _validate() {
    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();

    setState(() {
      _fullNameError = fullName.isEmpty ? 'Full name is required.' : null;
      _emailError =
          email.isEmpty
              ? 'Email is required.'
              : !email.contains('@')
              ? 'Enter a valid email address.'
              : null;
    });

    return _fullNameError == null && _emailError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    final String newFullName = _fullNameController.text.trim();
    final String newEmail = _emailController.text.trim();
    final bool fullNameChanged = newFullName != widget.teacher.fullName;
    final bool emailChanged = newEmail != widget.teacher.email;

    // Neither field changed — nothing to save, just close.
    if (!fullNameChanged && !emailChanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    widget.onPendingChanged(true);

    bool anySucceeded = false;
    AppFailure? failure;

    if (fullNameChanged) {
      try {
        await ref
            .read(profilesRepositoryProvider)
            .updateTeacherFullName(
              teacherId: widget.teacher.id,
              fullName: newFullName,
            );
        anySucceeded = true;
      } on AppFailure catch (f) {
        failure = f;
      }
    }

    if (emailChanged) {
      try {
        await ref
            .read(profilesRepositoryProvider)
            .updateTeacherEmail(
              teacherId: widget.teacher.id,
              newEmail: newEmail,
            );
        anySucceeded = true;
      } on AppFailure catch (f) {
        // If full name also failed above, this (the later) failure is what
        // gets surfaced — both fields failing in the same save is an edge
        // case rare enough that showing just one message, rather than
        // stacking two snackbars, keeps this simple.
        failure = f;
      }
    }

    widget.onPendingChanged(false);

    // Invalidate whenever at least one call succeeded, so the screen
    // reflects whatever DID save even if the other field's call failed.
    if (anySucceeded) {
      ref.invalidate(adminAccountsTeachersProvider);
      ref.invalidate(teachersListProvider);
      ref.invalidate(processedTeachersListProvider);
    }

    if (!mounted) return;

    if (failure != null) {
      // Keep the dialog open (with the admin's typed values intact) so
      // they can retry or adjust rather than losing their edits.
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    // Fully successful. Capture the messenger before popping — once this
    // dialog's own context is gone, `ScaffoldMessenger.of(context)` can no
    // longer resolve from it, but the already-resolved State object is
    // still valid to call `showSnackBar` on.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Edit User',
      type: AppDialogType.info,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _fullNameController,
            label: 'Full Name *',
            errorText: _fullNameError,
            enabled: !_isSaving,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _emailController,
            label: 'Email Address *',
            errorText: _emailError,
            enabled: !_isSaving,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Save Changes',
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.roleFilter,
    required this.onRoleChanged,
    required this.gradeFilter,
    required this.onGradeChanged,
    required this.sectionOptions,
    required this.sectionFilter,
    required this.onSectionChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.activeCount,
    required this.archivedCount,
    required this.canClear,
    required this.onClear,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final _AccountRole? roleFilter;
  final ValueChanged<_AccountRole?> onRoleChanged;
  final GradeLevel? gradeFilter;
  final ValueChanged<GradeLevel?> onGradeChanged;
  final List<Section> sectionOptions;
  final String? sectionFilter;
  final ValueChanged<String?> onSectionChanged;
  final _StatusFilter statusFilter;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final int? activeCount;
  final int? archivedCount;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('accounts_filter_toolbar'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AdultWorkspaceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget search = AppSearchBar(
                key: const Key('accounts_search_field'),
                controller: searchController,
                hint: 'Search accounts by name',
                size: AppComponentSize.small,
                onChanged: onSearchChanged,
              );
              final Widget status = _StatusSegmentedControl(
                selected: statusFilter,
                activeCount: activeCount,
                archivedCount: archivedCount,
                onChanged: onStatusChanged,
              );
              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    search,
                    const SizedBox(height: AppSpacing.sm),
                    status,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: search),
                  const SizedBox(width: AppSpacing.md),
                  status,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AppDropdown<_AccountRole>(
                key: const Key('accounts_role_filter'),
                label: 'Role',
                width: 150,
                size: AppComponentSize.small,
                selected: roleFilter,
                onChanged: onRoleChanged,
                options: const <AppDropdownOption<_AccountRole>>[
                  AppDropdownOption(value: null, label: 'All Roles'),
                  AppDropdownOption(
                    value: _AccountRole.teacher,
                    label: 'Teacher',
                  ),
                  AppDropdownOption(
                    value: _AccountRole.student,
                    label: 'Student',
                  ),
                ],
              ),
              AppDropdown<GradeLevel>(
                key: const Key('accounts_grade_filter'),
                label: 'Grade level',
                width: 164,
                size: AppComponentSize.small,
                selected: gradeFilter,
                onChanged: onGradeChanged,
                options: <AppDropdownOption<GradeLevel>>[
                  const AppDropdownOption(value: null, label: 'All Grades'),
                  for (final GradeLevel g in GradeLevel.values)
                    AppDropdownOption(value: g, label: g.label),
                ],
              ),
              AppDropdown<String>(
                key: const Key('accounts_section_filter'),
                label: 'Section',
                width: 190,
                size: AppComponentSize.small,
                selected: sectionFilter,
                onChanged: onSectionChanged,
                options: <AppDropdownOption<String>>[
                  const AppDropdownOption(value: null, label: 'All Sections'),
                  for (final Section s in sectionOptions)
                    AppDropdownOption(
                      value: s.id,
                      label: '${s.gradeLevel.label} — ${s.name}',
                    ),
                ],
              ),
              TextButton.icon(
                key: const Key('accounts_clear_filters'),
                onPressed: canClear ? onClear : null,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                label: const Text('Clear filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusSegmentedControl extends StatelessWidget {
  const _StatusSegmentedControl({
    required this.selected,
    required this.activeCount,
    required this.archivedCount,
    required this.onChanged,
  });

  final _StatusFilter selected;
  final int? activeCount;
  final int? archivedCount;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AdultWorkspaceColors.softBlue,
        borderRadius: AppRadius.mediumAll,
        border: Border.all(color: AdultWorkspaceColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StatusSegment(
            key: const Key('accounts_status_active'),
            label: 'Active',
            count: activeCount,
            selected: selected == _StatusFilter.active,
            onTap: () => onChanged(_StatusFilter.active),
          ),
          _StatusSegment(
            key: const Key('accounts_status_archived'),
            label: 'Archived',
            count: archivedCount,
            selected: selected == _StatusFilter.archived,
            onTap: () => onChanged(_StatusFilter.archived),
          ),
        ],
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label accounts${count == null ? '' : ', $count'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smallAll,
          hoverColor: AdultWorkspaceColors.primary.withValues(alpha: 0.08),
          focusColor: AdultWorkspaceColors.primary.withValues(alpha: 0.13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minWidth: 96, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  selected ? AdultWorkspaceColors.primary : Colors.transparent,
              borderRadius: AppRadius.smallAll,
              boxShadow:
                  selected
                      ? <BoxShadow>[
                        BoxShadow(
                          color: AdultWorkspaceColors.primary.withValues(
                            alpha: 0.16,
                          ),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ]
                      : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:
                        selected
                            ? Colors.white
                            : AdultWorkspaceColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (count != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          selected
                              ? Colors.white.withValues(alpha: 0.82)
                              : AdultWorkspaceColors.primaryMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDirectory extends StatelessWidget {
  const _AccountDirectory({
    required this.rows,
    required this.statusFilter,
    required this.pendingIds,
    required this.onArchiveTeacher,
    required this.onRestoreTeacher,
    required this.onDeleteTeacher,
    required this.onArchiveStudent,
    required this.onRestoreStudent,
    required this.onDeleteStudent,
    required this.onEditTeacher,
    required this.teachers,
    required this.students,
  });

  final List<_AccountRow> rows;
  final _StatusFilter statusFilter;
  final Set<String> pendingIds;
  final ValueChanged<Profile> onArchiveTeacher;
  final ValueChanged<Profile> onRestoreTeacher;
  final ValueChanged<Profile> onDeleteTeacher;
  final ValueChanged<Student> onArchiveStudent;
  final ValueChanged<StudentWithSection> onRestoreStudent;
  final ValueChanged<Student> onDeleteStudent;
  final ValueChanged<Profile> onEditTeacher;
  final List<Profile> teachers;
  final List<StudentWithSection> students;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('accounts_directory'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AdultWorkspaceColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AdultWorkspaceColors.navy.withValues(alpha: 0.035),
            offset: const Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 1100;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        statusFilter == _StatusFilter.active
                            ? 'Active accounts'
                            : 'Archived accounts',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AdultWorkspaceColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${rows.length} ${rows.length == 1 ? 'account' : 'accounts'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdultWorkspaceColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) const _AccountTableHeader(),
              const Divider(height: 1, color: AdultWorkspaceColors.border),
              for (int index = 0; index < rows.length; index++) ...<Widget>[
                _AccountRowCard(
                  key: Key('account_row_${rows[index].id}'),
                  row: rows[index],
                  compact: compact,
                  isPending: pendingIds.contains(rows[index].id),
                  onArchiveTeacher: onArchiveTeacher,
                  onRestoreTeacher: onRestoreTeacher,
                  onDeleteTeacher: onDeleteTeacher,
                  onArchiveStudent: onArchiveStudent,
                  onRestoreStudent: onRestoreStudent,
                  onDeleteStudent: onDeleteStudent,
                  onEditTeacher: onEditTeacher,
                  teachers: teachers,
                  students: students,
                ),
                if (index != rows.length - 1)
                  const Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: AdultWorkspaceColors.border,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AccountTableHeader extends StatelessWidget {
  const _AccountTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdultWorkspaceColors.fieldFill,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: const Row(
        children: <Widget>[
          Expanded(flex: 30, child: _TableColumnLabel('Account')),
          Expanded(flex: 12, child: _TableColumnLabel('Role')),
          Expanded(flex: 13, child: _TableColumnLabel('Grade')),
          Expanded(flex: 17, child: _TableColumnLabel('Section')),
          Expanded(flex: 14, child: _TableColumnLabel('Status')),
          SizedBox(
            width: 234,
            child: _TableColumnLabel('Actions', alignEnd: true),
          ),
        ],
      ),
    );
  }
}

class _TableColumnLabel extends StatelessWidget {
  const _TableColumnLabel(this.label, {this.alignEnd = false});

  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: const TextStyle(
        color: AdultWorkspaceColors.secondaryText,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.75,
      ),
    );
  }
}

class _AccountRowCard extends StatelessWidget {
  const _AccountRowCard({
    super.key,
    required this.row,
    required this.compact,
    required this.isPending,
    required this.onArchiveTeacher,
    required this.onRestoreTeacher,
    required this.onDeleteTeacher,
    required this.onArchiveStudent,
    required this.onRestoreStudent,
    required this.onDeleteStudent,
    required this.onEditTeacher,
    required this.teachers,
    required this.students,
  });

  final _AccountRow row;
  final bool compact;
  final bool isPending;
  final ValueChanged<Profile> onArchiveTeacher;
  final ValueChanged<Profile> onRestoreTeacher;
  final ValueChanged<Profile> onDeleteTeacher;
  final ValueChanged<Student> onArchiveStudent;

  /// Takes the row's resolved `StudentWithSection` (not just `Student`) so
  /// the confirm dialog can name the exact section the student will be
  /// re-enrolled into without a second repository lookup.
  final ValueChanged<StudentWithSection> onRestoreStudent;
  final ValueChanged<Student> onDeleteStudent;

  /// Teacher-only. Never invoked for a student row (see [_buildEditButton]'s
  /// `row.role == _AccountRole.teacher` guard) — still required rather than
  /// nullable so every call site is forced to wire it up, matching how the
  /// archive/restore callbacks are handled for both roles even though this
  /// screen shows only one role's action per row at a time.
  final ValueChanged<Profile> onEditTeacher;

  /// Source lists to resolve [row] back to its underlying [Profile]/
  /// [Student] when an action is pressed — rows are a display-only
  /// projection (see [_AccountRow]'s own doc comment), so the action
  /// callbacks need the real model, not just the id, since
  /// `archiveTeacher`/`archiveStudent` etc. all key off it and the
  /// success snackbars need the full name.
  final List<Profile> teachers;
  final List<StudentWithSection> students;

  String _initials(String fullName) {
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

  @override
  Widget build(BuildContext context) {
    return _AccountRowHoverSurface(
      child: Padding(
        padding:
            compact
                ? const EdgeInsets.all(AppSpacing.md)
                : const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: compact ? _buildCompactRow(context) : _buildDesktopRow(context),
      ),
    );
  }

  Widget _buildDesktopRow(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(flex: 30, child: _buildIdentity(context)),
        Expanded(flex: 12, child: _RowValue(_roleLabel)),
        Expanded(flex: 13, child: _RowValue(row.gradeLevelLabel)),
        Expanded(flex: 17, child: _buildSectionValue(context)),
        Expanded(
          flex: 14,
          child: Align(alignment: Alignment.centerLeft, child: _buildStatus()),
        ),
        SizedBox(
          width: 234,
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildActions(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _buildIdentity(context)),
            const SizedBox(width: AppSpacing.sm),
            _buildStatus(),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _CompactAccountDetail(label: 'Role', child: _RowValue(_roleLabel)),
            _CompactAccountDetail(
              label: 'Grade',
              child: _RowValue(row.gradeLevelLabel),
            ),
            _CompactAccountDetail(
              label: 'Section',
              child: _buildSectionValue(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(alignment: Alignment.centerRight, child: _buildActions()),
      ],
    );
  }

  Widget _buildIdentity(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                row.role == _AccountRole.teacher
                    ? AdultWorkspaceColors.softBlue
                    : AdultWorkspaceColors.paleBlue,
            borderRadius: AppRadius.mediumAll,
            border: Border.all(color: AdultWorkspaceColors.border),
          ),
          child: Text(
            _initials(row.name),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AdultWorkspaceColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AdultWorkspaceColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.role == _AccountRole.teacher
                    ? 'Educator account'
                    : 'Learner account',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdultWorkspaceColors.secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionValue(BuildContext context) {
    if (row.additionalSectionLabels.isEmpty) {
      return _RowValue(row.sectionLabel);
    }
    return Row(
      children: <Widget>[
        Flexible(child: _RowValue(row.sectionLabel)),
        const SizedBox(width: AppSpacing.xs),
        Tooltip(
          message:
              'Also assigned to:\n${row.additionalSectionLabels.join('\n')}',
          child: AppBadge(label: '+${row.additionalSectionLabels.length}'),
        ),
      ],
    );
  }

  Widget _buildStatus() {
    final String label =
        row.statusLabel.isEmpty
            ? row.statusLabel
            : '${row.statusLabel[0].toUpperCase()}${row.statusLabel.substring(1)}';
    return AppBadge(label: label, variant: row.statusVariant);
  }

  Widget _buildActions() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (row.isArchived) ...<Widget>[
          _buildRestoreButton(),
          _buildDeleteButton(),
        ] else ...<Widget>[
          if (row.role == _AccountRole.teacher) _buildEditButton(),
          _buildArchiveButton(),
        ],
      ],
    );
  }

  String get _roleLabel =>
      row.role == _AccountRole.teacher ? 'Teacher' : 'Student';

  /// Teacher-only. Visible for every teacher row, but only enabled when
  /// the underlying [Profile.status] is [ProfileStatus.approved] — for any
  /// other status (pending/rejected/suspended/archived), the button is
  /// rendered disabled with an explanatory tooltip rather than hidden
  /// outright, so its presence stays predictable across every teacher row.
  Widget _buildEditButton() {
    final Profile teacher = teachers.firstWhere((t) => t.id == row.id);
    final bool canEdit = teacher.status == ProfileStatus.approved;

    final Widget button = _AccountActionButton(
      label: 'Edit',
      icon: Icons.edit_outlined,
      isLoading: isPending,
      onPressed: (!canEdit || isPending) ? null : () => onEditTeacher(teacher),
    );

    if (canEdit) return button;

    return Tooltip(
      message: 'Only active teachers can be edited.',
      child: button,
    );
  }

  /// Visible for every archived row. For a Teacher row, always enabled —
  /// this feature doesn't touch teacher restore. For a Student row,
  /// disabled (with an explanatory tooltip) whenever
  /// `_AccountRow.studentCanRestore` is false, rather than left enabled to
  /// fail after the click — see [_AccountRow.studentCanRestore]'s own doc
  /// comment for exactly what it checks.
  Widget _buildRestoreButton() {
    final bool ineligible =
        row.role == _AccountRole.student && !row.studentCanRestore;

    final Widget button = _AccountActionButton(
      label: 'Restore',
      icon: Icons.restore_rounded,
      isLoading: isPending,
      onPressed: (ineligible || isPending) ? null : () => _handleRestore(),
    );

    if (!ineligible) return button;

    final String message =
        row.sections.isEmpty
            ? "Can't restore — this student has no section on record."
            : "Can't restore — last section (${row.sectionLabel}) is archived.";

    return Tooltip(message: message, child: button);
  }

  Widget _buildArchiveButton() {
    return _AccountActionButton(
      label: 'Archive',
      icon: Icons.inventory_2_outlined,
      tone: _AccountActionTone.destructive,
      isLoading: isPending,
      onPressed: isPending ? null : _handleArchive,
    );
  }

  Widget _buildDeleteButton() {
    return _AccountActionButton(
      key: Key('delete_account_${row.id}'),
      label: 'Delete permanently',
      icon: Icons.delete_forever_outlined,
      tone: _AccountActionTone.destructive,
      isLoading: isPending,
      onPressed: isPending ? null : _handleDelete,
    );
  }

  void _handleArchive() {
    if (row.role == _AccountRole.teacher) {
      final Profile teacher = teachers.firstWhere((t) => t.id == row.id);
      onArchiveTeacher(teacher);
    } else {
      final Student student =
          students.firstWhere((s) => s.student.id == row.id).student;
      onArchiveStudent(student);
    }
  }

  void _handleRestore() {
    if (row.role == _AccountRole.teacher) {
      final Profile teacher = teachers.firstWhere((t) => t.id == row.id);
      onRestoreTeacher(teacher);
    } else {
      final StudentWithSection studentWithSection = students.firstWhere(
        (s) => s.student.id == row.id,
      );
      onRestoreStudent(studentWithSection);
    }
  }

  void _handleDelete() {
    if (row.role == _AccountRole.teacher) {
      final Profile teacher = teachers.firstWhere((t) => t.id == row.id);
      onDeleteTeacher(teacher);
    } else {
      final Student student =
          students.firstWhere((s) => s.student.id == row.id).student;
      onDeleteStudent(student);
    }
  }
}

class _AccountRowHoverSurface extends StatefulWidget {
  const _AccountRowHoverSurface({required this.child});

  final Widget child;

  @override
  State<_AccountRowHoverSurface> createState() =>
      _AccountRowHoverSurfaceState();
}

class _AccountRowHoverSurfaceState extends State<_AccountRowHoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color:
            _hovered
                ? AdultWorkspaceColors.paleBlue.withValues(alpha: 0.72)
                : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

class _RowValue extends StatelessWidget {
  const _RowValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AdultWorkspaceColors.ink,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
  }
}

class _CompactAccountDetail extends StatelessWidget {
  const _CompactAccountDetail({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AdultWorkspaceColors.secondaryText,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

enum _AccountActionTone { normal, destructive }

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = _AccountActionTone.normal,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _AccountActionTone tone;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Color enabledColor =
        tone == _AccountActionTone.destructive
            ? Theme.of(context).colorScheme.error
            : AdultWorkspaceColors.primaryMuted;
    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: enabledColor,
          disabledForegroundColor: AdultWorkspaceColors.outline,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: enabledColor,
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
      ),
    );
  }
}
