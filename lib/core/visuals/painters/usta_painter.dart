import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';

/// Orijinal maskot "Usta": sarı baretli, gür bıyıklı, mavi tulumlu petrolcü.
class UstaPainter extends CustomPainter {
  UstaPainter({this.mood = 0, this.blink = 0});

  /// 0 mutlu, 1 heyecanlı, 2 endişeli, 3 düşünceli.
  final int mood;

  /// 0..1 göz kırpma.
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final c = Offset(s / 2, s * 0.56);
    final r = s * 0.30;

    // Arka daire
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, Paint()..color = Palette.sunset.withValues(alpha: 0.25));

    // Tulum (omuzlar)
    final body = Path()
      ..moveTo(s * 0.12, s)
      ..quadraticBezierTo(s * 0.18, s * 0.80, s / 2, s * 0.80)
      ..quadraticBezierTo(s * 0.82, s * 0.80, s * 0.88, s)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF2E5C9A));
    canvas.drawRect(Rect.fromLTWH(s * 0.44, s * 0.82, s * 0.12, s * 0.18), Paint()..color = const Color(0xFF244A7D));

    // Yüz
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFE0A877));
    // Kulaklar
    final ear = Paint()..color = const Color(0xFFD19566);
    canvas.drawCircle(c + Offset(-r * 0.98, r * 0.05), r * 0.18, ear);
    canvas.drawCircle(c + Offset(r * 0.98, r * 0.05), r * 0.18, ear);

    // Gözler
    final eyeY = c.dy - r * 0.10;
    final eyeH = r * 0.16 * (1 - blink.clamp(0, 1) * 0.9);
    final eye = Paint()..color = const Color(0xFF2A1E16);
    for (final dx in [-r * 0.38, r * 0.38]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + dx, eyeY), width: r * 0.16, height: eyeH), eye);
    }
    // Kaşlar
    final brow = Paint()
      ..color = const Color(0xFF3B2A1E)
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    final worried = mood == 2 ? 1.0 : 0.0;
    canvas.drawLine(Offset(c.dx - r * 0.55, eyeY - r * (0.25 - worried * 0.08)),
        Offset(c.dx - r * 0.2, eyeY - r * (0.30 + worried * 0.06)), brow);
    canvas.drawLine(Offset(c.dx + r * 0.2, eyeY - r * (0.30 + worried * 0.06)),
        Offset(c.dx + r * 0.55, eyeY - r * (0.25 - worried * 0.08)), brow);

    // Burun
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.12), width: r * 0.26, height: r * 0.22),
        Paint()..color = const Color(0xFFC98656));

    // Ağız
    final mouth = Paint()
      ..color = const Color(0xFF5A2A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    final my = c.dy + r * 0.52;
    switch (mood) {
      case 1:
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, my), width: r * 0.36, height: r * 0.30),
            Paint()..color = const Color(0xFF5A2A1A));
      case 2:
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, my + r * 0.12), width: r * 0.5, height: r * 0.25), pi,
            pi, false, mouth);
      default:
        canvas.drawArc(
            Rect.fromCenter(center: Offset(c.dx, my - r * 0.08), width: r * 0.55, height: r * 0.3), 0.2, pi - 0.4, false, mouth);
    }

    // Bıyık
    final mustache = Path()
      ..moveTo(c.dx, c.dy + r * 0.26)
      ..cubicTo(c.dx - r * 0.25, c.dy + r * 0.18, c.dx - r * 0.55, c.dy + r * 0.30, c.dx - r * 0.62, c.dy + r * 0.48)
      ..cubicTo(c.dx - r * 0.40, c.dy + r * 0.40, c.dx - r * 0.18, c.dy + r * 0.44, c.dx, c.dy + r * 0.38)
      ..cubicTo(c.dx + r * 0.18, c.dy + r * 0.44, c.dx + r * 0.40, c.dy + r * 0.40, c.dx + r * 0.62, c.dy + r * 0.48)
      ..cubicTo(c.dx + r * 0.55, c.dy + r * 0.30, c.dx + r * 0.25, c.dy + r * 0.18, c.dx, c.dy + r * 0.26)
      ..close();
    canvas.drawPath(mustache, Paint()..color = const Color(0xFF3B2A1E));

    // Baret
    final helmetRect = Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.55), width: r * 2.1, height: r * 1.5);
    final helmet = Path()
      ..addArc(helmetRect, pi, pi)
      ..close();
    canvas.drawPath(helmet, Paint()..color = Palette.gold);
    // Siperlik
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.55), width: r * 2.5, height: r * 0.22), Radius.circular(r * 0.1)),
      Paint()..color = const Color(0xFFE0A92C),
    );
    // Baret sırtı ve damla logosu
    canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.95), width: r * 0.22, height: r * 0.7),
        Paint()..color = const Color(0xFFE0A92C));
    final drop = Path()
      ..moveTo(c.dx + r * 0.55, c.dy - r * 1.05)
      ..quadraticBezierTo(c.dx + r * 0.75, c.dy - r * 0.8, c.dx + r * 0.55, c.dy - r * 0.72)
      ..quadraticBezierTo(c.dx + r * 0.35, c.dy - r * 0.8, c.dx + r * 0.55, c.dy - r * 1.05);
    canvas.drawPath(drop, Paint()..color = Palette.oil);

    canvas.restore();
  }

  @override
  bool shouldRepaint(UstaPainter old) => old.mood != mood || old.blink != blink;
}
