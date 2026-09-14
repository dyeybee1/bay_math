import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/section.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/bm_shared_widgets.dart';
import 'lesson_composer_screen.dart';
import 'teacher_content_ordering.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Providers — UNCHANGED
// ─────────────────────────────────────────────────────────────────────────────

/// Built-in lessons plus the calling Teacher's own — RLS already scopes
/// this to exactly that set (see `LessonsRepository.fetchVisibleToTeacher`).
final lessonsProvider = FutureProvider<List<Lesson>>((ref) {
  return ref.watch(lessonsRepositoryProvider).fetchVisibleToTeacher();
});

/// Section ids [lessonId] is currently assigned to.
final lessonSectionIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  lessonId,
) {
  return ref.watch(lessonsRepositoryProvider).fetchSectionIds(lessonId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Glyph helper — maps lesson title keywords → symbol + colour pair
// ─────────────────────────────────────────────────────────────────────────────

/// Returns (symbol, useAccent) where useAccent=true → accent+accentSoft,
/// false → teal+tealSoft.  Index is used to alternate when no keyword match.
({String symbol, bool useAccent}) _glyphFor(String title, int index) {
  final String t = title.toLowerCase();

  if (t.contains('add') ||
      t.contains('subtract') ||
      t.contains('sum') ||
      t.contains('differ')) {
    return (symbol: '±', useAccent: true);
  }
  if (t.contains('compar') || t.contains('greater') || t.contains('less')) {
    return (symbol: '<>', useAccent: false);
  }
  if (t.contains('multipl') || t.contains('product')) {
    return (symbol: '×', useAccent: true);
  }
  if (t.contains('divid') || t.contains('quotient')) {
    return (symbol: '÷', useAccent: false);
  }
  if (t.contains('fraction') || t.contains('ratio')) {
    return (symbol: '½', useAccent: true);
  }
  if (t.contains('percent') || t.contains('%')) {
    return (symbol: '%', useAccent: false);
  }
  if (t.contains('decimal')) {
    return (symbol: '.0', useAccent: true);
  }
  if (t.contains('geometr') || t.contains('shape') || t.contains('angle')) {
    return (symbol: '△', useAccent: false);
  }
  if (t.contains('algebra') ||
      t.contains('equation') ||
      t.contains('variable')) {
    return (symbol: 'x=', useAccent: true);
  }
  // Neutral fallback — alternate by index
  return (symbol: index.isEven ? '∑' : 'f(x)', useAccent: index.isEven);
}

// ─────────────────────────────────────────────────────────────────────────────
// LessonsScreen
// ─────────────────────────────────────────────────────────────────────────────

class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  _LessonListScope _scope = _LessonListScope.all;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final SessionState session = await ref.read(sessionProvider.future);
    if (!context.mounted) return;
    if (session is! SessionTeacher) return;

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LessonComposerScreen()),
    );
    if (saved ?? false) ref.invalidate(lessonsProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Lesson lesson) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LessonComposerScreen(lesson: lesson),
      ),
    );
    if (saved ?? false) ref.invalidate(lessonsProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Delete Lesson',
      type: AppDialogType.warning,
      message: 'Delete "${lesson.title}"? This cannot be undone.',
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
      await ref.read(lessonsRepositoryProvider).delete(lesson.id);
      ref.invalidate(lessonsProvider);
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _assignSections(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AssignSectionsDialog(lesson: lesson),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Lesson>> lessons = ref.watch(lessonsProvider);

    return Material(
      color: AppColors.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Header ─────────────────────────────────────────────────
            BmPageHeader(
              title: 'Lessons',
              subtitle: 'Built-in and your own instructional content.',
              action: BmPrimaryButton(
                label: 'New Lesson',
                onPressed: () => _create(context, ref),
              ),
            ),
            // ── List ───────────────────────────────────────────────────
            lessons.when(
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
                            : 'Could not load lessons.',
                    onRetry: () => ref.invalidate(lessonsProvider),
                  ),
              data: (List<Lesson> list) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No lessons yet',
                    description: 'Create your first lesson.',
                    actionLabel: 'New Lesson',
                    onAction: () => _create(context, ref),
                  );
                }
                final List<TeacherContentListEntry<Lesson>> ordered =
                    orderTeacherLessons(list);
                final List<TeacherContentListEntry<Lesson>> visible =
                    ordered.where((TeacherContentListEntry<Lesson> entry) {
                      final Lesson lesson = entry.content;
                      return switch (_scope) {
                        _LessonListScope.all => true,
                        _LessonListScope.builtIn =>
                          lesson.sourceType == ContentSourceType.builtIn,
                        _LessonListScope.mine =>
                          lesson.sourceType == ContentSourceType.teacher,
                      };
                    }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _LessonListFilters(
                      selected: _scope,
                      onSelected: (value) => setState(() => _scope = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (visible.isEmpty)
                      const AppEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No lessons in this view',
                        description: 'Choose another lesson filter.',
                      )
                    else
                      _LessonSequenceList(
                        lessons: visible,
                        onEdit: (l) => _edit(context, ref, l),
                        onDelete: (l) => _delete(context, ref, l),
                        onAssign: (l) => _assignSections(context, ref, l),
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

enum _LessonListScope { all, builtIn, mine }

class _LessonListFilters extends StatelessWidget {
  const _LessonListFilters({required this.selected, required this.onSelected});

  final _LessonListScope selected;
  final ValueChanged<_LessonListScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final (_LessonListScope scope, String label) option
            in <(_LessonListScope, String)>[
              (_LessonListScope.all, 'All'),
              (_LessonListScope.builtIn, 'Built-in'),
              (_LessonListScope.mine, 'My lessons'),
            ])
          ChoiceChip(
            label: Text(option.$2),
            selected: selected == option.$1,
            onSelected: (_) => onSelected(option.$1),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sequence list
// ─────────────────────────────────────────────────────────────────────────────

class _LessonSequenceList extends StatelessWidget {
  const _LessonSequenceList({
    required this.lessons,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  final List<TeacherContentListEntry<Lesson>> lessons;
  final void Function(Lesson) onEdit;
  final void Function(Lesson) onDelete;
  final void Function(Lesson) onAssign;

  static const double _nodeSize = 48.0;
  static const double _nodeColWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < lessons.length; i++)
          _LessonSequenceRow(
            lesson: lessons[i].content,
            sequenceNumber: lessons[i].sequenceNumber,
            index: i,
            isFirst: i == 0,
            isLast: i == lessons.length - 1,
            nodeSize: _nodeSize,
            nodeColWidth: _nodeColWidth,
            onEdit: onEdit,
            onDelete: onDelete,
            onAssign: onAssign,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single lesson row (node + connector + card)
// ─────────────────────────────────────────────────────────────────────────────

class _LessonSequenceRow extends StatefulWidget {
  const _LessonSequenceRow({
    required this.lesson,
    required this.sequenceNumber,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.nodeSize,
    required this.nodeColWidth,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  final Lesson lesson;
  final int? sequenceNumber;
  final int index;
  final bool isFirst;
  final bool isLast;
  final double nodeSize;
  final double nodeColWidth;
  final void Function(Lesson) onEdit;
  final void Function(Lesson) onDelete;
  final void Function(Lesson) onAssign;

  @override
  State<_LessonSequenceRow> createState() => _LessonSequenceRowState();
}

class _LessonSequenceRowState extends State<_LessonSequenceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isBuiltIn =
        widget.lesson.sourceType == ContentSourceType.builtIn;
    final glyph = _glyphFor(widget.lesson.title, widget.index);

    final Color glyphFg = glyph.useAccent ? AppColors.accent : AppColors.teal;
    final Color glyphBg =
        glyph.useAccent ? AppColors.accentSoft : AppColors.tealSoft;

    // Card height is dynamic — we just need to know the node column layout.
    // The node is centred vertically to the first line of the card.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Step node + connector column ──────────────────────────────
          SizedBox(
            width: widget.nodeColWidth,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                // Connector line — runs full column height, clipped above/below
                // the node.  We draw it behind the node (lower in stack order).
                Positioned.fill(
                  child: Column(
                    children: <Widget>[
                      // Space above node (half of node size)
                      SizedBox(height: widget.nodeSize / 2),
                      // Dashed line — occupies the rest of the column
                      Expanded(
                        child:
                            widget.isLast
                                ? const SizedBox.shrink()
                                : _DashedLine(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
                // Step node (drawn on top)
                Positioned(
                  top: 0,
                  child: _StepNode(
                    key: ValueKey<String>(
                      'lesson-sequence-${widget.lesson.id}',
                    ),
                    number: widget.sequenceNumber,
                    size: widget.nodeSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Lesson card ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          _hovered ? const Color(0xFFC8D3EC) : AppColors.line,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color:
                            _hovered
                                ? AppColors.accent.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                        blurRadius: _hovered ? 16 : 6,
                        offset: Offset(0, _hovered ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Glyph square
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: glyphBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          glyph.symbol,
                          style: AppTextStyles.lexend(
                            size: 18,
                            weight: FontWeight.w700,
                            color: glyphFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title + description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    widget.lesson.title,
                                    style: AppTextStyles.lexend(
                                      size: 16,
                                      weight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                BmSourceBadge(isBuiltIn: isBuiltIn),
                                if (!isBuiltIn) ...<Widget>[
                                  const SizedBox(width: 8),
                                  _LessonStatusBadge(
                                    status: widget.lesson.publicationStatus,
                                  ),
                                ],
                              ],
                            ),
                            if (widget.lesson.body.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                widget.lesson.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.inter(
                                  size: 13,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ],
                            // Action row for teacher-owned lessons
                            if (!isBuiltIn) ...<Widget>[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  _TextActionButton(
                                    label: 'Assign Sections',
                                    onPressed:
                                        () => widget.onAssign(widget.lesson),
                                  ),
                                  const SizedBox(width: 8),
                                  _TextActionButton(
                                    label: 'Edit',
                                    onPressed:
                                        () => widget.onEdit(widget.lesson),
                                  ),
                                  const SizedBox(width: 8),
                                  _TextActionButton(
                                    label: 'Delete',
                                    onPressed:
                                        () => widget.onDelete(widget.lesson),
                                    isDanger: true,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trailing chevron
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.grayText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonStatusBadge extends StatelessWidget {
  const _LessonStatusBadge({required this.status});

  final LessonPublicationStatus status;

  @override
  Widget build(BuildContext context) {
    final bool published = status == LessonPublicationStatus.published;
    final Color foreground =
        published ? const Color(0xFF246B58) : AppColors.textSoft;
    final Color background =
        published
            ? const Color(0xFFE7F4EF)
            : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.inter(
          size: 11,
          weight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step node
// ─────────────────────────────────────────────────────────────────────────────

class _StepNode extends StatelessWidget {
  const _StepNode({super.key, required this.number, required this.size});
  final int? number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        number?.toString() ?? '•',
        style: AppTextStyles.lexend(
          size: 16,
          weight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed vertical line
// ─────────────────────────────────────────────────────────────────────────────

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedLinePainter(color: color));
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    const double dashH = 6;
    const double gapH = 4;
    double y = 0;
    final double cx = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + dashH), paint);
      y += dashH + gapH;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline text action button (for card footer, teacher-owned)
// ─────────────────────────────────────────────────────────────────────────────

class _TextActionButton extends StatefulWidget {
  const _TextActionButton({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  State<_TextActionButton> createState() => _TextActionButtonState();
}

class _TextActionButtonState extends State<_TextActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        widget.isDanger
            ? (_hovered ? AppColors.danger : AppColors.textSoft)
            : (_hovered ? AppColors.accent : AppColors.textSoft);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 140),
          style: AppTextStyles.inter(
            size: 13,
            weight: FontWeight.w500,
            color: fg,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AssignSectionsDialog
// ─────────────────────────────────────────────────────────────────────────────

class _AssignSectionsDialog extends ConsumerWidget {
  const _AssignSectionsDialog({required this.lesson});
  final Lesson lesson;

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
            .read(lessonsRepositoryProvider)
            .assign(
              lessonId: lesson.id,
              sectionId: sectionId,
              assignedBy: session.profile.id,
            );
      } else {
        await ref
            .read(lessonsRepositoryProvider)
            .unassign(lessonId: lesson.id, sectionId: sectionId);
      }
      ref.invalidate(lessonSectionIdsProvider(lesson.id));
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
      lessonSectionIdsProvider(lesson.id),
    );

    return AppDialog(
      title: 'Assign Sections — ${lesson.title}',
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
              'You have no sections to assign this lesson to yet.',
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
