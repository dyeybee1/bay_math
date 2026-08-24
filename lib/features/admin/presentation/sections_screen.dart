import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved StateProvider out of the main barrel file — it still
// works the same, just needs this separate import now.
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/constants/app_spacing.dart';
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
final StateProvider<String?> selectedSchoolYearIdProvider = StateProvider<String?>((ref) => null);

final sectionsForYearProvider = FutureProvider.family<List<Section>, String>((ref, schoolYearId) {
  return ref.watch(sectionsRepositoryProvider).fetchForSchoolYear(schoolYearId);
});

/// Approved Teachers only — the pool eligible for section assignment
/// (`teacher_sections_admin_write`, 0015, does not itself require
/// `status = 'approved'`, but assigning a pending/rejected Teacher to a
/// section would be a dead end in the app's own routing, so the picker
/// only ever offers approved ones).
final FutureProvider<List<Profile>> approvedTeachersProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(profilesRepositoryProvider).fetchTeachers(status: ProfileStatus.approved);
});

/// One `teacher_sections` row paired with the resolved [Profile] for
/// display — the repository layer intentionally keeps those two concerns
/// separate (no embedded joins), so this pairing happens here instead.
class AssignedTeacher {
  const AssignedTeacher(this.teacherSection, this.profile);
  final TeacherSection teacherSection;

  /// Null only if the profile row was deleted out from under an existing
  /// assignment — not expected in practice (profiles are never hard-deleted
  /// except by Admin, and `teacher_sections.teacher_id` is `ON DELETE
  /// RESTRICT`), but handled rather than assumed.
  final Profile? profile;
}

final assignedTeachersProvider =
    FutureProvider.family<List<AssignedTeacher>, String>((ref, sectionId) async {
  final List<TeacherSection> teacherSections =
      await ref.watch(teacherSectionsRepositoryProvider).fetchForSection(sectionId);
  if (teacherSections.isEmpty) return const [];

  final List<Profile> profiles = await ref
      .watch(profilesRepositoryProvider)
      .fetchByIds(teacherSections.map((ts) => ts.teacherId).toList());
  final Map<String, Profile> profilesById = {for (final p in profiles) p.id: p};

  return [
    for (final TeacherSection ts in teacherSections) AssignedTeacher(ts, profilesById[ts.teacherId]),
  ];
});

class SectionsScreen extends ConsumerWidget {
  const SectionsScreen({super.key});

  String? _resolveDefaultYearId(List<SchoolYear> years) {
    if (years.isEmpty) return null;
    final SchoolYear current = years.firstWhere(
      (y) => y.isCurrent,
      orElse: () => years.first,
    );
    return current.id;
  }

