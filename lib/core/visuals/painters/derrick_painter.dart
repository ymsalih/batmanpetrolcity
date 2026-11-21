import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';
import 'paint_kit.dart';

/// Gerçekçi sondaj kulesi: alt yapı, platform, sondajcı kabini, vinç tamburu,
/// kafes direk, hareketli makara bloğu, istiflenmiş borular, çamur tankları.
/// [rect] içine en-boy oranını koruyarak, alt kenara oturtularak çizilir.
class DerrickPainter extends CustomPainter {
  DerrickPainter({this.spin = 0, this.time = 0, this.lightsOn = false, this.night = 0, this.drilling = true});

  /// 0..1 döngü (kelly şeridi).
  final double spin;

  /// Sürekli zaman (sn): makara bloğu, egzoz.
  final double time;
  final bool lightsOn;
  final double night;
  final bool drilling;

  static const designW = 100.0;
  static const designH = 160.0;

  static void drawDerrick(
    Canvas canvas,
    Rect rect, {
    double spin = 0,
    double time = 0,
    bool lightsOn = false,
    double night = 0,
    bool drilling = true,
    bool withSite = true,
  }) {
    final s = min(rect.width / designW, rect.height / designH);
    canvas.save();
    canvas.translate(rect.left + (rect.width - designW * s) / 2, rect.bottom - designH * s);
    canvas.scale(s);
    _paint(canvas, spin: spin, time: time, lightsOn: lightsOn, night: night, drilling: drilling, withSite: withSite);
    canvas.restore();
  }

