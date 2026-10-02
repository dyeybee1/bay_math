import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/quiz.dart';

/// Native Flutter drawings adapted from the prototype's inline SVG artwork.
/// The matching fallback drawings cover other built-in and teacher topics.
enum _QuizVisualKind {
  preTest,
  postTest,
  addSubtract,
  compare,
  placeValue,
  groups,
  fraction,
  numberLine,
  fractionBars,
  factors,
  decimals,
  clock,
  area,
  probability,
  circle,
  solid,
  ratio,
  powers,
  operations,
  generic,
}

class QuizTopicArtSpec {
  const QuizTopicArtSpec._(this._kind, this.accent, this.tint, this.edge);

  final _QuizVisualKind _kind;
  final Color accent;
  final Color tint;
  final Color edge;

  factory QuizTopicArtSpec.forQuiz(Quiz quiz) {
    final String title = quiz.title.toLowerCase();
    final _QuizVisualKind kind;
    if (quiz.assessmentType == AssessmentType.preTest) {
      kind = _QuizVisualKind.preTest;
    } else if (quiz.assessmentType == AssessmentType.postTest) {
      kind = _QuizVisualKind.postTest;
    } else if (title.contains('converting and plotting fractions')) {
      kind = _QuizVisualKind.numberLine;
    } else if (title.contains('comparing, adding, and subtracting fractions')) {
      kind = _QuizVisualKind.fractionBars;
    } else if (title.contains('types of fractions')) {
      kind = _QuizVisualKind.fraction;
    } else if (title.contains('place value of whole')) {
      kind = _QuizVisualKind.placeValue;
    } else if (title.contains('comparing numbers')) {
      kind = _QuizVisualKind.compare;
    } else if (title.contains('addition and subtraction of numbers')) {
      kind = _QuizVisualKind.addSubtract;
    } else if (title.contains('multiplication, division') ||
        title.contains('mdas')) {
      kind = _QuizVisualKind.groups;
    } else if (title.contains('factor') ||
        title.contains('divisib') ||
        title.contains('multiple') ||
        title.contains('prime')) {
      kind = _QuizVisualKind.factors;
    } else if (title.contains('time') || title.contains('hour')) {
      kind = _QuizVisualKind.clock;
    } else if (title.contains('probability')) {
      kind = _QuizVisualKind.probability;
    } else if (title.contains('ratio') || title.contains('proportion')) {
      kind = _QuizVisualKind.ratio;
    } else if (title.contains('exponent')) {
      kind = _QuizVisualKind.powers;
    } else if (title.contains('surface area') ||
        title.contains('volume') ||
        title.contains('cube')) {
      kind = _QuizVisualKind.solid;
    } else if (title.contains('circumference') || title.contains('circle')) {
      kind = _QuizVisualKind.circle;
    } else if (title.contains('area') || title.contains('perimeter')) {
      kind = _QuizVisualKind.area;
    } else if (title.contains('decimal')) {
      kind = _QuizVisualKind.decimals;
    } else if (title.contains('fraction')) {
      kind = _QuizVisualKind.fractionBars;
    } else if (title.contains('gmdas') || title.contains('operations')) {
      kind = _QuizVisualKind.operations;
    } else {
      kind = _QuizVisualKind.generic;
    }

    return switch (kind) {
      _QuizVisualKind.preTest ||
      _QuizVisualKind.compare ||
      _QuizVisualKind.fractionBars => QuizTopicArtSpec._(
        kind,
        const Color(0xFF8D6DC6),
        const Color(0xFFF1ECFB),
        const Color(0xFFE6DAF8),
      ),
      _QuizVisualKind.postTest ||
      _QuizVisualKind.fraction => QuizTopicArtSpec._(
        kind,
        const Color(0xFFC88743),
        const Color(0xFFFFF1E1),
        const Color(0xFFF5DFCA),
      ),
      _QuizVisualKind.placeValue ||
      _QuizVisualKind.factors ||
      _QuizVisualKind.ratio => QuizTopicArtSpec._(
        kind,
        const Color(0xFF5F9C86),
        const Color(0xFFE8F4EE),
        const Color(0xFFD9EADF),
      ),
      _ => QuizTopicArtSpec._(
        kind,
        const Color(0xFF5E86C7),
        const Color(0xFFEBF2FE),
        const Color(0xFFDCE8FA),
      ),
    };
  }
}

