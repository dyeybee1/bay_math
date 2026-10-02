import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';

enum StudentLessonArtKind {
  addSubtract,
  compare,
  placeValue,
  groups,
  fractionCircle,
  numberLine,
  fractionBars,
  factors,
  decimals,
  clock,
  geometry,
  ratio,
  probability,
  generic,
}

/// Presentation-only topic mapping. Unknown and teacher-authored lessons get
/// the same neutral book illustration without assuming their content.
class StudentLessonVisual {
  const StudentLessonVisual({
    required this.kind,
    required this.accent,
    required this.tint,
    required this.border,
    required this.titleColor,
  });

  final StudentLessonArtKind kind;
  final Color accent;
  final Color tint;
  final Color border;
  final Color titleColor;

  static const StudentLessonVisual blue = StudentLessonVisual(
    kind: StudentLessonArtKind.placeValue,
    accent: Color(0xFF3267AD),
    tint: Color(0xFFF1F6FF),
    border: Color(0xFFD6E4F5),
    titleColor: Color(0xFF244A7B),
  );
  static const StudentLessonVisual orange = StudentLessonVisual(
    kind: StudentLessonArtKind.groups,
    accent: Color(0xFFB57633),
    tint: Color(0xFFFFF5EA),
    border: Color(0xFFF0DCC6),
    titleColor: Color(0xFF87541F),
  );
  static const StudentLessonVisual green = StudentLessonVisual(
    kind: StudentLessonArtKind.fractionCircle,
    accent: Color(0xFF31806B),
    tint: Color(0xFFF0FAF5),
    border: Color(0xFFCBE8DC),
    titleColor: Color(0xFF286856),
  );
  static const StudentLessonVisual purple = StudentLessonVisual(
    kind: StudentLessonArtKind.factors,
    accent: Color(0xFF7459AC),
    tint: Color(0xFFF7F3FF),
    border: Color(0xFFDFD5F2),
    titleColor: Color(0xFF654C96),
  );
  static const StudentLessonVisual neutral = StudentLessonVisual(
    kind: StudentLessonArtKind.generic,
    accent: Color(0xFF607A99),
    tint: Color(0xFFF3F6FA),
    border: Color(0xFFDCE5EF),
    titleColor: Color(0xFF334D69),
  );

  StudentLessonVisual withKind(StudentLessonArtKind value) =>
      StudentLessonVisual(
        kind: value,
        accent: accent,
        tint: tint,
        border: border,
        titleColor: titleColor,
      );

  static StudentLessonVisual forLesson(Lesson lesson) {
    if (lesson.sourceType != ContentSourceType.builtIn) return neutral;
    final String title = lesson.title.toLowerCase();

    if (title.contains('decimal')) {
      return purple.withKind(StudentLessonArtKind.decimals);
    }
    if (title.contains('fraction')) {
      if (title.contains('plot') || title.contains('convert')) {
        return green.withKind(StudentLessonArtKind.numberLine);
      }
      if (title.contains('types of fraction')) return green;
      return green.withKind(StudentLessonArtKind.fractionBars);
    }
    if (title.contains('factor') ||
        title.contains('multiple') ||
        title.contains('divisib') ||
        title.contains('prime') ||
        title.contains('composite')) {
      return purple;
    }
    if (title.contains('place value')) return blue;
    if (title.contains('compar')) {
      return blue.withKind(StudentLessonArtKind.compare);
    }
    if ((title.contains('add') || title.contains('subtract')) &&
        title.contains('1,000,000')) {
      return blue.withKind(StudentLessonArtKind.addSubtract);
    }
    if (title.contains('gmdas') ||
        title.contains('gemdas') ||
        title.contains('mdas') ||
        title.contains('multipli') ||
        title.contains('divid') ||
        title.contains('operation') ||
        title.contains('exponent') ||
        title.contains('add') ||
        title.contains('subtract')) {
      return orange;
    }
    if (title.contains('time')) {
      return blue.withKind(StudentLessonArtKind.clock);
    }
    if (title.contains('probability')) {
      return purple.withKind(StudentLessonArtKind.probability);
    }
    if (title.contains('ratio') || title.contains('proportion')) {
      return green.withKind(StudentLessonArtKind.ratio);
    }
    if (title.contains('area') ||
        title.contains('perimeter') ||
        title.contains('volume') ||
        title.contains('surface') ||
        title.contains('circle') ||
        title.contains('figure')) {
      return purple.withKind(StudentLessonArtKind.geometry);
    }
    return neutral;
  }
}

