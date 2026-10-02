import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
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
import '../widgets/bm_shared_widgets.dart';
import 'question_bank_screen.dart' show questionBankProvider;
import 'question_form_dialog.dart';
import 'teacher_content_ordering.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

/// Built-in quizzes plus the calling Teacher's own.
final quizzesProvider = FutureProvider<List<Quiz>>((ref) {
  return ref.watch(quizzesRepositoryProvider).fetchVisibleToTeacher();
});

/// One batched count query for the visible Internal Quizzes. This avoids a
/// separate `quiz_questions` request for every compact library card.
final quizQuestionCountsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final List<Quiz> quizzes = await ref.watch(quizzesProvider.future);
  final List<String> internalQuizIds = <String>[
    for (final Quiz quiz in quizzes)
      if (quiz.quizType == QuizType.internal) quiz.id,
  ];
  return ref
      .watch(quizQuestionsRepositoryProvider)
      .fetchQuestionCountsForQuizzes(internalQuizIds);
});

final quizSectionIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  quizId,
) {
  return ref.watch(quizzesRepositoryProvider).fetchSectionIds(quizId);
});

final quizQuestionsProvider = FutureProvider.family<List<QuizQuestion>, String>(
  (ref, quizId) {
    return ref.watch(quizQuestionsRepositoryProvider).fetchForQuiz(quizId);
  },
);

/// Every question visible to the calling Teacher (built-in + own),
/// unfiltered by search — used to resolve prompt text for questions
/// already in a quiz, and as the base candidate list for the question
/// picker. Deliberately separate from `question_bank_screen.dart`'s
/// `questionBankProvider`, which depends on that screen's own search
/// field state — reusing it here would make this screen's question list
/// silently depend on whatever search term happens to be active on the
/// Question Bank tab (both tabs stay alive at once under the shell's
/// `IndexedStack`).
final allVisibleQuestionsProvider = FutureProvider<List<QuestionBankItem>>((
  ref,
) {
  return ref.watch(questionBankRepositoryProvider).fetchVisibleToTeacher();
});

class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});

  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen> {
  _QuizListFilter _filter = _QuizListFilter.all;
  bool _isCreating = false;

  Future<void> _create() async {
    if (_isCreating) return;
    final SessionState session =
        ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionTeacher) return;

    final _NewQuizFormResult? result = await showDialog<_NewQuizFormResult>(
      context: context,
      builder: (_) => const _NewQuizDialog(),
    );
    if (result == null) return;

    setState(() => _isCreating = true);
    try {
      await ref
          .read(quizzesRepositoryProvider)
          .create(
            title: result.title,
            quizType: QuizType.internal,
            createdBy: session.profile.id,
            shuffleQuestions: result.shuffleQuestions,
            shuffleChoices: result.shuffleChoices,
          );
      ref.invalidate(quizzesProvider);
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _delete(Quiz quiz) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete Quiz',
      type: AppDialogType.warning,
      message:
          'Delete this quiz permanently? Student attempts and results for this quiz will also be deleted. This action cannot be undone.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          size: AppComponentSize.small,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Delete permanently',
          variant: AppButtonVariant.danger,
          size: AppComponentSize.small,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      await ref.read(quizzesRepositoryProvider).delete(quiz.id);
      ref.invalidate(quizzesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz deleted successfully.')),
        );
      }
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
    final AsyncValue<List<Quiz>> quizzes = ref.watch(quizzesProvider);
    final Map<String, int>? questionCounts =
        ref.watch(quizQuestionCountsProvider).value;

    return Material(
      color: AppColors.bg,
      child: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BmPageHeader(
              title: 'Quizzes',
              subtitle: 'Built-in quizzes and quizzes you create.',
              action: AppButton(
                label: 'New Quiz',
                leadingIcon: Icons.add_rounded,
                size: AppComponentSize.small,
                isLoading: _isCreating,
                onPressed: _isCreating ? null : _create,
              ),
            ),
            quizzes.when(
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
                            : 'Could not load quizzes.',
                    onRetry: () => ref.invalidate(quizzesProvider),
                  ),
              data: (List<Quiz> list) => _buildLibrary(list, questionCounts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrary(List<Quiz> list, Map<String, int>? questionCounts) {
    if (list.isEmpty) {
      return AppEmptyState(
        icon: Icons.quiz_outlined,
        title: 'No quizzes yet',
        description: 'Create your first quiz.',
        actionLabel: 'New Quiz',
        onAction: _create,
      );
    }

    final List<TeacherContentListEntry<Quiz>> ordered = orderTeacherQuizzes(
      list,
    );
    final List<TeacherContentListEntry<Quiz>> visible =
        ordered.where(_filter.matches).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _QuizFilterBar(
          selected: _filter,
          onSelected: (_QuizListFilter filter) {
            setState(() => _filter = filter);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          AppEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: _filter.emptyTitle,
            description: 'Choose another filter or create a new quiz.',
          )
        else
          for (final TeacherContentListEntry<Quiz> entry in visible)
            _QuizLibraryCard(
              key: ValueKey<String>('quiz-card-${entry.content.id}'),
              entry: entry,
              questionCount:
                  entry.content.quizType == QuizType.internal &&
                          questionCounts != null
                      ? questionCounts[entry.content.id] ?? 0
                      : null,
              onManage:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizEditScreen(quiz: entry.content),
                    ),
                  ),
              onDelete: () => _delete(entry.content),
            ),
      ],
    );
  }
}

