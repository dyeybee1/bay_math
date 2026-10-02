import 'package:flutter/material.dart';

/// Native Flutter versions of the star, flame, and cup paths in the UI kit.
enum EndlessKitIconType { star, flame, cup }

class EndlessKitIcon extends StatelessWidget {
  const EndlessKitIcon({
    super.key,
    required this.type,
    required this.color,
    this.size = 24,
  });

  final EndlessKitIconType type;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _EndlessKitIconPainter(type, color)),
  );
}

class _EndlessKitIconPainter extends CustomPainter {
  const _EndlessKitIconPainter(this.type, this.color);

  final EndlessKitIconType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    switch (type) {
      case EndlessKitIconType.star:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(15, 8)
            ..lineTo(22, 9)
            ..lineTo(17, 14)
            ..lineTo(18, 21)
            ..lineTo(12, 18)
            ..lineTo(6, 21)
            ..lineTo(7, 14)
            ..lineTo(2, 9)
            ..lineTo(9, 8)
            ..close(),
          Paint()..color = color,
        );
      case EndlessKitIconType.flame:
        canvas.drawPath(
          Path()
            ..moveTo(13, 2)
            ..cubicTo(14, 8, 20, 9, 20, 15)
            ..arcToPoint(const Offset(4, 15), radius: const Radius.circular(8))
            ..cubicTo(4, 12, 6, 9, 9, 7)
            ..cubicTo(8, 11, 10, 12, 11, 12)
            ..cubicTo(13, 9, 14, 6, 13, 2)
            ..close(),
          Paint()..color = color,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 13)
            ..cubicTo(13, 16, 16, 17, 15, 19)
            ..arcToPoint(const Offset(9, 19), radius: const Radius.circular(3))
            ..cubicTo(9, 17, 11, 16, 12, 13)
            ..close(),
          Paint()..color = const Color(0xFFFFF3C7),
        );
      case EndlessKitIconType.cup:
        final Paint stroke =
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          Path()
            ..moveTo(7, 3)
            ..lineTo(17, 3)
            ..lineTo(17, 11)
            ..arcToPoint(const Offset(7, 11), radius: const Radius.circular(5))
            ..close()
            ..moveTo(12, 16)
            ..lineTo(12, 21)
            ..moveTo(8, 21)
            ..lineTo(16, 21)
            ..moveTo(7, 5)
            ..lineTo(3, 5)
            ..lineTo(3, 9)
            ..cubicTo(3, 12, 4, 13, 7, 13)
            ..moveTo(17, 5)
            ..lineTo(21, 5)
            ..lineTo(21, 9)
            ..cubicTo(21, 12, 20, 13, 17, 13),
          stroke,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EndlessKitIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
