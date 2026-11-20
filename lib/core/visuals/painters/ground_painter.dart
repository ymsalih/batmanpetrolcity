import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';

/// Parsel zemini: toprak dokusu, isteğe bağlı kuru kuyu çatlakları.
class GroundPainter extends CustomPainter {
  GroundPainter({this.seed = 0, this.cracked = false, this.night = 0, this.highlight});

  final int seed;
  final bool cracked;
  final double night;

  /// Etüt ipucunu yansıtan hafif renk tonu.
  final Color? highlight;

  Color _shade(Color c) => Color.lerp(c, const Color(0xFF0B0E1C), night * 0.5)!;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = cracked ? const Color(0xFF9A7B5C) : Palette.earth;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(Color.lerp(base, Palette.earthLight, 0.35)!), _shade(base)],
        ).createShader(rect),
    );
    if (highlight != null) {
      canvas.drawRect(rect, Paint()..color = highlight!.withValues(alpha: 0.18));
    }

    final rng = Random(seed);
    final speck = Paint();
    for (var i = 0; i < 40; i++) {
      speck.color = _shade(rng.nextBool() ? Palette.earthLight : const Color(0xFF5C3A20)).withValues(alpha: 0.6);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.8 + rng.nextDouble() * 1.8,
        speck,
      );
    }

    if (cracked) {
      final crack = Paint()
        ..color = _shade(const Color(0xFF4A3424))
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      for (var k = 0; k < 4; k++) {
        var p = Offset(size.width * (0.2 + rng.nextDouble() * 0.6), size.height * (0.2 + rng.nextDouble() * 0.6));
        final path = Path()..moveTo(p.dx, p.dy);
        for (var j = 0; j < 5; j++) {
          p += Offset((rng.nextDouble() - 0.5) * size.width * 0.3, (rng.nextDouble() - 0.5) * size.height * 0.3);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, crack);
      }
    } else {
      // Ot tutamları
      final grass = Paint()
        ..color = _shade(const Color(0xFF7D8F3A))
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final x = rng.nextDouble() * size.width;
        final y = rng.nextDouble() * size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 2, y - 5), grass);
        canvas.drawLine(Offset(x, y), Offset(x + 2, y - 6), grass);
      }
    }
  }

  @override
  bool shouldRepaint(GroundPainter old) =>
      old.seed != seed || old.cracked != cracked || old.night != night || old.highlight != highlight;
}

/// Toprak shader'ının üstüne parsel detayı: sürülmüş tarla izleri, etüt
/// ipucu tonu, kuru kuyu çatlakları ve içe doğru kenar gölgesi.
class PlotOverlayPainter extends CustomPainter {
  PlotOverlayPainter({this.seed = 0, this.cracked = false, this.tilled = true, this.night = 0, this.highlight});

  final int seed;
  final bool cracked;
  final bool tilled;
  final double night;
  final Color? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rng = Random(seed);

    if (highlight != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [highlight!.withValues(alpha: 0.28), highlight!.withValues(alpha: 0.05)])
              .createShader(rect),
      );
    }

    if (tilled) {
      // Sürülmüş toprak sıraları: açık/koyu çift çizgi, hafif eğri.
      final dark = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final light = Paint()
        ..color = Colors.white.withValues(alpha: 0.08 * (1 - night))
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final angle = (rng.nextDouble() - 0.5) * 0.3;
      for (var y = 6.0; y < size.height; y += 7) {
        final path = Path();
        for (var x = 0.0; x <= size.width; x += 6) {
          final yy = y + x * angle + sin(x / 17 + y) * 0.8;
          x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
        }
        canvas.drawPath(path, dark);
        canvas.drawPath(path.shift(const Offset(0, -1.3)), light);
      }
    }

    if (cracked) {
      final crack = Paint()
        ..color = const Color(0xFF3A2A1E).withValues(alpha: 0.75)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 5; k++) {
        var p = Offset(size.width * (0.2 + rng.nextDouble() * 0.6), size.height * (0.2 + rng.nextDouble() * 0.6));
        final path = Path()..moveTo(p.dx, p.dy);
        for (var j = 0; j < 6; j++) {
          p += Offset((rng.nextDouble() - 0.5) * size.width * 0.28, (rng.nextDouble() - 0.5) * size.height * 0.28);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, crack);
      }
    }

    // İçe doğru kenar gölgesi: parsel hafif çukur görünür.
    final edge = Paint()
      ..shader = RadialGradient(
        radius: 0.85,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
        stops: const [0.6, 1],
      ).createShader(rect);
    canvas.drawRect(rect, edge);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.75), const Radius.circular(12)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(PlotOverlayPainter old) =>
      old.seed != seed ||
      old.cracked != cracked ||
      old.tilled != tilled ||
      old.night != night ||
      old.highlight != highlight;
}
