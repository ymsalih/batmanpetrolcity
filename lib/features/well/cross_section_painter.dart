import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/utils/format.dart';
import '../../core/visuals/painters/derrick_painter.dart';
import '../../core/visuals/painters/paint_kit.dart';
import '../../core/visuals/shaders.dart';

/// Sondajın yer altı kesiti: dalgalı jeolojik katmanlar, derinlikle artan
/// karanlık, muhafaza borusu, dönen üç konili matkap, yukarı akan sondaj
/// çamuru; petrol bulununca kuyuda yükselen petrol sütunu.
///
/// Gökyüzü bu painter'da değil, arkasındaki shader katmanında çizilir.
class CrossSectionPainter extends CustomPainter {
  CrossSectionPainter({
    required this.progress,
    required this.layers,
    required this.targetDepthM,
    required this.time,
    this.outcome,
    this.lightsOn = false,
    this.night = 0,
    this.oilRise = 0,
    this.oilShader,
    this.geoShader,
  });

  final double progress;
  final List<GeoLayer> layers;
  final int targetDepthM;
  final double time;

  /// null: bilinmiyor, true: petrol, false: kuru.
  final bool? outcome;
  final bool lightsOn;
  final double night;

  /// 0..1: petrolün kuyu deliğinde yükselişi.
  final double oilRise;
  final ui.FragmentShader? oilShader;

  /// Gerçekçi kayaç dokuları (geology.frag). Yalnızca 5 katmanlı jeolojide.
  final ui.FragmentShader? geoShader;

  static const surfaceFraction = 0.22;

  static double _targetFraction(List<GeoLayer> layers) {
    final total = layers.fold(0.0, (a, l) => a + l.thickness);
    return 1 - layers.last.thickness / total * 0.5;
  }

