import 'package:flutter/material.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../core/models/question_bank_item.dart';
import '../../../core/models/question_choice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result type — UNCHANGED
// ─────────────────────────────────────────────────────────────────────────────

/// Result of the New/Edit Question form — shared by the Question Bank tab
/// and the Quizzes tab's "New Question" flow, so both write to
/// `question_bank` via the exact same shape.
class QuestionFormResult {
  const QuestionFormResult({
    required this.promptText,
    this.topic,
    this.explanationText,
    required this.choices,
  });
  final String promptText;
  final String? topic;
  final String? explanationText;
  final List<({String choiceText, bool isCorrect})> choices;
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal mutable choice row — UNCHANGED
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceRow {
  _ChoiceRow({String text = '', this.isCorrect = false})
      : controller = TextEditingController(text: text);
  final TextEditingController controller;
  bool isCorrect;
}

// ─────────────────────────────────────────────────────────────────────────────
// Design constants (local — keeps the dialog self-contained)
// ─────────────────────────────────────────────────────────────────────────────

const Color _correctBg     = Color(0xFFECFDF5);
const Color _correctBorder = Color(0xFF86EFAC);
const Color _correctText   = Color(0xFF16A34A);
const Color _neutralBg     = Color(0xFFF8F9FC);
const Color _neutralBorder = Color(0xFFE4E9F4);
const Color _fieldBorder   = Color(0xFFDDE3F0);
const Color _labelMuted    = Color(0xFF8A93AD);

// ─────────────────────────────────────────────────────────────────────────────
// QuestionFormDialog — public widget (name kept for call-site compatibility)
// ─────────────────────────────────────────────────────────────────────────────

/// New/Edit Question dialog — redesigned shell, all logic unchanged.
///
/// Shared between the Question Bank tab and the Quizzes tab's question
/// picker.
class QuestionFormDialog extends StatefulWidget {
  const QuestionFormDialog({super.key, this.initial, this.initialChoices = const []});
  final QuestionBankItem? initial;
  final List<QuestionChoice> initialChoices;

