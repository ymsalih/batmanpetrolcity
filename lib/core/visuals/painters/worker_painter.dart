import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../config/palette.dart';

/// Ekip işçisi portresi. Görünüm (ten, bıyık/sakal, kaş, gözlük) işçinin
/// kimliğinden türetilir; baret rengi görevden, baret şeritleri rütbeden gelir.
class WorkerPainter extends CustomPainter {
  WorkerPainter({required this.seed, required this.helmetColor, this.rank = 0, this.mood = 0, this.blink = 0});

  final int seed;
  final Color helmetColor;
  final int rank;

  /// 0 mutlu, 1 heyecanlı, 2 endişeli, 3 düşünceli.
  final int mood;
  final double blink;

  static const _skins = [Color(0xFFE6B48A), Color(0xFFD69C6E), Color(0xFFB97B51), Color(0xFF9A6240)];
  static const _hair = [Color(0xFF2B1D14), Color(0xFF3B2A1E), Color(0xFF5A4030), Color(0xFF6E6A66)];
  static const _overalls = [Color(0xFF2E5C9A), Color(0xFFE07B28), Color(0xFF3E4A3D), Color(0xFF5B4A7A)];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed * 7919 + 13);
    final skin = _skins[rng.nextInt(_skins.length)];
    final hair = _hair[rng.nextInt(_hair.length)];
    final overall = _overalls[rng.nextInt(_overalls.length)];
    final facial = rng.nextInt(4); // 0 yok, 1 ince bıyık, 2 gür bıyık, 3 sakal
    final glasses = rng.nextDouble() < 0.22;
    final browThick = 0.06 + rng.nextDouble() * 0.05;
    final faceW = 0.92 + rng.nextDouble() * 0.16;

    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final c = Offset(s / 2, s * 0.57);
    final r = s * 0.29;

    // Arka plan: baret renginde yumuşak hale
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s / 2,
      Paint()
        ..shader = ui.Gradient.radial(Offset(s / 2, s * 0.4), s / 2, [
          helmetColor.withValues(alpha: 0.35),
          helmetColor.withValues(alpha: 0.08),
        ]),
    );

    // Tulum ve yaka
    final body = Path()
      ..moveTo(s * 0.12, s)
      ..quadraticBezierTo(s * 0.18, s * 0.8, s / 2, s * 0.8)
      ..quadraticBezierTo(s * 0.82, s * 0.8, s * 0.88, s)
      ..close();
    canvas.drawPath(body, Paint()..color = overall);
    // Reflektör şerit
    canvas.drawRect(
      Rect.fromLTWH(s * 0.14, s * 0.92, s * 0.72, s * 0.035),
      Paint()..color = const Color(0xFFDCE775).withValues(alpha: 0.9),
    );
    // Rütbe yıldızları (yakada)
    final starPaint = Paint()..color = Palette.gold;
    for (var i = 0; i <= rank; i++) {
      final sx = s * 0.5 + (i - rank / 2) * s * 0.075;
      _star(canvas, Offset(sx, s * 0.86), s * 0.028, starPaint);
    }

    // Kulaklar ve yüz
    final ear = Paint()..color = Color.lerp(skin, Colors.black, 0.08)!;
    canvas.drawCircle(c + Offset(-r * faceW, r * 0.05), r * 0.18, ear);
    canvas.drawCircle(c + Offset(r * faceW, r * 0.05), r * 0.18, ear);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2 * faceW, height: r * 2.05),
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.3, -r * 0.3),
          r * 1.4,
          [Color.lerp(skin, Colors.white, 0.12)!, skin, Color.lerp(skin, Colors.black, 0.18)!],
          const [0, 0.6, 1],
        ),
    );

    // Sakal gölgesi / sakal
    if (facial == 3) {
      final beard = Path()
        ..moveTo(c.dx - r * 0.85 * faceW, c.dy + r * 0.05)
        ..quadraticBezierTo(c.dx - r * 0.7, c.dy + r * 1.1, c.dx, c.dy + r * 1.08)
        ..quadraticBezierTo(c.dx + r * 0.7, c.dy + r * 1.1, c.dx + r * 0.85 * faceW, c.dy + r * 0.05)
        ..quadraticBezierTo(c.dx, c.dy + r * 0.55, c.dx - r * 0.85 * faceW, c.dy + r * 0.05)
        ..close();
      canvas.drawPath(beard, Paint()..color = hair.withValues(alpha: 0.85));
    }

    // Gözler
    final eyeY = c.dy - r * 0.1;
    final eyeH = r * 0.16 * (1 - blink.clamp(0.0, 1.0) * 0.9);
    final eye = Paint()..color = const Color(0xFF241A12);
    for (final dx in [-r * 0.38, r * 0.38]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + dx, eyeY), width: r * 0.15, height: eyeH), eye);
    }
    if (glasses) {
      final frame = Paint()
        ..color = const Color(0xFF1C1C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06;
      for (final dx in [-r * 0.38, r * 0.38]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(c.dx + dx, eyeY), width: r * 0.48, height: r * 0.36),
            Radius.circular(r * 0.1),
          ),
          frame,
        );
      }
      canvas.drawLine(Offset(c.dx - r * 0.14, eyeY), Offset(c.dx + r * 0.14, eyeY), frame);
    }

    // Kaşlar
    final brow = Paint()
      ..color = hair
      ..strokeWidth = r * browThick * 1.4
      ..strokeCap = StrokeCap.round;
    final worried = mood == 2 ? 1.0 : 0.0;
    canvas.drawLine(
      Offset(c.dx - r * 0.55, eyeY - r * (0.26 - worried * 0.08)),
      Offset(c.dx - r * 0.2, eyeY - r * (0.31 + worried * 0.06)),
      brow,
    );
    canvas.drawLine(
      Offset(c.dx + r * 0.2, eyeY - r * (0.31 + worried * 0.06)),
      Offset(c.dx + r * 0.55, eyeY - r * (0.26 - worried * 0.08)),
      brow,
    );

    // Burun
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.14), width: r * 0.24, height: r * 0.2),
      Paint()..color = Color.lerp(skin, Colors.black, 0.15)!,
    );

    // Ağız
    final my = c.dy + r * 0.52;
    final mouth = Paint()
      ..color = const Color(0xFF5A2A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case 1:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(c.dx, my), width: r * 0.34, height: r * 0.28),
          Paint()..color = const Color(0xFF5A2A1A),
        );
      case 2:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(c.dx, my + r * 0.12), width: r * 0.46, height: r * 0.24),
          pi,
          pi,
          false,
          mouth,
        );
      default:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(c.dx, my - r * 0.08), width: r * 0.5, height: r * 0.28),
          0.25,
          pi - 0.5,
          false,
          mouth,
        );
    }

    // Bıyık
    if (facial == 1 || facial == 2) {
      final thick = facial == 2 ? 1.0 : 0.55;
      final m = Path()
        ..moveTo(c.dx, c.dy + r * 0.27)
        ..cubicTo(
          c.dx - r * 0.25,
          c.dy + r * 0.2,
          c.dx - r * 0.5,
          c.dy + r * 0.3,
          c.dx - r * 0.55,
          c.dy + r * (0.36 + 0.1 * thick),
        )
        ..cubicTo(
          c.dx - r * 0.35,
          c.dy + r * (0.33 + 0.06 * thick),
          c.dx - r * 0.15,
          c.dy + r * 0.38,
          c.dx,
          c.dy + r * 0.35,
        )
        ..cubicTo(
          c.dx + r * 0.15,
          c.dy + r * 0.38,
          c.dx + r * 0.35,
          c.dy + r * (0.33 + 0.06 * thick),
          c.dx + r * 0.55,
          c.dy + r * (0.36 + 0.1 * thick),
        )
        ..cubicTo(c.dx + r * 0.5, c.dy + r * 0.3, c.dx + r * 0.25, c.dy + r * 0.2, c.dx, c.dy + r * 0.27)
        ..close();
      canvas.drawPath(m, Paint()..color = hair);
    }

    // Baret: kubbe + siperlik + rütbe şeritleri
    final hc = c.translate(0, -r * 0.58);
    final helmetRect = Rect.fromCenter(center: hc, width: r * 2.15 * faceW, height: r * 1.5);
    final dome = Path()
      ..addArc(helmetRect, pi, pi)
      ..close();
    canvas.drawPath(
      dome,
      Paint()
        ..shader = ui.Gradient.linear(helmetRect.topCenter, helmetRect.center, [
          Color.lerp(helmetColor, Colors.white, 0.35)!,
          helmetColor,
        ]),
    );
    canvas.save();
    canvas.clipPath(dome);
    final stripe = Paint()
      ..color = (helmetColor.computeLuminance() > 0.6 ? Palette.sunset : Colors.white).withValues(alpha: 0.85);
    for (var i = 0; i < rank; i++) {
      canvas.drawRect(
        Rect.fromLTWH(helmetRect.left, hc.dy - r * (0.16 + i * 0.13), helmetRect.width, r * 0.06),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: hc, width: r * 2.55 * faceW, height: r * 0.22),
        Radius.circular(r * 0.1),
      ),
      Paint()..color = Color.lerp(helmetColor, Colors.black, 0.18)!,
    );
    // Parlama
    canvas.drawArc(
      Rect.fromCenter(center: hc.translate(-r * 0.25, -r * 0.1), width: r * 1.1, height: r * 0.9),
      pi * 1.1,
      pi * 0.35,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(WorkerPainter old) =>
      old.seed != seed || old.rank != rank || old.mood != mood || old.blink != blink || old.helmetColor != helmetColor;
}