  /// Verilen ilerlemedeki katmanın adı.
  static String layerAt(List<GeoLayer> layers, double progress) {
    final total = layers.fold(0.0, (a, l) => a + l.thickness);
    final f = progress * _targetFraction(layers);
    var acc = 0.0;
    for (final l in layers) {
      acc += l.thickness / total;
      if (f <= acc + 1e-6) return l.name;
    }
    return layers.last.name;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final surfaceY = h * surfaceFraction;
    final ugH = h - surfaceY;
    final total = layers.fold(0.0, (a, l) => a + l.thickness);

    // Katman sınırları: dalgalı, katlanmış (antiklinal) çizgiler.
    double boundary(int i, double x) {
      if (i == 0) return surfaceY;
      if (i >= layers.length) return h + 2;
      var acc = 0.0;
      for (var k = 0; k < i; k++) {
        acc += layers[k].thickness / total;
      }
      final base = surfaceY + ugH * acc;
      // Rezervuar tepesi kubbe şeklinde (petrol kapanı)
      final dome = i >= layers.length - 2 ? -ugH * 0.05 * exp(-pow((x / w - 0.5) * 3.2, 2)) : 0.0;
      return base +
          sin(x / w * 2 * pi * 1.3 + i * 1.7) * ugH * 0.012 +
          sin(x / w * 2 * pi * 3.1 + i) * ugH * 0.006 +
          dome;
    }

    Path layerPath(int i) {
      final path = Path()..moveTo(0, boundary(i, 0));
      for (var x = 0.0; x <= w; x += 8) {
        path.lineTo(x, boundary(i, x));
      }
      path.lineTo(w, boundary(i, w));
      for (var x = w; x >= 0; x -= 8) {
        path.lineTo(x, boundary(i + 1, x));
      }
      path.lineTo(0, boundary(i + 1, 0));
      path.close();
      return path;
    }

    final geo = layers.length == 5 ? geoShader : null;
    if (geo != null) {
      var acc = 0.0;
      final cum = <double>[];
      for (var k = 0; k < 4; k++) {
        acc += layers[k].thickness / total;
        cum.add(acc);
      }
      geo
        ..setFloat(0, w)
        ..setFloat(1, h)
        ..setFloat(2, surfaceFraction)
        ..setFloat(3, night)
        ..setFloat(4, cum[0])
        ..setFloat(5, cum[1])
        ..setFloat(6, cum[2])
        ..setFloat(7, cum[3]);
      for (var k = 0; k < 5; k++) {
        geo
          ..setFloat(8 + k * 3, layers[k].color.r)
          ..setFloat(9 + k * 3, layers[k].color.g)
          ..setFloat(10 + k * 3, layers[k].color.b);
      }
      for (var k = 0; k < 5; k++) {
        geo.setFloat(23 + k, layers[k].pattern.index.toDouble());
      }
      canvas.drawRect(Rect.fromLTWH(0, surfaceY - 2, w, h - surfaceY + 2), Paint()..shader = geo);
    }

    for (var i = 0; i < layers.length; i++) {
      final path = layerPath(i);
      final bounds = path.getBounds();
      if (geo != null) {
        // Shader tüm dokuları çizdi; yalnızca rezervuarın durumu üstüne gelir.
        if (layers[i].pattern == GeoPattern.reservoir && outcome != null) {
          canvas.save();
          canvas.clipPath(path);
          _paintReservoir(canvas, bounds, Random(i * 97 + 13), path);
          canvas.restore();
        } else if (layers[i].pattern == GeoPattern.reservoir) {
          _label(
            canvas,
            '?',
            Offset(bounds.center.dx - 140, bounds.center.dy - 8),
            Colors.white38,
            26,
            width: 40,
            align: TextAlign.center,
          );
        }
        _label(canvas, layers[i].name, Offset(8, boundary(i, 10) + 6), Colors.white.withValues(alpha: 0.85), 11);
        continue;
      }
      canvas.save();
      canvas.clipPath(path);
      _paintLayer(canvas, bounds, layers[i], i, path);
      canvas.restore();
      // Sınır çizgisi
      final edge = Path()..moveTo(0, boundary(i + 1, 0));
      for (var x = 0.0; x <= w; x += 8) {
        edge.lineTo(x, boundary(i + 1, x));
      }
      canvas.drawPath(
        edge,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final label = boundary(i, 10);
      _label(canvas, layers[i].name, Offset(8, label + 6), Colors.white.withValues(alpha: 0.8), 11);
    }

    // Derinlikle artan karanlık (ışık yüzeyden gelir; shader'da zaten var)
    final under = Rect.fromLTWH(0, surfaceY, w, ugH);
    if (geo == null) {
      canvas.drawRect(
        under,
        Paint()
          ..shader = ui.Gradient.linear(under.topCenter, under.bottomCenter, [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45 + night * 0.15),
          ]),
      );
    }

    // Derinlik cetveli
    final targetY = surfaceY + ugH * _targetFraction(layers);
    final tick = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    final step = targetDepthM > 1500 ? 500 : 250;
    for (var d = 0; d <= targetDepthM; d += step) {
      final ty = surfaceY + (targetY - surfaceY) * d / targetDepthM;
      canvas.drawLine(Offset(w - 14, ty), Offset(w, ty), tick);
      _label(
        canvas,
        '${Fmt.integer(d)} m',
        Offset(w - 62, ty - 7),
        Colors.white70,
        10,
        width: 46,
        align: TextAlign.right,
      );
    }

    _paintBorehole(canvas, size, surfaceY, targetY);

    // Yüzey: çimen şeridi + toprak kenarı
    canvas.drawRect(
      Rect.fromLTWH(0, surfaceY - 3, w, 5),
      Paint()..color = PaintKit.nightTint(const Color(0xFF6E8A35), night),
    );
    final derrickH = surfaceY * 0.92;
    DerrickPainter.drawDerrick(
      canvas,
      Rect.fromLTWH(w / 2 - derrickH * 0.36, surfaceY - derrickH + 2, derrickH * 0.72, derrickH),
      spin: outcome == null ? (time * 1.6) % 1 : 0,
      time: time,
      lightsOn: lightsOn,
      night: night,
      drilling: outcome == null,
      withSite: true,
    );
  }