  static void _paint(
    Canvas canvas, {
    required double spin,
    required double time,
    required bool lightsOn,
    required double night,
    required bool drilling,
    required bool withSite,
  }) {
    final n = night;
    const ground = 158.0;
    const floorY = 128.0;
    const topY = 10.0;
    const cx = 50.0;
    const steel = Color(0xFF6A727B);
    const red = Color(0xFFC0392B);

    // Gölge
    PaintKit.softShadow(canvas, const Rect.fromLTWH(4, ground - 5, 96, 7), opacity: 0.35 * (1 - n * 0.4), blur: 3);

    if (withSite) {
      // Çamur tankları (sağda)
      PaintKit.box(canvas, const Rect.fromLTWH(74, ground - 14, 24, 13), const Color(0xFF7A8088), night: n, depth: 2);
      final rail = Paint()
        ..color = PaintKit.nightTint(Palette.gold, n)
        ..strokeWidth = 0.8;
      canvas.drawLine(const Offset(74, ground - 18), const Offset(98, ground - 18), rail);
      for (var x = 76.0; x <= 98; x += 5.5) {
        canvas.drawLine(Offset(x, ground - 18), Offset(x, ground - 14), rail);
      }
      // Boru rafı (solda)
      for (var i = 0; i < 4; i++) {
        PaintKit.shadedBar(
          canvas,
          Offset(0, ground - 3 - i * 2.4),
          Offset(22, ground - 3 - i * 2.4),
          2.2,
          const Color(0xFF8C7A64),
          night: n,
        );
      }
    }

    if (withSite) {
      // Gergi halatları: direğin üst kısmından zemindeki çapalara.
      final guy = Paint()
        ..color = PaintKit.nightTint(const Color(0xFF8D959E), n).withValues(alpha: 0.55)
        ..strokeWidth = 0.45;
      canvas.drawLine(const Offset(cx - 6, topY + 30), const Offset(2, ground - 1), guy);
      canvas.drawLine(const Offset(cx + 6, topY + 30), const Offset(98, ground - 1), guy);
      canvas.drawLine(const Offset(cx - 5, topY + 60), const Offset(8, ground - 1), guy);
      canvas.drawLine(const Offset(cx + 5, topY + 60), const Offset(92, ground - 1), guy);
      // V-door rampası: boru rafından platforma eğimli kızak.
      PaintKit.shadedBar(
        canvas,
        const Offset(14, ground - 3),
        const Offset(30, floorY - 2),
        2.4,
        const Color(0xFF6E5F4C),
        night: n,
      );
    }

    // Alt yapı (substructure)
    PaintKit.box(canvas, const Rect.fromLTWH(22, floorY, 56, ground - floorY), const Color(0xFF555C64), night: n);
    final x = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF3B4046), n)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 3; i++) {
      final l = 22.0 + i * 18.6;
      canvas.drawLine(Offset(l, floorY + 2), Offset(l + 18.6, ground - 2), x);
      canvas.drawLine(Offset(l + 18.6, floorY + 2), Offset(l, ground - 2), x);
    }
    // Alt yapıya çıkan merdiven
    if (withSite) {
      final step = Paint()
        ..color = PaintKit.nightTint(const Color(0xFFD9A62E), n)
        ..strokeWidth = 0.8;
      canvas.drawLine(const Offset(80, ground - 1), const Offset(72, floorY + 1), step);
      for (var i = 1; i < 6; i++) {
        final t = i / 6;
        final p = Offset.lerp(const Offset(80, ground - 1), const Offset(72, floorY + 1), t)!;
        canvas.drawLine(p, p + const Offset(4, 0), step);
      }
    }
    // Platform
    PaintKit.box(canvas, const Rect.fromLTWH(16, floorY - 4, 68, 5), const Color(0xFF7A6A55), night: n, depth: 2);

    // Kafes direk
    const lb = Offset(28, floorY - 4);
    const rb = Offset(72, floorY - 4);
    const lt = Offset(cx - 7, topY + 8);
    const rt = Offset(cx + 7, topY + 8);
    PaintKit.shadedBar(canvas, lb, lt, 3.2, steel, night: n);
    PaintKit.shadedBar(canvas, rb, rt, 3.2, steel, night: n);
    final brace = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF8D959E), n)
      ..strokeWidth = 0.9;
    const levels = 9;
    for (var i = 0; i < levels; i++) {
      final t0 = i / levels;
      final t1 = (i + 1) / levels;
      final l0 = Offset.lerp(lb, lt, t0)!;
      final r0 = Offset.lerp(rb, rt, t0)!;
      final l1 = Offset.lerp(lb, lt, t1)!;
      final r1 = Offset.lerp(rb, rt, t1)!;
      canvas.drawLine(l0, r1, brace);
      canvas.drawLine(r0, l1, brace);
      canvas.drawLine(l1, r1, brace..strokeWidth = 1.3);
      brace.strokeWidth = 0.9;
    }
    // Monkey board ve istiflenmiş borular
    final mb = Offset.lerp(lb, lt, 0.62)!;
    PaintKit.box(canvas, Rect.fromLTWH(mb.dx - 6, mb.dy - 1, 12, 2.4), const Color(0xFF4D545B), night: n);
    for (var i = 0; i < 5; i++) {
      PaintKit.shadedBar(
        canvas,
        Offset(36 + i * 1.6, floorY - 5),
        Offset(mb.dx - 2 + i * 1.2, mb.dy + 1),
        1.3,
        const Color(0xFF9A8A70),
        night: n,
      );
    }

    // Taç bloğu
    PaintKit.box(canvas, const Rect.fromLTWH(cx - 10, topY + 2, 20, 7), Palette.sunset, night: n, depth: 2);
    PaintKit.sphere(canvas, const Offset(cx - 4, topY + 5.5), 2.2, const Color(0xFF9AA1A8), night: n);
    PaintKit.sphere(canvas, const Offset(cx + 4, topY + 5.5), 2.2, const Color(0xFF9AA1A8), night: n);

    // Makara bloğu: sondajda yavaşça iner, sonra hızla yukarı çıkar (boru ekleme döngüsü).
    final cycle = drilling ? (time / 9) % 1.0 : 0.7;
    final travel = cycle < 0.85 ? cycle / 0.85 : 1 - (cycle - 0.85) / 0.15;
    final blockY = ui.lerpDouble(topY + 26, floorY - 34, travel)!;
    final line = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF2C2C2C), n)
      ..strokeWidth = 0.6;
    for (final dx in [-3.0, -1.0, 1.0, 3.0]) {
      canvas.drawLine(Offset(cx + dx, topY + 9), Offset(cx + dx, blockY), line);
    }
    PaintKit.box(canvas, Rect.fromLTWH(cx - 5, blockY, 10, 9), Palette.gold, night: n, radius: 2);
    // Kanca + top drive
    PaintKit.box(canvas, Rect.fromLTWH(cx - 3.5, blockY + 9, 7, 9), const Color(0xFF3E5B78), night: n);
    // Sondaj borusu (kelly) dönen şeritle
    final pipeTop = blockY + 18;
    const pipeBottom = floorY - 4;
    final pipeRect = Rect.fromLTRB(cx - 1.6, pipeTop, cx + 1.6, pipeBottom);
    canvas.drawRect(
      pipeRect,
      Paint()
        ..shader = ui.Gradient.linear(Offset(pipeRect.left, 0), Offset(pipeRect.right, 0), [
          PaintKit.nightTint(const Color(0xFFD5D9DD), n),
          PaintKit.nightTint(const Color(0xFF5E656C), n),
        ]),
    );
    if (drilling) {
      final band = Paint()..color = Colors.black.withValues(alpha: 0.35);
      for (var k = 0; k < 3; k++) {
        final y = pipeTop + ((spin + k / 3) % 1) * (pipeBottom - pipeTop);
        canvas.drawRect(Rect.fromLTWH(cx - 1.6, y, 3.2, 1.2), band);
      }
    }

    // Vinç (drawworks) + dönen tambur
    PaintKit.box(canvas, const Rect.fromLTWH(54, floorY - 16, 18, 12), const Color(0xFF2F6E4F), night: n, depth: 2);
    final drum = const Offset(63, floorY - 10);
    PaintKit.sphere(canvas, drum, 4.2, const Color(0xFF7F878F), night: n);
    final spoke = Paint()
      ..color = Colors.black45
      ..strokeWidth = 0.8;
    final a = drilling ? time * 4 : 0.0;
    for (var k = 0; k < 3; k++) {
      final ang = a + k * pi / 1.5;
      canvas.drawLine(drum, drum + Offset(cos(ang), sin(ang)) * 3.8, spoke);
    }
    canvas.drawLine(const Offset(cx + 7, topY + 8), drum, line);

    // Sondajcı kabini (doghouse)
    PaintKit.box(canvas, const Rect.fromLTWH(10, floorY - 15, 16, 11), const Color(0xFFD9D2C3), night: n, depth: 2);
    final win = Paint()..color = lightsOn ? Palette.lamp : PaintKit.nightTint(const Color(0xFF7FB2D6), n);
    canvas.drawRect(const Rect.fromLTWH(13, floorY - 12.5, 4, 3.5), win);
    canvas.drawRect(const Rect.fromLTWH(19, floorY - 12.5, 4, 3.5), win);

    // Bayrak
    final flagWave = sin(time * 5) * 1.5;
    canvas.drawLine(
      const Offset(cx + 10, topY + 2),
      const Offset(cx + 10, topY - 8),
      Paint()
        ..color = PaintKit.nightTint(const Color(0xFF444444), n)
        ..strokeWidth = 0.7,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + 10, topY - 8)
        ..quadraticBezierTo(cx + 14, topY - 8 + flagWave, cx + 18, topY - 7)
        ..lineTo(cx + 18, topY - 3)
        ..quadraticBezierTo(cx + 14, topY - 4 + flagWave, cx + 10, topY - 4)
        ..close(),
      Paint()..color = PaintKit.nightTint(red, n),
    );

    // Uçak ikaz lambası (yanıp söner)
    final blink = (time % 1.6) < 0.8;
    canvas.drawCircle(
      const Offset(cx, topY),
      1.6,
      Paint()..color = blink ? const Color(0xFFFF3B30) : const Color(0xFF6B1A16),
    );
    if (blink) {
      canvas.drawCircle(
        const Offset(cx, topY),
        5,
        Paint()
          ..color = const Color(0xFFFF3B30).withValues(alpha: 0.35)
          ..maskFilter = PaintKit.blur(3),
      );
    }

    // Gece: direk boyunca çalışma lambaları ve platform aydınlatması
    if (lightsOn) {
      final glow = Paint()
        ..color = Palette.lamp.withValues(alpha: 0.9)
        ..maskFilter = PaintKit.blur(1.5);
      for (var i = 1; i < levels; i += 2) {
        final t = i / levels;
        canvas.drawCircle(Offset.lerp(lb, lt, t)!, 1.3, glow);
        canvas.drawCircle(Offset.lerp(rb, rt, t)!, 1.3, glow);
      }
      canvas.drawOval(
        const Rect.fromLTWH(6, floorY - 30, 88, 40),
        Paint()
          ..shader = ui.Gradient.radial(const Offset(cx, floorY - 8), 46, [
            Palette.lamp.withValues(alpha: 0.22),
            Colors.transparent,
          ]),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) => drawDerrick(
    canvas,
    Offset.zero & size,
    spin: spin,
    time: time,
    lightsOn: lightsOn,
    night: night,
    drilling: drilling,
  );

  @override
  bool shouldRepaint(DerrickPainter old) =>
      old.spin != spin || old.time != time || old.lightsOn != lightsOn || old.night != night;
}
