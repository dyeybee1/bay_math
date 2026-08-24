import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved StateProvider out of the main barrel file — see the
// same import note in sections_screen.dart.
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/content_source_type.dart';
import '../../../core/models/question_bank_item.dart';
import '../../../core/models/question_choice.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/bm_shared_widgets.dart';
import 'question_form_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers — UNCHANGED
// ─────────────────────────────────────────────────────────────────────────────

/// Current text in the question bank's search field.
final StateProvider<String> questionBankSearchProvider = StateProvider<String>((ref) => '');

final questionBankProvider = FutureProvider<List<QuestionBankItem>>((ref) {
  final String search = ref.watch(questionBankSearchProvider);
  return ref
      .watch(questionBankRepositoryProvider)
      .fetchVisibleToTeacher(search: search.isEmpty ? null : search);
});

// ─────────────────────────────────────────────────────────────────────────────
// QuestionBankScreen
// ─────────────────────────────────────────────────────────────────────────────

class QuestionBankScreen extends ConsumerWidget {
  const QuestionBankScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final SessionState session = ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionTeacher) return;

    final QuestionFormResult? result = await showDialog<QuestionFormResult>(
      context: context,
      builder: (_) => const QuestionFormDialog(),
    );
    if (result == null) return;

    try {
      final String questionId = await ref.read(questionBankRepositoryProvider).create(
            promptText: result.promptText,
            topic: result.topic,
            explanationText: result.explanationText,
            createdBy: session.profile.id,
          );
      await ref
          .read(questionBankRepositoryProvider)
          .replaceChoices(questionId: questionId, choices: result.choices);
      ref.invalidate(questionBankProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, QuestionBankItem item) async {
    final List<QuestionChoice> existingChoices;
    try {
      existingChoices = await ref.read(questionBankRepositoryProvider).fetchChoices([item.id]);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }
    if (!context.mounted) return;

    final QuestionFormResult? result = await showDialog<QuestionFormResult>(
      context: context,
      builder: (_) => QuestionFormDialog(initial: item, initialChoices: existingChoices),
    );
    if (result == null) return;

    try {
      await ref.read(questionBankRepositoryProvider).update(
            questionId: item.id,
            promptText: result.promptText,
            topic: result.topic,
            explanationText: result.explanationText,
          );
      await ref
          .read(questionBankRepositoryProvider)
          .replaceChoices(questionId: item.id, choices: result.choices);
      ref.invalidate(questionBankProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, QuestionBankItem item) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete Question',
      type: AppDialogType.warning,
      message: 'Delete this question? This cannot be undone, and it will be removed from any '
          'quizzes that use it.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Delete',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      await ref.read(questionBankRepositoryProvider).delete(item.id);
      ref.invalidate(questionBankProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QuestionBankItem>> questions = ref.watch(questionBankProvider);

    return Container(
      color: AppColors.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Header ─────────────────────────────────────────────────
            BmPageHeader(
              title: 'Question Bank',
              subtitle: 'Built-in and your own reusable questions.',
              action: BmPrimaryButton(
                label: 'New Question',
                onPressed: () => _create(context, ref),
              ),
            ),
            // ── Search bar ─────────────────────────────────────────────
            _BmSearchBar(
              hint: 'Search questions',
              onChanged: (String value) =>
                  ref.read(questionBankSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: AppSpacing.md),
            // ── List ───────────────────────────────────────────────────
            questions.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AppLoadingIndicator(),
              ),
              error: (error, _) => AppErrorState(
                message: error is AppFailure ? error.message : 'Could not load questions.',
                onRetry: () => ref.invalidate(questionBankProvider),
              ),
              data: (List<QuestionBankItem> list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'No questions found',
                    description: 'Create your first question for the bank.',
                    actionLabel: 'New Question',
                    onAction: () => _create(context, ref),
                  );
                }
                return _QuestionList(
                  items: list,
                  onEdit: (item) => _edit(context, ref, item),
                  onDelete: (item) => _delete(context, ref, item),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned search bar
// ─────────────────────────────────────────────────────────────────────────────

class _BmSearchBar extends StatefulWidget {
  const _BmSearchBar({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_BmSearchBar> createState() => _BmSearchBarState();
}

class _BmSearchBarState extends State<_BmSearchBar> {
  bool _focused = false;
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? AppColors.accent : AppColors.line,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        style: AppTextStyles.inter(size: 14, color: AppColors.navy),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTextStyles.inter(size: 14, color: const Color(0xFFADB5CC)),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: _focused ? AppColors.accent : AppColors.grayText,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dense scrollable list
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionList extends StatelessWidget {
  const _QuestionList({required this.items, required this.onEdit, required this.onDelete});
  final List<QuestionBankItem> items;
  final void Function(QuestionBankItem) onEdit;
  final void Function(QuestionBankItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final QuestionBankItem item in items)
          _QuestionRow(
            item: item,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single question row
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionRow extends StatefulWidget {
  const _QuestionRow({required this.item, required this.onEdit, required this.onDelete});
  final QuestionBankItem item;
  final void Function(QuestionBankItem) onEdit;
  final void Function(QuestionBankItem) onDelete;

  @override
  State<_QuestionRow> createState() => _QuestionRowState();
}

class _QuestionRowState extends State<_QuestionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isBuiltIn = widget.item.sourceType == ContentSourceType.builtIn;
    final bool hasTag = widget.item.topic != null && widget.item.topic!.isNotEmpty;

    // Left-border colour
    final Color borderAccent = isBuiltIn ? AppColors.graySoft : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? const Color(0xFFC8D3EC) : AppColors.line,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _hovered
                    ? AppColors.accent.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hovered ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Left accent border ──────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 4,
                  decoration: BoxDecoration(
                    color: borderAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                // ── Row content ─────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // Left: question text + tag
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                widget.item.promptText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.lexend(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                              if (hasTag) ...<Widget>[
                                const SizedBox(height: 5),
                                _TagChip(label: widget.item.topic!),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right: badge + actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            BmSourceBadge(isBuiltIn: isBuiltIn),
                            if (!isBuiltIn) ...<Widget>[
                              const SizedBox(width: 8),
                              BmIconActionButton(
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit',
                                onPressed: () => widget.onEdit(widget.item),
                              ),
                              const SizedBox(width: 6),
                              BmIconActionButton(
                                icon: Icons.delete_outline_rounded,
                                tooltip: 'Delete',
                                onPressed: () => widget.onDelete(widget.item),
                                isDanger: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag / topic chip — neutral pill, NOT a disabled button
// ─────────────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.graySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.inter(
          size: 12,
          weight: FontWeight.w500,
          color: AppColors.grayText,
        ),
      ),
    );
  }
}