  void _paintBorehole(Canvas canvas, Size size, double surfaceY, double targetY) {
    final cx = size.width * 0.5;
    final drillY = surfaceY + (targetY - surfaceY) * progress.clamp(0, 1);
    final holeW = size.width * 0.05;

    // Kuyu deliği (sondaj çamuruyla dolu)
    final hole = Rect.fromLTRB(cx - holeW / 2, surfaceY, cx + holeW / 2, drillY);
    canvas.drawRect(
      hole,
      Paint()
        ..shader = ui.Gradient.linear(
          hole.centerLeft,
          hole.centerRight,
          [const Color(0xFF2A211A), const Color(0xFF4A3B2E), const Color(0xFF2A211A)],
          const [0, 0.5, 1],
        ),
    );
    // Muhafaza borusu (casing): ilk %35
    final casingBottom = surfaceY + (targetY - surfaceY) * 0.35;
    final casing = Paint()
      ..color = const Color(0xFF8E979F)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(hole.left, surfaceY), Offset(hole.left, min(drillY, casingBottom)), casing);
    canvas.drawLine(Offset(hole.right, surfaceY), Offset(hole.right, min(drillY, casingBottom)), casing);
    if (drillY > casingBottom) {
      // Çimento pabucu
      canvas.drawRect(
        Rect.fromLTWH(hole.left - 3, casingBottom - 3, holeW + 6, 4),
        Paint()..color = const Color(0xFFB5ADA0),
      );
    }

