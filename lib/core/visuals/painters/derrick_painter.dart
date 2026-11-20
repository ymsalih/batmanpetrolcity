import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';

/// Kafes sondaj kulesi. [rect] içine çizilir; diğer painter'lar da
/// [DerrickPainter.drawDerrick] ile yeniden kullanır.
class DerrickPainter extends CustomPainter {
  DerrickPainter({this.spin = 0, this.lightsOn = false});

  /// Matkap dönüş fazı (animasyon için).
  final double spin;
  final bool lightsOn;

  static void drawDerrick(Canvas canvas, Rect rect, {double spin = 0, bool lightsOn = false}) {
    final w = rect.width;
    final h = rect.height;
    final baseY = rect.bottom;
    final topY = rect.top + h * 0.08;
    final leftB = rect.left + w * 0.15;
    final rightB = rect.right - w * 0.15;
    final leftT = rect.center.dx - w * 0.07;
    final rightT = rect.center.dx + w * 0.07;

    final frame = Paint()
      ..color = Palette.steel
      ..strokeWidth = max(1.2, w * 0.035)
      ..strokeCap = StrokeCap.round;
    final brace = Paint()
      ..color = Palette.steelLight
      ..strokeWidth = max(0.8, w * 0.018);

    canvas.drawLine(Offset(leftB, baseY), Offset(leftT, topY), frame);
    canvas.drawLine(Offset(rightB, baseY), Offset(rightT, topY), frame);

    // Çapraz bağlantılar
    const steps = 6;
    for (var i = 0; i < steps; i++) {
      final t0 = i / steps;
      final t1 = (i + 1) / steps;
      Offset l(double t) => Offset.lerp(Offset(leftB, baseY), Offset(leftT, topY), t)!;
      Offset r(double t) => Offset.lerp(Offset(rightB, baseY), Offset(rightT, topY), t)!;
      canvas.drawLine(l(t0), r(t1), brace);
      canvas.drawLine(r(t0), l(t1), brace);
      canvas.drawLine(l(t1), r(t1), brace);
    }

    // Taç bloğu
    canvas.drawRect(Rect.fromCenter(center: Offset(rect.center.dx, topY), width: w * 0.24, height: h * 0.05),
        Paint()..color = Palette.sunset);

    // Platform
    canvas.drawRect(Rect.fromLTRB(rect.left + w * 0.05, baseY - h * 0.08, rect.right - w * 0.05, baseY - h * 0.04),
        Paint()..color = Palette.earth);

    // Halat + kelly (dönen matkap borusu)
    canvas.drawLine(Offset(rect.center.dx, topY), Offset(rect.center.dx, baseY - h * 0.25), brace);
    final kellyRect = Rect.fromCenter(center: Offset(rect.center.dx, baseY - h * 0.17), width: w * 0.08, height: h * 0.18);
    canvas.drawRect(kellyRect, Paint()..color = Palette.steel);
    final stripe = (spin % 1) * kellyRect.height;
    canvas.drawRect(
        Rect.fromLTWH(kellyRect.left, kellyRect.top + stripe * 0.8, kellyRect.width, kellyRect.height * 0.2),
        Paint()..color = Palette.gold);

    if (lightsOn) {
      final glow = Paint()
        ..color = Palette.lamp
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(rect.center.dx, topY - h * 0.03), max(2, w * 0.05), glow);
    }
    // Uç ışığı (uçak ikazı)
    canvas.drawCircle(Offset(rect.center.dx, topY - h * 0.03), max(1, w * 0.025), Paint()..color = Palette.danger);
  }

  @override
  void paint(Canvas canvas, Size size) => drawDerrick(canvas, Offset.zero & size, spin: spin, lightsOn: lightsOn);

  @override
  bool shouldRepaint(DerrickPainter old) => old.spin != spin || old.lightsOn != lightsOn;
}
