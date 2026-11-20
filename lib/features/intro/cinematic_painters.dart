import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../core/visuals/painters/paint_kit.dart';

/// Rafineri silüeti: damıtma kuleleri, tanklar, küresel tanklar, boru
/// köprüsü ve meşale. [reveal] 0..1 ile yapılar yerden yükselir.
class RefineryPainter extends CustomPainter {
  RefineryPainter({required this.time, this.night = 1, this.reveal = 1});

  final double time;
  final double night;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.86;
    double grow(double delay) => Curves.easeOutCubic.transform(((reveal - delay) / 0.5).clamp(0.0, 1.0));

    // Zemin
    canvas.drawRect(
      Rect.fromLTWH(0, ground, w, h - ground),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, ground), Offset(0, h), [
          const Color(0xFF1A1410),
          const Color(0xFF0A0807),
        ]),
    );

    void column(double x, double width, double height, double delay) {
      final g = grow(delay);
      if (g <= 0) return;
      final top = ground - height * h * g;
      final r = Rect.fromLTRB(x - width / 2, top, x + width / 2, ground);
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            r.centerLeft,
            r.centerRight,
            [
              PaintKit.nightTint(const Color(0xFFB9C0C7), night),
              PaintKit.nightTint(const Color(0xFF7A838C), night),
              PaintKit.nightTint(const Color(0xFF3B4148), night),
            ],
            const [0, 0.45, 1],
          ),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, top), width: width, height: width * 0.3),
        Paint()..color = PaintKit.nightTint(const Color(0xFFD0D5DA), night),
      );
      // Platform halkaları ve merdiven
      final ring = Paint()
        ..color = PaintKit.nightTint(const Color(0xFF2A2F35), night)
        ..strokeWidth = 1.4;
      for (var y = top + 18; y < ground - 8; y += 26) {
        canvas.drawLine(Offset(x - width / 2 - 4, y), Offset(x + width / 2 + 4, y), ring);
      }
      final ladder = Paint()
        ..color = PaintKit.nightTint(const Color(0xFFF5C542), night).withValues(alpha: 0.7)
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(x + width / 2 + 2, top + 6), Offset(x + width / 2 + 2, ground), ladder);
      // Gece lambaları
      if (night > 0.4) {
        final glow = Paint()
          ..color = Palette.lamp
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        var i = 0;
        for (var y = top + 18; y < ground - 8; y += 26, i++) {
          final blink = 0.6 + 0.4 * sin(time * 2.2 + i + x);
          canvas.drawCircle(Offset(x - width / 2 - 4, y - 2), 3 * blink, glow);
          canvas.drawCircle(Offset(x + width / 2 + 4, y - 2), 3 * blink, glow);
        }
        canvas.drawCircle(
          Offset(x, top - 4),
          2.2,
          Paint()..color = const Color(0xFFFF3B30).withValues(alpha: (sin(time * 3) > 0) ? 1 : 0.3),
        );
      }
    }

    void tank(double x, double width, double height, double delay) {
      final g = grow(delay);
      if (g <= 0) return;
      final top = ground - height * h * g;
      final r = Rect.fromLTRB(x - width / 2, top, x + width / 2, ground);
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            r.centerLeft,
            r.centerRight,
            [
              PaintKit.nightTint(const Color(0xFFE8E4DA), night),
              PaintKit.nightTint(const Color(0xFFB3AEA3), night),
              PaintKit.nightTint(const Color(0xFF6F6B63), night),
            ],
            const [0, 0.5, 1],
          ),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, top), width: width, height: width * 0.22),
        Paint()..color = PaintKit.nightTint(const Color(0xFFF2EFE8), night),
      );
      final band = Paint()..color = PaintKit.nightTint(Palette.sunset, night).withValues(alpha: 0.85);
      canvas.drawRect(Rect.fromLTWH(r.left, top + r.height * 0.3, r.width, 3), band);
    }

    void sphereTank(double x, double radius, double delay) {
      final g = grow(delay);
      if (g <= 0) return;
      final c = Offset(x, ground - radius * 1.6 * g);
      final leg = Paint()
        ..color = PaintKit.nightTint(const Color(0xFF5A6068), night)
        ..strokeWidth = 2;
      canvas.drawLine(c + Offset(-radius * 0.7, radius * 0.5), Offset(x - radius * 0.8, ground), leg);
      canvas.drawLine(c + Offset(radius * 0.7, radius * 0.5), Offset(x + radius * 0.8, ground), leg);
      PaintKit.sphere(canvas, c, radius * g, const Color(0xFFE6E2D8), night: night);
    }

    // Gece endüstriyel ışık pusu
    canvas.drawRect(
      Rect.fromLTWH(0, ground - h * 0.6, w, h * 0.6),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, ground - h * 0.6), Offset(0, ground), [
          Colors.transparent,
          Palette.sunset.withValues(alpha: 0.18 * reveal),
        ]),
    );

    // Boru köprüsü (arkada)
    final pipe = Paint()
      ..color = PaintKit.nightTint(const Color(0xFF6B7178), night)
      ..strokeWidth = 2.2;
    final pg = grow(0.3);
    if (pg > 0) {
      for (var i = 0; i < 3; i++) {
        final y = ground - h * 0.12 - i * 5;
        canvas.drawLine(Offset(w * 0.08, y), Offset(w * (0.08 + 0.84 * pg), y), pipe);
      }
    }

    column(w * 0.22, 26, 0.5, 0.0);
    column(w * 0.32, 20, 0.4, 0.08);
    column(w * 0.40, 16, 0.32, 0.14);
    tank(w * 0.56, 46, 0.14, 0.2);
    tank(w * 0.68, 40, 0.12, 0.26);
    sphereTank(w * 0.82, 22, 0.32);

    // Meşale (flare) bacası ve alevi
    final fg = grow(0.1);
    if (fg > 0) {
      final fx = w * 0.92;
      final ftop = ground - h * 0.62 * fg;
      canvas.drawLine(
        Offset(fx, ground),
        Offset(fx, ftop),
        Paint()
          ..color = PaintKit.nightTint(const Color(0xFF8A9199), night)
          ..strokeWidth = 3,
      );
      if (fg >= 1) {
        final f = 0.85 + 0.15 * sin(time * 11) + 0.08 * sin(time * 23);
        canvas.drawCircle(
          Offset(fx, ftop - 12),
          60,
          Paint()
            ..shader = ui.Gradient.radial(Offset(fx, ftop - 12), 60, [
              Palette.sunset.withValues(alpha: 0.35 * night),
              Colors.transparent,
            ]),
        );
        final flame = Path()
          ..moveTo(fx - 6 * f, ftop)
          ..quadraticBezierTo(fx - 9 * f, ftop - 18 * f, fx + sin(time * 7) * 3, ftop - 34 * f)
          ..quadraticBezierTo(fx + 9 * f, ftop - 16 * f, fx + 6 * f, ftop)
          ..close();
        canvas.drawPath(
          flame,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(fx, ftop),
              Offset(fx, ftop - 34),
              [Palette.lamp, Palette.sunset, const Color(0x00F07A2A)],
              const [0, 0.5, 1],
            ),
        );
      }
    }

    // Su birikintisinde yansıma (gece)
    if (night > 0.4) {
      canvas.drawRect(
        Rect.fromLTWH(0, ground + 4, w, h - ground),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, ground), Offset(0, h), [
            Palette.lamp.withValues(alpha: 0.12 * night),
            Colors.transparent,
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(RefineryPainter old) => old.time != time || old.reveal != reveal || old.night != night;
}

/// Köyden şehre: kerpiç evlerden çok katlı binalara büyüyen silüet.
class CityGrowthPainter extends CustomPainter {
  CityGrowthPainter({required this.growth, required this.time, this.night = 0.6});

  /// 0 = İluh köyü, 1 = bugünkü Batman.
  final double growth;
  final double time;
  final double night;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.86;
    final rng = Random(11);

    canvas.drawRect(
      Rect.fromLTWH(0, ground, w, h - ground),
      Paint()..color = PaintKit.nightTint(const Color(0xFF5A4232), night),
    );

    // Arka sıra uzak binalar, ön sıra yakın binalar
    for (var row = 0; row < 2; row++) {
      final count = row == 0 ? 16 : 11;
      for (var i = 0; i < count; i++) {
        final delay = rng.nextDouble() * 0.6;
        final g = Curves.easeOutCubic.transform(((growth - delay) / 0.4).clamp(0.0, 1.0));
        final bw = (row == 0 ? 18.0 : 26.0) + rng.nextDouble() * 14;
        final x = (i + 0.2 * rng.nextDouble()) * w / count;
        final village = 8 + rng.nextDouble() * 6; // kerpiç ev
        final city = (row == 0 ? 60.0 : 40.0) + rng.nextDouble() * (row == 0 ? 120 : 90);
        final bh = village + (city - village) * g;
        final r = Rect.fromLTWH(x, ground - bh - (row == 0 ? 6 : 0), bw, bh);
        final mud = const Color(0xFFB08A62);
        final concrete = row == 0 ? const Color(0xFF8C8F94) : const Color(0xFFCFC6B8);
        final base = Color.lerp(mud, concrete, g)!;
        final c = PaintKit.nightTint(Color.lerp(base, Colors.black, row == 0 ? 0.25 : 0)!, night);
        canvas.drawRect(
          r,
          Paint()
            ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [
              Color.lerp(c, Colors.white, 0.1)!,
              Color.lerp(c, Colors.black, 0.2)!,
            ]),
        );
        // Pencereler: büyüdükçe artar, gece tek tek yanar
        if (g > 0.3) {
          final lit = Paint()..color = Palette.lamp.withValues(alpha: night > 0.3 ? 0.9 : 0.25);
          final dark = Paint()..color = Colors.black.withValues(alpha: 0.3);
          for (var wy = r.top + 5; wy < r.bottom - 6; wy += 7) {
            for (var wx = r.left + 3; wx < r.right - 4; wx += 6) {
              final on = rng.nextDouble() < 0.55 && (rng.nextDouble() < growth);
              canvas.drawRect(Rect.fromLTWH(wx, wy, 2.6, 3.2), on ? lit : dark);
            }
          }
        }
      }
    }

    // Minareler
    for (final mx in [w * 0.3, w * 0.72]) {
      final mh = 30 + 70 * growth;
      final m = Paint()..color = PaintKit.nightTint(const Color(0xFFEDE6D8), night);
      canvas.drawRect(Rect.fromLTWH(mx, ground - mh, 5, mh), m);
      canvas.drawPath(
        Path()
          ..moveTo(mx - 1, ground - mh)
          ..lineTo(mx + 2.5, ground - mh - 12)
          ..lineTo(mx + 6, ground - mh)
          ..close(),
        m,
      );
      canvas.drawRect(Rect.fromLTWH(mx - 1.5, ground - mh * 0.7, 8, 2), m);
    }

    // Sokak lambaları
    if (night > 0.3) {
      for (var i = 0; i < 9; i++) {
        final x = (i + 0.5) * w / 9;
        canvas.drawCircle(
          Offset(x, ground - 2),
          10,
          Paint()
            ..shader = ui.Gradient.radial(Offset(x, ground - 2), 10, [
              Palette.lamp.withValues(alpha: 0.5 * growth),
              Colors.transparent,
            ]),
        );
      }
    }
  }

  @override
  bool shouldRepaint(CityGrowthPainter old) => old.growth != growth || old.night != night;
}

