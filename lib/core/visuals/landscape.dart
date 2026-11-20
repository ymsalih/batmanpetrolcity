import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import 'day_night.dart';
import 'painters/paint_kit.dart';
import 'shaders.dart';

/// Saha ekranının üst bandı: shader gökyüzü + atmosferik perspektifli
/// katmanlı tepeler (paralaks) + süzülen kuşlar + uzaktaki kuleler.
class LandscapeBackdrop extends ConsumerStatefulWidget {
  const LandscapeBackdrop({super.key, this.parallax = 0, this.seed = 0});

  /// -1..1 yatay kaydırma (paralaks için).
  final double parallax;
  final int seed;

  @override
  ConsumerState<LandscapeBackdrop> createState() => _LandscapeBackdropState();
}

class _LandscapeBackdropState extends ConsumerState<LandscapeBackdrop> with SingleTickerProviderStateMixin, TimeTicker {
  @override
  Widget build(BuildContext context) {
    final dn = ref.watch(dayNightProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        const SkyView(),
        RepaintBoundary(
          child: CustomPaint(
            painter: _HillsPainter(dn: dn, time: seconds, parallax: widget.parallax, seed: widget.seed),
          ),
        ),
      ],
    );
  }
}

class _HillsPainter extends CustomPainter {
  _HillsPainter({required this.dn, required this.time, required this.parallax, required this.seed});

  final DayNight dn;
  final double time;
  final double parallax;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final haze = dn.skyBottom;

    // Üç katman: uzak (soluk, puslu) → yakın (koyu, doygun).
    final layers = [
      (base: 0.62, amp: 0.30, color: const Color(0xFF7A6250), mix: 0.45, speed: 0.15, freq: 1.2),
      (base: 0.78, amp: 0.18, color: const Color(0xFF6B5240), mix: 0.22, speed: 0.4, freq: 2.1),
      (base: 0.92, amp: 0.10, color: const Color(0xFF5A4232), mix: 0.06, speed: 0.8, freq: 3.4),
    ];
    for (var li = 0; li < layers.length; li++) {
      final l = layers[li];
      final shift = parallax * 30 * l.speed;
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 8; x += 6) {
        final xx = (x + shift) / w * l.freq * 2 * pi + seed + li * 3.1;
        final y = h * l.base - h * l.amp * (0.55 + 0.3 * sin(xx) + 0.15 * sin(xx * 2.7 + 1.3)).abs();
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      final c = Color.lerp(dn.shade(l.color), haze, l.mix * (1 - dn.night * 0.4))!;
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, h * (l.base - l.amp)), Offset(0, h), [
            c,
            Color.lerp(c, Colors.black, 0.2)!,
          ]),
      );

      // Orta katmanda uzak at kafası silüetleri
      if (li == 1) _paintDistantRigs(canvas, size, shift, c);
    }

    // Kuşlar (gündüz), sürü halinde süzülür
    if (dn.night < 0.5) {
      final bird = Paint()
        ..color = Colors.black.withValues(alpha: 0.55 * (1 - dn.night * 2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final fx = ((time * 0.025 + i * 0.07 + seed * 0.13) % 1.3) - 0.15;
        final p = Offset(fx * w + i * 9, h * (0.25 + 0.06 * sin(i * 1.7)) + sin(time * 0.8 + i) * 3);
        final flap = sin(time * 7 + i * 1.3) * 2.5;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - 5, p.dy - flap)
            ..quadraticBezierTo(p.dx - 2, p.dy - 1, p.dx, p.dy)
            ..quadraticBezierTo(p.dx + 2, p.dy - 1, p.dx + 5, p.dy - flap),
          bird,
        );
      }
    }
  }

  void _paintDistantRigs(Canvas canvas, Size size, double shift, Color hill) {
    final rng = Random(seed + 9);
    final c = Color.lerp(hill, Colors.black, 0.35)!;
    for (var i = 0; i < 3; i++) {
      final x = (rng.nextDouble() * size.width + shift) % size.width;
      final y = size.height * (0.70 + rng.nextDouble() * 0.06);
      final s = 0.12 + rng.nextDouble() * 0.06;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s);
      // Uzak at kafası: sallanan silüet
      final tilt = 0.2 * sin(time * 2.4 + i * 2);
      final p = Paint()..color = c;
      canvas.drawPath(
        Path()
          ..moveTo(-12, 0)
          ..lineTo(0, -40)
          ..lineTo(12, 0)
          ..close(),
        p,
      );
      canvas.save();
      canvas.translate(0, -40);
      canvas.rotate(tilt);
      canvas.drawRect(const Rect.fromLTWH(-45, -4, 80, 7), p);
      canvas.drawPath(
        Path()
          ..moveTo(-45, -6)
          ..quadraticBezierTo(-60, 4, -45, 18)
          ..lineTo(-40, 0)
          ..close(),
        p,
      );
      canvas.restore();
      canvas.restore();
      if (dn.lightsOn) {
        canvas.drawCircle(Offset(x, y - 40 * s - 3), 1.4, Paint()..color = Palette.lamp);
      }
    }
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.time != time || old.dn.phase != dn.phase || old.parallax != parallax;
}

/// Toprak zemin üzerinde gezinen bulut gölgeleri (gündüz).
class CloudShadowPainter extends CustomPainter {
  CloudShadowPainter({required this.time, required this.night, this.top = 0});
  final double time;
  final double night;

  /// Gölgelerin başladığı göreli yükseklik (üstü gökyüzü).
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    if (night > 0.7) return;
    final rng = Random(4);
    for (var i = 0; i < 4; i++) {
      final speed = 6 + rng.nextDouble() * 6;
      final w = size.width * (0.3 + rng.nextDouble() * 0.3);
      final x = ((time * speed + rng.nextDouble() * size.width * 2) % (size.width + w * 2)) - w;
      final y = size.height * (top + 0.1 + rng.nextDouble() * (0.9 - top));
      PaintKit.softShadow(
        canvas,
        Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.45),
        opacity: 0.12 * (1 - night),
        blur: 30,
      );
    }
  }

  @override
  bool shouldRepaint(CloudShadowPainter old) => old.time != time;
}
