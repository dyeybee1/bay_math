import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_text_styles.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_result_row.dart';
import '../../../core/models/student.dart';
import '../data/teacher_quiz_results_providers.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Filter state
// ─────────────────────────────────────────────────────────────────────────────

class QuizResultsFilter {
  const QuizResultsFilter({this.section = 'All', this.assessmentType = 'All'});
  final String section;
  final String assessmentType;
  QuizResultsFilter copyWith({String? section, String? assessmentType}) =>
      QuizResultsFilter(
        section: section ?? this.section,
        assessmentType: assessmentType ?? this.assessmentType,
      );
}

final StateProvider<QuizResultsFilter> quizResultsFilterProvider =
    StateProvider<QuizResultsFilter>((_) => const QuizResultsFilter());

// ─────────────────────────────────────────────────────────────────────────────
// Layout constants
// ─────────────────────────────────────────────────────────────────────────────

const double _studentColW = 168.0;
const double _maxColW = 148.0;
const double _minColW = 86.0;

// ─────────────────────────────────────────────────────────────────────────────
// Score-chip color helper — uses AppSemanticColors, no hardcoded hex
// ─────────────────────────────────────────────────────────────────────────────

({Color bg, Color fg}) _chipColors(double pct, BuildContext context) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  final AppSemanticColors? sem = Theme.of(context).extension<AppSemanticColors>();
  if (pct >= 80) {
    return (
      bg: sem?.successContainer ?? cs.primaryContainer,
      fg: sem?.onSuccessContainer ?? cs.onPrimaryContainer,
    );
  }
  if (pct >= 50) {
    return (
      bg: sem?.warningContainer ?? cs.tertiaryContainer,
      fg: sem?.onWarningContainer ?? cs.onTertiaryContainer,
    );
  }
  return (bg: cs.errorContainer, fg: cs.onErrorContainer);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────

/// Adaptive quiz results table. Pass [matrix] from
/// [teacherQuizResultsMatrixProvider] and [subtitle] for the header line.
class QuizResultsTable extends ConsumerStatefulWidget {
  const QuizResultsTable({
    super.key,
    required this.matrix,
    required this.subtitle,
    this.gradeLevelLabel = '',
    this.sectionName = '',
    this.assessmentTypeLabel = '',
  });

  final QuizResultsMatrix matrix;
  final String subtitle;
  final String gradeLevelLabel;
  final String sectionName;
  final String assessmentTypeLabel;

  @override
  ConsumerState<QuizResultsTable> createState() => _QuizResultsTableState();
}

class _QuizResultsTableState extends ConsumerState<QuizResultsTable> {
  // Shared scroll controller so the pinned student column and the
  // horizontally-scrolling score columns stay row-aligned vertically.
  final ScrollController _verticalCtrl = ScrollController();
  final ScrollController _hScrollCtrl = ScrollController();

  @override
  void dispose() {
    _verticalCtrl.dispose();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  // ── Stat computations ───────────────────────────────────────────────────
  int get _studentCount => widget.matrix.students.length;

  /// Average of each student's average % across quizzes they've taken.
  double? get _avgScore {
    if (widget.matrix.students.isEmpty) return null;
    final List<double> studentAvgs = [];
    for (final Student s in widget.matrix.students) {
      final Map<String, QuizResultRow>? row =
          widget.matrix.cellsByStudentThenQuiz[s.id];
      if (row == null || row.isEmpty) continue;
      final List<double> pcts = [];
      for (final QuizResultRow cell in row.values) {
        final int? total = widget.matrix.totalQuestionsByQuizId[cell.quizId];
        final num? score = cell.score;
        if (score != null && total != null && total > 0) {
          pcts.add(score / total * 100);
        }
      }
      if (pcts.isNotEmpty) {
        studentAvgs.add(pcts.reduce((a, b) => a + b) / pcts.length);
      }
    }
    if (studentAvgs.isEmpty) return null;
    return studentAvgs.reduce((a, b) => a + b) / studentAvgs.length;
  }

  int get _needsReview {
    int count = 0;
    for (final Student s in widget.matrix.students) {
      final Map<String, QuizResultRow>? row =
          widget.matrix.cellsByStudentThenQuiz[s.id];
      if (row == null || row.isEmpty) continue;
      final List<double> pcts = [];
      for (final QuizResultRow cell in row.values) {
        final int? total = widget.matrix.totalQuestionsByQuizId[cell.quizId];
        final num? score = cell.score;
        if (score != null && total != null && total > 0) {
          pcts.add(score / total * 100);
        }
      }
      if (pcts.isNotEmpty &&
          pcts.reduce((a, b) => a + b) / pcts.length < 70) {
        count++;
      }
    }
    return count;
  }

  // ── CSV export — same pattern as _ExportCsvButton ──────────────────────
  Future<void> _exportCsv() async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final QuizResultsMatrix m = widget.matrix;

    // Header row
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>[
        'Student',
        for (final Quiz q in m.quizzes)
          '${q.title} (${m.totalQuestionsByQuizId[q.id] ?? '?'} items)',
      ],
      for (final Student s in m.students)
        <Object?>[
          s.fullName,
          for (final Quiz q in m.quizzes)
            () {
              final QuizResultRow? cell =
                  m.cellsByStudentThenQuiz[s.id]?[q.id];
              final num? score = cell?.score;
              if (score == null) return '';
              return score == score.roundToDouble()
                  ? score.toInt().toString()
                  : score.toString();
            }(),
        ],
    ];

