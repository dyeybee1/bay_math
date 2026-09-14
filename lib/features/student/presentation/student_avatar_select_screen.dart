import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/avatar_catalog.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/layout/app_page_container.dart';

/// Shown exactly once, right after a student's first login
/// (`avatar_id is null` — see 0053_student_avatar.sql), before they ever
/// reach [StudentHomeScreen]. Not reachable from anywhere else in the app
/// (no back button, no nav entry) — [_confirm] uses `context.go`, not
/// `context.push`, so it replaces this route rather than leaving it behind
/// on the navigation stack.
class StudentAvatarSelectScreen extends ConsumerStatefulWidget {
  const StudentAvatarSelectScreen({super.key});

  @override
  ConsumerState<StudentAvatarSelectScreen> createState() =>
      _StudentAvatarSelectScreenState();
}

class _StudentAvatarSelectScreenState
    extends ConsumerState<StudentAvatarSelectScreen> {
  String? _selectedId;
  bool _isSaving = false;
  String? _errorText;

  Future<void> _confirm() async {
    final String? selectedId = _selectedId;
    if (selectedId == null) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(studentProfileRepositoryProvider)!.setAvatar(selectedId);
      // So StudentHomeScreen's watch of ownStudentProfileProvider picks up
      // the new avatar right away instead of showing stale (null) data
      // until its own next natural refetch.
      ref.invalidate(ownStudentProfileProvider);
      if (mounted) context.go(AppRoutes.studentHome);
    } on AppFailure catch (failure) {
      setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Pick your avatar!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "This is how you'll show up on your home screen. Choose one you like!",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columnCount = constraints.maxWidth >= 880 ? 6 : 4;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: AvatarCatalog.all.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 112,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final AvatarOption option = AvatarCatalog.all[index];
                    final bool isSelected = option.id == _selectedId;
                    return _AvatarTile(
                      option: option,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedId = option.id),
                    );
                  },
                );
              },
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Confirm',
              isFullWidth: true,
              isLoading: _isSaving,
              onPressed: _selectedId == null ? null : _confirm,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final AvatarOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: option.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
                boxShadow:
                    isSelected
                        ? <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                        : null,
              ),
              child: Icon(option.icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
