import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_enrollment.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../data/student_credentials_pdf_builder.dart';
import 'bulk_add_students_screen.dart';

/// One `student_enrollments` row paired with the resolved [Student] — same
/// separation-of-concerns pattern as `AssignedTeacher`/`MySection`.
class EnrolledStudent {
  const EnrolledStudent(this.enrollment, this.student);
  final StudentEnrollment enrollment;

  /// Null only if the student row was deleted out from under an active
  /// enrollment — students are never hard-deleted (0016), so not expected
  /// in practice, handled rather than assumed.
  final Student? student;
}

/// Currently-enrolled students for one section, paired with their student
/// records — the list this screen is built around.
final enrolledStudentsProvider = FutureProvider.family<List<EnrolledStudent>, String>((
  ref,
  sectionId,
) async {
  final List<StudentEnrollment> enrollments =
      await ref.watch(studentEnrollmentsRepositoryProvider).fetchActiveForSection(sectionId);
  if (enrollments.isEmpty) return const [];

  final List<Student> students = await ref
      .watch(studentsRepositoryProvider)
      .fetchByIds(enrollments.map((e) => e.studentId).toList());
  final Map<String, Student> studentsById = {for (final Student s in students) s.id: s};

  return [for (final StudentEnrollment e in enrollments) EnrolledStudent(e, studentsById[e.studentId])];
});

/// A Teacher's workspace for one section — the only place a student account
/// is ever created (Phase 4 architecture §3/§4: always scoped to a specific
/// section, never a global "add student" form).
class SectionWorkspaceScreen extends ConsumerWidget {
  const SectionWorkspaceScreen({super.key, required this.section});

  final Section section;

  Future<void> _createStudent(BuildContext context, WidgetRef ref) async {
    final _NewStudentFormResult? result = await showDialog<_NewStudentFormResult>(
      context: context,
      builder: (_) => const _NewStudentDialog(),
    );
    if (result == null) return;

    try {
      await ref.read(studentsRepositoryProvider).create(
            username: result.username,
            fullName: result.fullName,
            password: result.password,
            sectionId: section.id,
            studentNumber: result.studentNumber,
          );
      ref.invalidate(enrolledStudentsProvider(section.id));
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  /// Opens the bulk-add flow as a pushed screen (not a dialog — see
  /// `BulkAddStudentsScreen`'s own doc comment for why). That screen
  /// invalidates `enrolledStudentsProvider` itself, the moment any row of
  /// its own result succeeds — nothing to do here on return.
  void _openBulkAddStudents(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => BulkAddStudentsScreen(section: section)));
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, Student student) async {
    final String? newPassword = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(studentName: student.fullName),
    );
    if (newPassword == null) return;