class StudentLessonIllustration extends StatelessWidget {
  const StudentLessonIllustration({
    super.key,
    required this.visual,
    required this.size,
    required this.hovered,
    required this.reduceMotion,
  });

  final StudentLessonVisual visual;
  final double size;
  final bool hovered;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedSlide(
      offset: hovered && !reduceMotion ? const Offset(0, -.035) : Offset.zero,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedRotation(
        turns: hovered && !reduceMotion ? -.008 : 0,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _TopicPainter(visual)),
        ),
      ),
    ),
  );
}

class _TopicPainter extends CustomPainter {
  const _TopicPainter(this.visual);

  final StudentLessonVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    final Color ink = visual.accent;
    canvas.drawCircle(
      const Offset(60, 60),
      55,
      Paint()..color = ink.withValues(alpha: .10),
    );
    switch (visual.kind) {
      case StudentLessonArtKind.addSubtract:
        _card(canvas, const Rect.fromLTWH(12, 20, 53, 43), ink);
        _card(canvas, const Rect.fromLTWH(56, 66, 52, 39), ink);
        _text(canvas, '+', const Offset(39, 41), 31, ink);
        _text(canvas, '−', const Offset(82, 84), 30, ink);
      case StudentLessonArtKind.compare:
        _card(canvas, const Rect.fromLTWH(9, 38, 34, 47), ink);
        _card(canvas, const Rect.fromLTWH(77, 38, 34, 47), ink);
        _text(canvas, '8', const Offset(26, 61), 27, ink);
        _text(canvas, '5', const Offset(94, 61), 27, ink);
        _text(canvas, '>', const Offset(60, 60), 29, ink);
      case StudentLessonArtKind.placeValue:
        for (final (int index, double top) in <double>[34, 22, 43].indexed) {
          final double left = 12 + index * 34;
          _card(canvas, Rect.fromLTWH(left, top, 28, 94 - top), ink);
          _text(canvas, '${index + 1}', Offset(left + 14, 68), 23, ink);
        }
      case StudentLessonArtKind.groups:
        for (int row = 0; row < 3; row++) {
          for (int column = 0; column < 3; column++) {
            canvas.drawCircle(
              Offset(29 + column * 31, 29 + row * 31),
              8,
              Paint()..color = ink.withValues(alpha: .72),
            );
          }
        }
      case StudentLessonArtKind.fractionCircle:
        canvas.drawCircle(
          const Offset(60, 60),
          39,
          Paint()..color = Colors.white,
        );
        final Path quarter =
            Path()
              ..moveTo(60, 60)
              ..lineTo(60, 21)
              ..arcTo(
                const Rect.fromLTWH(21, 21, 78, 78),
                -math.pi / 2,
                math.pi / 2,
                false,
              )
              ..close();
        canvas.drawPath(quarter, Paint()..color = ink.withValues(alpha: .8));
        final Paint division =
            Paint()
              ..color = ink.withValues(alpha: .45)
              ..strokeWidth = 2;
        canvas.drawLine(const Offset(60, 21), const Offset(60, 99), division);
        canvas.drawLine(const Offset(21, 60), const Offset(99, 60), division);
      case StudentLessonArtKind.numberLine:
        final Paint line =
            Paint()
              ..color = ink
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(13, 72), const Offset(107, 72), line);
        for (final double x in <double>[14, 60, 106]) {
          canvas.drawLine(Offset(x, 64), Offset(x, 80), line);
        }
        canvas.drawCircle(const Offset(60, 72), 6, Paint()..color = ink);
        _text(canvas, '½', const Offset(60, 45), 27, ink);
      case StudentLessonArtKind.fractionBars:
        _card(canvas, const Rect.fromLTWH(12, 26, 96, 25), ink);
        _card(canvas, const Rect.fromLTWH(12, 68, 96, 25), ink);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 32, 44, 13),
            const Radius.circular(6),
          ),
          Paint()..color = ink.withValues(alpha: .7),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 74, 64, 13),
            const Radius.circular(6),
          ),
          Paint()..color = ink.withValues(alpha: .7),
        );
      case StudentLessonArtKind.factors:
        for (int row = 0; row < 3; row++) {
          for (int column = 0; column < 3; column++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(21 + column * 30, 21 + row * 30, 19, 19),
                const Radius.circular(4),
              ),
              Paint()..color = ink.withValues(alpha: .68),
            );
          }
        }
      case StudentLessonArtKind.decimals:
        _card(canvas, const Rect.fromLTWH(17, 25, 86, 70), ink);
        _text(canvas, '0.5', const Offset(60, 59), 29, ink);
        canvas.drawLine(
          const Offset(36, 79),
          const Offset(84, 79),
          Paint()
            ..color = ink.withValues(alpha: .45)
            ..strokeWidth = 4,
        );
      case StudentLessonArtKind.clock:
        canvas.drawCircle(
          const Offset(60, 60),
          40,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          const Offset(60, 60),
          40,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        final Paint hand =
            Paint()
              ..color = ink
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(60, 60), const Offset(60, 36), hand);
        canvas.drawLine(const Offset(60, 60), const Offset(79, 67), hand);
        canvas.drawCircle(const Offset(60, 60), 4, Paint()..color = ink);
      case StudentLessonArtKind.geometry:
        final Paint line =
            Paint()
              ..color = ink
              ..strokeWidth = 3
              ..style = PaintingStyle.stroke;
        canvas.drawRect(const Rect.fromLTWH(25, 27, 68, 63), line);
        canvas.drawLine(const Offset(25, 90), const Offset(93, 27), line);
        canvas.drawCircle(const Offset(93, 27), 5, Paint()..color = ink);
      case StudentLessonArtKind.ratio:
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(34 + i * 17, 42), 7, Paint()..color = ink);
        }
        for (int i = 0; i < 2; i++) {
          canvas.drawCircle(
            Offset(42 + i * 20, 78),
            8,
            Paint()..color = ink.withValues(alpha: .55),
          );
        }
        _text(canvas, ':', const Offset(91, 60), 30, ink);
      case StudentLessonArtKind.probability:
        _card(canvas, const Rect.fromLTWH(31, 29, 58, 58), ink);
        for (final Offset dot in <Offset>[
          const Offset(45, 43),
          const Offset(75, 43),
          const Offset(60, 58),
          const Offset(45, 73),
          const Offset(75, 73),
        ]) {
          canvas.drawCircle(dot, 4, Paint()..color = ink);
        }
      case StudentLessonArtKind.generic:
        final Paint book =
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round;
        final Path pages =
            Path()
              ..moveTo(60, 93)
              ..quadraticBezierTo(40, 82, 22, 88)
              ..lineTo(22, 31)
              ..quadraticBezierTo(42, 25, 60, 37)
              ..quadraticBezierTo(78, 25, 98, 31)
              ..lineTo(98, 88)
              ..quadraticBezierTo(78, 82, 60, 93)
              ..moveTo(60, 37)
              ..lineTo(60, 93);
        canvas.drawPath(pages, book);
    }
    canvas.restore();
  }

  void _card(Canvas canvas, Rect rect, Color ink) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      Paint()
        ..color = ink.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color ink,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: ink,
          fontSize: size,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _TopicPainter oldDelegate) =>
      oldDelegate.visual.kind != visual.kind ||
      oldDelegate.visual.accent != visual.accent;
}