/// Taş kemer köprü (Malabadi'den esinli) ve altından akan çay.
class BridgePainter extends CustomPainter {
  BridgePainter(this.time);
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Su
    final water = Rect.fromLTWH(0, h * 0.7, w, h * 0.3);
    canvas.drawRect(
      water,
      Paint()
        ..shader = ui.Gradient.linear(water.topCenter, water.bottomCenter, [
          const Color(0xFF3D8BC9),
          const Color(0xFF1E4F7A),
        ]),
    );
    final shimmer = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final x = ((time * 12 + i * 23) % (w + 20)) - 10;
      canvas.drawLine(Offset(x, h * 0.8 + i % 3 * 4), Offset(x + 8, h * 0.8 + i % 3 * 4), shimmer);
    }
    // Kemer
    final stone = Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.2), Offset(0, h * 0.75), [
        const Color(0xFFD9B98C),
        const Color(0xFF9C7A52),
      ]);
    final bridge = Path()
      ..moveTo(0, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.12, w, h * 0.42)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.86, h * 0.75)
      ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.14, h * 0.75)
      ..lineTo(0, h * 0.75)
      ..close();
    canvas.drawPath(bridge, stone);
    // Taş örgü çizgileri
    final joint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 9; i++) {
      final t = i / 9;
      final outer = Offset(w * t, h * 0.42 - sin(pi * t) * h * 0.3 * 0.75);
      final inner = Offset(w * (0.14 + 0.72 * t), h * 0.75 - sin(pi * t) * h * 0.57 * 0.95);
      canvas.drawLine(outer, inner, joint);
    }
  }

  @override
  bool shouldRepaint(BridgePainter old) => old.time != time;
}

/// Kayalık yamaç, mağara ağızları ve minare (Hasankeyf'ten esinli).
class CliffTownPainter extends CustomPainter {
  const CliffTownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cliff = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.3)
      ..lineTo(w * 0.25, h * 0.22)
      ..lineTo(w * 0.55, h * 0.35)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      cliff,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), [const Color(0xFFE0C79A), const Color(0xFF9C7A52)]),
    );
    final cave = Paint()..color = const Color(0xFF3B2A1C);
    final rng = Random(5);
    for (var i = 0; i < 9; i++) {
      final x = w * (0.05 + rng.nextDouble() * 0.55);
      final y = h * (0.4 + rng.nextDouble() * 0.35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 6, height: 7), const Radius.circular(3)),
        cave,
      );
    }
    // Minare
    final m = Paint()..color = const Color(0xFFC9A877);
    canvas.drawRect(Rect.fromLTWH(w * 0.78, h * 0.18, 7, h * 0.46), m);
    canvas.drawRect(Rect.fromLTWH(w * 0.78 - 2, h * 0.3, 11, 3), m);
    // Dicle
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14), Paint()..color = const Color(0xFF3D8BC9));
  }

  @override
  bool shouldRepaint(CliffTownPainter old) => false;
}
