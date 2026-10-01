import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_text_styles.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_section.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'lessons_screen.dart';
import 'progress_reports_screen.dart';
import 'question_bank_screen.dart';
import 'quiz_results_screen.dart';
import 'quizzes_screen.dart';
import 'section_workspace_screen.dart';
import 'teacher_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette (legacy — still used by _MySectionsView, _WelcomeBanner, etc.)
// Sidebar now uses AppColors tokens directly.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _C {
  static const Color primaryBlue = Color(0xFF2E6FF2);
  static const Color blue700 = Color(0xFF1E4FD8);
  static const Color deepBlue = Color(0xFF0F2A5C);
  static const Color lightBlueBg = Color(0xFFE8F1FF);
  static const Color pageBg = Color(0xFFF5F9FF);
  static const Color goldLight = Color(0xFFFFC94D);
  static const Color mutedText = Color(0xFF6B7A99);
  static const Color border = Color(0xFFE4EAF7);
  static const Color white = Colors.white;
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography helpers
// ─────────────────────────────────────────────────────────────────────────────
TextStyle _fredoka(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = _C.deepBlue,
}) => GoogleFonts.fredoka(fontSize: size, fontWeight: weight, color: color);

TextStyle _inter(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _C.deepBlue,
}) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

// ─────────────────────────────────────────────────────────────────────────────
// Misc helpers
// ─────────────────────────────────────────────────────────────────────────────
String _initials(String name) {
  final List<String> p =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) {
    return p[0].substring(0, math.min(2, p[0].length)).toUpperCase();
  }
  return '${p[0][0]}${p[1][0]}'.toUpperCase();
}

