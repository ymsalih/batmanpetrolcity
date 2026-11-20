import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/ui/premium.dart';
import '../../core/visuals/landscape.dart';
import '../../core/visuals/painters/derrick_painter.dart';
import 'cinematic.dart';

/// Açılış kapısı. İlk açılışta (veya oyuncu ayarlardan isterse) Batman'ın
/// petrol tarihini anlatan sinematiği gösterir; sonraki açılışlarda kısa,
/// amblemli bir açılış ekranı gösterir. Oyun arkada yüklenir.
class IntroGate extends ConsumerStatefulWidget {
  const IntroGate({super.key, required this.child, this.duration = const Duration(milliseconds: 3200)});
  final Widget child;
  final Duration duration;

  @override
  ConsumerState<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends ConsumerState<IntroGate> {
  bool _closing = false;
  bool _gone = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  void _close() {
    if (_closing || !mounted) return;
    _timer?.cancel();
    setState(() => _closing = true);
  }

  void _cinematicDone() {
    final ctrl = ref.read(gameControllerProvider.notifier);
    ctrl.setIntroSeen(true);
    ctrl.save();
    // Sinematikten sonra kısa açılış tekrar gösterilmez.
    setState(() {
      _closing = true;
      _gone = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(gameControllerProvider.select((s) => s.introSeen));
    return Stack(
      children: [
        widget.child,
        if (!seen)
          Positioned.fill(child: CinematicIntro(onDone: _cinematicDone))
        else if (!_gone)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _closing ? 0 : 1,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              onEnd: () => setState(() => _gone = true),
              child: GestureDetector(onTap: _close, child: const _IntroScene()),
            ),
          ),
      ],
    );
  }
}

class _IntroScene extends StatelessWidget {
  const _IntroScene();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.oil,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const LandscapeBackdrop(seed: 7),
          // Sinematik karartma
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Color(0x22000000), Color(0xCC0B0907), Color(0xFF0B0907)],
                stops: [0, 0.35, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),
                const SizedBox(width: 150, height: 150, child: CustomPaint(painter: EmblemPainter()))
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .scale(begin: const Offset(0.7, 0.7), duration: 900.ms, curve: Curves.easeOutBack)
                    .then(delay: 300.ms)
                    .shimmer(duration: 1400.ms, color: Colors.white54),
                const SizedBox(height: 22),
                Text(
                  'BATMAN',
                  style: Premium.overline.copyWith(fontSize: 14, letterSpacing: 10, color: Colors.white70),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms).moveY(begin: 10, end: 0),
                const SizedBox(height: 4),
                Premium.goldText('PETROL AĞASI', size: 38, spacing: 2)
                    .animate()
                    .fadeIn(delay: 650.ms, duration: 700.ms)
                    .moveY(begin: 14, end: 0, curve: Curves.easeOutCubic)
                    .then(delay: 200.ms)
                    .shimmer(duration: 1500.ms, color: Colors.white70),
                const SizedBox(height: 10),
                const Text(
                  'Raman\'ın topraklarından petrol imparatorluğuna',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14, letterSpacing: 0.3),
                ).animate().fadeIn(delay: 1100.ms, duration: 700.ms),
                const Spacer(flex: 4),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      color: Palette.gold,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms),
                const SizedBox(height: 14),
                const Text(
                  'Dokun ve başla',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(delay: 1400.ms, duration: 900.ms),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Amblem: altın çerçeveli altıgen, içinde sondaj kulesi ve petrol damlası.
class EmblemPainter extends CustomPainter {
  const EmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    Path hex(double radius) {
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = pi / 6 + i * pi / 3;
        final pt = c + Offset(cos(a), sin(a)) * radius;
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    // Parıltı
    canvas.drawCircle(
      c,
      r * 1.05,
      Paint()
        ..color = Palette.gold.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    // Altın çerçeve
    canvas.drawPath(
      hex(r),
      Paint()
        ..shader = ui.Gradient.linear(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), Premium.gold, const [0, 0.5, 1]),
    );
    // İç zemin: gece petrol sahası
    final inner = hex(r * 0.86);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = ui.Gradient.linear(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), const [
          Color(0xFF2B1D14),
          Color(0xFF120D0A),
        ]),
    );
    canvas.save();
    canvas.clipPath(inner);
    // Ufuk ışığı
    canvas.drawCircle(
      Offset(c.dx, c.dy + r * 0.45),
      r * 0.9,
      Paint()
        ..shader = ui.Gradient.radial(Offset(c.dx, c.dy + r * 0.45), r * 0.9, [
          Palette.sunset.withValues(alpha: 0.55),
          Colors.transparent,
        ]),
    );
    DerrickPainter.drawDerrick(
      canvas,
      Rect.fromCenter(center: Offset(c.dx - r * 0.12, c.dy + r * 0.05), width: r * 0.8, height: r * 1.2),
      lightsOn: true,
      night: 0.6,
      drilling: false,
      withSite: false,
    );
    canvas.restore();

    // Petrol damlası (sağ alt)
    final dc = Offset(c.dx + r * 0.42, c.dy + r * 0.18);
    final dr = r * 0.2;
    final drop = Path()
      ..moveTo(dc.dx, dc.dy - dr * 1.8)
      ..quadraticBezierTo(dc.dx + dr * 1.1, dc.dy - dr * 0.3, dc.dx + dr, dc.dy + dr * 0.2)
      ..arcToPoint(Offset(dc.dx - dr, dc.dy + dr * 0.2), radius: Radius.circular(dr), clockwise: true)
      ..quadraticBezierTo(dc.dx - dr * 1.1, dc.dy - dr * 0.3, dc.dx, dc.dy - dr * 1.8)
      ..close();
    canvas.drawPath(
      drop,
      Paint()
        ..shader = ui.Gradient.radial(dc + Offset(-dr * 0.3, -dr * 0.2), dr * 1.6, const [
          Color(0xFF4A4038),
          Color(0xFF0A0807),
        ]),
    );
    canvas.drawCircle(
      dc + Offset(-dr * 0.35, -dr * 0.1),
      dr * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawPath(
      drop,
      Paint()
        ..color = Palette.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(EmblemPainter old) => false;
}
