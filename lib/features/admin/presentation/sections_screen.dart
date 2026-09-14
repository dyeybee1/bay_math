import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved StateProvider out of the main barrel file — it still
// works the same, just needs this separate import now.
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/school_year.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_section.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'school_years_screen.dart' show schoolYearsListProvider;

/// Which school year the Sections screen is currently browsing. Null until
/// the first load resolves a sensible default (the current year, or the
/// most recent one if none is marked current).
final StateProvider<String?> selectedSchoolYearIdProvider =
    StateProvider<String?>((ref) => null);

typedef SectionsQuery = ({String schoolYearId, SectionStatus status});

final sectionsForYearProvider =
    FutureProvider.family<List<Section>, SectionsQuery>((ref, query) {
      return ref
          .watch(sectionsRepositoryProvider)
          .fetchForSchoolYear(query.schoolYearId, status: query.status);
    });

/// Approved Teachers only — the pool eligible for section assignment
/// (`teacher_sections_admin_write`, 0015, does not itself require
/// `status = 'approved'`, but assigning a pending/rejected Teacher to a
/// section would be a dead end in the app's own routing, so the picker
/// only ever offers approved ones).
final FutureProvider<List<Profile>> approvedTeachersProvider =
    FutureProvider<List<Profile>>((ref) {
      return ref
          .watch(profilesRepositoryProvider)
          .fetchTeachers(status: ProfileStatus.approved);
    });

/// One `teacher_sections` row paired with the resolved [Profile] for
/// display — the repository layer intentionally keeps those two concerns
/// separate (no embedded joins), so this pairing happens here instead.
class AssignedTeacher {
  const AssignedTeacher(this.teacherSection, this.profile);
  final TeacherSection teacherSection;

  /// Null only during a concurrent refresh if the profile was removed before
  /// its assignment list reloaded. Migration 0095 narrowly cascades these
  /// pure assignment rows when an eligible Teacher is permanently deleted.
  final Profile? profile;
}

final assignedTeachersProvider = FutureProvider.family<
  List<AssignedTeacher>,
  String
>((ref, sectionId) async {
  final List<TeacherSection> teacherSections = await ref
      .watch(teacherSectionsRepositoryProvider)
      .fetchForSection(sectionId);
  if (teacherSections.isEmpty) return const [];

  final List<Profile> profiles = await ref
      .watch(profilesRepositoryProvider)
      .fetchByIds(teacherSections.map((ts) => ts.teacherId).toList());
  final Map<String, Profile> profilesById = {for (final p in profiles) p.id: p};

  return [
    for (final TeacherSection ts in teacherSections)
      AssignedTeacher(ts, profilesById[ts.teacherId]),
  ];
});

enum _SectionsView { active, archive }

class SectionsScreen extends ConsumerStatefulWidget {
  const SectionsScreen({super.key});