String _greeting() {
  final int h = DateTime.now().hour;
  if (h < 12) return 'Good morning! ☀️';
  if (h < 18) return 'Good afternoon! 👋';
  return 'Good evening! 🌙';
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain model + provider — UNCHANGED from original
// ─────────────────────────────────────────────────────────────────────────────

/// One `teacher_sections` row paired with the resolved [Section] for display.
class MySection {
  const MySection(this.teacherSection, this.section);
  final TeacherSection teacherSection;
  final Section? section;
}

/// The signed-in Teacher's own section assignments, primary first.
final FutureProvider<List<MySection>> mySectionsProvider =
    FutureProvider<List<MySection>>((ref) async {
      final SessionState session =
          ref.watch(sessionProvider).value ?? const SessionNone();
      if (session is! SessionTeacher) return const [];

      final List<TeacherSection> assignments = await ref
          .watch(teacherSectionsRepositoryProvider)
          .fetchForTeacher(session.profile.id);
      if (assignments.isEmpty) return const [];

      final List<Section> sections = await ref
          .watch(sectionsRepositoryProvider)
          .fetchByIds(assignments.map((a) => a.sectionId).toList());
      final Map<String, Section> sectionsById = {
        for (final Section s in sections) s.id: s,
      };

      return [
        for (final TeacherSection a in assignments)
          MySection(a, sectionsById[a.sectionId]),
      ];
    });

// ─────────────────────────────────────────────────────────────────────────────
// Nav destination descriptor
// ─────────────────────────────────────────────────────────────────────────────
class _Dest {
  const _Dest({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const List<_Dest> _kDestinations = <_Dest>[
  _Dest(icon: Icons.groups_2_outlined, label: 'My Sections'),
  _Dest(icon: Icons.menu_book_outlined, label: 'Lessons'),
  _Dest(icon: Icons.help_outline_rounded, label: 'Question Bank'),
  _Dest(icon: Icons.assignment_outlined, label: 'Quizzes'),
  _Dest(icon: Icons.bar_chart_rounded, label: 'Quiz Results'),
  _Dest(icon: Icons.dashboard_outlined, label: 'Statistics'),
  _Dest(icon: Icons.summarize_outlined, label: 'Progress Reports'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Root shell
// ─────────────────────────────────────────────────────────────────────────────
class TeacherShellScreen extends ConsumerStatefulWidget {
  const TeacherShellScreen({super.key, this.initialDestination = 0});

  final int initialDestination;

  @override
  ConsumerState<TeacherShellScreen> createState() => _TeacherShellScreenState();
}

class _TeacherShellScreenState extends ConsumerState<TeacherShellScreen> {
  late int _selectedIndex;

  static const double _sidebarWidth = 248;
  static const double _mobileBreak = 700;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialDestination;
  }

  void _onNavTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final SessionState session =
        ref.watch(sessionProvider).value ?? const SessionNone();
    final String fullName =
        session is SessionTeacher ? session.profile.fullName : 'Teacher';
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= _mobileBreak;

    final Widget body = _buildBody(fullName, isWide);

    if (!isWide) {
      return Scaffold(
        backgroundColor: _C.pageBg,
        drawer: Drawer(
          width: _sidebarWidth,
          child: _Sidebar(
            selected: _selectedIndex,
            onTap: (i) {
              Navigator.of(context).pop();
              _onNavTap(i);
            },
            onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ),
        appBar: AppBar(
          backgroundColor: _C.white,
          elevation: 0,
          title: Text('BayMath', style: _fredoka(20, color: _C.deepBlue)),
        ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: _sidebarWidth,
            child: _Sidebar(
              selected: _selectedIndex,
              onTap: _onNavTap,
              onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
            ),
          ),
          Container(width: 1, color: AppColors.line),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildBody(String fullName, bool isWide) {
    final List<Widget> pages = <Widget>[
      _MySectionsView(fullName: fullName),
      const LessonsScreen(),
      const QuestionBankScreen(),
      const QuizzesScreen(),
      const QuizResultsScreen(),
      const TeacherDashboardScreen(),
      const ProgressReportsScreen(),
    ];
    return IndexedStack(index: _selectedIndex, children: pages);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onTap,
    required this.onSignOut,
  });

  final int selected;
  final ValueChanged<int> onTap;
  final VoidCallback onSignOut;

  // Height of the pinned sign-out footer — must match the actual widget height
  // so the ListView adds equivalent bottom padding and nothing hides behind it.
  static const double _signOutH = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── Scrollable nav content ────────────────────────────────────
          ListView(
            padding: const EdgeInsets.only(bottom: _signOutH + 8),
            children: <Widget>[
              // ── Logo mark + wordmark ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                child: Row(
                  children: <Widget>[
                    // Gradient badge (accent → navy2) with app initial
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: <Color>[AppColors.accent, AppColors.navy2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        'B',
                        style: AppTextStyles.lexend(
                          size: 18,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'BayMath',
                      style: AppTextStyles.lexend(
                        size: 20,
                        weight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              // ── MENU label ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  'MENU',
                  style: AppTextStyles.inter(
                    size: 11,
                    weight: FontWeight.w600,
                    color: const Color(0xFF9AA4C0),
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              // ── Nav items ────────────────────────────────────────────
              for (int i = 0; i < _kDestinations.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 1,
                  ),
                  child: _NavItem(
                    dest: _kDestinations[i],
                    isSelected: selected == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
          // ── Sign out — always pinned to viewport bottom ───────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: TextButton.icon(
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFB91C1C),
                  size: 18,
                ),
                label: Text(
                  'Sign out',
                  style: AppTextStyles.inter(
                    size: 14,
                    weight: FontWeight.w600,
                    color: const Color(0xFFB91C1C),
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

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.dest,
    required this.isSelected,
    required this.onTap,
  });
  final _Dest dest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;

    final Color bgColor =
        active
            ? AppColors.accent
            : (_hovered ? const Color(0xFFF3F5FB) : Colors.transparent);
    final Color iconColor = active ? Colors.white : AppColors.textSoft;
    final Color textColor = active ? Colors.white : AppColors.navy;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.dest.icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Text(
                widget.dest.label,
                style: AppTextStyles.inter(
                  size: 14,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Sections view
// ─────────────────────────────────────────────────────────────────────────────
class _MySectionsView extends ConsumerWidget {
  const _MySectionsView({required this.fullName});
  final String fullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MySection>> mySections = ref.watch(
      mySectionsProvider,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.8, -0.8),
          radius: 1.4,
          colors: <Color>[Color(0xFFDCEAFF), _C.pageBg],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Top bar ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        fullName,
                        style: _inter(
                          13,
                          weight: FontWeight.w600,
                          color: _C.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'My Sections',
                        style: _fredoka(34, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pick a section to manage its students.',
                        style: _inter(14, color: _C.mutedText),
                      ),
                    ],
                  ),
                ),
                // Teacher avatar chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _C.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: _C.border),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x142E6FF2),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: <Color>[_C.primaryBlue, _C.blue700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Text(
                          _initials(fullName),
                          style: _inter(
                            14,
                            weight: FontWeight.w700,
                            color: _C.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            fullName,
                            style: _inter(13, weight: FontWeight.w700),
                          ),
                          Text(
                            'Elementary · Math',
                            style: _inter(11, color: _C.mutedText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // ── Welcome banner ───────────────────────────────────────────
            _WelcomeBanner(fullName: fullName),
            const SizedBox(height: 32),
            // ── Section list ─────────────────────────────────────────────
            mySections.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (Object e, _) => AppErrorState(
                    message:
                        e is AppFailure
                            ? e.message
                            : 'Could not load your sections.',
                    onRetry: () => ref.invalidate(mySectionsProvider),
                  ),
              data:
                  (List<MySection> list) =>
                      _SectionListBody(sections: list, context: context),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.fullName});
  final String fullName;

  @override
  Widget build(BuildContext context) {
    final String firstName = fullName.trim().split(' ').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 0, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: <Color>[_C.primaryBlue, _C.blue700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x402E6FF2),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _greeting(),
                  style: _inter(15, weight: FontWeight.w600, color: _C.white),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: _fredoka(
                      22,
                      weight: FontWeight.w700,
                      color: _C.white,
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Ready for today, '),
                      TextSpan(
                        text: '$firstName?',
                        style: _fredoka(
                          22,
                          weight: FontWeight.w700,
                          color: _C.goldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/baymath_logo.png',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _SectionListBody extends StatelessWidget {
  const _SectionListBody({required this.sections, required this.context});
  final List<MySection> sections;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final int activeCount = sections.where((s) => s.section != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Your sections', style: _fredoka(20, weight: FontWeight.w700)),
            const Spacer(),
            Text(
              '$activeCount active ${activeCount == 1 ? 'section' : 'sections'}',
              style: _inter(13, color: _C.mutedText),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (sections.isEmpty)
          const AppEmptyState(
            icon: Icons.groups_outlined,
            title: 'No sections assigned yet',
            description:
                'Ask an admin to assign you to a section to get started.',
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              for (final MySection my in sections)
                _SectionCard(
                  my: my,
                  onTap:
                      my.section == null
                          ? null
                          : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => SectionWorkspaceScreen(
                                    section: my.section!,
                                  ),
                            ),
                          ),
                ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends ConsumerStatefulWidget {
  const _SectionCard({required this.my, required this.onTap});
  final MySection my;
  final VoidCallback? onTap;

  @override
  ConsumerState<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends ConsumerState<_SectionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Section? section = widget.my.section;
    final bool isPrimary = widget.my.teacherSection.isPrimary;

    // Fetch enrolled students for count + avatar stack
    final AsyncValue<List<EnrolledStudent>> studentsAsync =
        section != null
            ? ref.watch(enrolledStudentsProvider(section.id))
            : const AsyncValue.data([]);
    final List<EnrolledStudent> students = studentsAsync.maybeWhen(
      data: (d) => d,
      orElse: () => [],
    );
    final int count = students.length;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 330,
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color:
                    _hovered
                        ? const Color(0x252E6FF2)
                        : const Color(0x0F2E6FF2),
                blurRadius: _hovered ? 24 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Card body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Icon badge + PRIMARY pill
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _C.lightBlueBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.groups_2_outlined,
                            color: _C.primaryBlue,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _C.lightBlueBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: _inter(
                                11,
                                weight: FontWeight.w700,
                                color: _C.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Section name
                    Text(
                      section == null
                          ? 'Unknown section'
                          : '${section.gradeLevel.label} — ${section.name}',
                      style: _fredoka(19, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count ${count == 1 ? 'student' : 'students'}',
                      style: _inter(13, color: _C.mutedText),
                    ),
                  ],
                ),
              ),
              // Footer with avatar stack + arrow
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _C.border, style: BorderStyle.solid),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    _AvatarStack(students: students),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hovered ? _C.primaryBlue : _C.lightBlueBg,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _hovered ? _C.white : _C.primaryBlue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlapping avatar stack
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.students});
  final List<EnrolledStudent> students;

  static const double _size = 30;
  static const double _offset = 18; // horizontal shift per avatar
  static const int _maxShow = 3;

  static const List<List<Color>> _gradients = <List<Color>>[
    <Color>[Color(0xFFFFC94D), Color(0xFFF5A623)],
    <Color>[Color(0xFFFFDD80), Color(0xFFFFC94D)],
    <Color>[Color(0xFFF5A623), Color(0xFFE8852A)],
  ];

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const SizedBox.shrink();

    final int show = math.min(_maxShow, students.length);
    final int extra = students.length - show;
    final int total = show + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: _size + (_offset * (total - 1)),
      height: _size,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < show; i++)
            Positioned(
              left: i * _offset,
              child: _CircleAvatar(
                label: _initials(students[i].student?.fullName ?? '?'),
                gradient: _gradients[i % _gradients.length],
                textColor: const Color(0xFF5C3A00),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: show * _offset,
              child: _CircleAvatar(
                label: '+$extra',
                gradient: const <Color>[Color(0xFF3B3D6B), Color(0xFF1E2050)],
                textColor: _C.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({
    required this.label,
    required this.gradient,
    required this.textColor,
  });
  final String label;
  final List<Color> gradient;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AvatarStack._size,
      height: _AvatarStack._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _C.white, width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: label.startsWith('+') ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
