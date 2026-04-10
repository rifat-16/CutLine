import 'package:flutter/material.dart';

enum SupportBrand { facebook, whatsApp }

class SupportBrandIcon extends StatelessWidget {
  const SupportBrandIcon.facebook({
    super.key,
    this.size = 20,
  }) : brand = SupportBrand.facebook;

  const SupportBrandIcon.whatsApp({
    super.key,
    this.size = 20,
  }) : brand = SupportBrand.whatsApp;

  final SupportBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (brand) {
      case SupportBrand.facebook:
        return Icon(
          Icons.facebook_rounded,
          size: size,
          color: const Color(0xFF1877F2),
        );
      case SupportBrand.whatsApp:
        return CustomPaint(
          size: Size.square(size),
          painter: const _WhatsAppLogoPainter(),
        );
    }
  }
}

class _WhatsAppLogoPainter extends CustomPainter {
  const _WhatsAppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    final outerPaint = Paint()..color = const Color(0xFF25D366);
    canvas.drawCircle(center, outerRadius, outerPaint);

    final bubblePath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.47),
          radius: size.width * 0.31,
        ),
      )
      ..moveTo(size.width * 0.32, size.height * 0.68)
      ..lineTo(size.width * 0.26, size.height * 0.84)
      ..lineTo(size.width * 0.41, size.height * 0.75)
      ..close();

    final bubblePaint = Paint()..color = Colors.white;
    canvas.drawPath(bubblePath, bubblePaint);

    final phonePainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.call.codePoint),
        style: TextStyle(
          fontSize: size.width * 0.34,
          fontFamily: Icons.call.fontFamily,
          package: Icons.call.fontPackage,
          color: const Color(0xFF25D366),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    phonePainter.paint(
      canvas,
      Offset(
        center.dx - phonePainter.width / 2,
        size.height * 0.33,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
