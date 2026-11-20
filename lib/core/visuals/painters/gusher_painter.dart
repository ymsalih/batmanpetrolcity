import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';

/// Petrol fışkırması: yerçekimine uyan siyah damlacıklar. Durumsuzdur;
/// [t] (saniye) ile her kare yeniden hesaplanır.
class GusherPainter extends CustomPainter {
  GusherPainter({required this.t, required this.origin, this.intensity = 1});

  final double t;

  /// Fışkırmanın çıkış noktası (0..1 göreli).
  final Offset origin;
  final double intensity;

  static const _count = 90;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(origin.dx * size.width, origin.dy * size.height);
    final g = size.height * 1.6;
    final rng = Random(7);
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final life = 0.9 + rng.nextDouble() * 0.6;
      final offset = rng.nextDouble() * life;
      final vx = (rng.nextDouble() - 0.5) * size.width * 0.5;
      final vy = -size.height * (1.0 + rng.nextDouble() * 0.5) * intensity;
      final radius = 2.0 + rng.nextDouble() * 4;
      final local = (t + offset) % life;
      final pos = o + Offset(vx * local, vy * local + 0.5 * g * local * local);
      if (pos.dy > o.dy + 4) continue;
      final sheen = rng.nextDouble() < 0.2;
      paint.color = (sheen ? Palette.oilSheen : Palette.oil).withValues(alpha: 0.9);
      canvas.drawCircle(pos, radius, paint);
    }
    // Kuyu ağzındaki kabarcık
    canvas.drawOval(Rect.fromCenter(center: o, width: size.width * 0.18, height: size.height * 0.05),
        Paint()..color = Palette.oil);
  }

  @override
  bool shouldRepaint(GusherPainter old) => old.t != t;
}