    // Petrol yükselişi
    if (outcome == true && oilRise > 0) {
      final top = drillY - (drillY - surfaceY) * oilRise.clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTRB(hole.left + 1, top, hole.right - 1, drillY),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(hole.left, 0),
            Offset(hole.right, 0),
            [const Color(0xFF0B0908), const Color(0xFF3A322B), const Color(0xFF0B0908)],
            const [0, 0.5, 1],
          ),
      );
      // Yükselen gaz kabarcıkları
      final rng = Random(3);
      for (var i = 0; i < 10; i++) {
        final y = drillY - ((time * 140 + rng.nextDouble() * 400) % (drillY - top + 1));
        canvas.drawCircle(
          Offset(cx + (rng.nextDouble() - 0.5) * holeW * 0.6, y),
          1 + rng.nextDouble() * 1.5,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
      }
    }

    // Sondaj dizisi
    final pipe = Rect.fromLTRB(cx - holeW * 0.16, surfaceY - 6, cx + holeW * 0.16, drillY - holeW * 0.7);
    canvas.drawRect(
      pipe,
      Paint()
        ..shader = ui.Gradient.linear(
          pipe.centerLeft,
          pipe.centerRight,
          [const Color(0xFFD9DDE1), const Color(0xFF7D858D), const Color(0xFF4A5157)],
          const [0, 0.5, 1],
        ),
    );
    final joint = Paint()..color = const Color(0xFF5B636A);
    for (var jy = surfaceY + 24.0; jy < drillY - 14; jy += 30) {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, jy), width: holeW * 0.48, height: 4), joint);
    }

    // Halka boşlukta yukarı taşınan kırıntılar (çamur sirkülasyonu)
    if (outcome == null && progress > 0) {
      final rng = Random(11);
      final cut = Paint()..color = const Color(0xFFB59A78).withValues(alpha: 0.7);
      for (var i = 0; i < 22; i++) {
        final side = i.isEven ? -1 : 1;
        final speed = 40 + rng.nextDouble() * 40;
        final span = max(1.0, drillY - surfaceY);
        final y = drillY - ((time * speed + rng.nextDouble() * span) % span);
        canvas.drawCircle(Offset(cx + side * holeW * (0.3 + rng.nextDouble() * 0.12), y), 0.9 + rng.nextDouble(), cut);
      }
    }

    _paintBit(canvas, Offset(cx, drillY), holeW);

    // Matkap etrafında toz/kırıntı
    if (outcome == null && progress > 0 && progress < 1) {
      final rng = Random((time * 14).floor());
      final dust = Paint()..color = Colors.white.withValues(alpha: 0.35);
      for (var i = 0; i < 10; i++) {
        canvas.drawCircle(
          Offset(cx + (rng.nextDouble() - 0.5) * holeW * 3, drillY - rng.nextDouble() * holeW * 1.5),
          0.8 + rng.nextDouble() * 1.6,
          dust,
        );
      }
    }
  }

  /// Üç konili (tricone) matkap ucu: konilerin dişleri döner.
  void _paintBit(Canvas canvas, Offset tip, double holeW) {
    final bw = holeW * 0.95;
    final body = Path()
      ..moveTo(tip.dx - bw * 0.3, tip.dy - bw * 1.1)
      ..lineTo(tip.dx + bw * 0.3, tip.dy - bw * 1.1)
      ..lineTo(tip.dx + bw * 0.5, tip.dy - bw * 0.55)
      ..lineTo(tip.dx - bw * 0.5, tip.dy - bw * 0.55)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tip.dx - bw / 2, 0),
          Offset(tip.dx + bw / 2, 0),
          [const Color(0xFF9A7B2C), Palette.gold, const Color(0xFF7A5E1C)],
          const [0, 0.5, 1],
        ),
    );
    final spin = outcome == null ? time * 9 : 0.0;
    for (var k = -1; k <= 1; k++) {
      final c = Offset(tip.dx + k * bw * 0.3, tip.dy - bw * (k == 0 ? 0.22 : 0.3));
      final r = bw * 0.24;
      PaintKit.sphere(canvas, c, r, const Color(0xFF6D747B));
      final tooth = Paint()..color = const Color(0xFF2E3338);
      for (var i = 0; i < 5; i++) {
        final a = spin * (k.isEven ? 1 : -1) + i * 2 * pi / 5;
        final p = c + Offset(cos(a) * r * 0.75, sin(a) * r * 0.45);
        canvas.drawCircle(p, max(0.8, r * 0.18), tooth);
      }
    }
  }

  void _paintLayer(Canvas canvas, Rect rect, GeoLayer layer, int index, Path clip) {
    final rng = Random(index * 97 + 13);
    final base = PaintKit.nightTint(layer.color, night * 0.5);
    final darker = Color.lerp(base, Colors.black, 0.28)!;
    final lighter = Color.lerp(base, Colors.white, 0.16)!;
    // Taban: hafif dikey gradyan
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [lighter, base, darker], const [0, 0.4, 1]),
    );
    // Tanecik dokusu
    final grain = Paint();
    for (var i = 0; i < 160; i++) {
      grain.color = (rng.nextBool() ? Colors.black : Colors.white).withValues(alpha: 0.06 + rng.nextDouble() * 0.06);
      canvas.drawRect(
        Rect.fromLTWH(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height, 1.4, 1.4),
        grain,
      );
    }

    switch (layer.pattern) {
      case GeoPattern.soil:
        final p = Paint();
        for (var i = 0; i < 140; i++) {
          p.color = (rng.nextBool() ? darker : lighter).withValues(alpha: 0.8);
          canvas.drawCircle(
            Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height),
            0.6 + rng.nextDouble() * 2,
            p,
          );
        }
        // Kökler
        final root = Paint()
          ..color = const Color(0xFF3B2A1C).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9;
        for (var i = 0; i < 12; i++) {
          var pt = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + 2);
          final path = Path()..moveTo(pt.dx, pt.dy);
          for (var j = 0; j < 4; j++) {
            pt += Offset((rng.nextDouble() - 0.5) * 8, 3 + rng.nextDouble() * 5);
            path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, root);
        }
      case GeoPattern.clay:
        final p = Paint()
          ..color = darker.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
        for (var ly = rect.top + 6; ly < rect.bottom; ly += 7) {
          final path = Path()..moveTo(rect.left, ly);
          for (var x = 0.0; x <= rect.width; x += 10) {
            path.lineTo(rect.left + x, ly + sin(x / 22 + ly * 0.3) * 2.2);
          }
          canvas.drawPath(path, p);
        }
      case GeoPattern.rock:
        final stroke = Paint()
          ..color = darker
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (var i = 0; i < 34; i++) {
          final c = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height);
          final r = 4 + rng.nextDouble() * 11;
          final path = Path();
          final sides = 5 + rng.nextInt(3);
          for (var s = 0; s < sides; s++) {
            final a = s / sides * 2 * pi + rng.nextDouble() * 0.5;
            final rr = r * (0.7 + rng.nextDouble() * 0.4);
            final pt = c + Offset(cos(a) * rr, sin(a) * rr * 0.7);
            s == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          final tone = rng.nextDouble();
          canvas.drawPath(
            path,
            Paint()
              ..shader = ui.Gradient.linear(c - Offset(r, r), c + Offset(r, r), [
                Color.lerp(lighter, base, tone)!,
                Color.lerp(base, darker, tone)!,
              ]),
          );
          canvas.drawPath(path, stroke);
        }
      case GeoPattern.limestone:
        final p = Paint()
          ..color = darker.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9;
        const bh = 11.0;
        var row = 0;
        for (var by = rect.top; by < rect.bottom; by += bh, row++) {
          canvas.drawLine(Offset(rect.left, by), Offset(rect.right, by), p);
          final offset = row.isEven ? 0.0 : 13.0;
          for (var bx = rect.left + offset; bx < rect.right; bx += 26 + rng.nextDouble() * 6) {
            canvas.drawLine(Offset(bx, by), Offset(bx, min(by + bh, rect.bottom)), p);
          }
        }
        final shell = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9;
        for (var i = 0; i < 9; i++) {
          final c = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height);
          final r = 2.5 + rng.nextDouble() * 3;
          canvas.drawArc(Rect.fromCircle(center: c, radius: r), 0, pi * 1.6, false, shell);
          canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.5), 0, pi * 1.6, false, shell);
        }
      case GeoPattern.reservoir:
        _paintReservoir(canvas, rect, rng, clip);
    }
  }

  void _paintReservoir(Canvas canvas, Rect rect, Random rng, Path clip) {
    switch (outcome) {
      case true:
        // Gözenekli kumtaşı içinde petrol: shader ile yanardöner yüzey
        paintOilSurface(canvas, clip, rect, oilShader, time);
        final pore = Paint()..color = const Color(0xFF6E6259).withValues(alpha: 0.55);
        for (var i = 0; i < 70; i++) {
          canvas.drawCircle(
            Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height),
            1 + rng.nextDouble() * 2.4,
            pore,
          );
        }
        _label(
          canvas,
          'PETROL',
          Offset(rect.center.dx - 130, rect.center.dy - 2),
          Palette.gold,
          14,
          width: 80,
          align: TextAlign.center,
        );
      case false:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF7C7570));
        final crack = Paint()
          ..color = const Color(0xFF4A4440)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        for (var i = 0; i < 8; i++) {
          var p = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height);
          final path = Path()..moveTo(p.dx, p.dy);
          for (var j = 0; j < 4; j++) {
            p += Offset((rng.nextDouble() - 0.5) * 30, (rng.nextDouble() - 0.3) * 14);
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, crack);
        }
        _label(
          canvas,
          'KURU',
          Offset(rect.center.dx - 130, rect.center.dy - 2),
          Colors.white70,
          14,
          width: 60,
          align: TextAlign.center,
        );
      case null:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF3A332D));
        final pore = Paint()..color = Colors.black.withValues(alpha: 0.25);
        for (var i = 0; i < 60; i++) {
          canvas.drawCircle(
            Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height),
            1 + rng.nextDouble() * 2,
            pore,
          );
        }
        _label(
          canvas,
          '?',
          Offset(rect.center.dx - 20, rect.center.dy - 8),
          Colors.white24,
          26,
          width: 40,
          align: TextAlign.center,
        );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double size, {
    double width = 120,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(CrossSectionPainter old) => true;
}