  Future<void> _createSection(BuildContext context, WidgetRef ref, String schoolYearId) async {
    final result = await showDialog<_NewSectionFormResult>(
      context: context,
      builder: (_) => const _NewSectionDialog(),
    );
    if (result == null) return;

    try {
      await ref.read(sectionsRepositoryProvider).create(
            schoolYearId: schoolYearId,
            gradeLevel: result.gradeLevel,
            name: result.name,
          );
      ref.invalidate(sectionsForYearProvider(schoolYearId));
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _archive(WidgetRef ref, BuildContext context, Section section) async {
    try {
      await ref.read(sectionsRepositoryProvider).archive(section.id);
      ref.invalidate(sectionsForYearProvider(section.schoolYearId));
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _restore(WidgetRef ref, BuildContext context, Section section) async {
    try {
      await ref.read(sectionsRepositoryProvider).restore(section.id);
      ref.invalidate(sectionsForYearProvider(section.schoolYearId));
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _manageTeachers(BuildContext context, WidgetRef ref, Section section) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ManageTeachersDialog(section: section),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SchoolYear>> years = ref.watch(schoolYearsListProvider);

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppSectionHeader(
            title: 'Sections',
            subtitle: 'Organize students by grade level within a school year.',
          ),
          years.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: AppLoadingIndicator(),
            ),
            error: (error, _) => AppErrorState(
              message: error is AppFailure ? error.message : 'Could not load school years.',
              onRetry: () => ref.invalidate(schoolYearsListProvider),
            ),
            data: (List<SchoolYear> yearList) {
              if (yearList.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No school years yet',
                  description: 'Create a school year first, then add sections to it.',
                );
              }

              final String selectedYearId =
                  ref.watch(selectedSchoolYearIdProvider) ?? _resolveDefaultYearId(yearList)!;
              final SchoolYear selectedYear =
                  yearList.firstWhere((y) => y.id == selectedYearId, orElse: () => yearList.first);

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
                              ref.read(selectedSchoolYearIdProvider.notifier).state = id;
                            }
                          },
                          dropdownMenuEntries: [
                            for (final SchoolYear y in yearList)
                              DropdownMenuEntry<String>(
                                value: y.id,
                                label: y.isCurrent ? '${y.label} (Current)' : y.label,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: 'New Section',
                        leadingIcon: Icons.add,
                        onPressed: () => _createSection(context, ref, selectedYear.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionsList(
                    schoolYearId: selectedYear.id,
                    onArchive: (section) => _archive(ref, context, section),
                    onRestore: (section) => _restore(ref, context, section),
                    onManageTeachers: (section) => _manageTeachers(context, ref, section),
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
    required this.onArchive,
    required this.onRestore,
    required this.onManageTeachers,
  });

  final String schoolYearId;
  final ValueChanged<Section> onArchive;
  final ValueChanged<Section> onRestore;
  final ValueChanged<Section> onManageTeachers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Section>> sections = ref.watch(sectionsForYearProvider(schoolYearId));

    return sections.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      ),
      error: (error, _) => AppErrorState(
        message: error is AppFailure ? error.message : 'Could not load sections.',
        onRetry: () => ref.invalidate(sectionsForYearProvider(schoolYearId)),
      ),
      data: (List<Section> list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: Icons.groups_outlined,
            title: 'No sections yet',
            description: 'Create the first section for this school year.',
          );
        }
        return Column(
          children: <Widget>[
            for (final Section section in list)
              AppCard(
                header: Text('${section.gradeLevel.label} — ${section.name}'),
                trailing: AppBadge(
                  label: section.status.name,
                  variant: section.status == SectionStatus.active
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                ),
                footer: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    AppButton(
                      label: 'Manage Teachers',
                      variant: AppButtonVariant.outlined,
                      size: AppComponentSize.small,
                      onPressed: () => onManageTeachers(section),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (section.status == SectionStatus.active)
                      AppButton(
                        label: 'Archive',
                        variant: AppButtonVariant.text,
                        size: AppComponentSize.small,
                        onPressed: () => onArchive(section),
                      )
                    else
                      AppButton(
                        label: 'Restore',
                        variant: AppButtonVariant.text,
                        size: AppComponentSize.small,
                        onPressed: () => onRestore(section),
                      ),
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
    Navigator.of(context).pop(_NewSectionFormResult(gradeLevel: _gradeLevel, name: name));
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
            Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
  ConsumerState<_ManageTeachersDialog> createState() => _ManageTeachersDialogState();
}

class _ManageTeachersDialogState extends ConsumerState<_ManageTeachersDialog> {
  String? _pickedTeacherId;
  bool _assignAsPrimary = false;

  Future<void> _assign() async {
    final String? teacherId = _pickedTeacherId;
    if (teacherId == null) return;

    final SessionState session = ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionAdmin) return;

    try {
      await ref.read(teacherSectionsRepositoryProvider).assignTeacher(
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _unassign(TeacherSection ts) async {
    try {
      await ref.read(teacherSectionsRepositoryProvider).unassign(ts.id);
      ref.invalidate(assignedTeachersProvider(widget.section.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AssignedTeacher>> assigned =
        ref.watch(assignedTeachersProvider(widget.section.id));
    final AsyncValue<List<Profile>> approvedTeachers = ref.watch(approvedTeachersProvider);

    return AppDialog(
      title: 'Manage Teachers — ${widget.section.gradeLevel.label} ${widget.section.name}',
      maxWidth: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          assigned.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingIndicator(),
            ),
            error: (error, _) => AppErrorState(
              message: error is AppFailure ? error.message : 'Could not load assigned teachers.',
              onRetry: () => ref.invalidate(assignedTeachersProvider(widget.section.id)),
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
                      subtitle: Text(at.profile?.email ?? at.teacherSection.teacherId),
                      leading: at.teacherSection.isPrimary
                          ? const AppBadge(label: 'Primary', variant: AppBadgeVariant.info)
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
          Text('Assign a Teacher', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          approvedTeachers.when(
            loading: () => const AppLoadingIndicator(),
            error: (error, _) => AppErrorState(
              message: error is AppFailure ? error.message : 'Could not load teachers.',
              onRetry: () => ref.invalidate(approvedTeachersProvider),
            ),
            data: (List<Profile> teachers) {
              final List<Profile> alreadyAssignedFiltered = teachers
                  .where((t) => !(assigned.value ?? const [])
                      .any((at) => at.teacherSection.teacherId == t.id))
                  .toList();

              if (alreadyAssignedFiltered.isEmpty) {
                return const Text('No more approved teachers available to assign.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownMenu<String>(
                    label: const Text('Teacher'),
                    onSelected: (String? id) => setState(() => _pickedTeacherId = id),
                    dropdownMenuEntries: [
                      for (final Profile t in alreadyAssignedFiltered)
                        DropdownMenuEntry<String>(value: t.id, label: t.fullName),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _assignAsPrimary,
                    title: const Text('Assign as primary teacher'),
                    onChanged: (bool? value) => setState(() => _assignAsPrimary = value ?? false),
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