enum _QuizListFilter { all, builtIn, mine, preTest, postTest }

extension on _QuizListFilter {
  String get label => switch (this) {
    _QuizListFilter.all => 'All',
    _QuizListFilter.builtIn => 'Built-in',
    _QuizListFilter.mine => 'My Quizzes',
    _QuizListFilter.preTest => 'Pre-Test',
    _QuizListFilter.postTest => 'Post-Test',
  };

  String get emptyTitle => switch (this) {
    _QuizListFilter.all => 'No quizzes found',
    _QuizListFilter.builtIn => 'No built-in quizzes found',
    _QuizListFilter.mine => 'No quizzes created yet',
    _QuizListFilter.preTest => 'No Pre-Test found',
    _QuizListFilter.postTest => 'No Post-Test found',
  };

  bool matches(TeacherContentListEntry<Quiz> entry) {
    final Quiz quiz = entry.content;
    return switch (this) {
      _QuizListFilter.all => true,
      _QuizListFilter.builtIn => quiz.sourceType == ContentSourceType.builtIn,
      _QuizListFilter.mine => quiz.sourceType == ContentSourceType.teacher,
      _QuizListFilter.preTest => quiz.assessmentType == AssessmentType.preTest,
      _QuizListFilter.postTest =>
        quiz.assessmentType == AssessmentType.postTest,
    };
  }
}

class _QuizFilterBar extends StatelessWidget {
  const _QuizFilterBar({required this.selected, required this.onSelected});

  final _QuizListFilter selected;
  final ValueChanged<_QuizListFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final _QuizListFilter filter in _QuizListFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}

class _QuizLibraryCard extends StatelessWidget {
  const _QuizLibraryCard({
    super.key,
    required this.entry,
    required this.questionCount,
    required this.onManage,
    required this.onDelete,
  });

  final TeacherContentListEntry<Quiz> entry;
  final int? questionCount;
  final VoidCallback onManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Quiz quiz = entry.content;
    final bool isBuiltIn = quiz.sourceType == ContentSourceType.builtIn;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 680;
          final Widget summary = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _QuizIcon(assessmentType: quiz.assessmentType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _quizDisplayTitle(entry),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.lexend(
                        size: 15,
                        weight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _QuizMetadata(quiz: quiz, questionCount: questionCount),
                  ],
                ),
              ),
            ],
          );
          final Widget sourceBadge = _QuizSourceBadge(isBuiltIn: isBuiltIn);

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                summary,
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    sourceBadge,
                    const Spacer(),
                    if (!isBuiltIn)
                      _QuizCardActions(onManage: onManage, onDelete: onDelete),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.md),
              sourceBadge,
              if (!isBuiltIn) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                _QuizCardActions(onManage: onManage, onDelete: onDelete),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuizIcon extends StatelessWidget {
  const _QuizIcon({required this.assessmentType});

  final AssessmentType? assessmentType;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (assessmentType) {
      AssessmentType.preTest => Icons.fact_check_outlined,
      AssessmentType.postTest => Icons.task_alt_rounded,
      null => Icons.quiz_outlined,
    };
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 21, color: AppColors.accent),
    );
  }
}

