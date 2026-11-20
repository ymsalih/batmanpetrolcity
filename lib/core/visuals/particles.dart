import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';

enum ParticleKind { droplet, splash, mist, mud }

class Particle {
  Particle({
    required this.pos,
    required this.vel,
    required this.size,
    required this.life,
    required this.kind,
    required this.color,
  });

  Offset pos;
  Offset vel;
  double size;
  double age = 0;
  final double life;
  final ParticleKind kind;
  final Color color;

  double get t => (age / life).clamp(0.0, 1.0);
}

/// Basit ama fiziksel parçacık simülasyonu: yerçekimi, hava direnci,
/// zemine çarpma ve sıçrama.
class ParticleSim {
  ParticleSim({this.gravity = 900, this.drag = 0.9, this.groundY = double.infinity, int seed = 1}) : rng = Random(seed);

  final double gravity;
  final double drag;
  double groundY;
  final Random rng;
  final particles = <Particle>[];

  /// Zemine düşen petrol hacmi (gölet büyüklüğü için).
  double pooled = 0;

  void add(Particle p) => particles.add(p);

  void update(double dt, {double wind = 0}) {
    final splashes = <Particle>[];
    particles.removeWhere((p) {
      p.age += dt;
      if (p.age >= p.life) return true;
      switch (p.kind) {
        case ParticleKind.mist:
          p.vel = Offset(p.vel.dx + wind * 0.6 * dt, p.vel.dy - 12 * dt);
          p.size += 22 * dt;
        case _:
          p.vel = Offset(p.vel.dx + wind * dt, p.vel.dy + gravity * dt) * pow(1 - drag * 0.1, dt * 10).toDouble();
      }
      p.pos += p.vel * dt;
      if (p.kind != ParticleKind.mist && p.pos.dy >= groundY) {
        pooled += p.size * p.size;
        if (p.kind == ParticleKind.droplet && p.size > 2.4 && p.vel.dy > 120) {
          final n = 2 + rng.nextInt(2);
          for (var i = 0; i < n; i++) {
            splashes.add(
              Particle(
                pos: Offset(p.pos.dx, groundY - 1),
                vel: Offset((rng.nextDouble() - 0.5) * 160, -60 - rng.nextDouble() * 110),
                size: p.size * 0.45,
                life: 0.6,
                kind: ParticleKind.splash,
                color: p.color,
              ),
            );
          }
        }
        return true;
      }
      return false;
    });
    particles.addAll(splashes);
  }
}

/// Petrol fışkırması efekti. İlk anda çamur ve toprak, sonra kesintisiz
/// petrol sütunu; damlalar yere çarpıp sıçrar, kuyu başında gölet büyür.
class GusherEffect extends StatefulWidget {
  const GusherEffect({super.key, this.origin = const Offset(0.5, 0.9), this.groundY = 0.92, this.intensity = 1});

  /// Fışkırmanın çıkış noktası (0..1 göreli).
  final Offset origin;

  /// Zemin çizgisi (0..1 göreli).
  final double groundY;
  final double intensity;

  @override
  State<GusherEffect> createState() => _GusherEffectState();
}

class _GusherEffectState extends State<GusherEffect> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  ParticleSim? _sim;
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _elapsed = 0;
  double _spawnAcc = 0;
  double _mistAcc = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Basınç: önce yüksek, sonra sabit akışa oturur.
  double get _pressure => widget.intensity * (0.85 + 0.45 * exp(-_elapsed / 2.5) + 0.06 * sin(_elapsed * 7));

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = now;
    final sim = _sim;
    if (sim == null || _size.isEmpty) return;
    _elapsed += dt;
    final h = _size.height;
    final o = Offset(widget.origin.dx * _size.width, widget.origin.dy * h);
    final rng = sim.rng;
    final wind = 30 * sin(_elapsed * 0.6);

    _spawnAcc += dt * 320;
    while (_spawnAcc >= 1) {
      _spawnAcc -= 1;
      final mud = _elapsed < 0.7 && rng.nextDouble() < 0.6;
      final speed = h * (2.0 + rng.nextDouble() * 0.5) * _pressure;
      final spread = (rng.nextDouble() - 0.5) * (mud ? 0.5 : 0.18);
      sim.add(
        Particle(
          pos: o + Offset((rng.nextDouble() - 0.5) * 4, 0),
          vel: Offset(sin(spread) * speed, -cos(spread) * speed),
          size: 1.0 + pow(rng.nextDouble(), 2.5) * 4.5,
          life: 3,
          kind: mud ? ParticleKind.mud : ParticleKind.droplet,
          color: mud
              ? Color.lerp(Palette.earth, const Color(0xFF3B2A1C), rng.nextDouble())!
              : Color.lerp(Palette.oil, const Color(0xFF2E2620), rng.nextDouble() * 0.6)!,
        ),
      );
    }
    _mistAcc += dt * 14;
    while (_mistAcc >= 1) {
      _mistAcc -= 1;
      final peak = _peakHeight(h);
      sim.add(
        Particle(
          pos: o + Offset((rng.nextDouble() - 0.5) * 20, -peak * (0.6 + rng.nextDouble() * 0.4)),
          vel: Offset((rng.nextDouble() - 0.5) * 30, -10 - rng.nextDouble() * 15),
          size: 6 + rng.nextDouble() * 8,
          life: 2.2,
          kind: ParticleKind.mist,
          color: const Color(0xFF4A4038),
        ),
      );
    }
    sim.update(dt, wind: wind);
    setState(() {});
  }

  double _peakHeight(double h) {
    final v = h * 2.2 * _pressure;
    return v * v / (2 * h * 2.2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        _sim ??= ParticleSim(gravity: _size.height * 2.2, drag: 0.6, groundY: widget.groundY * _size.height, seed: 7);
        _sim!.groundY = widget.groundY * _size.height;
        return CustomPaint(
          size: _size,
          painter: _GusherPainter(
            sim: _sim!,
            origin: Offset(widget.origin.dx * _size.width, widget.origin.dy * _size.height),
            peak: _peakHeight(_size.height),
            elapsed: _elapsed,
          ),
        );
      },
    );
  }
}

