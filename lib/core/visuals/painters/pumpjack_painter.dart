import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';
import 'paint_kit.dart';

/// Gerçekçi at kafası (pumpjack).
///
/// Kinematik gerçek dört-çubuk mekanizmasıdır: krank döner, biyel kolu sabit
/// uzunluktadır, kiriş açısı iki çemberin kesişiminden hesaplanır. At başının
/// yüzü pivot merkezli bir yay olduğundan halat (bridle) her zaman dikey
/// sarkar ve cilalı çubuk gerçekteki gibi düz iner.
///
/// Çizim 200x124 birimlik tasarım alanında yapılır ve ölçeklenir.
class PumpjackPainter extends CustomPainter {
  PumpjackPainter({
    required this.phase,
    this.time = 0,
    this.broken = false,
    this.night = 0,
    this.sunX = 0.4,
    this.running = true,
  });

  /// 0..1 krank turu.
  final double phase;

  /// Sürekli zaman (sn): duman, titreşim.
  final double time;
  final bool broken;
  final double night;

  /// Güneşin yatay yönü (-1 sol .. 1 sağ): gölge ters yöne düşer.
  final double sunX;
  final bool running;

  static const designW = 200.0;
  static const designH = 124.0;

  // Mekanizma geometrisi (tasarım birimleri)
  static const pivot = Offset(86, 40);
  static const frontLen = 64.0; // pivot → at başı yüzü
  static const rearLen = 60.0; // pivot → kuyruk yatağı
  static const crankCenter = Offset(152, 90);
  static const crankR = 13.0;
  static const pitmanLen = 53.5;
  static const groundY = 118.0;
  static const headSpan = 0.30; // at başı yayının yarı açısı

  /// Kiriş açısı (rad). Negatif: kuyruk yukarı, at başı aşağı.
  static double beamAngle(double phase) {
    final theta = -phase * 2 * pi;
    final pin = crankCenter + Offset(cos(theta), sin(theta)) * crankR;
    final tail = PaintKit.circleIntersection(pivot, rearLen, pin, pitmanLen) ?? pivot + const Offset(rearLen, 0);
    return atan2(tail.dy - pivot.dy, tail.dx - pivot.dx);
  }