  @override
  ConsumerState<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends ConsumerState<SectionsScreen> {
  _SectionsView _view = _SectionsView.active;
  final Set<String> _pendingIds = <String>{};
  final Set<String> _hiddenFromActive = <String>{};
  final Set<String> _hiddenFromArchive = <String>{};

  String? _resolveDefaultYearId(List<SchoolYear> years) {
    if (years.isEmpty) return null;
    final SchoolYear current = years.firstWhere(
      (y) => y.isCurrent,
      orElse: () => years.first,
    );
    return current.id;
  }

  Future<void> _createSection(String schoolYearId) async {
    final result = await showDialog<_NewSectionFormResult>(
      context: context,
      builder: (_) => const _NewSectionDialog(),
    );
    if (result == null) return;

    try {
      await ref
          .read(sectionsRepositoryProvider)
          .create(
            schoolYearId: schoolYearId,
            gradeLevel: result.gradeLevel,
            name: result.name,
          );
      _invalidateSectionLists(schoolYearId);
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _archive(Section section) async {
    setState(() => _pendingIds.add(section.id));
    try {
      await ref.read(sectionsRepositoryProvider).archive(section.id);
      if (!mounted) return;
      setState(() {
        _hiddenFromActive.add(section.id);
        _hiddenFromArchive.remove(section.id);
      });
      _invalidateSectionLists(section.schoolYearId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section archived successfully.')),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(section.id));
    }
  }

  Future<void> _restore(Section section) async {
    setState(() => _pendingIds.add(section.id));
    try {
      await ref.read(sectionsRepositoryProvider).restore(section.id);
      if (!mounted) return;
      setState(() {
        _hiddenFromArchive.add(section.id);
        _hiddenFromActive.remove(section.id);
      });
      _invalidateSectionLists(section.schoolYearId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section restored successfully.')),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(section.id));
    }
  }

  Future<void> _deletePermanently(Section section) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete this archived section permanently?',
      type: AppDialogType.error,
      message:
          'This will permanently remove the section and any records that depend on it according to the system\'s deletion rules. This action cannot be undone.',
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

    setState(() => _pendingIds.add(section.id));
    try {
      await ref.read(sectionsRepositoryProvider).deletePermanently(section.id);
      if (!mounted) return;
      setState(() {
        _hiddenFromArchive.add(section.id);
        _hiddenFromActive.add(section.id);
      });
      _invalidateSectionLists(section.schoolYearId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section deleted permanently.')),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(section.id));
    }
  }

  void _invalidateSectionLists(String schoolYearId) {
    ref.invalidate(
      sectionsForYearProvider((
        schoolYearId: schoolYearId,
        status: SectionStatus.active,
      )),
    );
    ref.invalidate(
      sectionsForYearProvider((
        schoolYearId: schoolYearId,
        status: SectionStatus.archived,
      )),
    );
  }

  Future<void> _manageTeachers(Section section) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ManageTeachersDialog(section: section),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SchoolYear>> years = ref.watch(
      schoolYearsListProvider,
    );

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: 'Sections',
            subtitle: 'Organize students by grade level within a school year.',
            action: _SectionsViewControl(
              selected: _view,
              onChanged: (_SectionsView view) => setState(() => _view = view),
            ),
          ),
          years.when(
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
                          : 'Could not load school years.',
                  onRetry: () => ref.invalidate(schoolYearsListProvider),
                ),
            data: (List<SchoolYear> yearList) {
              if (yearList.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No school years yet',
                  description:
                      'Create a school year first, then add sections to it.',
                );
              }

              final String selectedYearId =
                  ref.watch(selectedSchoolYearIdProvider) ??
                  _resolveDefaultYearId(yearList)!;
              final SchoolYear selectedYear = yearList.firstWhere(
                (y) => y.id == selectedYearId,
                orElse: () => yearList.first,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownMenu<String>(
                          initialSelection: selectedYear.id,
                          label: const Text('School Year'),
                          onSelected: (String? id) {
                            if (id != null) {
                              ref
                                  .read(selectedSchoolYearIdProvider.notifier)
                                  .state = id;
                            }
                          },
                          dropdownMenuEntries: [
                            for (final SchoolYear y in yearList)
                              DropdownMenuEntry<String>(
                                value: y.id,
                                label:
                                    y.isCurrent
                                        ? '${y.label} (Current)'
                                        : y.label,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (_view == _SectionsView.active)
                        AppButton(
                          label: 'New Section',
                          leadingIcon: Icons.add,
                          onPressed: () => _createSection(selectedYear.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionsList(
                    schoolYearId: selectedYear.id,
                    status:
                        _view == _SectionsView.active
                            ? SectionStatus.active
                            : SectionStatus.archived,
                    hiddenIds:
                        _view == _SectionsView.active
                            ? _hiddenFromActive
                            : _hiddenFromArchive,
                    pendingIds: _pendingIds,
                    onArchive: _archive,
                    onRestore: _restore,
                    onDeletePermanently: _deletePermanently,
                    onManageTeachers: _manageTeachers,
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

class _SectionsList extends ConsumerWidget {
  const _SectionsList({
    required this.schoolYearId,
    required this.status,
    required this.hiddenIds,
    required this.pendingIds,
    required this.onArchive,
    required this.onRestore,
    required this.onDeletePermanently,
    required this.onManageTeachers,
  });

  final String schoolYearId;
  final SectionStatus status;
  final Set<String> hiddenIds;
  final Set<String> pendingIds;
  final ValueChanged<Section> onArchive;
  final ValueChanged<Section> onRestore;
  final ValueChanged<Section> onDeletePermanently;
  final ValueChanged<Section> onManageTeachers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SectionsQuery query = (schoolYearId: schoolYearId, status: status);
    final AsyncValue<List<Section>> sections = ref.watch(
      sectionsForYearProvider(query),
    );

    return sections.when(
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
                    : 'Could not load sections.',
            onRetry: () => ref.invalidate(sectionsForYearProvider(query)),
          ),
      data: (List<Section> list) {
        final List<Section> visible =
            list
                .where(
                  (Section section) =>
                      section.status == status &&
                      !hiddenIds.contains(section.id),
                )
                .toList();
        if (visible.isEmpty) {
          return AppEmptyState(
            icon:
                status == SectionStatus.active
                    ? Icons.groups_outlined
                    : Icons.inventory_2_outlined,
            title:
                status == SectionStatus.active
                    ? 'No active sections.'
                    : 'No archived sections.',
            description:
                status == SectionStatus.active
                    ? 'Create the first section for this school year.'
                    : 'Sections you archive will appear here.',
          );
        }
        return Column(
          children: <Widget>[
            for (final Section section in visible)
              AppCard(
                key: Key('section_card_${section.id}'),
                header: Text('${section.gradeLevel.label} — ${section.name}'),
                trailing: AppBadge(
                  label:
                      section.status == SectionStatus.active
                          ? 'Active'
                          : 'Archived',
                  variant:
                      section.status == SectionStatus.active
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.neutral,
                ),
                footer: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    if (section.status == SectionStatus.active) ...<Widget>[
                      AppButton(
                        label: 'Manage Teachers',
                        variant: AppButtonVariant.outlined,
                        size: AppComponentSize.small,
                        onPressed:
                            pendingIds.contains(section.id)
                                ? null
                                : () => onManageTeachers(section),
                      ),
                      AppButton(
                        key: Key('archive_section_${section.id}'),
                        label: 'Archive',
                        variant: AppButtonVariant.text,
                        size: AppComponentSize.small,
                        isLoading: pendingIds.contains(section.id),
                        onPressed: () => onArchive(section),
                      ),
                    ] else ...<Widget>[
                      AppButton(
                        key: Key('restore_section_${section.id}'),
                        label: 'Restore',
                        variant: AppButtonVariant.outlined,
                        size: AppComponentSize.small,
                        onPressed:
                            pendingIds.contains(section.id)
                                ? null
                                : () => onRestore(section),
                      ),
                      AppButton(
                        key: Key('delete_section_${section.id}'),
                        label: 'Delete permanently',
                        variant: AppButtonVariant.danger,
                        size: AppComponentSize.small,
                        isLoading: pendingIds.contains(section.id),
                        onPressed: () => onDeletePermanently(section),
                      ),
                    ],
                  ],
                ),
                child: const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }
}

class _SectionsViewControl extends StatelessWidget {
  const _SectionsViewControl({required this.selected, required this.onChanged});

  final _SectionsView selected;
  final ValueChanged<_SectionsView> onChanged;

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
          _SectionsViewButton(
            key: const Key('sections_view_active'),
            label: 'Active Sections',
            selected: selected == _SectionsView.active,
            onTap: () => onChanged(_SectionsView.active),
          ),
          _SectionsViewButton(
            key: const Key('sections_view_archive'),
            label: 'Archive',
            selected: selected == _SectionsView.archive,
            onTap: () => onChanged(_SectionsView.archive),
          ),
        ],
      ),
    );
  }
}

class _SectionsViewButton extends StatelessWidget {
  const _SectionsViewButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smallAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  selected ? AdultWorkspaceColors.primary : Colors.transparent,
              borderRadius: AppRadius.smallAll,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color:
                    selected
                        ? Colors.white
                        : AdultWorkspaceColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewSectionFormResult {
  const _NewSectionFormResult({required this.gradeLevel, required this.name});
  final GradeLevel gradeLevel;
  final String name;
}

class _NewSectionDialog extends StatefulWidget {
  const _NewSectionDialog();

  @override
  State<_NewSectionDialog> createState() => _NewSectionDialogState();
}

class _NewSectionDialogState extends State<_NewSectionDialog> {
  final TextEditingController _nameController = TextEditingController();
  GradeLevel _gradeLevel = GradeLevel.grade4;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a section name.');
      return;
    }
    Navigator.of(
      context,
    ).pop(_NewSectionFormResult(gradeLevel: _gradeLevel, name: name));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'New Section',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownMenu<GradeLevel>(
            initialSelection: _gradeLevel,
            label: const Text('Grade Level'),
            onSelected: (GradeLevel? value) {
              if (value != null) setState(() => _gradeLevel = value);
            },
            dropdownMenuEntries: [
              for (final GradeLevel g in GradeLevel.values)
                DropdownMenuEntry<GradeLevel>(value: g, label: g.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            label: 'Section Name',
            hint: 'e.g. Sampaguita',
          ),
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Create', onPressed: _submit),
      ],
    );
  }
}

class _ManageTeachersDialog extends ConsumerStatefulWidget {
  const _ManageTeachersDialog({required this.section});
  final Section section;

  @override
  ConsumerState<_ManageTeachersDialog> createState() =>
      _ManageTeachersDialogState();
}

class _ManageTeachersDialogState extends ConsumerState<_ManageTeachersDialog> {
  String? _pickedTeacherId;
  bool _assignAsPrimary = false;

  Future<void> _assign() async {
    final String? teacherId = _pickedTeacherId;
    if (teacherId == null) return;

    final SessionState session =
        ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionAdmin) return;

    try {
      await ref
          .read(teacherSectionsRepositoryProvider)
          .assignTeacher(
            sectionId: widget.section.id,
            teacherId: teacherId,
            isPrimary: _assignAsPrimary,
            assignedByAdminId: session.profile.id,
          );
      ref.invalidate(assignedTeachersProvider(widget.section.id));
      setState(() {
        _pickedTeacherId = null;
        _assignAsPrimary = false;
      });
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _setPrimary(TeacherSection ts) async {
    try {
      await ref
          .read(teacherSectionsRepositoryProvider)
          .setPrimary(teacherSectionId: ts.id, sectionId: widget.section.id);
      ref.invalidate(assignedTeachersProvider(widget.section.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _unassign(TeacherSection ts) async {
    try {
      await ref.read(teacherSectionsRepositoryProvider).unassign(ts.id);
      ref.invalidate(assignedTeachersProvider(widget.section.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AssignedTeacher>> assigned = ref.watch(
      assignedTeachersProvider(widget.section.id),
    );
    final AsyncValue<List<Profile>> approvedTeachers = ref.watch(
      approvedTeachersProvider,
    );

    return AppDialog(
      title:
          'Manage Teachers — ${widget.section.gradeLevel.label} ${widget.section.name}',
      maxWidth: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          assigned.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: AppLoadingIndicator(),
                ),
            error:
                (error, _) => AppErrorState(
                  message:
                      error is AppFailure
                          ? error.message
                          : 'Could not load assigned teachers.',
                  onRetry:
                      () => ref.invalidate(
                        assignedTeachersProvider(widget.section.id),
                      ),
                ),
            data: (List<AssignedTeacher> list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No teachers assigned to this section yet.'),
                );
              }
              return Column(
                children: <Widget>[
                  for (final AssignedTeacher at in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(at.profile?.fullName ?? 'Unknown teacher'),
                      subtitle: Text(
                        at.profile?.email ?? at.teacherSection.teacherId,
                      ),
                      leading:
                          at.teacherSection.isPrimary
                              ? const AppBadge(
                                label: 'Primary',
                                variant: AppBadgeVariant.info,
                              )
                              : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (!at.teacherSection.isPrimary)
                            IconButton(
                              icon: const Icon(Icons.star_outline),
                              tooltip: 'Make primary',
                              onPressed: () => _setPrimary(at.teacherSection),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove',
                            onPressed: () => _unassign(at.teacherSection),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(height: AppSpacing.xl),
          Text(
            'Assign a Teacher',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          approvedTeachers.when(
            loading: () => const AppLoadingIndicator(),
            error:
                (error, _) => AppErrorState(
                  message:
                      error is AppFailure
                          ? error.message
                          : 'Could not load teachers.',
                  onRetry: () => ref.invalidate(approvedTeachersProvider),
                ),
            data: (List<Profile> teachers) {
              final List<Profile> alreadyAssignedFiltered =
                  teachers
                      .where(
                        (t) =>
                            !(assigned.value ?? const []).any(
                              (at) => at.teacherSection.teacherId == t.id,
                            ),
                      )
                      .toList();

              if (alreadyAssignedFiltered.isEmpty) {
                return const Text(
                  'No more approved teachers available to assign.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownMenu<String>(
                    label: const Text('Teacher'),
                    onSelected:
                        (String? id) => setState(() => _pickedTeacherId = id),
                    dropdownMenuEntries: [
                      for (final Profile t in alreadyAssignedFiltered)
                        DropdownMenuEntry<String>(
                          value: t.id,
                          label: t.fullName,
                        ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _assignAsPrimary,
                    title: const Text('Assign as primary teacher'),
                    onChanged:
                        (bool? value) =>
                            setState(() => _assignAsPrimary = value ?? false),
                  ),
                  AppButton(
                    label: 'Assign',
                    leadingIcon: Icons.person_add_alt_1,
                    onPressed: _pickedTeacherId == null ? null : _assign,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton(
          label: 'Done',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
