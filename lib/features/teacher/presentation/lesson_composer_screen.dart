import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/lesson_block_type.dart';
import '../../../core/models/lesson_page.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/inputs/app_text_field.dart';
import '../../../core/widgets/lesson/lesson_content_block_view.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/loading/app_loading_indicator.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

class LessonComposerScreen extends ConsumerStatefulWidget {
  const LessonComposerScreen({super.key, this.lesson});

  final Lesson? lesson;

  @override
  ConsumerState<LessonComposerScreen> createState() =>
      _LessonComposerScreenState();
}

class _LessonComposerScreenState extends ConsumerState<LessonComposerScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final List<_LessonBlockDraft> _blocks = <_LessonBlockDraft>[];
  final Set<String> _sectionIds = <String>{};

  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  String? _formError;
  LessonPublicationStatus _status = LessonPublicationStatus.draft;

  bool get _isEditing => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.lesson?.title ?? '';
    _summaryController.text = widget.lesson?.body ?? '';
    _status = widget.lesson?.publicationStatus ?? LessonPublicationStatus.draft;
    if (_isEditing) {
      _loading = true;
      Future<void>.microtask(_loadExistingLesson);
    } else {
      _blocks.add(_LessonBlockDraft(type: LessonBlockType.paragraph));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingLesson() async {
    try {
      final pages = await ref
          .read(lessonsRepositoryProvider)
          .fetchPages(widget.lesson!.id);
      final sectionIds = await ref
          .read(lessonsRepositoryProvider)
          .fetchSectionIds(widget.lesson!.id);
      if (!mounted) return;
      setState(() {
        _blocks
          ..clear()
          ..addAll(
            pages.isEmpty
                ? <_LessonBlockDraft>[
                  _LessonBlockDraft(
                    type: LessonBlockType.paragraph,
                    body: widget.lesson!.body,
                  ),
                ]
                : pages.map(_LessonBlockDraft.fromPage),
          );
        _sectionIds
          ..clear()
          ..addAll(sectionIds);
        _loading = false;
        _dirty = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loadError = failure.message;
        _loading = false;
      });
    }
  }

  void _markDirty() {
    if (!_dirty || _formError != null) {
      setState(() {
        _dirty = true;
        _formError = null;
      });
    }
  }

  void _addBlock(LessonBlockType type) {
    setState(() {
      _blocks.add(_LessonBlockDraft(type: type));
      _dirty = true;
      _formError = null;
    });
  }

  void _moveBlock(int index, int delta) {
    final int destination = index + delta;
    if (destination < 0 || destination >= _blocks.length) return;
    setState(() {
      final _LessonBlockDraft block = _blocks.removeAt(index);
      _blocks.insert(destination, block);
      _dirty = true;
    });
  }

  void _duplicateBlock(int index) {
    setState(() {
      _blocks.insert(index + 1, _blocks[index].duplicate());
      _dirty = true;
    });
  }

  void _deleteBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      _dirty = true;
    });
  }

  Future<void> _chooseImage(_LessonBlockDraft block) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      setState(() => _formError = 'The selected image could not be read.');
      return;
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      setState(() => _formError = 'Lesson images must be 5 MB or smaller.');
      return;
    }
    setState(() {
      block.imageBytes = bytes;
      block.imageFileName = file.name;
      _formError = null;
      _dirty = true;
    });
  }

  String? _blockError(_LessonBlockDraft block) {
    switch (block.type) {
      case LessonBlockType.heading:
        return block.title.trim().isEmpty ? 'Enter a heading.' : null;
      case LessonBlockType.paragraph:
        return block.body.trim().isEmpty ? 'Enter paragraph text.' : null;
      case LessonBlockType.image:
        if (block.imageBytes == null && block.body.trim().isEmpty) {
          return 'Choose an image.';
        }
        return block.title.trim().isEmpty
            ? 'Add a short accessible caption.'
            : null;
      case LessonBlockType.keyIdea:
        return block.body.trim().isEmpty ? 'Enter the key idea.' : null;
      case LessonBlockType.workedExample:
        return block.body.trim().isEmpty
            ? 'Enter the worked example steps.'
            : null;
      case LessonBlockType.link:
        if (block.title.trim().isEmpty) return 'Enter a link label.';
        final Uri? uri = Uri.tryParse(block.body.trim());
        return uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')
            ? 'Enter a complete http:// or https:// link.'
            : null;
    }
  }

  bool _validate({required bool publishing}) {
    String? error;
    if (_titleController.text.trim().isEmpty) {
      error = 'Add a lesson title.';
    } else if (_summaryController.text.trim().isEmpty) {
      error = 'Add a short learning summary.';
    } else if (_blocks.isEmpty) {
      error = 'Add at least one content block.';
    } else if (_blocks.any((block) => _blockError(block) != null)) {
      error = 'Complete the highlighted content blocks.';
    } else if (publishing && _sectionIds.isEmpty) {
      error = 'Choose at least one section before publishing.';
    }
    setState(() => _formError = error);
    return error == null;
  }

  Future<void> _save(LessonPublicationStatus status) async {
    final bool publishing = status == LessonPublicationStatus.published;
    if (!_validate(publishing: publishing)) return;

    final SessionState session;
    try {
      session = await ref.read(sessionProvider.future);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _formError = failure.message);
      return;
    }
    if (!mounted) return;
    if (session is! SessionTeacher) {
      setState(() => _formError = 'A Teacher session is required to save.');
      return;
    }

    setState(() => _saving = true);
    final List<String> uploadedPaths = <String>[];
    try {
      final List<LessonPageInput> inputs = <LessonPageInput>[];
      for (final _LessonBlockDraft block in _blocks) {
        String body = block.body.trim();
        if (block.type == LessonBlockType.image && block.imageBytes != null) {
          final upload = await ref
              .read(lessonsRepositoryProvider)
              .uploadLessonImage(
                teacherId: session.profile.id,
                fileName: block.imageFileName!,
                bytes: block.imageBytes!,
              );
          uploadedPaths.add(upload.path);
          body = upload.publicUrl;
        }
        inputs.add(
          LessonPageInput(
            sectionType: block.type.sectionType,
            title: block.title.trim(),
            body: body,
          ),
        );
      }

      await ref
          .read(lessonsRepositoryProvider)
          .saveComposedLesson(
            lessonId: widget.lesson?.id,
            title: _titleController.text.trim(),
            summary: _summaryController.text.trim(),
            publicationStatus: status,
            sectionIds: _sectionIds.toList(),
            blocks: inputs,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppFailure catch (failure) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await ref
              .read(lessonsRepositoryProvider)
              .removeLessonImages(uploadedPaths);
        } catch (_) {
          // The original save failure is the actionable error for the user.
        }
      }
      if (!mounted) return;
      setState(() {
        _formError = failure.message;
        _saving = false;
      });
    }
  }

  void _preview() {
    if (!_validate(publishing: false)) return;
    final DateTime now = DateTime.now();
    final List<LessonPage> pages = <LessonPage>[
      for (int index = 0; index < _blocks.length; index++)
        LessonPage(
          id: _blocks[index].localId,
          lessonId: widget.lesson?.id ?? 'preview',
          displayOrder: index + 1,
          sectionType: _blocks[index].type.sectionType,
          title: _blocks[index].title.trim(),
          body: _blocks[index].body.trim(),
          createdAt: now,
          updatedAt: now,
        ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => LessonComposerPreviewScreen(
              title: _titleController.text.trim(),
              summary: _summaryController.text.trim(),
              pages: pages,
              imageBytesByPageId: <String, Uint8List>{
                for (final _LessonBlockDraft block in _blocks)
                  if (block.imageBytes != null)
                    block.localId: block.imageBytes!,
              },
            ),
      ),
    );
  }

  Future<void> _requestClose() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final bool discard =
        await showDialog<bool>(
          context: context,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Discard unsaved changes?'),
                content: const Text(
                  'Your lesson changes have not been saved yet.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
        ) ??
        false;
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MySection>> sectionsAsync = ref.watch(
      mySectionsProvider,
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child:
              _loading
                  ? const Center(
                    child: AppLoadingIndicator(message: 'Opening lesson…'),
                  )
                  : _loadError != null
                  ? Center(
                    child: AppErrorState(
                      message: _loadError!,
                      onRetry: () {
                        setState(() {
                          _loadError = null;
                          _loading = true;
                        });
                        _loadExistingLesson();
                      },
                    ),
                  )
                  : LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final bool wide = constraints.maxWidth >= 1080;
                      final double horizontalPadding =
                          constraints.maxWidth >= 1500 ? 48 : 28;

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          20,
                          horizontalPadding,
                          40,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _ComposerToolbar(
                                  isEditing: _isEditing,
                                  status: _status,
                                  saving: _saving,
                                  onBack: _requestClose,
                                  onPreview: _preview,
                                  onSaveDraft:
                                      () =>
                                          _save(LessonPublicationStatus.draft),
                                  onPublish:
                                      () => _save(
                                        LessonPublicationStatus.published,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                if (_formError != null) ...<Widget>[
                                  _ComposerError(message: _formError!),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(child: _buildEditor()),
                                      const SizedBox(width: AppSpacing.lg),
                                      SizedBox(
                                        width: 330,
                                        child: _buildSettings(sectionsAsync),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: <Widget>[
                                      _buildEditor(),
                                      const SizedBox(height: AppSpacing.lg),
                                      _buildSettings(sectionsAsync),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ComposerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Lesson details',
                style: AppTextStyles.lexend(size: 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Give students a clear reason to open this lesson.',
                style: AppTextStyles.inter(size: 13, color: AppColors.textSoft),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('lesson_composer_title'),
                controller: _titleController,
                label: 'Lesson title',
                hint: 'e.g. Understanding equivalent fractions',
                maxLength: 120,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('lesson_composer_summary'),
                controller: _summaryController,
                label: 'Learning summary',
                hint:
                    'A short description students will see in the lesson list',
                type: AppTextFieldType.multiline,
                maxLines: 3,
                maxLength: 280,
                onChanged: (_) => _markDirty(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ComposerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Lesson content',
                          style: AppTextStyles.lexend(
                            size: 18,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BayMath formats each block consistently for students.',
                          style: AppTextStyles.inter(
                            size: 13,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AddContentButton(onSelected: _addBlock),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_blocks.isEmpty)
                _EmptyComposer(
                  onAdd: () => _addBlock(LessonBlockType.paragraph),
                )
              else
                for (
                  int index = 0;
                  index < _blocks.length;
                  index++
                ) ...<Widget>[
                  _LessonBlockEditor(
                    key: ValueKey<String>(_blocks[index].localId),
                    block: _blocks[index],
                    index: index,
                    count: _blocks.length,
                    errorText:
                        _formError == null ? null : _blockError(_blocks[index]),
                    onChanged: _markDirty,
                    onChooseImage: () => _chooseImage(_blocks[index]),
                    onMoveUp: () => _moveBlock(index, -1),
                    onMoveDown: () => _moveBlock(index, 1),
                    onDuplicate: () => _duplicateBlock(index),
                    onDelete: () => _deleteBlock(index),
                  ),
                  if (index != _blocks.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettings(AsyncValue<List<MySection>> sectionsAsync) {
    return _ComposerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Audience & status',
            style: AppTextStyles.lexend(size: 17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Drafts stay hidden. Publishing shares the lesson with selected sections.',
            style: AppTextStyles.inter(
              size: 13,
              color: AppColors.textSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'SECTIONS',
            style: AppTextStyles.inter(
              size: 11,
              weight: FontWeight.w700,
              color: AppColors.textSoft,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          sectionsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Could not load your sections.'),
            data: (List<MySection> sections) {
              final List<MySection> resolved = <MySection>[
                for (final MySection section in sections)
                  if (section.section != null) section,
              ];
              if (resolved.isEmpty) {
                return Text(
                  'No sections are available yet. You can still save a draft.',
                  style: AppTextStyles.inter(
                    size: 13,
                    color: AppColors.textSoft,
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final MySection item in resolved)
                    CheckboxListTile(
                      key: ValueKey<String>(
                        'lesson_composer_section_${item.section!.id}',
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _sectionIds.contains(item.section!.id),
                      title: Text(
                        '${item.section!.gradeLevel.label} — '
                        '${item.section!.name}',
                        style: AppTextStyles.inter(
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                      onChanged:
                          _saving
                              ? null
                              : (bool? selected) {
                                setState(() {
                                  if (selected ?? false) {
                                    _sectionIds.add(item.section!.id);
                                  } else {
                                    _sectionIds.remove(item.section!.id);
                                  }
                                  _dirty = true;
                                  _formError = null;
                                });
                              },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          _StatusExplanation(status: _status),
        ],
      ),
    );
  }
}

class _ComposerToolbar extends StatelessWidget {
  const _ComposerToolbar({
    required this.isEditing,
    required this.status,
    required this.saving,
    required this.onBack,
    required this.onPreview,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final bool isEditing;
  final LessonPublicationStatus status;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onPreview;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: const Key('lesson_composer_back'),
              tooltip: 'Back to Lessons',
              onPressed: saving ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isEditing ? 'Edit lesson' : 'Create lesson',
                  style: AppTextStyles.lexend(
                    size: 28,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                _StatusBadge(status: status),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AppButton(
              key: const Key('lesson_composer_preview'),
              label: 'Preview',
              leadingIcon: Icons.visibility_outlined,
              variant: AppButtonVariant.text,
              onPressed: saving ? null : onPreview,
            ),
            AppButton(
              key: const Key('lesson_composer_save_draft'),
              label: 'Save draft',
              variant: AppButtonVariant.outlined,
              isLoading: saving,
              onPressed: saving ? null : onSaveDraft,
            ),
            AppButton(
              key: const Key('lesson_composer_publish'),
              label:
                  status == LessonPublicationStatus.published
                      ? 'Save & publish'
                      : 'Publish',
              leadingIcon: Icons.publish_rounded,
              isLoading: saving,
              onPressed: saving ? null : onPublish,
            ),
          ],
        ),
      ],
    );
  }
}

class _ComposerSurface extends StatelessWidget {
  const _ComposerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class _ComposerError extends StatelessWidget {
  const _ComposerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.inter(
                size: 13,
                weight: FontWeight.w600,
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddContentButton extends StatelessWidget {
  const _AddContentButton({required this.onSelected});

  final ValueChanged<LessonBlockType> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LessonBlockType>(
      key: const Key('lesson_composer_add_content'),
      tooltip: 'Add lesson content',
      onSelected: onSelected,
      itemBuilder:
          (_) => <PopupMenuEntry<LessonBlockType>>[
            for (final LessonBlockType type in LessonBlockType.values)
              PopupMenuItem<LessonBlockType>(
                value: type,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_blockIcon(type), color: AppColors.accent),
                  title: Text(type.label),
                ),
              ),
          ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add content'),
        ),
      ),
    );
  }
}

class _LessonBlockEditor extends StatelessWidget {
  const _LessonBlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.count,
    required this.errorText,
    required this.onChanged,
    required this.onChooseImage,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
  });

  final _LessonBlockDraft block;
  final int index;
  final int count;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onChooseImage;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('lesson_composer_block_$index'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: errorText == null ? colors.outlineVariant : colors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _blockIcon(block.type),
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  block.type.label,
                  style: AppTextStyles.inter(size: 13, weight: FontWeight.w700),
                ),
              ),
              _BlockAction(
                tooltip: 'Move up',
                icon: Icons.keyboard_arrow_up_rounded,
                onPressed: index == 0 ? null : onMoveUp,
              ),
              _BlockAction(
                tooltip: 'Move down',
                icon: Icons.keyboard_arrow_down_rounded,
                onPressed: index == count - 1 ? null : onMoveDown,
              ),
              _BlockAction(
                tooltip: 'Duplicate block',
                icon: Icons.copy_outlined,
                onPressed: onDuplicate,
              ),
              _BlockAction(
                tooltip: 'Delete block',
                icon: Icons.delete_outline_rounded,
                color: colors.error,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._fieldsForBlock(),
          if (errorText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorText!,
              style: AppTextStyles.inter(size: 12, color: colors.error),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _fieldsForBlock() {
    void updateTitle(String value) {
      block.title = value;
      onChanged();
    }

    void updateBody(String value) {
      block.body = value;
      onChanged();
    }

    return switch (block.type) {
      LessonBlockType.heading => <Widget>[
        _BlockField(
          key: ValueKey<String>('${block.localId}_heading'),
          label: 'Heading',
          hint: 'What is a fraction?',
          initialValue: block.title,
          onChanged: updateTitle,
        ),
      ],
      LessonBlockType.paragraph => <Widget>[
        _BlockField(
          key: ValueKey<String>('${block.localId}_paragraph'),
          label: 'Paragraph',
          hint: 'Explain the idea in clear, student-friendly language.',
          multiline: true,
          maxLines: 5,
          initialValue: block.body,
          onChanged: updateBody,
        ),
      ],
      LessonBlockType.image => <Widget>[
        _BlockField(
          key: ValueKey<String>('${block.localId}_caption'),
          label: 'Image caption / description',
          hint: 'Describe what students should notice.',
          initialValue: block.title,
          onChanged: updateTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (block.imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.memory(block.imageBytes!, fit: BoxFit.contain),
            ),
          )
        else if (block.body.isNotEmpty)
          Text(
            'Current image is ready. Choose another image to replace it.',
            style: AppTextStyles.inter(size: 12, color: AppColors.textSoft),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onChooseImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              block.imageFileName == null ? 'Choose image' : 'Replace image',
            ),
          ),
        ),
        if (block.imageFileName != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            block.imageFileName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.inter(size: 12, color: AppColors.textSoft),
          ),
        ],
      ],
      LessonBlockType.keyIdea => <Widget>[
        _BlockField(
          key: ValueKey<String>('${block.localId}_key_title'),
          label: 'Optional label',
          hint: 'Key idea',
          initialValue: block.title,
          onChanged: updateTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        _BlockField(
          key: ValueKey<String>('${block.localId}_key_body'),
          label: 'Important note',
          multiline: true,
          maxLines: 4,
          initialValue: block.body,
          onChanged: updateBody,
        ),
      ],
      LessonBlockType.workedExample => <Widget>[
        _BlockField(
          key: ValueKey<String>('${block.localId}_example_title'),
          label: 'Example title',
          hint: 'Example: Add fractions with like denominators',
          initialValue: block.title,
          onChanged: updateTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        _BlockField(
          key: ValueKey<String>('${block.localId}_example_body'),
          label: 'Steps and solution',
          multiline: true,
          maxLines: 6,
          initialValue: block.body,
          onChanged: updateBody,
        ),
      ],
      LessonBlockType.link => <Widget>[
        _BlockField(
          key: ValueKey<String>('${block.localId}_link_title'),
          label: 'Link label',
          hint: 'Explore an interactive fraction model',
          initialValue: block.title,
          onChanged: updateTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        _BlockField(
          key: ValueKey<String>('${block.localId}_link_url'),
          label: 'Web address',
          hint: 'https://',
          keyboardType: TextInputType.url,
          initialValue: block.body,
          onChanged: updateBody,
        ),
      ],
    };
  }
}

class _BlockAction extends StatelessWidget {
  const _BlockAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: color,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
    );
  }
}

class _BlockField extends StatelessWidget {
  const _BlockField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hint,
    this.multiline = false,
    this.maxLines,
    this.keyboardType,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool multiline;
  final int? maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: multiline ? (maxLines ?? 4) : 1,
      keyboardType:
          keyboardType ??
          (multiline ? TextInputType.multiline : TextInputType.text),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _EmptyComposer extends StatelessWidget {
  const _EmptyComposer({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.post_add_rounded, size: 36, color: AppColors.accent),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Build the lesson one clear idea at a time.',
            textAlign: TextAlign.center,
            style: AppTextStyles.inter(weight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Add text', onPressed: onAdd),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final LessonPublicationStatus status;

  @override
  Widget build(BuildContext context) {
    final bool published = status == LessonPublicationStatus.published;
    final Color color =
        published ? const Color(0xFF246B58) : AppColors.textSoft;
    final Color background =
        published
            ? const Color(0xFFE7F4EF)
            : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.inter(
          size: 11,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusExplanation extends StatelessWidget {
  const _StatusExplanation({required this.status});

  final LessonPublicationStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          status == LessonPublicationStatus.published
              ? Icons.public_rounded
              : Icons.edit_note_rounded,
          color: AppColors.accent,
          size: 22,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StatusBadge(status: status),
              const SizedBox(height: 6),
              Text(
                status == LessonPublicationStatus.published
                    ? 'Students in selected sections can currently open this lesson.'
                    : 'Students cannot see this lesson until you publish it.',
                style: AppTextStyles.inter(
                  size: 12,
                  color: AppColors.textSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _blockIcon(LessonBlockType type) => switch (type) {
  LessonBlockType.heading => Icons.title_rounded,
  LessonBlockType.paragraph => Icons.notes_rounded,
  LessonBlockType.image => Icons.image_outlined,
  LessonBlockType.keyIdea => Icons.lightbulb_outline_rounded,
  LessonBlockType.workedExample => Icons.calculate_outlined,
  LessonBlockType.link => Icons.link_rounded,
};

class _LessonBlockDraft {
  _LessonBlockDraft({
    required this.type,
    this.title = '',
    this.body = '',
    this.imageBytes,
    this.imageFileName,
  }) : localId = 'block-${_nextBlockId++}';

  factory _LessonBlockDraft.fromPage(LessonPage page) {
    final LessonBlockType type =
        LessonBlockType.fromSectionType(page.sectionType) ??
        switch (page.sectionType) {
          'examples' => LessonBlockType.workedExample,
          'summary' => LessonBlockType.keyIdea,
          _ => LessonBlockType.paragraph,
        };
    return _LessonBlockDraft(type: type, title: page.title, body: page.body);
  }

  final String localId;
  final LessonBlockType type;
  String title;
  String body;
  Uint8List? imageBytes;
  String? imageFileName;

  _LessonBlockDraft duplicate() => _LessonBlockDraft(
    type: type,
    title: title,
    body: body,
    imageBytes: imageBytes,
    imageFileName: imageFileName,
  );
}

int _nextBlockId = 0;

class LessonComposerPreviewScreen extends StatelessWidget {
  const LessonComposerPreviewScreen({
    super.key,
    required this.title,
    required this.summary,
    required this.pages,
    this.imageBytesByPageId = const <String, Uint8List>{},
  });

  final String title;
  final String summary;
  final List<LessonPage> pages;
  final Map<String, Uint8List> imageBytesByPageId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      appBar: AppBar(
        title: const Text('Student preview'),
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('Preview only'),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxHeight < 680;
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 1100 ? 24 : 48,
              vertical: compact ? 18 : 28,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTextStyles.lexend(
                          size: compact ? 28 : 34,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        summary,
                        style: AppTextStyles.inter(
                          size: compact ? 15 : 17,
                          color: AppColors.textSoft,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      for (
                        int index = 0;
                        index < pages.length;
                        index++
                      ) ...<Widget>[
                        LessonContentBlockView(
                          page: pages[index],
                          compact: compact,
                          imageBytes: imageBytesByPageId[pages[index].id],
                        ),
                        if (index != pages.length - 1)
                          SizedBox(height: compact ? 20 : 28),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
