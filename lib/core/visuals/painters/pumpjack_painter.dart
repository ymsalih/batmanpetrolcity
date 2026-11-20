import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';

/// At kafası (pumpjack): A-çatı gövde, sallanan kiriş, at başı, dönen krank
/// ve karşı ağırlık. [phase] 0..1 bir pompalama döngüsüdür.
class PumpjackPainter extends CustomPainter {
  PumpjackPainter({required this.phase, this.broken = false, this.night = 0});

  final double phase;
  final bool broken;
  final double night;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = phase * 2 * pi;

    final steel = Paint()..color = Color.lerp(Palette.steel, Colors.black, night * 0.4)!;
    final beamColor = broken ? Palette.danger : Color.lerp(Palette.sunset, Colors.black, night * 0.3)!;
    final dark = Paint()..color = Palette.oil;

    final groundY = h * 0.92;
    // Kaide
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.08, groundY - h * 0.05, w * 0.95, groundY), const Radius.circular(2)),
      steel,
    );

    // Geometri
    final pivot = Offset(w * 0.48, h * 0.30);
    final frontLen = w * 0.36; // pivottan at başına
    final rearLen = w * 0.30; // pivottan arka uca
    final tilt = 0.20 * sin(a); // kiriş eğimi
    final dir = Offset(cos(tilt), sin(tilt));
    final front = pivot - dir * frontLen;
    final rear = pivot + dir * rearLen;

    final crankCenter = Offset(w * 0.80, h * 0.68);
    final crankR = h * 0.12;
    // Krank pimi kiriş arka ucu ile aynı fazda iner/çıkar.
    final pinAngle = a + pi / 2;
    final pin = crankCenter + Offset(cos(pinAngle) * crankR, sin(a) * crankR);

    // Samson direği (A-çatı)
    final legs = Paint()
      ..color = steel.color
      ..strokeWidth = max(2, w * 0.03)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.36, groundY - h * 0.05), pivot, legs);
    canvas.drawLine(Offset(w * 0.60, groundY - h * 0.05), pivot, legs);
    canvas.drawLine(Offset(w * 0.40, h * 0.62), Offset(w * 0.56, h * 0.62), legs..strokeWidth = max(1.5, w * 0.018));

    // Dişli kutusu
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: crankCenter + Offset(0, h * 0.10), width: w * 0.20, height: h * 0.16),
          const Radius.circular(3)),
      steel,
    );

    // Krank kolu + karşı ağırlık
    final crankPaint = Paint()
      ..color = Palette.steelLight
      ..strokeWidth = max(2, w * 0.025)
      ..strokeCap = StrokeCap.round;
    final weightAngle = atan2(pin.dy - crankCenter.dy, pin.dx - crankCenter.dx) + pi;
    final weightCenter = crankCenter + Offset(cos(weightAngle), sin(weightAngle)) * crankR * 0.9;
    canvas.drawLine(pin, weightCenter, crankPaint);
    final weight = Path()
      ..addArc(Rect.fromCircle(center: weightCenter, radius: crankR * 0.75), weightAngle - 1.1 + pi, 2.2)
      ..lineTo(weightCenter.dx, weightCenter.dy)
      ..close();
    canvas.drawPath(weight, Paint()..color = Palette.steel);
    canvas.drawCircle(weightCenter, crankR * 0.42, Paint()..color = const Color(0xFF555C66));
    canvas.drawCircle(crankCenter, max(2, w * 0.02), dark);

    // Biyel kolu (pitman)
    canvas.drawLine(pin, rear, Paint()
      ..color = Palette.steelLight
      ..strokeWidth = max(1.5, w * 0.018));

    // Kiriş
    final beamPaint = Paint()
      ..color = beamColor
      ..strokeWidth = max(3, h * 0.06)
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(front, rear, beamPaint);

    // At başı
    final normal = Offset(-dir.dy, dir.dx);
    final headH = h * 0.26;
    final headTop = front - normal * headH * 0.35;
    final headBottom = front + normal * headH * 0.65;
    final head = Path()
      ..moveTo(headTop.dx, headTop.dy)
      ..quadraticBezierTo(
        front.dx - dir.dx * w * 0.10 - normal.dx * headH * 0.1,
        front.dy - dir.dy * w * 0.10 + headH * 0.1,
        headBottom.dx,
        headBottom.dy,
      )
      ..lineTo(headBottom.dx + dir.dx * w * 0.05, headBottom.dy + dir.dy * w * 0.05)
      ..lineTo(headTop.dx + dir.dx * w * 0.06, headTop.dy + dir.dy * w * 0.06)
      ..close();
    canvas.drawPath(head, Paint()..color = Color.lerp(beamColor, Palette.oil, 0.45)!);

    // Kuyu başı ve pistonlu çubuk
    final wellX = front.dx - dir.dx * w * 0.06;
    final rodTop = Offset(wellX, headBottom.dy);
    final wellHead = Offset(wellX, groundY - h * 0.10);
    canvas.drawLine(rodTop, wellHead, Paint()
      ..color = Palette.steelLight
      ..strokeWidth = max(1, w * 0.012));
    canvas.drawRect(Rect.fromCenter(center: wellHead + Offset(0, h * 0.03), width: w * 0.08, height: h * 0.08), dark);
    canvas.drawRect(Rect.fromCenter(center: wellHead + Offset(0, h * 0.01), width: w * 0.14, height: h * 0.025), steel);

    // Pivot yatağı
    canvas.drawCircle(pivot, max(2.5, w * 0.025), dark);
  }

  @override
  bool shouldRepaint(PumpjackPainter old) => old.phase != phase || old.broken != broken || old.night != night;
}
