import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Flutter-painted versions of the approved prototype's inline SVG artwork.
enum StatisticsIconKind { book, target, medal, flame, chart }

class StatisticsIcon extends StatelessWidget {
  const StatisticsIcon({
    super.key,
    required this.kind,
    required this.color,
    this.size = 24,
  });

  final StatisticsIconKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StatisticsIconPainter(kind, color)),
    ),
  );
}

class _StatisticsIconPainter extends CustomPainter {
  const _StatisticsIconPainter(this.kind, this.color);

  final StatisticsIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final Paint fill = Paint()..color = color;
    final Paint stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case StatisticsIconKind.book:
        final Path book =
            Path()
              ..moveTo(3, 4)
              ..quadraticBezierTo(8, 3, 12, 6)
              ..quadraticBezierTo(16, 3, 21, 4)
              ..lineTo(21, 19)
              ..quadraticBezierTo(16, 18, 12, 20)
              ..quadraticBezierTo(8, 18, 3, 19)
              ..close();
        canvas.drawPath(book, fill);
        canvas.drawLine(
          const Offset(12, 6),
          const Offset(12, 20),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
      case StatisticsIconKind.target:
        canvas.drawCircle(const Offset(11, 13), 8, stroke);
        canvas.drawCircle(const Offset(11, 13), 4, stroke);
        canvas.drawLine(const Offset(11, 13), const Offset(20, 4), stroke);
        canvas.drawLine(const Offset(16, 4), const Offset(20, 4), stroke);
        canvas.drawLine(const Offset(20, 4), const Offset(20, 8), stroke);
      case StatisticsIconKind.medal:
        final Path ribbon =
            Path()
              ..moveTo(8, 13)
              ..lineTo(5, 22)
              ..lineTo(12, 19)
              ..lineTo(19, 22)
              ..lineTo(16, 13)
              ..close();
        canvas.drawPath(ribbon, Paint()..color = color.withValues(alpha: 0.6));
        canvas.drawCircle(const Offset(12, 9), 7, fill);
        _drawStar(canvas, const Offset(12, 9), 4.5, Colors.white);
      case StatisticsIconKind.flame:
        final Path flame =
            Path()
              ..moveTo(13, 2)
              ..cubicTo(14, 8, 20, 9, 20, 15)
              ..arcToPoint(
                const Offset(4, 15),
                radius: const Radius.circular(8),
              )
              ..cubicTo(4, 12, 6, 9, 9, 7)
              ..cubicTo(8, 11, 10, 12, 11, 12)
              ..cubicTo(13, 9, 14, 6, 13, 2)
              ..close();
        canvas.drawPath(flame, fill);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(12, 17), width: 5, height: 7),
          Paint()..color = const Color(0xFFFFF5DE),
        );
      case StatisticsIconKind.chart:
        for (final (double x, double top, double opacity)
            in <(double, double, double)>[
              (3, 13, 0.6),
              (10, 8, 1),
              (17, 3, 0.8),
            ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, top, 4, 21 - top),
              const Radius.circular(1),
            ),
            Paint()..color = color.withValues(alpha: opacity),
          );
        }
    }
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final Path path = Path();
    for (int i = 0; i < 10; i++) {
      final double angle = -math.pi / 2 + i * math.pi / 5;
      final double distance = i.isEven ? radius : radius * 0.45;
      final Offset point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StatisticsIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

enum StatisticsEmptyArtKind { book, target }

class StatisticsEmptyArt extends StatelessWidget {
  const StatisticsEmptyArt({super.key, required this.kind});

  final StatisticsEmptyArtKind kind;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 116,
      height: 97,
      child: CustomPaint(painter: _StatisticsEmptyPainter(kind)),
    ),
  );
}

class _StatisticsEmptyPainter extends CustomPainter {
  const _StatisticsEmptyPainter(this.kind);

  final StatisticsEmptyArtKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 100);
    if (kind == StatisticsEmptyArtKind.book) {
      canvas.drawCircle(
        const Offset(60, 48),
        42,
        Paint()..color = const Color(0xFFEDF3FF),
      );
      _rect(canvas, 28, 28, 41, 52, 8, const Color(0xFF9EB9EE));
      _rect(canvas, 37, 20, 47, 54, 8, const Color(0xFFC5D6F7));
      _rect(canvas, 45, 30, 31, 5, 2, Colors.white);
      _rect(canvas, 45, 42, 24, 4, 2, Colors.white);
      _rect(canvas, 45, 52, 28, 4, 2, Colors.white);
      canvas.drawCircle(
        const Offset(22, 63),
        5,
        Paint()..color = const Color(0xFFB4D8C7),
      );
      final Path star =
          Path()
            ..moveTo(93, 19)
            ..lineTo(96, 25)
            ..lineTo(103, 26)
            ..lineTo(98, 31)
            ..lineTo(99, 38)
            ..lineTo(93, 35)
            ..lineTo(87, 38)
            ..lineTo(88, 31)
            ..lineTo(83, 26)
            ..lineTo(90, 25)
            ..close();
      canvas.drawPath(star, Paint()..color = const Color(0xFFEFC46A));
    } else {
      canvas.drawCircle(
        const Offset(60, 49),
        42,
        Paint()..color = const Color(0xFFEFF7F3),
      );
      for (final (double radius, Color color) in <(double, Color)>[
        (29, const Color(0xFFC8DFD3)),
        (20, const Color(0xFFF6FBF8)),
        (10, const Color(0xFF96BDAA)),
      ]) {
        canvas.drawCircle(const Offset(60, 49), radius, Paint()..color = color);
      }
      final Paint arrow =
          Paint()
            ..color = const Color(0xFF669E86)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(60, 49), const Offset(89, 20), arrow);
      canvas.drawLine(const Offset(79, 20), const Offset(89, 20), arrow);
      canvas.drawLine(const Offset(89, 20), const Offset(89, 30), arrow);
    }
    canvas.restore();
  }

  void _rect(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double radius,
    Color color,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(radius),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _StatisticsEmptyPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