class QuizTopicArt extends StatelessWidget {
  const QuizTopicArt({super.key, required this.spec, required this.compact});

  final QuizTopicArtSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double width = compact ? 78 : 92;
    final double height = compact ? 82 : 94;
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: spec.tint,
          borderRadius: BorderRadius.circular(compact ? 17 : 20),
        ),
        child: CustomPaint(painter: _QuizArtPainter(spec._kind)),
      ),
    );
  }
}

class _QuizArtPainter extends CustomPainter {
  const _QuizArtPainter(this.kind);

  final _QuizVisualKind kind;

  static const Color blue = Color(0xFF6896ED);
  static const Color purple = Color(0xFF9277D5);
  static const Color orange = Color(0xFFEAAF5E);
  static const Color mint = Color(0xFF76B7A0);
  static const Color darkBlue = Color(0xFF5D7FB9);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawCircle(
      const Offset(50, 48),
      39,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    switch (kind) {
      case _QuizVisualKind.preTest:
        _line(canvas, const Offset(29, 78), const Offset(29, 21), purple, 6);
        _box(canvas, 29, 20, 46, 35, const Color(0xFFA48BE4), 6);
        _line(
          canvas,
          const Offset(43, 36),
          const Offset(50, 43),
          Colors.white,
          5,
        );
        _line(
          canvas,
          const Offset(50, 43),
          const Offset(64, 29),
          Colors.white,
          5,
        );
        _box(canvas, 18, 79, 25, 6, const Color(0xFFCAB9EE), 3);
      case _QuizVisualKind.postTest:
        _polygon(canvas, const <Offset>[
          Offset(35, 52),
          Offset(27, 84),
          Offset(44, 76),
          Offset(52, 87),
          Offset(57, 53),
        ], const Color(0xFFEF9C64));
        _polygon(canvas, const <Offset>[
          Offset(63, 52),
          Offset(74, 84),
          Offset(57, 76),
          Offset(49, 87),
          Offset(43, 53),
        ], const Color(0xFFE9AA70));
        _circle(canvas, 51, 39, 25, const Color(0xFFF6C971));
        _circle(canvas, 51, 39, 18, const Color(0xFFFFE6A9));
        _star(canvas, const Offset(51, 39), 13, const Color(0xFFD49833));
      case _QuizVisualKind.addSubtract:
        _box(canvas, 13, 28, 37, 37, blue, 9);
        _text(canvas, '+', 31, 48, Colors.white, 25);
        _box(canvas, 51, 43, 36, 36, orange, 9);
        _text(canvas, '−', 69, 62, Colors.white, 26);
        _circle(canvas, 73, 23, 7, const Color(0xFFBDD1F7));
      case _QuizVisualKind.compare:
        _box(canvas, 10, 24, 33, 48, const Color(0xFF8A79D8), 9);
        _text(canvas, '8', 26, 47, Colors.white, 22);
        _box(canvas, 60, 31, 30, 41, const Color(0xFFB5A3EC), 9);
        _text(canvas, '3', 75, 49, Colors.white, 22);
        _text(canvas, '>', 51, 48, const Color(0xFF6853B1), 20);
      case _QuizVisualKind.placeValue:
        _box(canvas, 9, 24, 25, 54, const Color(0xFF67A998), 5);
        _box(canvas, 37, 33, 25, 45, const Color(0xFF79BDAC), 5);
        _box(canvas, 65, 41, 25, 37, const Color(0xFFA0D5C7), 5);
        _text(canvas, '4', 21, 52, Colors.white, 20);
        _text(canvas, '2', 49, 55, Colors.white, 20);
        _text(canvas, '6', 77, 58, const Color(0xFF386C60), 20);
        _text(canvas, 'H', 21, 14, const Color(0xFF578C7E), 10);
        _text(canvas, 'T', 49, 23, const Color(0xFF578C7E), 10);
        _text(canvas, 'O', 77, 31, const Color(0xFF578C7E), 10);
      case _QuizVisualKind.groups:
        _box(canvas, 10, 22, 37, 52, const Color(0xFFD8E6FB), 9);
        _box(canvas, 54, 22, 37, 52, const Color(0xFFD8E6FB), 9);
        for (final double x in <double>[23, 36, 67, 80]) {
          for (final double y in <double>[37, 58]) {
            _circle(canvas, x, y, 5, const Color(0xFF608BD3));
          }
        }
        _text(canvas, '×  ÷', 51, 87, const Color(0xFF5777AB), 17);
      case _QuizVisualKind.fraction:
        _circle(canvas, 50, 50, 31, const Color(0xFFFFE1AD));
        canvas.drawArc(
          const Rect.fromLTWH(19, 19, 62, 62),
          -math.pi / 2,
          math.pi / 2,
          true,
          Paint()..color = const Color(0xFFEEA04E),
        );
        _line(
          canvas,
          const Offset(50, 19),
          const Offset(50, 81),
          Colors.white,
          4,
        );
        _line(
          canvas,
          const Offset(19, 50),
          const Offset(81, 50),
          Colors.white,
          4,
        );
        _text(canvas, '¼', 50, 89, const Color(0xFFBF8844), 15);
      case _QuizVisualKind.numberLine:
        _line(canvas, const Offset(14, 59), const Offset(88, 59), darkBlue, 3);
        for (final double x in <double>[16, 40, 64, 88]) {
          _line(canvas, Offset(x, 49), Offset(x, 69), darkBlue, 3);
        }
        _circle(canvas, 40, 59, 7, const Color(0xFFE9B54E));
        _box(canvas, 24, 20, 33, 21, const Color(0xFFE4EBFA), 6);
        _text(canvas, '⅓', 40, 27, darkBlue, 15);
        _text(canvas, '0', 16, 78, darkBlue, 12);
        _text(canvas, '⅓', 40, 78, darkBlue, 12);
        _text(canvas, '1', 88, 78, darkBlue, 12);
      case _QuizVisualKind.fractionBars:
        _box(canvas, 12, 23, 76, 18, const Color(0xFFECE4FA), 5);
        _box(canvas, 12, 23, 38, 18, const Color(0xFF9D80D3), 5);
        _box(canvas, 12, 51, 76, 18, const Color(0xFFECE4FA), 5);
        _box(canvas, 12, 51, 57, 18, const Color(0xFFBD9AE4), 5);
        _text(canvas, '+  −', 51, 82, const Color(0xFF9072B6), 19);
      case _QuizVisualKind.factors:
        _box(canvas, 13, 20, 31, 31, mint, 8);
        _text(canvas, '2', 28, 36, Colors.white, 18);
        _box(canvas, 51, 29, 34, 34, const Color(0xFFA0CBBB), 8);
        _text(canvas, '6', 68, 45, const Color(0xFF467862), 20);
        _box(canvas, 25, 60, 32, 27, const Color(0xFFD4ECE2), 8);
        _text(canvas, '12', 41, 72, const Color(0xFF548973), 16);
      case _QuizVisualKind.decimals:
        _box(canvas, 16, 29, 68, 44, const Color(0xFFD8E6FB), 10);
        _text(canvas, '0.75', 50, 50, darkBlue, 25);
      case _QuizVisualKind.clock:
        _circle(canvas, 50, 50, 31, const Color(0xFFD7E5FA));
        _circle(canvas, 50, 50, 25, Colors.white);
        _line(canvas, const Offset(50, 50), const Offset(50, 31), darkBlue, 4);
        _line(canvas, const Offset(50, 50), const Offset(66, 58), darkBlue, 4);
        _circle(canvas, 50, 50, 3, darkBlue);
      case _QuizVisualKind.area:
        _box(canvas, 19, 19, 61, 61, const Color(0xFFD8E6FB), 5);
        for (final double xy in <double>[39, 59]) {
          _line(canvas, Offset(xy, 19), Offset(xy, 80), Colors.white, 3);
          _line(canvas, Offset(19, xy), Offset(80, xy), Colors.white, 3);
        }
        _box(canvas, 21, 21, 17, 17, blue, 2);
        _box(canvas, 41, 21, 17, 17, blue, 2);
        _box(canvas, 21, 41, 17, 17, blue, 2);
      case _QuizVisualKind.probability:
        _box(canvas, 22, 22, 56, 56, Colors.white, 11);
        for (final Offset dot in <Offset>[
          const Offset(36, 36),
          const Offset(64, 36),
          const Offset(50, 50),
          const Offset(36, 64),
          const Offset(64, 64),
        ]) {
          _circle(canvas, dot.dx, dot.dy, 5, blue);
        }
      case _QuizVisualKind.circle:
        _circle(canvas, 50, 50, 30, const Color(0xFFDCEAFB));
        _circle(canvas, 50, 50, 25, Colors.white);
        _line(canvas, const Offset(50, 50), const Offset(76, 50), darkBlue, 3);
        _circle(canvas, 50, 50, 3, darkBlue);
        _text(canvas, 'r', 63, 36, darkBlue, 15);
      case _QuizVisualKind.solid:
        _polygon(canvas, const <Offset>[
          Offset(50, 18),
          Offset(80, 35),
          Offset(50, 52),
          Offset(20, 35),
        ], const Color(0xFFB7CEF4));
        _polygon(canvas, const <Offset>[
          Offset(20, 35),
          Offset(50, 52),
          Offset(50, 84),
          Offset(20, 67),
        ], blue);
        _polygon(canvas, const <Offset>[
          Offset(50, 52),
          Offset(80, 35),
          Offset(80, 67),
          Offset(50, 84),
        ], darkBlue);
      case _QuizVisualKind.ratio:
        _box(canvas, 13, 27, 48, 17, mint, 5);
        _box(canvas, 13, 55, 74, 17, const Color(0xFFA7D4C3), 5);
        _text(canvas, '2 : 3', 50, 80, const Color(0xFF467862), 14);
      case _QuizVisualKind.powers:
        _box(canvas, 19, 27, 62, 49, const Color(0xFFD8E6FB), 10);
        _text(canvas, '2²', 50, 49, darkBlue, 28);
      case _QuizVisualKind.operations:
        _box(canvas, 17, 27, 66, 47, const Color(0xFFD8E6FB), 10);
        _text(canvas, '+  ×', 50, 50, darkBlue, 24);
      case _QuizVisualKind.generic:
        _box(canvas, 20, 24, 60, 54, const Color(0xFFD8E6FB), 10);
        _text(canvas, '1 2 3', 50, 50, darkBlue, 18);
    }
    canvas.restore();
  }

  void _box(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
    double radius,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      Paint()..color = color,
    );
  }

  void _circle(Canvas canvas, double x, double y, double radius, Color color) {
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color, double width) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _polygon(Canvas canvas, List<Offset> points, Color color) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final List<Offset> points = <Offset>[
      for (int index = 0; index < 10; index++)
        Offset(
          center.dx +
              math.cos(-math.pi / 2 + index * math.pi / 5) *
                  (index.isEven ? radius : radius * 0.48),
          center.dy +
              math.sin(-math.pi / 2 + index * math.pi / 5) *
                  (index.isEven ? radius : radius * 0.48),
        ),
    ];
    _polygon(canvas, points, color);
  }

  void _text(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color,
    double size,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(x - painter.width / 2, y - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _QuizArtPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