class _QuizMetadata extends StatelessWidget {
  const _QuizMetadata({required this.quiz, required this.questionCount});

  final Quiz quiz;
  final int? questionCount;

  @override
  Widget build(BuildContext context) {
    final String kind = _quizKindLabel(quiz);
    final String? grade = quiz.gradeLevel?.label;
    final List<String> details = <String>[
      if (grade != null) grade,
      kind,
      if (questionCount case final int count)
        '$count ${count == 1 ? 'question' : 'questions'}',
    ];
    return Text(
      details.join(' • '),
      style: AppTextStyles.inter(size: 12, color: AppColors.textSoft),
    );
  }
}

class _QuizSourceBadge extends StatelessWidget {
  const _QuizSourceBadge({required this.isBuiltIn});

  final bool isBuiltIn;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isBuiltIn ? AppColors.amber : AppColors.accent;
    final Color background =
        isBuiltIn ? AppColors.amberSoft : AppColors.accentSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isBuiltIn ? Icons.lock_outline_rounded : Icons.person_outline,
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isBuiltIn ? 'Built-in' : 'My Quiz',
            style: AppTextStyles.inter(
              size: 11,
              weight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizCardActions extends StatelessWidget {
  const _QuizCardActions({required this.onManage, required this.onDelete});

  final VoidCallback onManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppButton(
          label: 'Manage',
          leadingIcon: Icons.tune_rounded,
          variant: AppButtonVariant.outlined,
          size: AppComponentSize.small,
          onPressed: onManage,
        ),
        const SizedBox(width: AppSpacing.xs),
        Tooltip(
          message: 'Delete quiz',
          child: IconButton(
            key: const ValueKey<String>('delete-quiz-action'),
            onPressed: onDelete,
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ),
      ],
    );
  }
}

String _quizDisplayTitle(TeacherContentListEntry<Quiz> entry) {
  final Quiz quiz = entry.content;
  final int? number = entry.sequenceNumber;
  if (quiz.sourceType == ContentSourceType.teacher && number != null) {
    return 'Quiz $number: ${quiz.title}';
  }
  return quiz.title;
}

String _quizKindLabel(Quiz quiz) {
  if (quiz.assessmentType case final AssessmentType assessmentType) {
    return assessmentType.label;
  }
  return quiz.quizType == QuizType.externalActivity
      ? 'External Activity'
      : 'Regular Quiz';
}