    const String bom = '\uFEFF';
    final String csv =
        '$bom${const ListToCsvConverter(eol: '\r\n').convert(rows)}';

    final String dateStr = () {
      final DateTime now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
    }();
    final String defaultName =
        '${widget.gradeLevelLabel}-${widget.sectionName}'
        '_${widget.assessmentTypeLabel}_$dateStr.csv';

    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Quiz Results',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
    );
    if (savePath == null) {
      msg.showSnackBar(const SnackBar(content: Text('Export cancelled.')));
      return;
    }
    try {
      final String path =
          savePath.toLowerCase().endsWith('.csv') ? savePath : '$savePath.csv';
      await File(path).writeAsBytes(utf8.encode(csv));
      msg.showSnackBar(
        SnackBar(content: Text('Exported to ${path.split(Platform.pathSeparator).last}')),
      );
    } catch (_) {
      msg.showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Header ─────────────────────────────────────────────────────
        _QRHeader(
          subtitle: widget.subtitle,
          onExport: _exportCsv,
        ),
        const SizedBox(height: 20),
        // ── Stat cards ─────────────────────────────────────────────────
        _QRStatCards(
          studentCount: _studentCount,
          avgScore: _avgScore,
          needsReview: _needsReview,
        ),
        const SizedBox(height: 20),
        // ── Table ──────────────────────────────────────────────────────
        _QRAdaptiveTable(
          matrix: widget.matrix,
          verticalCtrl: _verticalCtrl,
          hScrollCtrl: _hScrollCtrl,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header sub-widget
// ─────────────────────────────────────────────────────────────────────────────

class _QRHeader extends ConsumerStatefulWidget {
  const _QRHeader({required this.subtitle, required this.onExport});
  final String subtitle;
  final VoidCallback onExport;

  @override
  ConsumerState<_QRHeader> createState() => _QRHeaderState();
}

class _QRHeaderState extends ConsumerState<_QRHeader> {
  String? _defaultSectionId(List<MySection> sections) {
    for (final MySection section in sections) {
      if (section.section != null) return section.section!.id;
    }
    return null;
  }

  int _activeFilterCount(
    TeacherQuizResultsSelection selection,
    List<MySection> sections,
  ) {
    int count = 0;
    if (selection.sectionId != _defaultSectionId(sections)) count += 1;
    if (selection.assessmentType != QuizResultsAssessmentFilter.regular) {
      count += 1;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;

    final TeacherQuizResultsSelection appliedSelection = ref.watch(
      teacherQuizResultsSelectionProvider,
    );
    final List<MySection> sections =
        ref.watch(mySectionsProvider).value ?? const <MySection>[];
    final int activeFilterCount = _activeFilterCount(
      appliedSelection,
      sections,
    );
    final String filterLabel =
        activeFilterCount == 0 ? 'Filters' : 'Filters · $activeFilterCount';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Quiz results',
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // ── Filters popup ────────────────────────────────────────────────
        PopupMenuButton<Never>(
          key: const Key('teacher_quiz_results_filters_button'),
          tooltip: 'Filters',
          offset: const Offset(0, 44),
          color: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder:
              (_) => <PopupMenuEntry<Never>>[
                PopupMenuItem<Never>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: _QRFilterPanel(
                    initialSelection: appliedSelection,
                    sections: sections,
                    onApply: (TeacherQuizResultsSelection selection) {
                      ref
                          .read(teacherQuizResultsSelectionProvider.notifier)
                          .state = selection;
                    },
                  ),
                ),
              ],
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list_rounded, size: 16),
              label: Text(filterLabel),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: widget.onExport,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export CSV'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _QRFilterPanel extends StatefulWidget {
  const _QRFilterPanel({
    required this.initialSelection,
    required this.sections,
    required this.onApply,
  });

  final TeacherQuizResultsSelection initialSelection;
  final List<MySection> sections;
  final ValueChanged<TeacherQuizResultsSelection> onApply;

  @override
  State<_QRFilterPanel> createState() => _QRFilterPanelState();
}

class _QRFilterPanelState extends State<_QRFilterPanel> {
  late String? _sectionId;
  late QuizResultsAssessmentFilter? _assessmentType;

  String? get _defaultSectionId {
    for (final MySection section in widget.sections) {
      if (section.section != null) return section.section!.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _sectionId = widget.initialSelection.sectionId;
    _assessmentType = widget.initialSelection.assessmentType;
  }

  void _reset() {
    setState(() {
      _sectionId = _defaultSectionId;
      _assessmentType = QuizResultsAssessmentFilter.regular;
    });
  }

  void _apply() {
    final TeacherQuizResultsSelection selection = TeacherQuizResultsSelection(
      sectionId: _sectionId,
      assessmentType: _assessmentType,
    );
    Navigator.of(context).pop();
    widget.onApply(selection);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool canApply = _sectionId != null && _assessmentType != null;

    return SizedBox(
      key: const Key('teacher_quiz_results_filter_popover'),
      width: 304,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Filters',
                        style: AppTextStyles.inter(
                          size: 15,
                          weight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Apply both selections when ready.',
                        style: AppTextStyles.inter(
                          size: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('teacher_quiz_results_filter_reset'),
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Section',
              style: AppTextStyles.inter(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 4),
            KeyedSubtree(
              key: const Key('teacher_quiz_results_section_filter'),
              child: DropdownButtonFormField<String>(
                key: ValueKey<String?>('section-$_sectionId'),
                initialValue: _sectionId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final MySection section in widget.sections)
                    if (section.section != null)
                      DropdownMenuItem<String>(
                        value: section.section!.id,
                        child: Text(
                          '${section.section!.gradeLevel.label} — '
                          '${section.section!.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: (String? value) {
                  setState(() => _sectionId = value);
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Assessment type',
              style: AppTextStyles.inter(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 4),
            KeyedSubtree(
              key: const Key('teacher_quiz_results_assessment_filter'),
              child: DropdownButtonFormField<QuizResultsAssessmentFilter>(
                key: ValueKey<QuizResultsAssessmentFilter?>(_assessmentType),
                initialValue: _assessmentType,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                items: <DropdownMenuItem<QuizResultsAssessmentFilter>>[
                  for (final QuizResultsAssessmentFilter filter
                      in QuizResultsAssessmentFilter.values)
                    DropdownMenuItem<QuizResultsAssessmentFilter>(
                      value: filter,
                      child: Text(filter.label),
                    ),
                ],
                onChanged: (QuizResultsAssessmentFilter? value) {
                  setState(() => _assessmentType = value);
                },
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('teacher_quiz_results_filter_apply'),
              onPressed: canApply ? _apply : null,
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat cards
// ─────────────────────────────────────────────────────────────────────────────

class _QRStatCards extends StatelessWidget {
  const _QRStatCards({
    required this.studentCount,
    required this.avgScore,
    required this.needsReview,
  });
  final int studentCount;
  final double? avgScore;
  final int needsReview;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppSemanticColors? sem =
        Theme.of(context).extension<AppSemanticColors>();
    final Color successColor = sem?.success ?? cs.primary;
    final Color errorColor = cs.error;

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: <Widget>[
        _StatCard(
          label: 'Students',
          value: '$studentCount',
          valueColor: cs.onSurface,
        ),
        _StatCard(
          label: 'Avg score',
          value: avgScore == null ? '—' : '${avgScore!.round()}%',
          valueColor: successColor,
        ),
        _StatCard(
          label: 'Needs review',
          value: '$needsReview',
          valueColor: errorColor,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            value,
            style: (tt.headlineMedium ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed row heights — shared by the pinned column and every score column so
// that row i on the left is always the same height as row i on the right.
// ─────────────────────────────────────────────────────────────────────────────

/// Height of the quiz-name header row.
/// Sized to accommodate ~4 lines of wrapped text at the largest fontSize.
const double _headerRowH = 104.0;

/// Height of the "Total items" row.
const double _totalRowH = 44.0;

/// Height of each individual student data row.
const double _studentRowH = 56.0;

// ─────────────────────────────────────────────────────────────────────────────
// Adaptive table
// ─────────────────────────────────────────────────────────────────────────────

class _QRAdaptiveTable extends StatelessWidget {
  const _QRAdaptiveTable({
    required this.matrix,
    required this.verticalCtrl,
    required this.hScrollCtrl,
  });
  final QuizResultsMatrix matrix;
  final ScrollController verticalCtrl;
  final ScrollController hScrollCtrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        // ── Adaptive column width logic ─────────────────────────────────
        final int n = matrix.quizzes.length;
        final double available = constraints.maxWidth - _studentColW;
        final double rawColW = n > 0 ? available / n : _maxColW;
        final bool scrollMode;
        final double colW;
        if (rawColW >= _minColW) {
          colW = rawColW.clamp(0.0, _maxColW);
          scrollMode = false;
        } else {
          colW = _minColW;
          scrollMode = true;
        }
        final double t =
            ((colW - _minColW) / (_maxColW - _minColW)).clamp(0.0, 1.0);
        final double fontSize = 11 + t * 3;
        final double hPad = 8 + t * 8;

        // ── Cell style factories ────────────────────────────────────────
        TextStyle headerStyle(BuildContext c) => AppTextStyles.inter(
              size: fontSize,
              weight: FontWeight.w600,
              color: Theme.of(c).colorScheme.onSurface,
            );
        TextStyle bodyStyle(BuildContext c) => AppTextStyles.inter(
              size: fontSize,
              color: Theme.of(c).colorScheme.onSurface,
            );
        TextStyle mutedStyle(BuildContext c) => AppTextStyles.inter(
              size: fontSize - 1,
              color: Theme.of(c).colorScheme.onSurfaceVariant,
            );

        // ── Pinned "Student" header cell — must be exactly _headerRowH tall ──
        final Widget studentHeaderCell = SizedBox(
          width: _studentColW,
          height: _headerRowH,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text('Student', style: headerStyle(ctx)),
          ),
        );

        // ── Pinned "Total items" cell — must be exactly _totalRowH tall ──────
        final Widget studentTotalCell = SizedBox(
          width: _studentColW,
          height: _totalRowH,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text('Total items', style: mutedStyle(ctx)),
          ),
        );

        // ── Score-column header cell — exactly _headerRowH tall ──────────────
        Widget quizHeaderCell(Quiz q) => SizedBox(
              width: colW,
              height: _headerRowH,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  border: Border(
                    left: BorderSide(color: cs.outlineVariant, width: 0.5),
                    bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      q.title,
                      textAlign: TextAlign.center,
                      style: headerStyle(ctx),
                      // Allow up to 4 lines of wrapping — _headerRowH is sized for this.
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );

        // ── Score-column "Total items" cell — exactly _totalRowH tall ────────
        Widget totalItemsCell(Quiz q) => SizedBox(
              width: colW,
              height: _totalRowH,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(
                    left: BorderSide(color: cs.outlineVariant, width: 0.5),
                    bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                ),
                child: Text(
                  '${matrix.totalQuestionsByQuizId[q.id] ?? '—'}',
                  style: mutedStyle(ctx),
                ),
              ),
            );

        // ── Pinned student name cell — exactly _studentRowH tall ─────────────
        Widget studentNameCell(Student s) => SizedBox(
              width: _studentColW,
              height: _studentRowH,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  s.fullName,
                  style: bodyStyle(ctx),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );

        // ── Score cell — exactly _studentRowH tall ───────────────────────────
        Widget scoreCell(Student s, Quiz q) {
          final QuizResultRow? cell =
              matrix.cellsByStudentThenQuiz[s.id]?[q.id];
          final num? score = cell?.score;
          final int? total = matrix.totalQuestionsByQuizId[q.id];
          Widget inner;
          if (score == null) {
            inner = Text(
              '—',
              style: mutedStyle(ctx).copyWith(color: cs.onSurfaceVariant),
            );
          } else {
            final double pct =
                total != null && total > 0 ? score / total * 100 : 0;
            final (:Color bg, :Color fg) = _chipColors(pct, ctx);
            final String label = score == score.roundToDouble()
                ? score.toInt().toString()
                : score.toString();
            inner = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: AppTextStyles.inter(
                  size: fontSize,
                  weight: FontWeight.w600,
                  color: fg,
                ),
              ),
            );
          }
          return SizedBox(
            width: colW,
            height: _studentRowH,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: cs.outlineVariant, width: 0.5),
                  bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                ),
              ),
              child: inner,
            ),
          );
        }

        // ── Pinned column — all cells have fixed heights ──────────────────────
        final Widget pinnedCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            studentHeaderCell,
            studentTotalCell,
            for (final Student s in matrix.students) studentNameCell(s),
          ],
        );

        // ── Score columns (horizontally scrollable) ───────────────────────────
        final Widget scoreColumns = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final Quiz q in matrix.quizzes)
              Column(
                children: <Widget>[
                  quizHeaderCell(q),
                  totalItemsCell(q),
                  for (final Student s in matrix.students) scoreCell(s, q),
                ],
              ),
          ],
        );

        final Widget tableContent = Stack(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                pinnedCol,
                Expanded(
                  child: scrollMode
                      ? SingleChildScrollView(
                          controller: hScrollCtrl,
                          scrollDirection: Axis.horizontal,
                          child: scoreColumns,
                        )
                      : scoreColumns,
                ),
              ],
            ),
            // Right-edge fade when in scroll mode
            if (scrollMode)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            cs.surface.withValues(alpha: 0),
                            cs.surface,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Table container
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: tableContent,
            ),
          ],
        );
      },
    );
  }
}