    try {
      await ref
          .read(studentsRepositoryProvider)
          .resetPassword(studentId: student.id, newPassword: newPassword);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Password reset for ${student.fullName}.')));
      }
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _viewPassword(BuildContext context, WidgetRef ref, Student student) async {
    try {
      final String password = await ref.read(studentsRepositoryProvider).viewPassword(student.id);
      if (context.mounted) {
        await AppDialog.show<void>(
          context,
          title: student.fullName,
          type: AppDialogType.info,
          message: 'Current password: $password',
          actions: <Widget>[
            AppButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
          ],
        );
      }
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EnrolledStudent>> students = ref.watch(enrolledStudentsProvider(section.id));

    return Scaffold(
      appBar: AppBar(title: Text('${section.gradeLevel.label} — ${section.name}')),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSectionHeader(
              title: 'Students',
              subtitle: 'Manage student accounts enrolled in this section.',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ExportCredentialsButton(section: section),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Bulk Add Students',
                    leadingIcon: Icons.group_add,
                    variant: AppButtonVariant.outlined,
                    size: AppComponentSize.small,
                    onPressed: () => _openBulkAddStudents(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Add Student',
                    leadingIcon: Icons.person_add_alt_1,
                    size: AppComponentSize.small,
                    onPressed: () => _createStudent(context, ref),
                  ),
                ],
              ),
            ),
            students.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AppLoadingIndicator(),
              ),
              error: (error, _) => AppErrorState(
                message: error is AppFailure ? error.message : 'Could not load students.',
                onRetry: () => ref.invalidate(enrolledStudentsProvider(section.id)),
              ),
              data: (List<EnrolledStudent> list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.school_outlined,
                    title: 'No students yet',
                    description: 'Add the first student account for ${section.name}.',
                    actionLabel: 'Add Student',
                    onAction: () => _createStudent(context, ref),
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final EnrolledStudent enrolled in list)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        header: Text(enrolled.student?.fullName ?? 'Unknown student'),
                        subtitle: Text('@${enrolled.student?.username ?? '—'}'),
                        footer: enrolled.student == null
                            ? null
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  AppButton(
                                    label: 'View Password',
                                    variant: AppButtonVariant.text,
                                    size: AppComponentSize.small,
                                    onPressed: () => _viewPassword(context, ref, enrolled.student!),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  AppButton(
                                    label: 'Reset Password',
                                    variant: AppButtonVariant.outlined,
                                    size: AppComponentSize.small,
                                    onPressed: () => _resetPassword(context, ref, enrolled.student!),
                                  ),
                                ],
                              ),
                        child: const SizedBox.shrink(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Export Credentials" button in the header's action row — reveals and
/// exports every currently-enrolled student's current plaintext password
/// as a cut-able PDF card sheet. Enabled only once
/// `enrolledStudentsProvider(section.id)` has resolved with a non-empty
/// list — same enablement shape `performance_reports_screen.dart`'s own
/// `_ExportReportButton` uses for its own result list.
///
/// A [ConsumerStatefulWidget] (not the stateless `_ExportReportButton`
/// shape this otherwise mirrors) purely because this button needs its own
/// `_isExporting` flag to drive `AppButton.isLoading` across the
/// multi-step confirm -> fetch -> build -> save flow below — the same
/// `_isSubmitting`-on-a-button pattern this codebase already uses
/// elsewhere (e.g. `BulkAddStudentsScreen`), just scoped to a single
/// button instead of a whole screen.
class _ExportCredentialsButton extends ConsumerStatefulWidget {
  const _ExportCredentialsButton({required this.section});

  final Section section;

  @override
  ConsumerState<_ExportCredentialsButton> createState() => _ExportCredentialsButtonState();
}

class _ExportCredentialsButtonState extends ConsumerState<_ExportCredentialsButton> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final List<EnrolledStudent>? students =
        ref.watch(enrolledStudentsProvider(widget.section.id)).value;
    final bool canExport = !_isExporting && students != null && students.isNotEmpty;

    return AppButton(
      label: 'Export Credentials',
      leadingIcon: Icons.badge_outlined,
      variant: AppButtonVariant.outlined,
      size: AppComponentSize.small,
      isLoading: _isExporting,
      onPressed: canExport ? () => _confirmAndExport(context, students) : null,
    );
  }

  Future<void> _confirmAndExport(
    BuildContext context,
    List<EnrolledStudent> students,
  ) async {
    // Only students with a resolved Student row can actually have their
    // password fetched — see EnrolledStudent.student's own doc comment on
    // when this is null (a deleted-out-from-under-an-enrollment edge case,
    // not expected in practice). Counted/confirmed/exported against this
    // filtered list, not the raw enrollment count, so the confirmation
    // dialog's own student count always matches what actually gets
    // fetched below.
    final List<Student> resolvableStudents = <Student>[
      for (final EnrolledStudent enrolled in students)
        if (enrolled.student != null) enrolled.student!,
    ];
    if (resolvableStudents.isEmpty) return;

    // Reveals every currently-enrolled student's password at once and
    // audit-logs one `password_viewed`-style event per student
    // server-side (the existing view-student-password Edge Function's own
    // established per-call behavior) — deserves the same "are you sure"
    // treatment this codebase already gives other deliberate
    // credential-revealing actions (see
    // `BulkAddStudentsScreen._confirmDiscardUnsavedPasswords`), not a
    // silent one-tap export.
    final bool? proceed = await AppDialog.show<bool>(
      context,
      title: 'Export student credentials?',
      type: AppDialogType.warning,
      message:
          'This will reveal and export the current password for every student in this section '
          '(${resolvableStudents.length} students). Continue?',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Continue',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (proceed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isExporting = true);

    try {
      // Fetched fresh every time this button is pressed, discarded the
      // moment the PDF is built (never stored for later reuse) — same
      // "shown/used once" treatment passwords already get elsewhere in
      // this codebase (BulkCreateStudentResult.password's own doc
      // comment).
      //
      // Fetched CONCURRENTLY via Future.wait, not one-at-a-time, so a
      // normal class size's worth of view-student-password calls stays a
      // short wait rather than N sequential round-trips. NOTE: if this
      // project's Edge Function invocation ever turns out to rate-limit
      // under concurrent load, switching this to sequential or
      // small-batch fetching is the fix — nothing in this codebase today
      // suggests a limit that low, so concurrent is the default here.
      //
      // Each fetch catches its OWN failure (returns a nullable
      // "credential or null" pair) rather than letting one bad student
      // abort Future.wait entirely — partial failure is handled below,
      // not treated as a whole-export failure.
      Future<(Student, String?)> fetchOne(Student student) async {
        try {
          final String password = await ref.read(studentsRepositoryProvider).viewPassword(student.id);
          return (student, password);
        } catch (_) {
          return (student, null);
        }
      }

      final List<(Student, String?)> results = await Future.wait(
        <Future<(Student, String?)>>[for (final Student student in resolvableStudents) fetchOne(student)],
      );

      final List<StudentCredential> credentials = <StudentCredential>[];
      final List<String> failedNames = <String>[];
      for (final (Student student, String? password) in results) {
        if (password == null) {
          failedNames.add(student.fullName);
        } else {
          credentials.add(
            StudentCredential(fullName: student.fullName, username: student.username, password: password),
          );
        }
      }

      if (credentials.isEmpty) {
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not fetch any student passwords. Please try again.'),
            ),
          );
        }
        return;
      }

      final String sectionLabel = '${widget.section.gradeLevel.label} — ${widget.section.name}';
      const StudentCredentialsPdfBuilder builder = StudentCredentialsPdfBuilder();
      final Uint8List pdfBytes = await builder.build(
        credentials: credentials,
        sectionLabel: sectionLabel,
      );
      final String defaultFileName = builder.buildFileName(sectionLabel: sectionLabel);

      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Student Credentials',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
      );

      if (savePath == null) {
        if (context.mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Export cancelled.')));
        }
        return;
      }

      final String resolvedPath = savePath.toLowerCase().endsWith('.pdf') ? savePath : '$savePath.pdf';
      await File(resolvedPath).writeAsBytes(pdfBytes);
      final String displayName = resolvedPath.split(Platform.pathSeparator).last;

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Exported to $displayName')));
        if (failedNames.isNotEmpty) {
          // A second, separate snackbar rather than cramming both
          // messages into one — the success message above already
          // dismisses on its own timer; this one names exactly who was
          // skipped so it doesn't get lost.
          messenger.showSnackBar(
            SnackBar(
              content: Text('Skipped (could not fetch password): ${failedNames.join(', ')}'),
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to export student credentials. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _NewStudentFormResult {
  const _NewStudentFormResult({
    required this.username,
    required this.fullName,
    required this.password,
    this.studentNumber,
  });
  final String username;
  final String fullName;
  final String password;
  final String? studentNumber;
}

class _NewStudentDialog extends StatefulWidget {
  const _NewStudentDialog();

  @override
  State<_NewStudentDialog> createState() => _NewStudentDialogState();
}

class _NewStudentDialogState extends State<_NewStudentDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _studentNumberController.dispose();
    super.dispose();
  }

  void _submit() {
    final String username = _usernameController.text.trim();
    final String fullName = _fullNameController.text.trim();
    final String password = _passwordController.text;

    if (username.isEmpty || fullName.isEmpty) {
      setState(() => _errorText = 'Enter a username and full name.');
      return;
    }
    if (password.length < 4) {
      setState(() => _errorText = 'Password must be at least 4 characters.');
      return;
    }

    Navigator.of(context).pop(
      _NewStudentFormResult(
        username: username,
        fullName: fullName,
        password: password,
        studentNumber: _studentNumberController.text.trim().isEmpty
            ? null
            : _studentNumberController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'New Student',
      maxWidth: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(controller: _fullNameController, label: 'Full Name'),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(controller: _usernameController, label: 'Username'),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _passwordController,
            label: 'Initial Password',
            type: AppTextFieldType.password,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _studentNumberController,
            label: 'Student Number (optional)',
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

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.studentName});
  final String studentName;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final String password = _passwordController.text;
    if (password.length < 4) {
      setState(() => _errorText = 'Password must be at least 4 characters.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Reset Password — ${widget.studentName}',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _passwordController,
            label: 'New Password',
            type: AppTextFieldType.password,
            autofocus: true,
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
        AppButton(label: 'Reset', onPressed: _submit),
      ],
    );
  }
}