class _NewQuizFormResult {
  const _NewQuizFormResult({
    required this.title,
    required this.shuffleQuestions,
    required this.shuffleChoices,
  });
  final String title;
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
  bool _shuffleQuestions = true;
  bool _shuffleChoices = true;
  String? _errorText;
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = 'Enter a quiz title.');
      return;
    }

    _submitted = true;
    Navigator.of(context).pop(
      _NewQuizFormResult(
        title: title,
        shuffleQuestions: _shuffleQuestions,
        shuffleChoices: _shuffleChoices,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Create New Quiz',
      icon: Icons.add_task_rounded,
      message: 'Set the title and how questions appear to students.',
      maxWidth: 520,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _titleController,
            autofocus: true,
            label: 'Quiz title',
            hint: 'Enter quiz title',
            helperText:
                'Use a short title that teachers and students recognize.',
            errorText: _errorText,
            prefixIcon: Icons.edit_note_rounded,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Options',
            style: AppTextStyles.lexend(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _QuizOptionSwitch(
            value: _shuffleQuestions,
            title: 'Shuffle questions',
            description:
                'Show questions in a different order for each attempt.',
            onChanged:
                (bool value) => setState(() => _shuffleQuestions = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _QuizOptionSwitch(
            value: _shuffleChoices,
            title: 'Shuffle choices',
            description: 'Randomize the answer choices for each question.',
            onChanged: (bool value) => setState(() => _shuffleChoices = value),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Create Quiz', onPressed: _submit),
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
  late final TextEditingController _titleController = TextEditingController(
    text: widget.quiz.title,
  );
  late final TextEditingController _urlController = TextEditingController(
    text: widget.quiz.externalUrl ?? '',
  );
  late ExternalPlatformHint? _platformHint = widget.quiz.externalPlatformHint;
  late bool _shuffleQuestions = widget.quiz.shuffleQuestions;
  late bool _shuffleChoices = widget.quiz.shuffleChoices;
  String? _metaErrorText;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveMeta() async {
    if (_isSaving) return;
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _metaErrorText = 'Enter a title.');
      return;
    }

    String? externalUrl;
    if (widget.quiz.quizType == QuizType.externalActivity) {
      externalUrl = _urlController.text.trim();
      if (!externalUrl.startsWith('https://')) {
        setState(
          () => _metaErrorText = 'External Activities need an https:// URL.',
        );
        return;
      }
    }

    setState(() => _metaErrorText = null);
    setState(() => _isSaving = true);

    try {
      await ref
          .read(quizzesRepositoryProvider)
          .update(
            quizId: widget.quiz.id,
            title: title,
            externalUrl: externalUrl,
            externalPlatformHint:
                widget.quiz.quizType == QuizType.externalActivity
                    ? _platformHint
                    : null,
            shuffleQuestions: _shuffleQuestions,
            shuffleChoices: _shuffleChoices,
          );
      ref.invalidate(quizzesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _reorder(
    List<QuizQuestion> current,
    int oldIndex,
    int newIndex,
  ) async {
    final List<QuizQuestion> reordered = List<QuizQuestion>.of(current);
    final QuizQuestion moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    try {
      await ref
          .read(quizQuestionsRepositoryProvider)
          .reorder(
            quizId: widget.quiz.id,
            orderedQuestionIds: [
              for (final QuizQuestion qq in reordered) qq.questionId,
            ],
          );
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Manage Quiz')),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _QuizManageHeader(quiz: widget.quiz),
            const SizedBox(height: AppSpacing.lg),
            _QuizManagementCard(
              icon: Icons.tune_rounded,
              title: 'Quiz Details',
              description: 'Update the title and quiz attempt options.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: AppTextField(
                      controller: _titleController,
                      label: 'Title',
                      errorText: _metaErrorText,
                      onChanged: (_) {
                        if (_metaErrorText != null) {
                          setState(() => _metaErrorText = null);
                        }
                      },
                    ),
                  ),
                  if (widget.quiz.quizType ==
                      QuizType.externalActivity) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: AppTextField(
                        controller: _urlController,
                        label: 'URL',
                        hint: 'https://...',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DropdownMenu<ExternalPlatformHint?>(
                        initialSelection: _platformHint,
                        label: const Text('Platform (optional)'),
                        onSelected:
                            (ExternalPlatformHint? value) =>
                                setState(() => _platformHint = value),
                        dropdownMenuEntries:
                            <DropdownMenuEntry<ExternalPlatformHint?>>[
                              const DropdownMenuEntry<ExternalPlatformHint?>(
                                value: null,
                                label: 'None',
                              ),
                              for (final ExternalPlatformHint hint
                                  in ExternalPlatformHint.values)
                                DropdownMenuEntry<ExternalPlatformHint?>(
                                  value: hint,
                                  label: hint.label,
                                ),
                            ],
                      ),
                    ),
                  ],
                  if (widget.quiz.quizType == QuizType.internal) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    LayoutBuilder(
                      builder: (
                        BuildContext context,
                        BoxConstraints constraints,
                      ) {
                        final bool stackOptions = constraints.maxWidth < 660;
                        final Widget questionsOption = _QuizOptionSwitch(
                          value: _shuffleQuestions,
                          title: 'Shuffle questions',
                          description:
                              'Show questions in a different order for each attempt.',
                          onChanged:
                              (bool value) =>
                                  setState(() => _shuffleQuestions = value),
                        );
                        final Widget choicesOption = _QuizOptionSwitch(
                          value: _shuffleChoices,
                          title: 'Shuffle choices',
                          description:
                              'Randomize the answer choices for each question.',
                          onChanged:
                              (bool value) =>
                                  setState(() => _shuffleChoices = value),
                        );
                        if (stackOptions) {
                          return Column(
                            children: <Widget>[
                              questionsOption,
                              const SizedBox(height: AppSpacing.sm),
                              choicesOption,
                            ],
                          );
                        }
                        return Row(
                          children: <Widget>[
                            Expanded(child: questionsOption),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: choicesOption),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'Save Changes',
                      leadingIcon: Icons.save_outlined,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveMeta,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AssignedSectionsCard(quiz: widget.quiz),
            if (widget.quiz.quizType == QuizType.internal) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _QuizManagementCard(
                icon: Icons.format_list_numbered_rounded,
                title: 'Questions',
                description: 'Drag questions to change their order.',
                action: AppButton(
                  label: 'Add Question',
                  leadingIcon: Icons.add_rounded,
                  size: AppComponentSize.small,
                  onPressed: _addQuestion,
                ),
                child: _QuestionListSection(
                  quiz: widget.quiz,
                  onRemove: _removeQuestion,
                  onReorder: _reorder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizManageHeader extends StatelessWidget {
  const _QuizManageHeader({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _QuizIcon(assessmentType: quiz.assessmentType),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                quiz.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.lexend(
                  size: 22,
                  weight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'My Quiz • ${_quizKindLabel(quiz)}',
                style: AppTextStyles.inter(size: 13, color: AppColors.textSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const _QuizSourceBadge(isBuiltIn: false),
      ],
    );
  }
}

class _QuizManagementCard extends StatelessWidget {
  const _QuizManagementCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget heading = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTextStyles.lexend(
                            size: 16,
                            weight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: AppTextStyles.inter(
                            size: 12,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (action == null) return heading;
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    heading,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: heading),
                  const SizedBox(width: AppSpacing.md),
                  action!,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _AssignedSectionsCard extends ConsumerWidget {
  const _AssignedSectionsCard({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MySection>> mySections = ref.watch(
      mySectionsProvider,
    );
    final AsyncValue<List<String>> assignedIds = ref.watch(
      quizSectionIdsProvider(quiz.id),
    );

    return _QuizManagementCard(
      icon: Icons.groups_2_outlined,
      title: 'Assigned Sections',
      description: 'Choose which of your sections can access this quiz.',
      action: AppButton(
        label: 'Assign Sections',
        leadingIcon: Icons.group_add_outlined,
        variant: AppButtonVariant.outlined,
        size: AppComponentSize.small,
        onPressed:
            () => showDialog<void>(
              context: context,
              builder: (_) => _QuizAssignSectionsDialog(quiz: quiz),
            ),
      ),
      child: _AssignedSectionsSummary(
        mySections: mySections,
        assignedIds: assignedIds,
      ),
    );
  }
}

class _AssignedSectionsSummary extends StatelessWidget {
  const _AssignedSectionsSummary({
    required this.mySections,
    required this.assignedIds,
  });

  final AsyncValue<List<MySection>> mySections;
  final AsyncValue<List<String>> assignedIds;

  @override
  Widget build(BuildContext context) {
    if (mySections.isLoading || assignedIds.isLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (mySections.hasError || assignedIds.hasError) {
      return Text(
        'Could not load assigned sections.',
        style: AppTextStyles.inter(
          size: 13,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }

    final Set<String> selectedIds =
        (assignedIds.value ?? const <String>[]).toSet();
    final List<Section> selectedSections = <Section>[
      for (final MySection item in mySections.value ?? const <MySection>[])
        if (item.section case final Section section)
          if (selectedIds.contains(section.id)) section,
    ];
    if (selectedSections.isEmpty) {
      return Text(
        'No sections assigned yet.',
        style: AppTextStyles.inter(size: 13, color: AppColors.textSoft),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final Section section in selectedSections)
          Chip(
            avatar: const Icon(Icons.groups_outlined, size: 16),
            label: Text('${section.gradeLevel.label} — ${section.name}'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _QuizOptionSwitch extends StatelessWidget {
  const _QuizOptionSwitch({
    required this.value,
    required this.title,
    required this.description,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String description;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.graySoft.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.inter(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.inter(
                        size: 11,
                        color: AppColors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
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
  final void Function(List<QuizQuestion> current, int oldIndex, int newIndex)
  onReorder;

  /// Edits the underlying `question_bank` row itself — the exact same
  /// write as the Question Bank tab's "Edit" (`question_bank_screen.dart`'s
  /// `_edit`) — so the change is visible everywhere that question is used,
  /// not just in this quiz.
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    QuestionBankItem item,
  ) async {
    final List<QuestionChoice> existingChoices;
    try {
      existingChoices = await ref
          .read(questionBankRepositoryProvider)
          .fetchChoices([item.id]);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }
    if (!context.mounted) return;

    final QuestionFormResult? result = await showDialog<QuestionFormResult>(
      context: context,
      builder:
          (_) => QuestionFormDialog(
            initial: item,
            initialChoices: existingChoices,
          ),
    );
    if (result == null) return;

    try {
      await ref
          .read(questionBankRepositoryProvider)
          .update(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  /// Deletes the question from `question_bank` entirely — not just from
  /// this quiz. `quiz_questions.question_id` is `on delete restrict`
  /// (0009_quizzes.sql), so this quiz's own link is unlinked first; if the
  /// question is also used by another quiz, the bank delete below still
  /// fails and surfaces that as a normal error message.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    QuizQuestion quizQuestion,
  ) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete Question',
      type: AppDialogType.warning,
      message:
          'Delete this question from the question bank? This cannot be undone, and it will '
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
      await ref
          .read(questionBankRepositoryProvider)
          .delete(quizQuestion.questionId);
      ref.invalidate(allVisibleQuestionsProvider);
      ref.invalidate(questionBankProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      ref.invalidate(quizQuestionsProvider(quiz.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QuizQuestion>> quizQuestions = ref.watch(
      quizQuestionsProvider(quiz.id),
    );

    return quizQuestions.when(
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
                    : 'Could not load quiz questions.',
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

        final AsyncValue<List<QuestionBankItem>> allQuestions = ref.watch(
          allVisibleQuestionsProvider,
        );

        return allQuestions.when(
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
                        : 'Could not load the question bank.',
                onRetry: () => ref.invalidate(allVisibleQuestionsProvider),
              ),
          data: (List<QuestionBankItem> all) {
            final Map<String, QuestionBankItem> byId = {
              for (final QuestionBankItem q in all) q.id: q,
            };

            return ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              onReorderItem:
                  (int oldIndex, int newIndex) =>
                      onReorder(list, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final QuizQuestion qq = list[index];
                final QuestionBankItem? question = byId[qq.questionId];
                return _QuizQuestionRow(
                  key: ValueKey(qq.id),
                  index: index,
                  question: question,
                  onRemove: () => onRemove(qq),
                  onEdit:
                      question == null ||
                              question.sourceType == ContentSourceType.builtIn
                          ? null
                          : () => _edit(context, ref, question),
                  onDelete:
                      question == null ||
                              question.sourceType == ContentSourceType.builtIn
                          ? null
                          : () => _delete(context, ref, qq),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QuizQuestionRow extends StatelessWidget {
  const _QuizQuestionRow({
    super.key,
    required this.index,
    required this.question,
    required this.onRemove,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final QuestionBankItem? question;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isOwned = onEdit != null && onDelete != null;
    final String? topic = question?.topic?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.graySoft.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget summary = Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: const Tooltip(
                  message: 'Drag to reorder',
                  child: SizedBox(
                    width: 38,
                    height: 40,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: AppColors.grayText,
                    ),
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTextStyles.inter(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      question?.promptText ?? 'Unknown question',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.navy,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic == null || topic.isEmpty
                          ? (isOwned ? 'My question' : 'Built-in question')
                          : topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        size: 11,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final Widget actions =
              isOwned
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppButton(
                        label: 'Edit',
                        leadingIcon: Icons.edit_outlined,
                        variant: AppButtonVariant.outlined,
                        size: AppComponentSize.small,
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Delete'),
                      ),
                    ],
                  )
                  : AppButton(
                    label: 'Remove from Quiz',
                    leadingIcon: Icons.link_off_rounded,
                    variant: AppButtonVariant.text,
                    size: AppComponentSize.small,
                    onPressed: onRemove,
                  );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                summary,
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.sm),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _QuizAssignSectionsDialog extends ConsumerWidget {
  const _QuizAssignSectionsDialog({required this.quiz});
  final Quiz quiz;

  Future<void> _toggle(
    WidgetRef ref,
    BuildContext context,
    String sectionId,
    bool assign,
  ) async {
    final SessionState session =
        ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionTeacher) return;

    try {
      if (assign) {
        await ref
            .read(quizzesRepositoryProvider)
            .assign(
              quizId: quiz.id,
              sectionId: sectionId,
              assignedBy: session.profile.id,
            );
      } else {
        await ref
            .read(quizzesRepositoryProvider)
            .unassign(quizId: quiz.id, sectionId: sectionId);
      }
      ref.invalidate(quizSectionIdsProvider(quiz.id));
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MySection>> mySections = ref.watch(
      mySectionsProvider,
    );
    final AsyncValue<List<String>> assignedIds = ref.watch(
      quizSectionIdsProvider(quiz.id),
    );

    return AppDialog(
      title: 'Assign Sections — ${quiz.title}',
      maxWidth: 480,
      content: mySections.when(
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
                      : 'Could not load your sections.',
              onRetry: () => ref.invalidate(mySectionsProvider),
            ),
        data: (List<MySection> sections) {
          final List<Section> ownSections = [
            for (final MySection s in sections)
              if (s.section != null) s.section!,
          ];
          if (ownSections.isEmpty) {
            return const Text(
              'You have no sections to assign this quiz to yet.',
            );
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
                  onChanged:
                      assignedIds.isLoading
                          ? null
                          : (bool? value) =>
                              _toggle(ref, context, section.id, value ?? false),
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
  ConsumerState<_QuestionPickerDialog> createState() =>
      _QuestionPickerDialogState();
}

class _QuestionPickerDialogState extends ConsumerState<_QuestionPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _add(
    List<QuizQuestion> currentQuestions,
    QuestionBankItem question,
  ) async {
    try {
      await ref
          .read(quizQuestionsRepositoryProvider)
          .add(
            quizId: widget.quiz.id,
            questionId: question.id,
            displayOrder: currentQuestions.length + 1,
          );
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  /// Lets a Teacher write a brand-new question without leaving the quiz
  /// they're building. This is the exact same `question_bank` write as
  /// "New Question" on the Question Bank tab (`question_bank_screen.dart`'s
  /// `_create`) — same dialog, same repository call — so the question ends
  /// up there too, not just in this quiz.
  Future<void> _createNewQuestion(List<QuizQuestion> currentQuestions) async {
    final SessionState session =
        ref.read(sessionProvider).value ?? const SessionNone();
    if (session is! SessionTeacher) return;

    final QuestionFormResult? result = await showDialog<QuestionFormResult>(
      context: context,
      builder: (_) => const QuestionFormDialog(),
    );
    if (result == null) return;

    try {
      final String questionId = await ref
          .read(questionBankRepositoryProvider)
          .create(
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
      await ref
          .read(quizQuestionsRepositoryProvider)
          .add(
            quizId: widget.quiz.id,
            questionId: questionId,
            displayOrder: currentQuestions.length + 1,
          );
      ref.invalidate(quizQuestionsProvider(widget.quiz.id));
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
    final AsyncValue<List<QuizQuestion>> quizQuestions = ref.watch(
      quizQuestionsProvider(widget.quiz.id),
    );
    final AsyncValue<List<QuestionBankItem>> allQuestions = ref.watch(
      allVisibleQuestionsProvider,
    );
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
            onChanged:
                (String value) =>
                    setState(() => _search = value.trim().toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 360,
            child: quizQuestions.when(
              loading: () => const AppLoadingIndicator(),
              error:
                  (error, _) => AppErrorState(
                    message:
                        error is AppFailure
                            ? error.message
                            : 'Could not load quiz questions.',
                    onRetry:
                        () => ref.invalidate(
                          quizQuestionsProvider(widget.quiz.id),
                        ),
                  ),
              data: (List<QuizQuestion> current) {
                final Set<String> alreadyAdded =
                    current.map((qq) => qq.questionId).toSet();

                return allQuestions.when(
                  loading: () => const AppLoadingIndicator(),
                  error:
                      (error, _) => AppErrorState(
                        message:
                            error is AppFailure
                                ? error.message
                                : 'Could not load the question bank.',
                        onRetry:
                            () => ref.invalidate(allVisibleQuestionsProvider),
                      ),
                  data: (List<QuestionBankItem> all) {
                    final List<QuestionBankItem> candidates =
                        all
                            .where((q) => !alreadyAdded.contains(q.id))
                            .where(
                              (q) =>
                                  _search.isEmpty ||
                                  q.promptText.toLowerCase().contains(_search),
                            )
                            .toList();

                    if (candidates.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'No questions available',
                        description:
                            'Every matching question is already in this quiz.',
                      );
                    }

                    return ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final QuestionBankItem question = candidates[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            question.promptText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle:
                              question.topic == null
                                  ? null
                                  : Text(question.topic!),
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