  /// Taşıyıcı çubuğun (carrier bar) y konumu: halat yay üzerinde sarılır.
  static double carrierY(double beam) => pivot.dy + 63.2 - frontLen * (beam + headSpan);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / designW, size.height / designH);
    canvas.save();
    canvas.translate((size.width - designW * s) / 2, size.height - designH * s);
    canvas.scale(s);
    _paintUnit(canvas, s);
    canvas.restore();
  }

  void _paintUnit(Canvas canvas, double scale) {
    final n = night;
    final theta = -phase * 2 * pi;
    final pin = crankCenter + Offset(cos(theta), sin(theta)) * crankR;
    final tail = PaintKit.circleIntersection(pivot, rearLen, pin, pitmanLen) ?? pivot + const Offset(rearLen, 0);
    final phi = atan2(tail.dy - pivot.dy, tail.dx - pivot.dx);
    final u = Offset(cos(phi), sin(phi)); // pivot → kuyruk
    final jitter = running && !broken ? Offset(sin(time * 71) * 0.25, cos(time * 53) * 0.2) : Offset.zero;

    final beamColor = broken ? const Color(0xFFB8432F) : const Color(0xFFE0782A);
    const steel = Color(0xFF59616B);
    const darkSteel = Color(0xFF353A40);

    // ------------------------------------------------- Zemin, gölge, leke
    final shadowShift = -sunX * 14;
    PaintKit.box(canvas, const Rect.fromLTWH(8, groundY - 2, 192, 6), const Color(0xFF9A9389), night: n, radius: 1);
    PaintKit.softShadow(
      canvas,
      Rect.fromLTWH(30 + shadowShift, groundY - 6, 170, 9),
      opacity: 0.38 * (1 - n * 0.5),
      blur: 4,
    );
    // Kuyu başı etrafında petrol lekesi
    canvas.drawOval(
      const Rect.fromLTWH(6, groundY - 4, 36, 7),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(22, groundY - 1),
          18,
          [const Color(0xFF0B0908), const Color(0xFF1A1512), Colors.transparent],
          const [0, 0.6, 1],
        ),
    );
    canvas.drawOval(
      const Rect.fromLTWH(14, groundY - 3, 10, 2),
      Paint()..color = const Color(0xFF6A5B7A).withValues(alpha: 0.35 * (1 - n)),
    );

    // Ana kızak (skid)
    PaintKit.box(canvas, const Rect.fromLTWH(58, groundY - 7, 140, 5), darkSteel, night: n);

    // ---------------------------------------------- Kuyu başı & akış hattı
    PaintKit.shadedBar(
      canvas,
      const Offset(22, groundY - 8),
      const Offset(64, groundY - 8),
      3.2,
      const Color(0xFF6F6A60),
      night: n,
    );
    PaintKit.box(canvas, const Rect.fromLTWH(15, groundY - 22, 14, 16), const Color(0xFF4A4F55), night: n);
    PaintKit.box(canvas, const Rect.fromLTWH(12, groundY - 12, 20, 3), steel, night: n);
    PaintKit.box(canvas, const Rect.fromLTWH(13, groundY - 21, 18, 3), steel, night: n);
    PaintKit.box(
      canvas,
      const Rect.fromLTWH(18, groundY - 30, 8, 9),
      const Color(0xFF6B7178),
      night: n,
    ); // stuffing box
    // Vana el çarkı
    canvas.drawCircle(
      const Offset(34, groundY - 16),
      3.2,
      Paint()
        ..color = PaintKit.nightTint(const Color(0xFFC0392B), n)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // --------------------------------------------------- Samson direği
    final legC = steel;
    PaintKit.shadedBar(canvas, const Offset(66, groundY - 6), pivot + const Offset(-3, 4), 3.6, legC, night: n);
    PaintKit.shadedBar(canvas, const Offset(108, groundY - 6), pivot + const Offset(3, 4), 3.6, legC, night: n);
    PaintKit.shadedBar(canvas, const Offset(96, groundY - 6), pivot + const Offset(1, 5), 2.4, darkSteel, night: n);
    for (final y in [64.0, 86.0, 104.0]) {
      final t = (y - pivot.dy - 4) / (groundY - 6 - pivot.dy - 4);
      final l = Offset.lerp(pivot + const Offset(-3, 4), const Offset(66, groundY - 6), t)!;
      final r = Offset.lerp(pivot + const Offset(3, 4), const Offset(108, groundY - 6), t)!;
      PaintKit.shadedBar(canvas, l, r, 1.6, legC, night: n);
    }
    // Merdiven
    final ladder = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF8A929B), n)
      ..strokeWidth = 0.6;
    for (var y = 52.0; y < groundY - 8; y += 5) {
      final t = (y - pivot.dy - 4) / (groundY - 6 - pivot.dy - 4);
      final x = ui.lerpDouble(83, 66, t)!;
      canvas.drawLine(Offset(x - 1, y), Offset(x + 3, y), ladder);
    }

    // ------------------------------------------- Dişli kutusu & motor
    PaintKit.box(canvas, const Rect.fromLTWH(134, 101, 36, 11), const Color(0xFF4B4F55), night: n, depth: 3);
    PaintKit.box(canvas, const Rect.fromLTWH(140, 80, 26, 21), const Color(0xFF3E5B78), night: n, depth: 4);
    // Kayış koruyucu
    final guard = Path()
      ..moveTo(150, 84)
      ..lineTo(182, 97)
      ..lineTo(182, 107)
      ..lineTo(150, 98)
      ..close();
    canvas.drawPath(
      guard,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 84), const Offset(0, 107), [
          PaintKit.nightTint(const Color(0xFFF2C14E), n),
          PaintKit.nightTint(const Color(0xFFB8892A), n),
        ]),
    );
    final hatch = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF2A2A2A), n).withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (var x = 154.0; x < 180; x += 6) {
      canvas.drawLine(Offset(x, 86 + (x - 150) * 0.4), Offset(x + 3, 97 + (x - 150) * 0.3), hatch);
    }
    // Motor (titreşimli)
    canvas.save();
    canvas.translate(jitter.dx, jitter.dy);
    PaintKit.box(canvas, const Rect.fromLTWH(176, 96, 20, 15), const Color(0xFF2F6E4F), night: n, depth: 2);
    final fin = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF1F4C36), n)
      ..strokeWidth = 0.7;
    for (var y = 99.0; y < 110; y += 2.2) {
      canvas.drawLine(Offset(178, y), Offset(194, y), fin);
    }
    // Egzoz
    PaintKit.shadedBar(canvas, const Offset(192, 96), const Offset(192, 86), 2.2, const Color(0xFF555555), night: n);
    canvas.restore();
    if (running && !broken) _paintSmoke(canvas, const Offset(192, 85));

    // ------------------------------------------------------ Krank
    final weightCenter = crankCenter - (pin - crankCenter) * 0.85;
    PaintKit.shadedBar(canvas, weightCenter, pin, 6, const Color(0xFF5A5F66), night: n);
    // Karşı ağırlık: krank koluna yapışık, dönen yarım disk
    canvas.save();
    canvas.translate(weightCenter.dx, weightCenter.dy);
    canvas.rotate(atan2(weightCenter.dy - crankCenter.dy, weightCenter.dx - crankCenter.dx));
    final cw = Path()
      ..moveTo(-6, -11)
      ..quadraticBezierTo(12, -12, 12, 0)
      ..quadraticBezierTo(12, 12, -6, 11)
      ..close();
    canvas.drawPath(
      cw,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -12),
          const Offset(0, 12),
          [
            PaintKit.nightTint(const Color(0xFF8B929A), n),
            PaintKit.nightTint(const Color(0xFF4C535B), n),
            PaintKit.nightTint(const Color(0xFF24282C), n),
          ],
          const [0, 0.5, 1],
        ),
    );
    canvas.drawLine(
      const Offset(-4, -9),
      const Offset(-4, 9),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 0.8,
    );
    canvas.restore();
    PaintKit.sphere(canvas, crankCenter, 3.4, const Color(0xFF8A9199), night: n);
    PaintKit.sphere(canvas, pin, 2.4, const Color(0xFFB0B6BC), night: n);

    // ------------------------------------------------- Biyel kolları
    const side = Offset(0.8, -0.6);
    PaintKit.shadedBar(canvas, tail + side, pin + side, 2.4, darkSteel, night: n);
    PaintKit.shadedBar(canvas, tail, pin, 2.6, const Color(0xFF6E767F), night: n);

    // ---------------------------------------------- Kiriş (I-profil)
    final front = pivot - u * (frontLen - 12);
    final rearEnd = pivot + u * (rearLen + 6);
    PaintKit.shadedBar(canvas, front, rearEnd, 7.5, beamColor, night: n, highlight: 0.4, shadow: 0.55);
    final flange = Paint()
      ..color = PaintKit.nightTint(Color.lerp(beamColor, Colors.black, 0.35)!, n)
      ..strokeWidth = 0.8;
    final nrm = Offset(-u.dy, u.dx);
    canvas.drawLine(front + nrm * 2.2, rearEnd + nrm * 2.2, flange);
    canvas.drawLine(front - nrm * 2.2, rearEnd - nrm * 2.2, flange);
    // Kuyruk yatağı (equalizer)
    PaintKit.shadedBar(canvas, tail - nrm * 5, tail + nrm * 5, 3, darkSteel, night: n);
    PaintKit.sphere(canvas, tail, 2.6, const Color(0xFF9AA1A8), night: n);

    // ----------------------------------------------------- At başı
    Offset arc(double localAngle, double r) =>
        pivot + PaintKit.rotate(Offset(cos(localAngle), sin(localAngle)) * r, phi);
    final head = Path();
    const steps = 14;
    for (var i = 0; i <= steps; i++) {
      final a = pi - headSpan + 2 * headSpan * i / steps;
      final p = arc(a, frontLen + 1.5);
      i == 0 ? head.moveTo(p.dx, p.dy) : head.lineTo(p.dx, p.dy);
    }
    for (var i = steps; i >= 0; i--) {
      final a = pi - headSpan * 0.55 + headSpan * 1.25 * i / steps;
      final p = arc(a, frontLen - 13);
      head.lineTo(p.dx, p.dy);
    }
    head.close();
    final headTop = arc(pi + headSpan, frontLen);
    final headBottom = arc(pi - headSpan, frontLen);
    canvas.drawPath(
      head,
      Paint()
        ..shader = ui.Gradient.linear(
          headTop,
          headBottom,
          [
            PaintKit.nightTint(Color.lerp(beamColor, Colors.white, 0.25)!, n),
            PaintKit.nightTint(beamColor, n),
            PaintKit.nightTint(Color.lerp(beamColor, Colors.black, 0.5)!, n),
          ],
          const [0, 0.45, 1],
        ),
    );
    // Yüz plakası
    final face = Path();
    for (var i = 0; i <= steps; i++) {
      final p = arc(pi - headSpan + 2 * headSpan * i / steps, frontLen + 1.5);
      i == 0 ? face.moveTo(p.dx, p.dy) : face.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      face,
      Paint()
        ..color = PaintKit.nightTint(const Color(0xFF2A211C), n)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // ------------------------------------------- Halat & cilalı çubuk
    final wireX = pivot.dx - frontLen - 2.6;
    final cy = carrierY(phi);
    final wire = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF1C1C1C), n)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    // Halat yüz üzerinde sarılı kısım
    final wrap = Path();
    const wSteps = 10;
    final worldTop = pi + phi + headSpan;
    for (var i = 0; i <= wSteps; i++) {
      final a = worldTop + (pi - worldTop) * i / wSteps;
      final p = pivot + Offset(cos(a), sin(a)) * (frontLen + 2.6);
      i == 0 ? wrap.moveTo(p.dx, p.dy) : wrap.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(wrap, wire);
    canvas.drawLine(Offset(wireX, pivot.dy), Offset(wireX, cy), wire);
    canvas.drawLine(Offset(wireX + 1.6, pivot.dy), Offset(wireX + 1.6, cy), wire);
    // Taşıyıcı çubuk
    PaintKit.box(canvas, Rect.fromLTWH(wireX - 3, cy, 8, 2.4), darkSteel, night: n, radius: 0.5);
    // Cilalı çubuk: parlak, krom
    final rodTop = cy - 5;
    final rodBottom = groundY - 28;
    canvas.drawRect(
      Rect.fromLTWH(wireX - 0.1, rodTop, 1.8, rodBottom - rodTop),
      Paint()
        ..shader = ui.Gradient.linear(Offset(wireX, 0), Offset(wireX + 1.8, 0), [
          PaintKit.nightTint(const Color(0xFFEDEFF2), n),
          PaintKit.nightTint(const Color(0xFF9CA3AA), n),
        ]),
    );
    // Çubuk üzerinde yağ parıltısı
    canvas.drawRect(
      Rect.fromLTWH(wireX + 0.2, rodBottom - 6, 1.2, 6),
      Paint()..color = const Color(0xFF2B2420).withValues(alpha: 0.7),
    );

    // Pivot yatağı
    PaintKit.box(
      canvas,
      Rect.fromCenter(center: pivot + const Offset(0, 4), width: 10, height: 5),
      darkSteel,
      night: n,
    );
    PaintKit.sphere(canvas, pivot, 3, const Color(0xFFA3AAB1), night: n);

    // ---------------------------------------------------- Gece ışığı
    if (n > 0.45) {
      final lamp = pivot + const Offset(0, 10);
      final glowA = ((n - 0.45) / 0.55).clamp(0.0, 1.0);
      canvas.drawCircle(
        lamp,
        26,
        Paint()
          ..shader = ui.Gradient.radial(lamp, 26, [Palette.lamp.withValues(alpha: 0.28 * glowA), Colors.transparent]),
      );
      canvas.drawCircle(lamp, 1.6, Paint()..color = Palette.lamp);
    }

    if (broken) {
      // Arızada motordan kıvılcım
      final r = Random((time * 8).floor());
      final spark = Paint()
        ..color = Palette.gold
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final o = const Offset(178, 96) + Offset(r.nextDouble() * 8, r.nextDouble() * 4);
        final d = Offset(r.nextDouble() * 6 - 3, -r.nextDouble() * 6);
        canvas.drawLine(o, o + d, spark);
      }
    }
  }

  void _paintSmoke(Canvas canvas, Offset origin) {
    const puffs = 6;
    const life = 2.4;
    for (var i = 0; i < puffs; i++) {
      final t = ((time + i * life / puffs) % life) / life;
      final drift = Offset(-t * 16 + sin(time * 1.3 + i) * 2, -t * 26);
      final r = 1.5 + t * 6;
      canvas.drawCircle(
        origin + drift,
        r,
        Paint()
          ..color = Color.lerp(const Color(0xFF6E6A66), const Color(0xFFB8B4AE), t)!.withValues(alpha: 0.35 * (1 - t))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1 + t * 2),
      );
    }
  }

  @override
  bool shouldRepaint(PumpjackPainter old) =>
      old.phase != phase || old.time != time || old.broken != broken || old.night != night || old.sunX != sunX;
}
