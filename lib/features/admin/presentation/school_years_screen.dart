import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/school.dart';
import '../../../core/models/school_year.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';

final FutureProvider<School?> defaultSchoolProvider = FutureProvider<School?>((ref) {
  return ref.watch(schoolsRepositoryProvider).fetchFirst();
});

final FutureProvider<List<SchoolYear>> schoolYearsListProvider =
    FutureProvider<List<SchoolYear>>((ref) {
  return ref.watch(schoolYearsRepositoryProvider).fetchAll();
});

class SchoolYearsScreen extends ConsumerWidget {
  const SchoolYearsScreen({super.key});

  Future<void> _createYear(BuildContext context, WidgetRef ref, String schoolId) async {
    final result = await showDialog<_NewYearFormResult>(
      context: context,
      builder: (_) => const _NewSchoolYearDialog(),
    );
    if (result == null) return;

    try {
      await ref.read(schoolYearsRepositoryProvider).create(
            schoolId: schoolId,
            label: result.label,
            startDate: result.startDate,
            endDate: result.endDate,
          );
      ref.invalidate(schoolYearsListProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _setCurrent(WidgetRef ref, BuildContext context, SchoolYear year) async {
    try {
      await ref
          .read(schoolYearsRepositoryProvider)
          .setCurrent(schoolId: year.schoolId, yearId: year.id);
      ref.invalidate(schoolYearsListProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _requestClose(
    WidgetRef ref,
    BuildContext context,
    SchoolYear year,
  ) async {
    final bool? closed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _CloseSchoolYearDialog(
            year: year,
            onClose: () async {
              await ref.read(schoolYearsRepositoryProvider).close(year.id);
              ref.invalidate(schoolYearsListProvider);
            },
          ),
    );

    if (closed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_schoolYearName(year.label)} has been closed successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<School?> school = ref.watch(defaultSchoolProvider);
    final AsyncValue<List<SchoolYear>> years = ref.watch(schoolYearsListProvider);

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          school.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (School? s) => AppSectionHeader(
              title: 'School Years',
              subtitle: s?.name,
              action: s == null
                  ? null
                  : AppButton(
                      label: 'New School Year',
                      leadingIcon: Icons.add,
                      size: AppComponentSize.small,
                      onPressed: () => _createYear(context, ref, s.id),
                    ),
            ),
          ),
          if (school.value == null && !school.isLoading)
            const AppErrorState(
              icon: Icons.domain_disabled_outlined,
              message: 'No school is configured yet. This requires a one-time setup step '
                  '(see the Phase 2 operational notes).',
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
            data: (List<SchoolYear> list) {
              if (list.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No school years yet',
                  description: 'Create the first school year to begin assigning sections.',
                );
              }
              return Column(
                children: <Widget>[
                  for (final SchoolYear year in list)
                    AppCard(
                      header: Text(year.label),
                      trailing: year.isCurrent
                          ? const AppBadge(label: 'Current', variant: AppBadgeVariant.info)
                          : AppBadge(
                              label: year.status.name,
                              variant: year.status == SchoolYearStatus.closed
                                  ? AppBadgeVariant.neutral
                                  : AppBadgeVariant.success,
                            ),
                      footer: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          if (!year.isCurrent && year.status == SchoolYearStatus.active)
                            AppButton(
                              label: 'Set as Current',
                              variant: AppButtonVariant.outlined,
                              size: AppComponentSize.small,
                              onPressed: () => _setCurrent(ref, context, year),
                            ),
                          if (year.status == SchoolYearStatus.active) ...<Widget>[
                            const SizedBox(width: AppSpacing.sm),
                            AppButton(
                              key: Key('close_school_year_${year.id}'),
                              label: 'Close',
                              variant: AppButtonVariant.text,
                              size: AppComponentSize.small,
                              onPressed: () => _requestClose(ref, context, year),
                            ),
                          ],
                        ],
                      ),
                      child: Text(
                        '${_formatDate(year.startDate)} – ${_formatDate(year.endDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _schoolYearName(String label) {
  if (label.toLowerCase().startsWith('school year')) return label;
  return 'School Year $label';
}

class _CloseSchoolYearDialog extends StatefulWidget {
  const _CloseSchoolYearDialog({required this.year, required this.onClose});

  final SchoolYear year;
  final Future<void> Function() onClose;

  @override
  State<_CloseSchoolYearDialog> createState() => _CloseSchoolYearDialogState();
}

class _CloseSchoolYearDialogState extends State<_CloseSchoolYearDialog> {
  final TextEditingController _confirmationController = TextEditingController();

  bool _isClosing = false;
  String? _errorMessage;

  bool get _isConfirmed => _confirmationController.text == 'CLOSE';

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isClosing || !_isConfirmed) return;

    setState(() {
      _isClosing = true;
      _errorMessage = null;
    });

    try {
      await widget.onClose();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isClosing = false;
        _errorMessage = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isClosing = false;
        _errorMessage = 'Could not close this school year. Please try again.';
      });
    }
  }

  void _onSubmitted(String _) {
    if (_isConfirmed && !_isClosing) _submit();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String schoolYearName = _schoolYearName(widget.year.label);

    return PopScope(
      canPop: !_isClosing,
      child: AppDialog(
        title: 'Close School Year?',
        type: AppDialogType.error,
        icon: Icons.event_busy_outlined,
        message:
            'Are you sure you want to close $schoolYearName?\n\n'
            'Closing this school year is a permanent action and cannot be undone.',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Type CLOSE to confirm.',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: const Key('close_school_year_confirmation_field'),
              controller: _confirmationController,
              label: 'Confirmation',
              hint: 'CLOSE',
              autofocus: true,
              enabled: !_isClosing,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _errorMessage = null),
              onSubmitted: _onSubmitted,
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      key: const Key('close_school_year_error'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: <Widget>[
          AppButton(
            key: const Key('cancel_close_school_year'),
            label: 'Cancel',
            variant: AppButtonVariant.text,
            onPressed:
                _isClosing ? null : () => Navigator.of(context).pop(false),
          ),
          AppButton(
            key: const Key('confirm_close_school_year'),
            label: 'Close School Year',
            variant: AppButtonVariant.danger,
            isLoading: _isClosing,
            onPressed: _isConfirmed && !_isClosing ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _NewYearFormResult {
  const _NewYearFormResult({
    required this.label,
    required this.startDate,
    required this.endDate,
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
}

class _NewSchoolYearDialog extends StatefulWidget {
  const _NewSchoolYearDialog();

  @override
  State<_NewSchoolYearDialog> createState() => _NewSchoolYearDialogState();
}

class _NewSchoolYearDialogState extends State<_NewSchoolYearDialog> {
  final TextEditingController _labelController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _errorText;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _submit() {
    final String label = _labelController.text.trim();
    if (label.isEmpty || _startDate == null || _endDate == null) {
      setState(() => _errorText = 'Fill in the label and both dates.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      setState(() => _errorText = 'End date must be after the start date.');
      return;
    }
    Navigator.of(context).pop(
      _NewYearFormResult(label: label, startDate: _startDate!, endDate: _endDate!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'New School Year',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _labelController,
            label: 'Label',
            hint: 'e.g. 2026–2027',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _startDate == null ? 'Pick start date' : 'Start: ${_startDate!.toIso8601String().split('T').first}',
            variant: AppButtonVariant.outlined,
            isFullWidth: true,
            onPressed: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _endDate == null ? 'Pick end date' : 'End: ${_endDate!.toIso8601String().split('T').first}',
            variant: AppButtonVariant.outlined,
            isFullWidth: true,
            onPressed: () => _pickDate(isStart: false),
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