  @override
  State<QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<QuestionFormDialog> {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final TextEditingController _promptController =
      TextEditingController(text: widget.initial?.promptText ?? '');
  late final TextEditingController _topicController =
      TextEditingController(text: widget.initial?.topic ?? '');
  late final TextEditingController _explanationController =
      TextEditingController(text: widget.initial?.explanationText ?? '');

  late final List<_ChoiceRow> _choiceRows = widget.initialChoices.isEmpty
      ? [_ChoiceRow(), _ChoiceRow()]
      : [
          for (final QuestionChoice c in widget.initialChoices)
            _ChoiceRow(text: c.choiceText, isCorrect: c.isCorrect),
        ];

  String? _errorText;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _promptController.dispose();
    _topicController.dispose();
    _explanationController.dispose();
    for (final _ChoiceRow row in _choiceRows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  // ── Mutators — UNCHANGED logic ─────────────────────────────────────────────
  void _addChoiceRow() => setState(() => _choiceRows.add(_ChoiceRow()));

  void _removeChoiceRow(int index) {
    setState(() {
      _choiceRows.removeAt(index).controller.dispose();
    });
  }

  /// Single-select: mark only [index] as correct, clear all others.
  void _selectCorrect(int index) {
    setState(() {
      for (int i = 0; i < _choiceRows.length; i++) {
        _choiceRows[i].isCorrect = (i == index);
      }
    });
  }

  void _submit() {
    final String promptText = _promptController.text.trim();
    if (promptText.isEmpty) {
      setState(() => _errorText = 'Enter the question prompt.');
      return;
    }
    if (_choiceRows.length < 2) {
      setState(() => _errorText = 'Add at least 2 choices.');
      return;
    }
    if (_choiceRows.any((row) => row.controller.text.trim().isEmpty)) {
      setState(() => _errorText = 'Every choice needs text.');
      return;
    }
    if (!_choiceRows.any((row) => row.isCorrect)) {
      setState(() => _errorText = 'Mark at least one choice as correct.');
      return;
    }

    final String topic = _topicController.text.trim();
    final String explanation = _explanationController.text.trim();

    Navigator.of(context).pop(
      QuestionFormResult(
        promptText: promptText,
        topic: topic.isEmpty ? null : topic,
        explanationText: explanation.isEmpty ? null : explanation,
        choices: [
          for (final _ChoiceRow row in _choiceRows)
            (choiceText: row.controller.text.trim(), isCorrect: row.isCorrect),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.initial != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Header ────────────────────────────────────────────────────
            _DialogHeader(isEdit: isEdit),
            // ── Scrollable content ────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Question prompt
                    _FieldLabel(
                      label: 'Question prompt',
                    ),
                    const SizedBox(height: 6),
                    _StyledTextField(
                      controller: _promptController,
                      hint: 'e.g. What is 1 + 1 = ?',
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    // Topic
                    _FieldLabel(
                      label: 'Topic',
                      hint: '(optional)',
                    ),
                    const SizedBox(height: 6),
                    _StyledTextField(
                      controller: _topicController,
                      hint: 'e.g. Addition',
                    ),
                    const SizedBox(height: 16),
                    // Explanation
                    _FieldLabel(
                      label: 'Explanation',
                      hint: '(shown after answering)',
                    ),
                    const SizedBox(height: 6),
                    _StyledTextField(
                      controller: _explanationController,
                      hint: 'Explain why the correct answer is correct',
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    // Answer choices header
                    RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Answer choices',
                            style: AppTextStyles.inter(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          TextSpan(
                            text: ' — select the correct one',
                            style: AppTextStyles.inter(
                              size: 13,
                              color: _labelMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Choice rows
                    for (int i = 0; i < _choiceRows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ChoiceRowWidget(
                          row: _choiceRows[i],
                          index: i,
                          canDelete: _choiceRows.length > 2,
                          onSelectCorrect: () => _selectCorrect(i),
                          onDelete: () => _removeChoiceRow(i),
                        ),
                      ),
                    // Add choice
                    _AddChoiceButton(onPressed: _addChoiceRow),
                    // Error
                    if (_errorText != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.error_outline_rounded,
                              size: 14, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Text(
                            _errorText!,
                            style: AppTextStyles.inter(
                              size: 13,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // ── Footer ────────────────────────────────────────────────────
            _DialogFooter(
              isEdit: isEdit,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DialogHeader
// ─────────────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.isEdit});
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _fieldBorder)),
      ),
      child: Row(
        children: <Widget>[
          // Icon badge
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEdit ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEdit ? 'Edit question' : 'New question',
              style: AppTextStyles.lexend(
                size: 17,
                weight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          // Close button
          _CloseButton(onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DialogFooter
// ─────────────────────────────────────────────────────────────────────────────

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.isEdit,
    required this.onCancel,
    required this.onSave,
  });
  final bool isEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FC),
        border: Border(top: BorderSide(color: _fieldBorder)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _FooterButton(
            label: 'Cancel',
            onPressed: onCancel,
            filled: false,
          ),
          const SizedBox(width: 10),
          _FooterButton(
            label: isEdit ? 'Save changes' : 'Create question',
            onPressed: onSave,
            filled: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChoiceRowWidget
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceRowWidget extends StatefulWidget {
  const _ChoiceRowWidget({
    required this.row,
    required this.index,
    required this.canDelete,
    required this.onSelectCorrect,
    required this.onDelete,
  });
  final _ChoiceRow row;
  final int index;
  final bool canDelete;
  final VoidCallback onSelectCorrect;
  final VoidCallback onDelete;

  @override
  State<_ChoiceRowWidget> createState() => _ChoiceRowWidgetState();
}

class _ChoiceRowWidgetState extends State<_ChoiceRowWidget> {
  bool _deleteHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool correct = widget.row.isCorrect;

    final Color rowBg     = correct ? _correctBg     : _neutralBg;
    final Color rowBorder = correct ? _correctBorder : _neutralBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rowBorder),
      ),
      child: Row(
        children: <Widget>[
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: const Color(0xFFBCC3D8),
            ),
          ),
          // Radio indicator — tap anywhere on it
          GestureDetector(
            onTap: widget.onSelectCorrect,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: correct ? _correctText : Colors.transparent,
                  border: Border.all(
                    color: correct ? _correctText : const Color(0xFFBCC3D8),
                    width: 2,
                  ),
                ),
                child: correct
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Choice text input — transparent/borderless, expands
          Expanded(
            child: TextField(
              controller: widget.row.controller,
              style: AppTextStyles.inter(
                size: 14,
                color: AppColors.navy,
              ),
              decoration: InputDecoration(
                hintText: 'Choice ${widget.index + 1}',
                hintStyle: AppTextStyles.inter(
                  size: 14,
                  color: const Color(0xFFADB5CC),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          // "Correct" label
          if (correct) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              'Correct',
              style: AppTextStyles.inter(
                size: 12,
                weight: FontWeight.w600,
                color: _correctText,
              ),
            ),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 8),
          // Delete button
          MouseRegion(
            cursor: widget.canDelete
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onEnter: (_) => setState(() => _deleteHovered = true),
            onExit: (_) => setState(() => _deleteHovered = false),
            child: GestureDetector(
              onTap: widget.canDelete ? widget.onDelete : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _deleteHovered && widget.canDelete
                      ? AppColors.dangerSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: !widget.canDelete
                      ? const Color(0xFFD0D5E5)
                      : _deleteHovered
                          ? AppColors.danger
                          : const Color(0xFFBCC3D8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.hint});
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.inter(
            size: 13,
            weight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(width: 5),
          Text(
            hint!,
            style: AppTextStyles.inter(size: 13, color: _labelMuted),
          ),
        ],
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String? hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: AppTextStyles.inter(size: 14, color: AppColors.navy),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.inter(size: 14, color: const Color(0xFFADB5CC)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _AddChoiceButton extends StatefulWidget {
  const _AddChoiceButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_AddChoiceButton> createState() => _AddChoiceButtonState();
}

class _AddChoiceButtonState extends State<_AddChoiceButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Add choice',
                style: AppTextStyles.inter(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.graySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? AppColors.line : Colors.transparent,
            ),
          ),
          child: Icon(Icons.close_rounded, size: 18, color: AppColors.textSoft),
        ),
      ),
    );
  }
}

class _FooterButton extends StatefulWidget {
  const _FooterButton({
    required this.label,
    required this.onPressed,
    required this.filled,
  });
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.filled
        ? (_hovered ? AppColors.navy2 : AppColors.navy)
        : (_hovered ? AppColors.graySoft : Colors.white);
    final Color fg = widget.filled ? Colors.white : AppColors.navy;
    final Color border = widget.filled ? Colors.transparent : _fieldBorder;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.inter(
              size: 14,
              weight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
