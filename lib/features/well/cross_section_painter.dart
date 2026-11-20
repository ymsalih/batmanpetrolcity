import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/utils/format.dart';
import '../../core/visuals/painters/derrick_painter.dart';

/// Sondajın yer altı kesiti: gökyüzü + kule, jeolojik katmanlar, inen matkap.
class CrossSectionPainter extends CustomPainter {
  CrossSectionPainter({
    required this.progress,
    required this.layers,
    required this.targetDepthM,
    required this.time,
    required this.skyTop,
    required this.skyBottom,
    this.outcome,
    this.lightsOn = false,
  });

  final double progress;
  final List<GeoLayer> layers;
  final int targetDepthM;

  /// Saniye cinsinden animasyon zamanı.
  final double time;
  final Color skyTop;
  final Color skyBottom;

  /// null: bilinmiyor, true: petrol, false: kuru.
  final bool? outcome;
  final bool lightsOn;

  static const surfaceFraction = 0.22;

  /// Rezervuar katmanının ortası, matkabın hedefi (0..1 yeraltı oranı).
  double get _targetFraction {
    final total = layers.fold(0.0, (a, l) => a + l.thickness);
    final last = layers.last.thickness / total;
    return 1 - last * 0.5;
  }

  /// Verilen ilerlemedeki katmanın adı.
  static String layerAt(List<GeoLayer> layers, double progress) {
    final total = layers.fold(0.0, (a, l) => a + l.thickness);
    final last = layers.last.thickness / total;
    final f = progress * (1 - last * 0.5);
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
    final undergroundH = h - surfaceY;

    // Gökyüzü
    final skyRect = Rect.fromLTWH(0, 0, w, surfaceY);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyBottom],
        ).createShader(skyRect),
    );
    // Uzakta Raman Dağı silüeti
    final hills = Path()..moveTo(0, surfaceY);
    for (var i = 0; i <= 8; i++) {
      final x = w * i / 8;
      final y = surfaceY - h * (0.03 + 0.04 * sin(i * 1.7) * sin(i * 0.9).abs());
      hills.lineTo(x, y);
    }
    hills
      ..lineTo(w, surfaceY)
      ..close();
    canvas.drawPath(hills, Paint()..color = Color.lerp(Palette.mountain, skyBottom, 0.45)!);

    // Katmanlar
    final total = layers.fold(0.0, (a, l) => a + l.thickness);
    var y = surfaceY;
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final lh = undergroundH * layer.thickness / total;
      final rect = Rect.fromLTWH(0, y, w, lh);
      _paintLayer(canvas, rect, layer, i);
      _label(canvas, layer.name, Offset(8, y + 6), Colors.white.withValues(alpha: 0.75), 11);
      y += lh;
    }

    // Derinlik cetveli
    final targetY = surfaceY + undergroundH * _targetFraction;
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

    // Kuyu deliği, boru ve matkap ucu
    final cx = w * 0.5;
    final drillY = surfaceY + (targetY - surfaceY) * progress.clamp(0, 1);
    final holeW = w * 0.045;
    canvas.drawRect(
      Rect.fromLTRB(cx - holeW / 2, surfaceY, cx + holeW / 2, drillY),
      Paint()..color = const Color(0xFF1E1813),
    );
    canvas.drawRect(
      Rect.fromLTRB(cx - holeW * 0.18, surfaceY - h * 0.02, cx + holeW * 0.18, drillY - holeW * 0.4),
      Paint()..color = Palette.steelLight,
    );
    // Boru ekleri
    final joint = Paint()..color = Palette.steel;
    for (var jy = surfaceY + 20.0; jy < drillY - 10; jy += 28) {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, jy), width: holeW * 0.5, height: 3), joint);
    }
    _paintBit(canvas, Offset(cx, drillY), holeW);

    // Sondaj sırasında matkap etrafında toz
    if (outcome == null && progress > 0 && progress < 1) {
      final rng = Random((time * 12).floor());
      final dust = Paint()..color = Colors.white.withValues(alpha: 0.35);
      for (var i = 0; i < 8; i++) {
        canvas.drawCircle(
          Offset(cx + (rng.nextDouble() - 0.5) * holeW * 3, drillY - rng.nextDouble() * holeW * 1.5),
          1 + rng.nextDouble() * 1.5,
          dust,
        );
      }
    }

    // Yüzey ve kule
    canvas.drawRect(Rect.fromLTWH(0, surfaceY - 3, w, 4), Paint()..color = const Color(0xFF5E7D2F));
    final derrickH = surfaceY * 0.78;
    DerrickPainter.drawDerrick(
      canvas,
      Rect.fromLTWH(cx - derrickH * 0.32, surfaceY - derrickH, derrickH * 0.64, derrickH),
      spin: outcome == null ? time * 2 : 0,
      lightsOn: lightsOn,
    );
  }

  void _paintBit(Canvas canvas, Offset tip, double holeW) {
    final bw = holeW * 0.9;
    final bit = Path()
      ..moveTo(tip.dx - bw / 2, tip.dy - bw * 0.7)
      ..lineTo(tip.dx + bw / 2, tip.dy - bw * 0.7)
      ..lineTo(tip.dx + bw * 0.25, tip.dy)
      ..lineTo(tip.dx - bw * 0.25, tip.dy)
      ..close();
    canvas.drawPath(bit, Paint()..color = Palette.gold);
    // Dönen dişler
    final teeth = Paint()..color = Palette.steel;
    final phase = (time * 6) % 1;
    for (var i = 0; i < 3; i++) {
      final x = tip.dx - bw / 2 + bw * ((i / 3 + phase / 3) % 1);
      canvas.drawRect(Rect.fromLTWH(x, tip.dy - bw * 0.55, bw * 0.12, bw * 0.4), teeth);
    }
  }

  void _paintLayer(Canvas canvas, Rect rect, GeoLayer layer, int index) {
    final rng = Random(index * 97 + 13);
    canvas.drawRect(rect, Paint()..color = layer.color);
    final darker = Color.lerp(layer.color, Colors.black, 0.25)!;
    final lighter = Color.lerp(layer.color, Colors.white, 0.18)!;

    switch (layer.pattern) {
      case GeoPattern.soil:
        final p = Paint();
        for (var i = 0; i < 120; i++) {
          p.color = rng.nextBool() ? darker : lighter;
          canvas.drawCircle(
            Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height),
            0.8 + rng.nextDouble() * 2,
            p,
          );
        }
      case GeoPattern.clay:
        final p = Paint()
          ..color = darker
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        for (var ly = rect.top + 8; ly < rect.bottom; ly += 9) {
          final path = Path()..moveTo(rect.left, ly);
          for (var x = 0.0; x <= rect.width; x += 12) {
            path.lineTo(rect.left + x, ly + sin(x / 18 + ly) * 2.5);
          }
          canvas.drawPath(path, p);
        }
      case GeoPattern.rock:
        final fill = Paint();
        final stroke = Paint()
          ..color = darker
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        for (var i = 0; i < 26; i++) {
          final c = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height);
          final r = 5 + rng.nextDouble() * 10;
          final path = Path();
          const sides = 6;
          for (var s = 0; s < sides; s++) {
            final a = s / sides * 2 * pi + rng.nextDouble() * 0.5;
            final rr = r * (0.7 + rng.nextDouble() * 0.4);
            final pt = c + Offset(cos(a) * rr, sin(a) * rr * 0.7);
            s == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          fill.color = rng.nextBool() ? lighter : layer.color;
          canvas.save();
          canvas.clipRect(rect);
          canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
          canvas.restore();
        }
      case GeoPattern.limestone:
        final p = Paint()
          ..color = darker.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        const bh = 12.0;
        var row = 0;
        for (var by = rect.top; by < rect.bottom; by += bh, row++) {
          canvas.drawLine(Offset(rect.left, by), Offset(rect.right, by), p);
          final offset = row.isEven ? 0.0 : 14.0;
          for (var bx = rect.left + offset; bx < rect.right; bx += 28) {
            canvas.drawLine(Offset(bx, by), Offset(bx, min(by + bh, rect.bottom)), p);
          }
        }
        // Fosil kabukları
        final shell = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < 6; i++) {
          final c = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height);
          canvas.drawArc(Rect.fromCircle(center: c, radius: 4), 0, pi * 1.5, false, shell);
        }
      case GeoPattern.reservoir:
        _paintReservoir(canvas, rect, rng);
    }
  }

  void _paintReservoir(Canvas canvas, Rect rect, Random rng) {
    switch (outcome) {
      case true:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF6E6259));
        final dome = Path()
          ..moveTo(rect.left + rect.width * 0.1, rect.bottom)
          ..quadraticBezierTo(rect.center.dx, rect.top - rect.height * 0.4, rect.right - rect.width * 0.1, rect.bottom)
          ..close();
        canvas.drawPath(dome, Paint()..color = Palette.oil);
        // Parıltı
        final shimmer = 0.5 + 0.5 * sin(time * 3);
        canvas.drawPath(
          Path()
            ..moveTo(rect.left + rect.width * 0.3, rect.bottom - rect.height * 0.25)
            ..quadraticBezierTo(
              rect.center.dx,
              rect.top + rect.height * 0.15,
              rect.right - rect.width * 0.3,
              rect.bottom - rect.height * 0.25,
            ),
          Paint()
            ..color = Palette.oilSheen.withValues(alpha: 0.4 + 0.4 * shimmer)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _label(
          canvas,
          'PETROL',
          Offset(rect.center.dx - 30, rect.bottom - rect.height * 0.45),
          Palette.gold,
          14,
          width: 60,
          align: TextAlign.center,
        );
      case false:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF7C7570));
        final crack = Paint()
          ..color = const Color(0xFF4A4440)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        for (var i = 0; i < 6; i++) {
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
          Offset(rect.center.dx - 30, rect.center.dy - 8),
          Colors.white70,
          14,
          width: 60,
          align: TextAlign.center,
        );
      case null:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF3A332D));
        _label(
          canvas,
          '?',
          Offset(rect.center.dx - 20, rect.center.dy - 14),
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
          shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(CrossSectionPainter old) =>
      old.progress != progress || old.time != time || old.outcome != outcome || old.skyTop != skyTop;
}
