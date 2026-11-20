import 'dart:math';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

/// Ekranın üstünde "+1 varil" gibi yükselen yazılar ve parçacık patlamaları
/// gösteren katman. Herhangi bir widget `EffectLayer.of(context)` ile erişir.
class EffectLayer extends StatefulWidget {
  const EffectLayer({super.key, required this.child});
  final Widget child;

  static EffectLayerState? maybeOf(BuildContext context) => context.findAncestorStateOfType<EffectLayerState>();

  @override
  State<EffectLayer> createState() => EffectLayerState();
}

class EffectLayerState extends State<EffectLayer> {
  final _effects = <Key, Widget>{};
  int _seq = 0;

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  void _add(Widget Function(Key key, VoidCallback done) builder) {
    final key = ValueKey(_seq++);
    void done() {
      if (mounted) setState(() => _effects.remove(key));
    }

    setState(() => _effects[key] = builder(key, done));
  }

  /// Verilen ekran konumundan yukarı süzülen yazı.
  void floatText(Offset global, String text, {Color color = const Color(0xFFFFD36E)}) {
    final p = _toLocal(global);
    _add((key, done) => Positioned(
          key: key,
          left: p.dx - 80,
          top: p.dy - 20,
          width: 160,
          child: IgnorePointer(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            )
                .animate(onComplete: (_) => done())
                .moveY(begin: 0, end: -70, duration: 900.ms, curve: Curves.easeOut)
                .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.1, 1.1), duration: 250.ms)
                .then()
                .fadeOut(duration: 450.ms),
          ),
        ));
  }

  /// Basit parçacık patlaması.
  void burst(Offset global, {Color color = const Color(0xFF14110F), int count = 14, double spread = 70}) {
    final p = _toLocal(global);
    _add((key, done) => Positioned(
          key: key,
          left: p.dx - spread,
          top: p.dy - spread,
          width: spread * 2,
          height: spread * 2,
          child: IgnorePointer(child: ParticleBurst(color: color, count: count, onDone: done)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [widget.child, ..._effects.values]);
  }
}

class ParticleBurst extends StatefulWidget {
  const ParticleBurst({super.key, required this.color, this.count = 14, this.onDone});
  final Color color;
  final int count;
  final VoidCallback? onDone;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<(double angle, double speed, double size)> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(
      widget.count,
      (_) => (rng.nextDouble() * 2 * pi, 0.5 + rng.nextDouble() * 0.5, 3 + rng.nextDouble() * 4),
    );
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _BurstPainter(_c.value, _particles, widget.color)),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.particles, this.color);
  final double t;
  final List<(double, double, double)> particles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ease = Curves.easeOut.transform(t);
    final paint = Paint()..color = color.withValues(alpha: (1 - t).clamp(0, 1));
    for (final (angle, speed, s) in particles) {
      final d = r * speed * ease;
      final pos = c + Offset(cos(angle) * d, sin(angle) * d + 20 * t * t);
      canvas.drawCircle(pos, s * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
