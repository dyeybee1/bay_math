import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../data/endless_quiz_leaderboard_providers.dart';
import '../widgets/student_avatar.dart';
import 'endless_quiz_design.dart';
import 'endless_quiz_full_leaderboard_screen.dart';
import 'endless_quiz_kit_icon.dart';
import 'endless_quiz_leaderboard_widgets.dart';
import 'endless_quiz_screen.dart';

class EndlessQuizLandingScreen extends ConsumerStatefulWidget {
  const EndlessQuizLandingScreen({super.key});

  @override
  ConsumerState<EndlessQuizLandingScreen> createState() =>
      _EndlessQuizLandingScreenState();
}

class _EndlessQuizLandingScreenState
    extends ConsumerState<EndlessQuizLandingScreen> {
  bool _anotherScreenOpen = false;

  Future<void> _whileMascotPaused(Future<void> Function() action) async {
    setState(() => _anotherScreenOpen = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _anotherScreenOpen = false);
    }
  }

  Future<void> _openQuiz() => _whileMascotPaused(_pushQuiz);

  Future<void> _pushQuiz() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EndlessQuizScreen()));
  }

  Future<void> _openLeaderboard() => _whileMascotPaused(() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EndlessQuizFullLeaderboardScreen(),
      ),
    );
  });

  Future<void> _openHelp() =>
      _whileMascotPaused(() => _showHowItWorks(context));

  Future<void> _openProfile(
    Student? profile,
    LeaderboardEntry rank,
  ) => _whileMascotPaused(() async {
    final String name = profile?.fullName ?? rank.fullName;
    final bool? start = await AppDialog.show<bool>(
      context,
      title: 'Your Endless Quiz progress',
      type: AppDialogType.info,
      icon: Icons.account_circle_outlined,
      message:
          '$name\nPersonal best: ${rank.bestEndlessStreak} in a row\nGrade rank: #${rank.rank}',
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        EndlessPrimaryButton(
          label: 'Start a run',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (start == true && mounted) await _pushQuiz();
  });

  @override
  Widget build(BuildContext context) {
    final AsyncValue<EndlessQuizLeaderboardData> dataAsync = ref.watch(
      endlessQuizLeaderboardProvider,
    );
    final Student? profile = ref.watch(ownStudentProfileProvider).value;
    final GradeLevel? grade = ref.watch(ownStudentGradeLevelProvider).value;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool narrowHeader = screenWidth < 760;

    return Scaffold(
      backgroundColor: EndlessQuizColors.pageBackground,
      body: EndlessQuizBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              EndlessQuizHeader(
                title: 'Endless Quiz',
                subtitle: 'A little practice. A lot of progress.',
                brandLeading: !narrowHeader,
                showBrand: !narrowHeader,
                onBack: () => Navigator.maybePop(context),
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (grade != null && !narrowHeader) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF3FF),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          grade.label,
                          style: endlessBodyStyle(
                            12,
                            weight: FontWeight.w800,
                            color: EndlessQuizColors.challengeInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    IconButton(
                      tooltip: 'Your personal best',
                      onPressed:
                          dataAsync.value == null
                              ? null
                              : () => _openProfile(
                                profile,
                                dataAsync.value!.myRank,
                              ),
                      icon: StudentAvatar(
                        fullName: profile?.fullName ?? 'Student',
                        avatarId: profile?.avatarId,
                        size: 36,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(48),
                        padding: const EdgeInsets.all(5),
                      ),
                    ),
                    if (!narrowHeader) const SizedBox(width: AppSpacing.xs),
                    EndlessIconButton(
                      tooltip: 'How Endless Quiz works',
                      icon: Icons.info_outline_rounded,
                      onPressed: _openHelp,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints viewport) {
                    final double sidePadding =
                        viewport.maxWidth < 700 ? 16 : 28;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        18,
                        sidePadding,
                        20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1360),
                          child: dataAsync.when(
                            loading:
                                () => SizedBox(
                                  height: math.max(
                                    360,
                                    viewport.maxHeight - 40,
                                  ),
                                  child: const EndlessStatePanel(
                                    title: 'Preparing your challenge',
                                    message:
                                        'Loading your best streak and grade rankings.',
                                    icon: Icons.bolt_rounded,
                                    loading: true,
                                  ),
                                ),
                            error:
                                (Object error, StackTrace _) => SizedBox(
                                  height: math.max(
                                    360,
                                    viewport.maxHeight - 40,
                                  ),
                                  child: EndlessStatePanel(
                                    title: 'Could not open Endless Quiz',
                                    message:
                                        error is AppFailure
                                            ? error.message
                                            : 'The challenge data could not be loaded right now.',
                                    icon: Icons.cloud_off_outlined,
                                    actionLabel: 'Try again',
                                    onAction:
                                        () => ref.invalidate(
                                          endlessQuizLeaderboardProvider,
                                        ),
                                  ),
                                ),
                            data:
                                (EndlessQuizLeaderboardData data) =>
                                    _LandingLayout(
                                      data: data,
                                      profile: profile,
                                      grade: grade,
                                      mascotActive: !_anotherScreenOpen,
                                      onPlay: _openQuiz,
                                      onHowItWorks: _openHelp,
                                      onLeaderboard: _openLeaderboard,
                                    ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingLayout extends StatelessWidget {
  const _LandingLayout({
    required this.data,
    required this.profile,
    required this.grade,
    required this.mascotActive,
    required this.onPlay,
    required this.onHowItWorks,
    required this.onLeaderboard,
  });

  final EndlessQuizLeaderboardData data;
  final Student? profile;
  final GradeLevel? grade;
  final bool mascotActive;
  final VoidCallback onPlay;
  final VoidCallback onHowItWorks;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 820;
        final bool compact =
            constraints.maxWidth < 1100 ||
            MediaQuery.sizeOf(context).height < 760;
        final Widget left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChallengeHero(
              compact: compact,
              mascotActive: mascotActive,
              onPlay: onPlay,
            ),
            const SizedBox(height: 12),
            _StatsRow(rank: data.myRank),
            const SizedBox(height: 12),
            _HowCard(onHowItWorks: onHowItWorks),
          ],
        );
        final Widget right = _LeadersCard(
          entries: data.topEntries,
          myRank: data.myRank,
          currentStudentName: profile?.fullName,
          grade: grade,
          compact: compact,
          onViewAll: onLeaderboard,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 142, child: left),
                  const SizedBox(width: 18),
                  Expanded(flex: 100, child: right),
                ],
              )
            else ...<Widget>[
              left,
              const SizedBox(height: AppSpacing.md),
              right,
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              "A fresh question. A fresh chance. Let's learn together.",
              style: endlessBodyStyle(
                10.5,
                color: EndlessQuizColors.challengeMuted,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({
    required this.compact,
    required this.mascotActive,
    required this.onPlay,
  });

  final bool compact;
  final bool mascotActive;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool narrow = width < 440;
        final double height = narrow ? 350 : (compact ? 320 : 330);
        return Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFE9F0FF),
                Color(0xFFEAF1FF),
                Color(0xFFDCE9FF),
              ],
            ),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFDCE6FC)),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                right: -55,
                top: -70,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 0,
                width: width * (narrow ? 0.43 : 0.40),
                height: height,
                child: _MascotScene(active: mascotActive),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 18 : (compact ? 20 : 26),
                  compact ? 20 : 25,
                  0,
                  14,
                ),
                child: SizedBox(
                  width: width * (narrow ? 0.71 : 0.64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const EndlessKitIcon(
                              type: EndlessKitIconType.star,
                              color: Color(0xFFE5B344),
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'THE ENDLESS CHALLENGE',
                              style: endlessBodyStyle(
                                9,
                                weight: FontWeight.w800,
                                color: const Color(0xFF86632C),
                              ).copyWith(letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Small steps.\nBig math energy.',
                        style: endlessTitleStyle(
                          narrow ? 27 : (compact ? 30 : 36),
                          weight: FontWeight.w800,
                          color: EndlessQuizColors.challengeInk,
                        ).copyWith(height: 1.08, letterSpacing: -1),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Keep your streak going with every correct answer. Your next best starts here.',
                        maxLines: narrow ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: endlessBodyStyle(
                          narrow ? 11 : 12,
                          color: EndlessQuizColors.challengeMuted,
                          height: 1.48,
                        ),
                      ),
                      const SizedBox(height: 13),
                      FilledButton(
                        onPressed: onPlay,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(180, 52),
                          backgroundColor: EndlessQuizColors.challengeBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          textStyle: endlessBodyStyle(
                            15,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.play_arrow_rounded, size: 18),
                            SizedBox(width: 7),
                            Text('Start a run'),
                            SizedBox(width: 7),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'No timer. Take your time and think.',
                        style: endlessBodyStyle(
                          10,
                          color: EndlessQuizColors.challengeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MascotScene extends StatefulWidget {
  const _MascotScene({required this.active});

  final bool active;

  @override
  State<_MascotScene> createState() => _MascotSceneState();
}

class _MascotSceneState extends State<_MascotScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const List<String> _messages = <String>[
    "You've got this!",
    'Ready for a question?',
    'Take your time.',
    'One step at a time!',
    "Let's try together!",
  ];

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  Timer? _messageTimer;
  int _messageIndex = 0;
  bool _userPaused = false;
  bool _appVisible = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    _appVisible = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _MascotScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final bool running =
        widget.active && _appVisible && !_userPaused && !_reduceMotion;
    if (running) {
      _messageTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) {
          setState(
            () => _messageIndex = (_messageIndex + 1) % _messages.length,
          );
        }
      });
      if (!_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _messageTimer?.cancel();
      _messageTimer = null;
      _float.stop();
      if (_reduceMotion) _float.value = 0;
    }
  }

  void _togglePause() {
    if (_reduceMotion) return;
    setState(() => _userPaused = !_userPaused);
    _syncMotion();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        return Stack(
          children: <Widget>[
            Positioned(
              right: 9,
              bottom: 12,
              child: Container(
                width: width * 0.78,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFB5CCF5).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 1,
              width: width,
              height: height * 0.80,
              child: AnimatedBuilder(
                animation: _float,
                child: Image.asset(
                  'assets/images/endless_quiz_owl.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  semanticLabel: 'Smiling blue BayMath owl holding a star',
                ),
                builder:
                    (BuildContext context, Widget? child) =>
                        Transform.translate(
                          offset: Offset(0, -6 * _float.value),
                          child: child,
                        ),
              ),
            ),
            Positioned(
              right: 13,
              top: 77,
              child: AnimatedBuilder(
                animation: _float,
                builder:
                    (BuildContext context, Widget? child) => Opacity(
                      opacity: 0.58 + 0.42 * _float.value,
                      child: Transform.rotate(
                        angle: 0.13 * _float.value,
                        child: child,
                      ),
                    ),
                child: const ExcludeSemantics(
                  child: EndlessKitIcon(
                    type: EndlessKitIconType.star,
                    color: Color(0xFFE5B344),
                    size: 22,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 7,
              width: math.min(width - 8, 162),
              height: 53,
              child: Semantics(
                label:
                    _reduceMotion
                        ? 'Mascot motion disabled by reduced motion setting'
                        : _userPaused
                        ? 'Resume mascot animation'
                        : 'Pause mascot animation',
                button: true,
                toggled: _userPaused,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    topRight: Radius.circular(17),
                    bottomLeft: Radius.circular(17),
                    bottomRight: Radius.circular(4),
                  ),
                  child: InkWell(
                    onTap: _reduceMotion ? null : _togglePause,
                    focusColor: const Color(0xFFFFE8A7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      topRight: Radius.circular(17),
                      bottomLeft: Radius.circular(17),
                      bottomRight: Radius.circular(4),
                    ),
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: AnimatedSwitcher(
                                duration:
                                    _reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                child: Text(
                                  _messages[_messageIndex],
                                  key: ValueKey<int>(_messageIndex),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style: endlessBodyStyle(
                                    10.5,
                                    weight: FontWeight.w800,
                                    color: EndlessQuizColors.challengeInk,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              _reduceMotion
                                  ? Icons.motion_photos_off_outlined
                                  : _userPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 14,
                              color: EndlessQuizColors.challengeMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.rank});

  final LeaderboardEntry rank;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget best = _StatCard(
          icon: EndlessKitIconType.flame,
          iconColor: EndlessQuizColors.streak,
          iconBackground: const Color(0xFFFFEDDD),
          label: 'PERSONAL BEST',
          value: rank.bestEndlessStreak.toString(),
          suffix: 'in a row',
          caption: 'Your next run is a fresh start!',
        );
        final Widget grade = _StatCard(
          icon: EndlessKitIconType.cup,
          iconColor: EndlessQuizColors.lavender,
          iconBackground: EndlessQuizColors.lavenderSoft,
          label: 'GRADE RANK',
          value: '#${rank.rank}',
          caption: 'Keep learning, keep climbing.',
        );
        if (constraints.maxWidth < 490) {
          return Column(
            children: <Widget>[best, const SizedBox(height: 10), grade],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: best),
            const SizedBox(width: 12),
            Expanded(child: grade),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.caption,
    this.suffix,
  });

  final EndlessKitIconType icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final String caption;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return EndlessPaper(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      radius: 21,
      elevated: false,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: EndlessKitIcon(type: icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  style: endlessBodyStyle(
                    8.5,
                    weight: FontWeight.w800,
                    color: EndlessQuizColors.challengeMuted,
                  ).copyWith(letterSpacing: 0.5),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      value,
                      style: endlessTitleStyle(
                        26,
                        weight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                    if (suffix != null) ...<Widget>[
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          suffix!,
                          style: endlessBodyStyle(
                            10,
                            color: EndlessQuizColors.challengeMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: endlessBodyStyle(
                    9.5,
                    color: EndlessQuizColors.challengeMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard({required this.onHowItWorks});

  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return EndlessPaper(
      padding: const EdgeInsets.fromLTRB(15, 10, 13, 12),
      radius: 21,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: EndlessQuizColors.mintSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '?',
                      style: endlessTitleStyle(15, color: AppColors.secondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Little steps, endless learning',
                      maxLines: 2,
                      style: endlessTitleStyle(13, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onHowItWorks,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: EndlessQuizColors.challengeBlue,
                ),
                label: const Text('How to play'),
                icon: const Icon(Icons.north_east_rounded, size: 15),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final List<Widget> steps = <Widget>[
                const _HowStepSummary(
                  number: '1',
                  title: 'Give your answer',
                  color: Color(0xFFEDF3FF),
                  numberColor: EndlessQuizColors.challengeBlue,
                ),
                const _HowStepSummary(
                  number: '2',
                  title: 'Grow your streak',
                  color: Color(0xFFFFEDDD),
                  numberColor: EndlessQuizColors.streak,
                ),
                const _HowStepSummary(
                  number: '3',
                  title: 'Try, learn, repeat',
                  color: EndlessQuizColors.lavenderSoft,
                  numberColor: EndlessQuizColors.lavender,
                ),
              ];
              if (constraints.maxWidth < 465) {
                return Column(
                  children: <Widget>[
                    for (final Widget step in steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: step,
                      ),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  for (
                    int index = 0;
                    index < steps.length;
                    index++
                  ) ...<Widget>[
                    if (index > 0) const SizedBox(width: 7),
                    Expanded(child: steps[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HowStepSummary extends StatelessWidget {
  const _HowStepSummary({
    required this.number,
    required this.title,
    required this.color,
    required this.numberColor,
  });

  final String number;
  final String title;
  final Color color;
  final Color numberColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: endlessBodyStyle(
              11,
              weight: FontWeight.w800,
              color: numberColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: endlessBodyStyle(10.5, weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _LeadersCard extends StatelessWidget {
  const _LeadersCard({
    required this.entries,
    required this.myRank,
    required this.currentStudentName,
    required this.grade,
    required this.compact,
    required this.onViewAll,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry myRank;
  final String? currentStudentName;
  final GradeLevel? grade;
  final bool compact;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry> top = entries.take(3).toList();
    final List<LeaderboardEntry> rest =
        entries.skip(3).take(compact ? 2 : 3).toList();
    return EndlessPaper(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      radius: 23,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EndlessQuizColors.goldSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const EndlessKitIcon(
                  type: EndlessKitIconType.cup,
                  color: Color(0xFFC5902A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Streak leaders',
                      style: endlessTitleStyle(15, weight: FontWeight.w800),
                    ),
                    Text(
                      grade == null
                          ? 'Your learning crew'
                          : 'Your ${grade!.label} learning crew',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: endlessBodyStyle(
                        10,
                        color: EndlessQuizColors.challengeMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: EndlessQuizColors.challengeBlue,
                ),
                label: const Text('See all'),
                icon: const Icon(Icons.north_east_rounded, size: 14),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const EndlessKitIcon(
                  type: EndlessKitIconType.star,
                  color: Color(0xFFDCAD48),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Every great streak starts with one.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: endlessBodyStyle(10, color: const Color(0xFF96743B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: EndlessStatePanel(
                title: 'No rankings yet',
                message: 'The first completed run will begin the board.',
                icon: Icons.flag_outlined,
              ),
            )
          else
            _LandingPodium(
              entries: top,
              currentStudentName: currentStudentName,
            ),
          const Divider(height: 12, color: AppColors.outlineVariant),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'THE LEARNING CREW',
                style: endlessBodyStyle(
                  8.5,
                  weight: FontWeight.w800,
                  color: EndlessQuizColors.challengeMuted,
                ).copyWith(letterSpacing: 0.6),
              ),
              Text(
                'BEST STREAK',
                style: endlessBodyStyle(
                  8.5,
                  weight: FontWeight.w800,
                  color: EndlessQuizColors.challengeMuted,
                ).copyWith(letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final LeaderboardEntry entry in rest) ...<Widget>[
            EndlessLeaderboardRow(entry: entry, compact: true),
            const Divider(height: 1, color: AppColors.outlineVariant),
          ],
          const SizedBox(height: 8),
          EndlessLeaderboardRow(
            entry: myRank,
            compact: true,
            isCurrentStudent: true,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              "✦  Practice makes progress. You've got this!",
              style: endlessBodyStyle(
                10,
                color: EndlessQuizColors.challengeMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingPodium extends StatelessWidget {
  const _LandingPodium({
    required this.entries,
    required this.currentStudentName,
  });

  final List<LeaderboardEntry> entries;
  final String? currentStudentName;

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry?> ordered = <LeaderboardEntry?>[
      entries.length > 1 ? entries[1] : null,
      entries.first,
      entries.length > 2 ? entries[2] : null,
    ];
    return SizedBox(
      height: 176,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int index = 0; index < ordered.length; index++)
            Expanded(
              child:
                  ordered[index] == null
                      ? const SizedBox.shrink()
                      : _PodiumStudent(
                        entry: ordered[index]!,
                        isCurrentStudent:
                            ordered[index]!.fullName == currentStudentName,
                      ),
            ),
        ],
      ),
    );
  }
}

class _PodiumStudent extends StatelessWidget {
  const _PodiumStudent({
    required this.entry,
    required this.isCurrentStudent,
  });

  final LeaderboardEntry entry;
  final bool isCurrentStudent;

  @override
  Widget build(BuildContext context) {
    final bool winner = entry.rank == 1;
    final Color pedestal = switch (entry.rank) {
      1 => const Color(0xFFFFE3A0),
      2 => const Color(0xFFE8EEF8),
      _ => const Color(0xFFF5E3D6),
    };
    return Semantics(
      container: true,
      label:
          '${isCurrentStudent ? 'You. ' : ''}Rank ${entry.rank}, ${entry.fullName}, best streak ${entry.bestEndlessStreak}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (winner)
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFE5B344),
                size: 22,
              )
            else
              const SizedBox(height: 22),
            StudentAvatar(
              fullName: entry.fullName,
              avatarId: entry.avatarId,
              size: winner ? 54 : 46,
              highlighted: isCurrentStudent,
            ),
            const SizedBox(height: 5),
            Text(
              entry.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: endlessBodyStyle(10, weight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const EndlessKitIcon(
                  type: EndlessKitIconType.flame,
                  color: EndlessQuizColors.streak,
                  size: 13,
                ),
                const SizedBox(width: 3),
                Text(
                  entry.bestEndlessStreak.toString(),
                  style: endlessBodyStyle(
                    10,
                    weight: FontWeight.w800,
                    color: EndlessQuizColors.streak,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: winner ? 53 : (entry.rank == 2 ? 40 : 33),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pedestal,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  entry.rank.toString(),
                  style: endlessBodyStyle(
                    11,
                    weight: FontWeight.w800,
                    color: EndlessQuizColors.challengeInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showHowItWorks(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder:
        (BuildContext dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: EndlessPaper(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'How a run works',
                          style: endlessTitleStyle(21),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _HowStep(
                    icon: Icons.touch_app_rounded,
                    title: 'Answer once',
                    description:
                        'Your choice is checked immediately and recorded only once.',
                  ),
                  const _HowStep(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Grow the streak',
                    description:
                        'Each correct answer adds one to your current streak.',
                    streak: true,
                  ),
                  const _HowStep(
                    icon: Icons.refresh_rounded,
                    title: 'Reset, then continue',
                    description:
                        'A mistake resets the streak to zero. The run keeps going with a new question.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  EndlessPrimaryButton(
                    label: 'Ready to practice',
                    icon: Icons.check_rounded,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.icon,
    required this.title,
    required this.description,
    this.streak = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool streak;

  @override
  Widget build(BuildContext context) {
    final Color color = streak ? EndlessQuizColors.streak : AppColors.primary;
    final Color container =
        streak ? EndlessQuizColors.streakSoft : AppColors.primaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: container,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: endlessBodyStyle(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: endlessBodyStyle(12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
