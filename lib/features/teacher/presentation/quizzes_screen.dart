import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/content_source_type.dart';
import '../../../core/models/question_bank_item.dart';
import '../../../core/models/question_choice.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_question.dart';
import '../../../core/models/section.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'question_bank_screen.dart' show questionBankProvider;
import 'question_form_dialog.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

/// Built-in quizzes (Internal + External Activity) plus the calling
/// Teacher's own.
final quizzesProvider = FutureProvider<List<Quiz>>((ref) {
  return ref.watch(quizzesRepositoryProvider).fetchVisibleToTeacher();
});

final quizSectionIdsProvider = FutureProvider.family<List<String>, String>((ref, quizId) {
  return ref.watch(quizzesRepositoryProvider).fetchSectionIds(quizId);
});

final quizQuestionsProvider = FutureProvider.family<List<QuizQuestion>, String>((ref, quizId) {
  return ref.watch(quizQuestionsRepositoryProvider).fetchForQuiz(quizId);
});

/// Every question visible to the calling Teacher (built-in + own),
/// unfiltered by search — used to resolve prompt text for questions
/// already in a quiz, and as the base candidate list for the question
/// picker. Deliberately separate from `question_bank_screen.dart`'s
/// `questionBankProvider`, which depends on that screen's own search
/// field state — reusing it here would make this screen's question list
/// silently depend on whatever search term happens to be active on the
/// Question Bank tab (both tabs stay alive at once under the shell's
/// `IndexedStack`).
final allVisibleQuestionsProvider = FutureProvider<List<QuestionBankItem>>((ref) {
  return ref.watch(questionBankRepositoryProvider).fetchVisibleToTeacher();
});

class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final SessionState session = ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionTeacher) return;

    final _NewQuizFormResult? result = await showDialog<_NewQuizFormResult>(
      context: context,
      builder: (_) => const _NewQuizDialog(),
    );
    if (result == null) return;

    try {
      await ref.read(quizzesRepositoryProvider).create(
            title: result.title,
            quizType: result.quizType,
            createdBy: session.profile.id,
            externalUrl: result.externalUrl,
            externalPlatformHint: result.externalPlatformHint,
            shuffleQuestions: result.shuffleQuestions,
            shuffleChoices: result.shuffleChoices,
          );
      ref.invalidate(quizzesProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Quiz quiz) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete Quiz',
      type: AppDialogType.warning,
      message: 'Delete "${quiz.title}"? This cannot be undone.',
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
      await ref.read(quizzesRepositoryProvider).delete(quiz.id);
      ref.invalidate(quizzesProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Quiz>> quizzes = ref.watch(quizzesProvider);

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: 'Quizzes',
            subtitle: 'Built-in and your own Internal Quizzes and External Activities.',
            action: AppButton(
              label: 'New Quiz',
              leadingIcon: Icons.add,
              size: AppComponentSize.small,
              onPressed: () => _create(context, ref),
            ),
          ),
          quizzes.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: AppLoadingIndicator(),
            ),
            error: (error, _) => AppErrorState(
              message: error is AppFailure ? error.message : 'Could not load quizzes.',
              onRetry: () => ref.invalidate(quizzesProvider),
            ),
            data: (List<Quiz> list) {
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No quizzes yet',
                  description: 'Create your first Internal Quiz or External Activity.',
                  actionLabel: 'New Quiz',
                  onAction: () => _create(context, ref),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Quiz quiz in list)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      header: Text(quiz.title),
                      subtitle: Text(quiz.quizType.label),
                      trailing: AppBadge(
                        label: quiz.sourceType.label,
                        variant: quiz.sourceType == ContentSourceType.builtIn
                            ? AppBadgeVariant.neutral
                            : AppBadgeVariant.info,
                      ),
                      footer: quiz.sourceType == ContentSourceType.builtIn
                          ? null
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                AppButton(
                                  label: 'Manage',
                                  variant: AppButtonVariant.outlined,
                                  size: AppComponentSize.small,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => QuizEditScreen(quiz: quiz),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppButton(
                                  label: 'Delete',
                                  variant: AppButtonVariant.text,
                                  size: AppComponentSize.small,
                                  onPressed: () => _delete(context, ref, quiz),
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
    );
  }
}