class _GusherPainter extends CustomPainter {
  _GusherPainter({required this.sim, required this.origin, required this.peak, required this.elapsed});

  final ParticleSim sim;
  final Offset origin;
  final double peak;
  final double elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    // Petrol göleti: hacimle büyür, üzerinde gökkuşağı yansıması.
    final poolW = min(size.width * 0.85, 30 + sqrt(sim.pooled) * 1.6);
    final poolRect = Rect.fromCenter(center: Offset(origin.dx, sim.groundY + 2), width: poolW, height: poolW * 0.12);
    canvas.drawOval(
      poolRect,
      Paint()
        ..shader = ui.Gradient.radial(
          poolRect.center,
          poolW / 2,
          [const Color(0xFF0A0807), const Color(0xFF16110E), const Color(0x0016110E)],
          const [0, 0.85, 1],
        ),
    );
    final sheen = Rect.fromCenter(
      center: poolRect.center + Offset(poolW * 0.12, -1),
      width: poolW * 0.5,
      height: poolRect.height * 0.5,
    );
    canvas.drawOval(
      sheen,
      Paint()
        ..shader = ui.Gradient.sweep(
          sheen.center,
          const [Color(0x557B4FA0), Color(0x5546A08C), Color(0x55C9A43A), Color(0x55A04F6E), Color(0x557B4FA0)],
          const [0, 0.25, 0.5, 0.75, 1],
          TileMode.clamp,
          elapsed * 0.4,
          elapsed * 0.4 + 2 * pi,
        ),
    );

    // Sürekli petrol sütunu (çekirdek)
    if (elapsed > 0.2) {
      final wobble = sin(elapsed * 9) * 3;
      final top = origin + Offset(wobble, -peak * 0.92);
      final core = Path()
        ..moveTo(origin.dx - 7, origin.dy)
        ..quadraticBezierTo(origin.dx - 4 + wobble * 0.5, origin.dy - peak * 0.5, top.dx - 2, top.dy)
        ..lineTo(top.dx + 1.5, top.dy)
        ..quadraticBezierTo(origin.dx + 4 + wobble * 0.5, origin.dy - peak * 0.5, origin.dx + 7, origin.dy)
        ..close();
      canvas.drawPath(
        core,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(origin.dx - 7, 0),
            Offset(origin.dx + 7, 0),
            [const Color(0xFF1A1512), const Color(0xFF4A4038), const Color(0xFF0E0B09)],
            const [0, 0.35, 1],
          ),
      );
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final p in sim.particles) {
      switch (p.kind) {
        case ParticleKind.mist:
          canvas.drawCircle(
            p.pos,
            p.size,
            Paint()
              ..color = p.color.withValues(alpha: 0.22 * (1 - p.t))
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.6),
          );
        case _:
          // Hıza göre uzayan damla: hareket bulanıklığı.
          final tail = p.vel * 0.018;
          paint
            ..color = p.color
            ..strokeWidth = p.size;
          canvas.drawLine(p.pos, p.pos - tail, paint);
          if (p.size > 3 && p.kind == ParticleKind.droplet) {
            canvas.drawCircle(
              p.pos + Offset(-p.size * 0.2, -p.size * 0.2),
              p.size * 0.18,
              Paint()..color = Colors.white.withValues(alpha: 0.35),
            );
          }
      }
    }
  }

  @override
  bool shouldRepaint(_GusherPainter old) => true;
}
