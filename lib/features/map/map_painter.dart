import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/visuals/day_night.dart';

/// Batman'ın stilize haritası: Raman Dağı silüeti, Batman Çayı, Dicle,
/// şehir, yollar ve rafineri. Gece şehir ve rafineri ışıkları yanar.
class MapPainter extends CustomPainter {
  MapPainter({required this.dayNight, required this.unlocked, required this.time, this.skyFromShader = false});

  /// true ise gökyüzü, güneş ve yıldızlar arkadaki shader katmanında çizilir.
  final bool skyFromShader;

  final DayNight dayNight;
  final Set<String> unlocked;

  /// Saniye: ışık titreşimi ve su parıltısı için.
  final double time;

  static const horizon = 0.20;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dn = dayNight;
    final horizonY = h * horizon;

    // Gökyüzü
    final sky = Rect.fromLTWH(0, 0, w, horizonY + 2);
    if (!skyFromShader) {
      canvas.drawRect(
        sky,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [dn.skyTop, dn.skyBottom],
          ).createShader(sky),
      );
    }
    _paintSunMoon(canvas, size, horizonY);

    // Raman Dağı silüeti
    final ridge = Path()..moveTo(0, horizonY);
    const peaks = [0.0, 0.35, 0.55, 0.95, 0.7, 1.0, 0.6, 0.4, 0.75, 0.5, 0.3, 0.2];
    for (var i = 0; i < peaks.length; i++) {
      ridge.lineTo(w * i / (peaks.length - 1), horizonY - h * 0.11 * peaks[i]);
    }
    ridge
      ..lineTo(w, horizonY)
      ..close();
    canvas.drawPath(ridge, Paint()..color = dn.shade(Palette.mountain));
    // Karlı/aydınlık tepeler
    final light = Path()
      ..moveTo(w * 3 / 11 - w * 0.03, horizonY - h * 0.11 * 0.80)
      ..lineTo(w * 3 / 11, horizonY - h * 0.11 * 0.95)
      ..lineTo(w * 3 / 11 + w * 0.035, horizonY - h * 0.11 * 0.78)
      ..close();
    canvas.drawPath(light, Paint()..color = dn.shade(const Color(0xFFB59A80)));
    _text(
      canvas,
      'RAMAN DAĞI',
      Offset(w * 0.18, horizonY - h * 0.045),
      Colors.white.withValues(alpha: 0.7),
      11,
      letterSpacing: 2,
    );

    // Ova
    final land = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    canvas.drawRect(
      land,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [dn.shade(const Color(0xFFC9A273)), dn.shade(const Color(0xFFA77A4C))],
        ).createShader(land),
    );
    final rng = Random(3);
    final field = Paint();
    for (var i = 0; i < 26; i++) {
      field.color = dn.shade(i.isEven ? const Color(0xFFB8925F) : const Color(0xFF9E8A4E)).withValues(alpha: 0.5);
      final r = Rect.fromLTWH(
        rng.nextDouble() * w,
        horizonY + rng.nextDouble() * (h - horizonY),
        30 + rng.nextDouble() * 50,
        18 + rng.nextDouble() * 26,
      );
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate((rng.nextDouble() - 0.5) * 0.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height),
          const Radius.circular(4),
        ),
        field,
      );
      canvas.restore();
    }

    // Dicle (güneyde)
    final tigris = Path()..moveTo(0, h * 0.93);
    for (var x = 0.0; x <= w; x += 10) {
      tigris.lineTo(x, h * 0.93 + sin(x / 50) * 8);
    }
    _paintRiver(canvas, tigris, 22);
    _text(canvas, 'DİCLE', Offset(w * 0.06, h * 0.93 - 26), Colors.white70, 11, letterSpacing: 2);

    // Batman Çayı (kuzeyden güneye)
    final river = Path()..moveTo(w * 0.46, horizonY);
    river.cubicTo(w * 0.40, h * 0.40, w * 0.58, h * 0.55, w * 0.48, h * 0.70);
    river.cubicTo(w * 0.42, h * 0.80, w * 0.52, h * 0.88, w * 0.50, h * 0.93);
    _paintRiver(canvas, river, 9);
    canvas.save();
    canvas.translate(w * 0.43, h * 0.40);
    canvas.rotate(1.25);
    _text(canvas, 'Batman Çayı', Offset.zero, Colors.white70, 11);
    canvas.restore();

    // Yollar: şehirden sahalara
    final city = Offset(w * 0.40, h * 0.58);
    final road = Paint()
      ..color = dn.shade(const Color(0xFF6B5A48))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final s in GameConfig.sites) {
      final p = Offset(s.mapX * w, s.mapY * h);
      final mid = Offset((city.dx + p.dx) / 2, (city.dy + p.dy) / 2 + 20);
      canvas.drawPath(
        Path()
          ..moveTo(city.dx, city.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, p.dx, p.dy),
        road,
      );
    }

    _paintCity(canvas, city, w);

    final refinery = GameConfig.sites.where((s) => s.unlocksRefinery).firstOrNull;
    if (refinery != null) {
      _paintRefinery(canvas, Offset(refinery.mapX * w + 50, refinery.mapY * h - 6), unlocked.contains(refinery.id));
    }
  }

  void _paintSunMoon(Canvas canvas, Size size, double horizonY) {
    final dn = dayNight;
    // Güneş ve ay yay çizerek hareket eder.
    final a = dn.phase * 2 * pi;
    final sun = Offset(size.width * (0.5 - 0.42 * cos(a - pi / 2)), horizonY - horizonY * 0.85 * sin(a - pi / 2));
    final moon = Offset(size.width * (0.5 + 0.42 * cos(a - pi / 2)), horizonY + horizonY * 0.85 * sin(a - pi / 2));
    if (dn.night > 0.3 && !skyFromShader) {
      final rng = Random(11);
      final star = Paint()..color = Colors.white.withValues(alpha: (dn.night - 0.3) * 1.2);
      for (var i = 0; i < 40; i++) {
        final twinkle = 0.6 + 0.4 * sin(time * 2 + i);
        canvas.drawCircle(
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * horizonY),
          0.6 + rng.nextDouble() * twinkle,
          star,
        );
      }
    }
    if (sun.dy < horizonY && !skyFromShader) {
      canvas.drawCircle(
        sun,
        22,
        Paint()
          ..color = Palette.sunsetLight.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(sun, 13, Paint()..color = Color.lerp(const Color(0xFFFFF0B3), Palette.sunset, dn.dusk)!);
    }
    if (moon.dy < horizonY) {
      canvas.drawCircle(moon, 11, Paint()..color = const Color(0xFFF4F1DE));
      canvas.drawCircle(moon + const Offset(4, -3), 10, Paint()..color = dn.skyTop);
    }
  }

  void _paintRiver(Canvas canvas, Path path, double width) {
    final dn = dayNight;
    canvas.drawPath(
      path,
      Paint()
        ..color = dn.shade(const Color(0xFF2E6E9E))
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = dn.shade(Palette.river)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    // Parıltı (gece ışık yansıması)
    final shimmer = Paint()
      ..color = (dn.lightsOn ? Palette.lamp : Colors.white).withValues(alpha: 0.25 + 0.15 * sin(time * 2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, width * 0.2)
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = (time * 20) % 40; d < metric.length; d += 40) {
        canvas.drawPath(metric.extractPath(d, d + 10), shimmer);
      }
    }
  }

  void _paintCity(Canvas canvas, Offset c, double w) {
    final dn = dayNight;
    final rng = Random(5);
    final building = Paint();
    final window = Paint()..color = Palette.lamp.withValues(alpha: dn.lightsOn ? 0.95 : 0.0);
    for (var i = 0; i < 16; i++) {
      final bw = 10.0 + rng.nextDouble() * 10;
      final bh = 12.0 + rng.nextDouble() * 26;
      final x = c.dx - 48 + (i % 8) * 13 + rng.nextDouble() * 4;
      final y = c.dy + (i ~/ 8) * 24;
      final r = Rect.fromLTWH(x, y - bh, bw, bh);
      building.color = dn.shade(Color.lerp(const Color(0xFFE8D8C0), const Color(0xFFB39B80), rng.nextDouble())!);
      canvas.drawRect(r, building);
      if (dn.lightsOn) {
        for (var wy = r.top + 3; wy < r.bottom - 3; wy += 6) {
          if (rng.nextDouble() < 0.6) canvas.drawRect(Rect.fromLTWH(r.left + 2, wy, 2.5, 2.5), window);
          if (rng.nextDouble() < 0.6) canvas.drawRect(Rect.fromLTWH(r.right - 4.5, wy, 2.5, 2.5), window);
        }
      }
    }
    // Minare
    final minaret = Paint()..color = dn.shade(const Color(0xFFF2EADB));
    canvas.drawRect(Rect.fromLTWH(c.dx + 62, c.dy - 40, 4, 40), minaret);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 61, c.dy - 40)
        ..lineTo(c.dx + 64, c.dy - 50)
        ..lineTo(c.dx + 67, c.dy - 40)
        ..close(),
      minaret,
    );
    _text(canvas, 'BATMAN', Offset(c.dx - 38, c.dy + 30), Colors.white, 14, letterSpacing: 3, bold: true);
  }

  void _paintRefinery(Canvas canvas, Offset c, bool active) {
    final dn = dayNight;
    final tank = Paint()..color = dn.shade(const Color(0xFFD8D8D0));
    final steel = Paint()..color = dn.shade(Palette.steelLight);
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(c.dx - 30 + i * 18, c.dy - 14, 15, 14);
      canvas.drawRect(r, tank);
      canvas.drawOval(Rect.fromLTWH(r.left, r.top - 3, r.width, 6), steel);
    }
    // Damıtma kuleleri ve baca
    canvas.drawRect(Rect.fromLTWH(c.dx + 26, c.dy - 34, 7, 34), steel);
    canvas.drawRect(Rect.fromLTWH(c.dx + 36, c.dy - 26, 6, 26), steel);
    canvas.drawRect(Rect.fromLTWH(c.dx + 46, c.dy - 44, 4, 44), steel);
    if (active) {
      // Baca alevi
      final flicker = 0.8 + 0.2 * sin(time * 9);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + 48, c.dy - 50), width: 8 * flicker, height: 14 * flicker),
        Paint()..color = Palette.sunset,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + 48, c.dy - 48), width: 4, height: 8),
        Paint()..color = Palette.lamp,
      );
    }
    if (dn.lightsOn) {
      // Gece ışıkları
      final glow = Paint()
        ..color = Palette.lamp.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      const lights = [
        Offset(-24, -16),
        Offset(-6, -16),
        Offset(12, -16),
        Offset(29, -36),
        Offset(39, -28),
        Offset(48, -46),
        Offset(29, -20),
        Offset(39, -12),
      ];
      for (var i = 0; i < lights.length; i++) {
        final on = active || i.isEven;
        if (!on) continue;
        final blink = 0.6 + 0.4 * sin(time * 3 + i);
        canvas.drawCircle(c + lights[i], 2.4 * blink, glow);
      }
      canvas.drawCircle(
        c + const Offset(15, -10),
        40,
        Paint()
          ..color = Palette.lamp.withValues(alpha: active ? 0.12 : 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double size, {
    double letterSpacing = 0,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          letterSpacing: letterSpacing,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.time != time || old.dayNight.phase != dayNight.phase || old.unlocked.length != unlocked.length;
}
