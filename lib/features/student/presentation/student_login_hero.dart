import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum StudentLoginStage { idle, checking, preparing, error, success }

/// The logo is an unchanged image asset. Motion and pointer response are
/// confined to the decorative paint layer behind it.
class StudentLoginHero extends StatefulWidget {
  const StudentLoginHero({
    super.key,
    required this.compact,
    required this.short,
    required this.phase,
    required this.motionEnabled,
    required this.allowParallax,
  });

  final bool compact;
  final bool short;
  final StudentLoginStage phase;
  final bool motionEnabled;
  final bool allowParallax;

  @override
  State<StudentLoginHero> createState() => _StudentLoginHeroState();
}

class _StudentLoginHeroState extends State<StudentLoginHero>
    with TickerProviderStateMixin {
  final ValueNotifier<Offset> _pointer = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.motionEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.motionEnabled) _scene.forward(from: 0);
      });
    } else {
      _scene.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant StudentLoginHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motionEnabled != widget.motionEnabled) {
      if (widget.motionEnabled) {
        _scene.forward(from: 0);
      } else {
        _scene.value = 1;
        _celebration.stop();
        _pointer.value = Offset.zero;
      }
    }
    if (widget.motionEnabled &&
        oldWidget.phase != widget.phase &&
        widget.phase == StudentLoginStage.preparing) {
      _celebration.forward(from: 0);
    } else if (!widget.motionEnabled &&
        oldWidget.phase != widget.phase &&
        widget.phase == StudentLoginStage.preparing) {
      _celebration.value = 1;
    }
    if (!widget.allowParallax && _pointer.value != Offset.zero) {
      _pointer.value = Offset.zero;
    }
  }

  @override
  void dispose() {
    _pointer.dispose();
    _scene.dispose();
    _celebration.dispose();
    super.dispose();
  }

  void _hover(PointerHoverEvent event) {
    if (!widget.allowParallax || event.kind != PointerDeviceKind.mouse) return;
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset local = box.globalToLocal(event.position);
    final Size size = box.size;
    final double x = ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0) * 5;
    final double y = ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0) * 5;
    final Offset next = Offset(x, y);
    if ((_pointer.value - next).distance >= .5) _pointer.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _hover,
      onExit: (_) => _pointer.value = Offset.zero,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF0C2852), Color(0xFF173E79)],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  key: const Key('student_hero_canvas'),
                  child: AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[
                      _scene,
                      _celebration,
                      _pointer,
                    ]),
                    builder:
                        (BuildContext context, Widget? child) => CustomPaint(
                          painter: _HeroPainter(
                            pointer: _pointer.value,
                            intro: _scene.value,
                            accepted: _celebration.value,
                            compact: widget.compact,
                            phase: widget.phase,
                          ),
                        ),
                  ),
                ),
              ),
            ),
            if (widget.motionEnabled && !widget.compact)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _celebration,
                    builder: (BuildContext context, Widget? child) {
                      if (_celebration.value == 0 || _celebration.isCompleted) {
                        return const SizedBox.shrink();
                      }
                      final double t = _celebration.value;
                      return Stack(
                        children: <Widget>[
                          for (final (int index, String symbol)
                              in <String>['+', '×', '÷', '−'].indexed)
                            Positioned(
                              left: index.isEven ? 12.0 : null,
                              right: index.isOdd ? 12.0 : null,
                              bottom: 45 + index * 26 + 22 * t,
                              child: Opacity(
                                opacity: math.sin(t * math.pi).clamp(0, 1),
                                child: Text(
                                  symbol,
                                  style: TextStyle(
                                    fontSize: index.isEven ? 19 : 16,
                                    color:
                                        index.isEven
                                            ? const Color(0xFFFFDA8B)
                                            : const Color(0xFFA9CFED),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding:
                  widget.compact
                      ? const EdgeInsets.symmetric(horizontal: 18, vertical: 17)
                      : EdgeInsets.symmetric(
                        horizontal: widget.short ? 28 : 34,
                        vertical: widget.short ? 22 : 30,
                      ),
              child: widget.compact ? _compactContent() : _wideContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo({required double width, required double height}) => Image.asset(
    'assets/images/baymath_logo_for_login.png',
    key: const Key('student_login_logo'),
    width: width,
    height: height,
    fit: BoxFit.contain,
    semanticLabel: 'BayMath, Learn, Practice, Master',
  );

  Widget _heroReveal({required Widget child, double start = .04}) {
    if (!widget.motionEnabled) return child;
    return AnimatedBuilder(
      animation: _scene,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double progress = ((_scene.value - start) / .24).clamp(0, 1);
        final double eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: .30 + .70 * eased,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _compactContent() => Row(
    children: <Widget>[
      SizedBox(width: 145, child: _logo(width: 145, height: 105)),
      const SizedBox(width: 14),
      Expanded(
        child: _heroReveal(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Learn something\nnew today.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.17,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Bring your curiosity. We’ll take the next step together.',
                style: TextStyle(
                  color: Color(0xFFC4D6EF),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _wideContent() {
    final int active = switch (widget.phase) {
      StudentLoginStage.checking => 1,
      StudentLoginStage.preparing => 2,
      StudentLoginStage.success => 3,
      StudentLoginStage.idle || StudentLoginStage.error => 0,
    };
    final String journey = switch (widget.phase) {
      StudentLoginStage.checking => 'Checking your details…',
      StudentLoginStage.preparing => 'Preparing your learning space…',
      StudentLoginStage.success => 'Ready for your next lesson',
      StudentLoginStage.error => 'Check your details and try again',
      StudentLoginStage.idle => 'Your learning starts here',
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: Divider(color: Color(0xFFFFCE64), thickness: 2),
            ),
            SizedBox(width: 8),
            Text(
              'A PLACE TO LEARN AND GROW',
              style: TextStyle(
                color: Color(0xFFC3D6EF),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.short ? 7 : 12),
        Center(
          child: _logo(
            width: widget.short ? 290 : 350,
            height: widget.short ? 177 : 214,
          ),
        ),
        SizedBox(height: widget.short ? 7 : 14),
        _heroReveal(
          child: Text(
            'Learn something\nnew today.',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.short ? 27 : 31,
              height: 1.14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 9),
        _heroReveal(
          start: .09,
          child: const Text(
            'Bring your curiosity.\nWe’ll take the next step together.',
            style: TextStyle(
              color: Color(0xFFC4D6EF),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
        SizedBox(height: widget.short ? 16 : 23),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _pathItem(Icons.menu_book_outlined, 'Lessons', active >= 1),
              _pathDivider(active >= 2),
              _pathItem(Icons.edit_outlined, 'Practice', active >= 2),
              _pathDivider(active >= 3),
              _pathItem(Icons.bar_chart_rounded, 'Progress', active >= 3),
            ],
          ),
        ),
        SizedBox(height: widget.short ? 14 : 19),
        Container(height: 1, color: Colors.white.withValues(alpha: .15)),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color:
                      widget.phase == StudentLoginStage.success
                          ? const Color(0xFFA4E6BC)
                          : const Color(0xFFA5CFFF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  journey,
                  style: const TextStyle(
                    color: Color(0xFFB8CCEB),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pathItem(IconData icon, String label, bool active) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(
        icon,
        size: 16,
        color: active ? const Color(0xFFFFDA83) : const Color(0xFF9BBDE9),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : const Color(0xFFD7E5F8),
        ),
      ),
    ],
  );

  Widget _pathDivider(bool active) => Container(
    width: 16,
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 7),
    color: active ? const Color(0xFFFFDA83) : const Color(0xFF7B9EC8),
  );
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter({
    required this.pointer,
    required this.intro,
    required this.accepted,
    required this.compact,
    required this.phase,
  });

  final Offset pointer;
  final double intro;
  final double accepted;
  final bool compact;
  final StudentLoginStage phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid =
        Paint()
          ..color = Colors.white.withValues(alpha: .028)
          ..strokeWidth = 1;
    for (double x = pointer.dx * -.35; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = pointer.dy * -.35; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Offset glowCenter = Offset(
      size.width * .5 + pointer.dx * 2,
      size.height * .33 + pointer.dy * 2,
    );
    final double glowPulse = math.sin(intro * math.pi);
    canvas.drawCircle(
      glowCenter,
      math.min(size.width, size.height) * .38,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Color.fromRGBO(61, 141, 221, .15 + glowPulse * .08),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: glowCenter,
            radius: math.min(size.width, size.height) * .38,
          ),
        ),
    );

    final Offset orbitCenter = Offset(
      size.width * .5 + pointer.dx,
      size.height * .34 + pointer.dy,
    );
    final Paint orbit =
        Paint()
          ..color = const Color.fromRGBO(166, 207, 255, .15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    canvas.drawCircle(orbitCenter, math.min(size.width * .31, 132), orbit);

    if (compact) return;

    final double baseY = size.height - 20;
    final Paint graph =
        Paint()
          ..color = Color.fromRGBO(
            174,
            210,
            250,
            phase == StudentLoginStage.error ? .24 : .63,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final Path curve =
        Path()
          ..moveTo(16, baseY)
          ..cubicTo(
            size.width * .2,
            baseY - 8,
            size.width * .31,
            baseY - 48,
            size.width * .47,
            baseY - 41,
          )
          ..cubicTo(
            size.width * .68,
            baseY - 32,
            size.width * .75,
            baseY - 88,
            size.width - 22,
            baseY - 98,
          );
    final PathMetric metric = curve.computeMetrics().first;
    final double trace = Curves.easeInOutCubic.transform(
      (intro / .5).clamp(0.0, 1.0),
    );
    if (trace > 0) {
      canvas.drawPath(metric.extractPath(0, metric.length * trace), graph);
      final Offset? dot =
          metric.getTangentForOffset(metric.length * trace)?.position;
      if (dot != null) {
        canvas.drawCircle(dot, 4, Paint()..color = const Color(0xFFFFD789));
      }
    }

    if (accepted > 0) {
      final Paint completed =
          Paint()
            ..color = const Color(0xFFFFD789).withValues(alpha: .68)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
      canvas.drawPath(
        metric.extractPath(0, metric.length * accepted),
        completed,
      );
    }

    final double float = math.sin(intro * math.pi) * 10;
    _paintSymbol(canvas, '+', Offset(25, size.height - 176 - float), 19);
    _paintSymbol(
      canvas,
      '×',
      Offset(size.width - 43, size.height - 166 + float),
      18,
    );
    _paintSymbol(
      canvas,
      '÷',
      Offset(size.width - 58, size.height - 60 - float),
      17,
    );
  }

  void _paintSymbol(Canvas canvas, String symbol, Offset offset, double size) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFC6DDFA).withValues(alpha: .48),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset + pointer * .35);
  }

  @override
  bool shouldRepaint(covariant _HeroPainter oldDelegate) =>
      oldDelegate.pointer != pointer ||
      oldDelegate.intro != intro ||
      oldDelegate.accepted != accepted ||
      oldDelegate.compact != compact ||
      oldDelegate.phase != phase;
}