class _NewQuizFormResult {
  const _NewQuizFormResult({
    required this.title,
    required this.quizType,
    this.externalUrl,
    this.externalPlatformHint,
    required this.shuffleQuestions,
    required this.shuffleChoices,
  });
  final String title;
  final QuizType quizType;
  final String? externalUrl;
  final ExternalPlatformHint? externalPlatformHint;
  final bool shuffleQuestions;
  final bool shuffleChoices;
}

class _NewQuizDialog extends StatefulWidget {
  const _NewQuizDialog();

  @override
  State<_NewQuizDialog> createState() => _NewQuizDialogState();
}

class _NewQuizDialogState extends State<_NewQuizDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  QuizType _quizType = QuizType.internal;
  ExternalPlatformHint? _platformHint;
  bool _shuffleQuestions = true;
  bool _shuffleChoices = true;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = 'Enter a title.');
      return;
    }

    String? externalUrl;
    if (_quizType == QuizType.externalActivity) {
      externalUrl = _urlController.text.trim();
      if (!externalUrl.startsWith('https://')) {
        setState(() => _errorText = 'External Activities need an https:// URL.');
        return;
      }
    }

    Navigator.of(context).pop(
      _NewQuizFormResult(
        title: title,
        quizType: _quizType,
        externalUrl: externalUrl,
        externalPlatformHint: _quizType == QuizType.externalActivity ? _platformHint : null,
        shuffleQuestions: _shuffleQuestions,
        shuffleChoices: _shuffleChoices,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'New Quiz',
      maxWidth: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownMenu<QuizType>(
            initialSelection: _quizType,
            label: const Text('Type'),
            onSelected: (QuizType? value) {
              if (value != null) setState(() => _quizType = value);
            },
            dropdownMenuEntries: [
              for (final QuizType t in QuizType.values)
                DropdownMenuEntry<QuizType>(value: t, label: t.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(controller: _titleController, label: 'Title'),
          if (_quizType == QuizType.externalActivity) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _urlController,
              label: 'URL',
              hint: 'https://...',
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownMenu<ExternalPlatformHint?>(
              initialSelection: _platformHint,
              label: const Text('Platform (optional)'),
              onSelected: (ExternalPlatformHint? value) => setState(() => _platformHint = value),
              dropdownMenuEntries: [
                const DropdownMenuEntry<ExternalPlatformHint?>(value: null, label: 'None'),
                for (final ExternalPlatformHint h in ExternalPlatformHint.values)
                  DropdownMenuEntry<ExternalPlatformHint?>(value: h, label: h.label),
              ],
            ),
          ],
          if (_quizType == QuizType.internal) ...<Widget>[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _shuffleQuestions,
              title: const Text('Shuffle questions'),
              onChanged: (bool? value) => setState(() => _shuffleQuestions = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _shuffleChoices,
              title: const Text('Shuffle choices'),
              onChanged: (bool? value) => setState(() => _shuffleChoices = value ?? true),
            ),
          ],
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

/// A Teacher's editor for one owned quiz: meta fields, section assignment,
/// and — for Internal Quizzes — the question picker. Reached via
/// `Navigator.push` from `QuizzesScreen`, mirroring how
/// `SectionWorkspaceScreen` is reached from "My Sections".
class QuizEditScreen extends ConsumerStatefulWidget {
  const QuizEditScreen({super.key, required this.quiz});
  final Quiz quiz;

  @override
  ConsumerState<QuizEditScreen> createState() => _QuizEditScreenState();
}

class _QuizEditScreenState extends ConsumerState<QuizEditScreen> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.quiz.title);
  late final TextEditingController _urlController =
      TextEditingController(text: widget.quiz.externalUrl ?? '');
  late ExternalPlatformHint? _platformHint = widget.quiz.externalPlatformHint;
  late bool _shuffleQuestions = widget.quiz.shuffleQuestions;
  late bool _shuffleChoices = widget.quiz.shuffleChoices;
  String? _metaErrorText;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveMeta() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _metaErrorText = 'Enter a title.');
      return;
    }

    String? externalUrl;
    if (widget.quiz.quizType == QuizType.externalActivity) {
      externalUrl = _urlController.text.trim();
      if (!externalUrl.startsWith('https://')) {
        setState(() => _metaErrorText = 'External Activities need an https:// URL.');
        return;
      }
    }

    setState(() => _metaErrorText = null);

    try {
      await ref.read(quizzesRepositoryProvider).update(
            quizId: widget.quiz.id,
            title: title,
            externalUrl: externalUrl,
            externalPlatformHint: widget.quiz.quizType == QuizType.externalActivity
                ? _platformHint
                : null,
            shuffleQuestions: _shuffleQuestions,
            shuffleChoices: _shuffleChoices,
          );
      ref.invalidate(quizzesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _addQuestion() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _QuestionPickerDialog(quiz: widget.quiz),
    );
  }

  Future<void> _removeQuestion(QuizQuestion quizQuestion) async {
    try {
      await ref.read(quizQuestionsRepositoryProvider).remove(quizQuestion.id);
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _reorder(List<QuizQuestion> current, int oldIndex, int newIndex) async {
    final List<QuizQuestion> reordered = List<QuizQuestion>.of(current);
    final QuizQuestion moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    try {
      await ref.read(quizQuestionsRepositoryProvider).reorder(
            quizId: widget.quiz.id,
            orderedQuestionIds: [for (final QuizQuestion qq in reordered) qq.questionId],
          );
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz.title)),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSectionHeader(title: 'Details', subtitle: widget.quiz.quizType.label),
            AppTextField(controller: _titleController, label: 'Title'),
            if (widget.quiz.quizType == QuizType.externalActivity) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _urlController, label: 'URL', hint: 'https://...'),
              const SizedBox(height: AppSpacing.sm),
              DropdownMenu<ExternalPlatformHint?>(
                initialSelection: _platformHint,
                label: const Text('Platform (optional)'),
                onSelected: (ExternalPlatformHint? value) => setState(() => _platformHint = value),
                dropdownMenuEntries: [
                  const DropdownMenuEntry<ExternalPlatformHint?>(value: null, label: 'None'),
                  for (final ExternalPlatformHint h in ExternalPlatformHint.values)
                    DropdownMenuEntry<ExternalPlatformHint?>(value: h, label: h.label),
                ],
              ),
            ],
            if (widget.quiz.quizType == QuizType.internal) ...<Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _shuffleQuestions,
                title: const Text('Shuffle questions'),
                onChanged: (bool? value) => setState(() => _shuffleQuestions = value ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _shuffleChoices,
                title: const Text('Shuffle choices'),
                onChanged: (bool? value) => setState(() => _shuffleChoices = value ?? true),
              ),
            ],
            if (_metaErrorText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(_metaErrorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(label: 'Save Details', onPressed: _saveMeta),
            ),
            const AppDivider(),
            AppSectionHeader(
              title: 'Sections',
              subtitle: 'Which of your sections can see this quiz.',
              action: AppButton(
                label: 'Assign Sections',
                variant: AppButtonVariant.outlined,
                size: AppComponentSize.small,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _QuizAssignSectionsDialog(quiz: widget.quiz),
                ),
              ),
            ),
            if (widget.quiz.quizType == QuizType.internal) ...<Widget>[
              const AppDivider(),
              AppSectionHeader(
                title: 'Questions',
                subtitle: 'Drag to reorder.',
                action: AppButton(
                  label: 'Add Question',
                  leadingIcon: Icons.add,
                  size: AppComponentSize.small,
                  onPressed: _addQuestion,
                ),
              ),
              _QuestionListSection(
                quiz: widget.quiz,
                onRemove: _removeQuestion,
                onReorder: _reorder,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionListSection extends ConsumerWidget {
  const _QuestionListSection({
    required this.quiz,
    required this.onRemove,
    required this.onReorder,
  });

  final Quiz quiz;
  final ValueChanged<QuizQuestion> onRemove;
  final void Function(List<QuizQuestion> current, int oldIndex, int newIndex) onReorder;

  /// Edits the underlying `question_bank` row itself — the exact same
  /// write as the Question Bank tab's "Edit" (`question_bank_screen.dart`'s
  /// `_edit`) — so the change is visible everywhere that question is used,
  /// not just in this quiz.
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
      ref.invalidate(allVisibleQuestionsProvider);
      ref.invalidate(questionBankProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  /// Deletes the question from `question_bank` entirely — not just from
  /// this quiz. `quiz_questions.question_id` is `on delete restrict`
  /// (0009_quizzes.sql), so this quiz's own link is unlinked first; if the
  /// question is also used by another quiz, the bank delete below still
  /// fails and surfaces that as a normal error message.
  Future<void> _delete(BuildContext context, WidgetRef ref, QuizQuestion quizQuestion) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete Question',
      type: AppDialogType.warning,
      message: 'Delete this question from the question bank? This cannot be undone, and it will '
          'be removed from every quiz that uses it.',
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
      await ref.read(quizQuestionsRepositoryProvider).remove(quizQuestion.id);
      await ref.read(questionBankRepositoryProvider).delete(quizQuestion.questionId);
      ref.invalidate(allVisibleQuestionsProvider);
      ref.invalidate(questionBankProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      ref.invalidate(quizQuestionsProvider(quiz.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QuizQuestion>> quizQuestions = ref.watch(quizQuestionsProvider(quiz.id));

    return quizQuestions.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      ),
      error: (error, _) => AppErrorState(
        message: error is AppFailure ? error.message : 'Could not load quiz questions.',
        onRetry: () => ref.invalidate(quizQuestionsProvider(quiz.id)),
      ),
      data: (List<QuizQuestion> list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: Icons.format_list_numbered,
            title: 'No questions yet',
            description: 'Add questions from the question bank.',
          );
        }

        final AsyncValue<List<QuestionBankItem>> allQuestions = ref.watch(allVisibleQuestionsProvider);

        return allQuestions.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingIndicator(),
          ),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load the question bank.',
            onRetry: () => ref.invalidate(allVisibleQuestionsProvider),
          ),
          data: (List<QuestionBankItem> all) {
            final Map<String, QuestionBankItem> byId = {for (final QuestionBankItem q in all) q.id: q};

            return ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              onReorderItem: (int oldIndex, int newIndex) => onReorder(list, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final QuizQuestion qq = list[index];
                final QuestionBankItem? question = byId[qq.questionId];
                return AppCard(
                  key: ValueKey(qq.id),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  header: Text(question?.promptText ?? 'Unknown question'),
                  footer: question == null || question.sourceType == ContentSourceType.builtIn
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(
                            label: 'Remove from Quiz',
                            variant: AppButtonVariant.text,
                            size: AppComponentSize.small,
                            onPressed: () => onRemove(qq),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            AppButton(
                              label: 'Edit',
                              variant: AppButtonVariant.outlined,
                              size: AppComponentSize.small,
                              onPressed: () => _edit(context, ref, question),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            AppButton(
                              label: 'Delete',
                              variant: AppButtonVariant.text,
                              size: AppComponentSize.small,
                              onPressed: () => _delete(context, ref, qq),
                            ),
                          ],
                        ),
                  child: const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QuizAssignSectionsDialog extends ConsumerWidget {
  const _QuizAssignSectionsDialog({required this.quiz});
  final Quiz quiz;

  Future<void> _toggle(WidgetRef ref, BuildContext context, String sectionId, bool assign) async {
    final SessionState session = ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionTeacher) return;

    try {
      if (assign) {
        await ref.read(quizzesRepositoryProvider).assign(
              quizId: quiz.id,
              sectionId: sectionId,
              assignedBy: session.profile.id,
            );
      } else {
        await ref.read(quizzesRepositoryProvider).unassign(quizId: quiz.id, sectionId: sectionId);
      }
      ref.invalidate(quizSectionIdsProvider(quiz.id));
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MySection>> mySections = ref.watch(mySectionsProvider);
    final AsyncValue<List<String>> assignedIds = ref.watch(quizSectionIdsProvider(quiz.id));

    return AppDialog(
      title: 'Assign Sections — ${quiz.title}',
      maxWidth: 480,
      content: mySections.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: AppLoadingIndicator(),
        ),
        error: (error, _) => AppErrorState(
          message: error is AppFailure ? error.message : 'Could not load your sections.',
          onRetry: () => ref.invalidate(mySectionsProvider),
        ),
        data: (List<MySection> sections) {
          final List<Section> ownSections =
              [for (final MySection s in sections) if (s.section != null) s.section!];
          if (ownSections.isEmpty) {
            return const Text('You have no sections to assign this quiz to yet.');
          }
          final Set<String> assigned = (assignedIds.value ?? const []).toSet();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Section section in ownSections)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: assigned.contains(section.id),
                  title: Text('${section.gradeLevel.label} — ${section.name}'),
                  onChanged: assignedIds.isLoading
                      ? null
                      : (bool? value) => _toggle(ref, context, section.id, value ?? false),
                ),
            ],
          );
        },
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

class _QuestionPickerDialog extends ConsumerStatefulWidget {
  const _QuestionPickerDialog({required this.quiz});
  final Quiz quiz;

  @override
  ConsumerState<_QuestionPickerDialog> createState() => _QuestionPickerDialogState();
}

class _QuestionPickerDialogState extends ConsumerState<_QuestionPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _add(List<QuizQuestion> currentQuestions, QuestionBankItem question) async {
    try {
      await ref.read(quizQuestionsRepositoryProvider).add(
            quizId: widget.quiz.id,
            questionId: question.id,
            displayOrder: currentQuestions.length + 1,
          );
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  /// Lets a Teacher write a brand-new question without leaving the quiz
  /// they're building. This is the exact same `question_bank` write as
  /// "New Question" on the Question Bank tab (`question_bank_screen.dart`'s
  /// `_create`) — same dialog, same repository call — so the question ends
  /// up there too, not just in this quiz.
  Future<void> _createNewQuestion(List<QuizQuestion> currentQuestions) async {
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

      // Refresh the question bank everywhere it's read from...
      ref.invalidate(allVisibleQuestionsProvider);
      ref.invalidate(questionBankProvider);

      // ...and, since it was created for this quiz, add it straight in.
      await ref.read(quizQuestionsRepositoryProvider).add(
            quizId: widget.quiz.id,
            questionId: questionId,
            displayOrder: currentQuestions.length + 1,
          );
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<QuizQuestion>> quizQuestions =
        ref.watch(quizQuestionsProvider(widget.quiz.id));
    final AsyncValue<List<QuestionBankItem>> allQuestions = ref.watch(allVisibleQuestionsProvider);
    final List<QuizQuestion> currentQuestions = quizQuestions.value ?? const [];

    return AppDialog(
      title: 'Add Questions — ${widget.quiz.title}',
      maxWidth: 560,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'New Question',
              variant: AppButtonVariant.outlined,
              size: AppComponentSize.small,
              leadingIcon: Icons.add,
              onPressed: () => _createNewQuestion(currentQuestions),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSearchBar(
            controller: _searchController,
            hint: 'Search questions',
            onChanged: (String value) => setState(() => _search = value.trim().toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 360,
            child: quizQuestions.when(
              loading: () => const AppLoadingIndicator(),
              error: (error, _) => AppErrorState(
                message: error is AppFailure ? error.message : 'Could not load quiz questions.',
                onRetry: () => ref.invalidate(quizQuestionsProvider(widget.quiz.id)),
              ),
              data: (List<QuizQuestion> current) {
                final Set<String> alreadyAdded = current.map((qq) => qq.questionId).toSet();

                return allQuestions.when(
                  loading: () => const AppLoadingIndicator(),
                  error: (error, _) => AppErrorState(
                    message: error is AppFailure
                        ? error.message
                        : 'Could not load the question bank.',
                    onRetry: () => ref.invalidate(allVisibleQuestionsProvider),
                  ),
                  data: (List<QuestionBankItem> all) {
                    final List<QuestionBankItem> candidates = all
                        .where((q) => !alreadyAdded.contains(q.id))
                        .where((q) => _search.isEmpty || q.promptText.toLowerCase().contains(_search))
                        .toList();

                    if (candidates.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'No questions available',
                        description: 'Every matching question is already in this quiz.',
                      );
                    }

                    return ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final QuestionBankItem question = candidates[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(question.promptText, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: question.topic == null ? null : Text(question.topic!),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add to quiz',
                            onPressed: () => _add(current, question),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
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
