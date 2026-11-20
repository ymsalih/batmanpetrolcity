import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
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

class _LandscapeBackdropState extends ConsumerState<LandscapeBackdrop> with SingleTickerProviderStateMixin {
  /// Gün-gece döngüsü bu kadar dilime bölünür; manzara her dilimde bir kez
  /// çizilir (8 dk'lık günde ~5 sn).
  static const _slices = 96;

  final _slot = ShaderSlot();
  final _cache = ShaderImageCache();
  ui.Image? _previous;
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..value = 1
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _dropPrevious();
    });

  void _dropPrevious() {
    _previous?.dispose();
    _previous = null;
  }

  @override
  void dispose() {
    _fade.dispose();
    _dropPrevious();
    _cache.dispose();
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(shaderBankProvider).landscape;
    if (program == null) {
      return _FallbackLandscape(seed: widget.seed, parallax: widget.parallax);
    }
    // Yalnızca dilim değişince yeniden hesaplanır (saniyede bir build olsa da).
    final slice = ref.watch(dayNightProvider.select((d) => (d.phase * _slices).floor()));
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final dn = DayNight((slice + 0.5) / _slices);
        final replaced = _cache.update(
          key: (size, dpr, slice, widget.seed, widget.parallax),
          size: size,
          pixelRatio: dpr,
          paint: (canvas, sz) => LandscapePainter(
            shader: _slot.of(program)!,
            dayNight: dn,
            // Bulutlar dilimden dilime ilerler; geçiş efekti kaymayı yumuşatır.
            time: slice * GameConfig.dayLengthSeconds / _slices,
            seed: widget.seed.toDouble(),
            parallax: widget.parallax,
          ).paint(canvas, sz),
          onReplaced: (old) {
            _dropPrevious();
            _previous = old;
          },
        );
        if (replaced && _previous != null) _fade.forward(from: 0);

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _CachedImagePainter(current: _cache.image, previous: _previous, fade: _fade),
              ),
            ),
            _LifeLayer(seed: widget.seed),
          ],
        );
      },
    );
  }
}

/// Önbellekteki manzara görüntüsünü, eskisinden yumuşak geçişle çizer.
class _CachedImagePainter extends CustomPainter {
  _CachedImagePainter({required this.current, required this.previous, required this.fade}) : super(repaint: fade);
  final ui.Image? current;
  final ui.Image? previous;
  final Animation<double> fade;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final prev = previous;
    final cur = current;
    if (prev != null && fade.value < 1) drawCachedImage(canvas, prev, dst);
    if (cur != null) drawCachedImage(canvas, cur, dst, opacity: prev == null ? 1 : fade.value);
  }

  @override
  bool shouldRepaint(_CachedImagePainter old) => old.current != current || old.previous != previous;
}

/// Ucuz, canlı vektör katmanı: kuşlar ve uzak at kafaları.
class _LifeLayer extends ConsumerStatefulWidget {
  const _LifeLayer({required this.seed});
  final int seed;

  @override
  ConsumerState<_LifeLayer> createState() => _LifeLayerState();
}

class _LifeLayerState extends ConsumerState<_LifeLayer> with SingleTickerProviderStateMixin, TimeTicker {
  @override
  Widget build(BuildContext context) {
    final dn = ref.watch(dayNightProvider);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LifePainter(dn: dn, time: seconds, seed: widget.seed),
      ),
    );
  }
}

/// Shader yüklenemezse: gradyan gökyüzü + vektör tepeler.
class _FallbackLandscape extends ConsumerStatefulWidget {
  const _FallbackLandscape({required this.seed, required this.parallax});
  final int seed;
  final double parallax;

  @override
  ConsumerState<_FallbackLandscape> createState() => _FallbackLandscapeState();
}

class _FallbackLandscapeState extends ConsumerState<_FallbackLandscape>
    with SingleTickerProviderStateMixin, TimeTicker {
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

/// Manzara shader'ını çizer.
class LandscapePainter extends CustomPainter {
  LandscapePainter({
    required this.shader,
    required this.dayNight,
    required this.time,
    required this.seed,
    required this.parallax,
  });

  final ui.FragmentShader shader;
  final DayNight dayNight;
  final double time;
  final double seed;
  final double parallax;

  @override
  void paint(Canvas canvas, Size size) {
    final sun = dayNight.sunPosition;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, dayNight.skyTop.r)
      ..setFloat(4, dayNight.skyTop.g)
      ..setFloat(5, dayNight.skyTop.b)
      ..setFloat(6, dayNight.skyBottom.r)
      ..setFloat(7, dayNight.skyBottom.g)
      ..setFloat(8, dayNight.skyBottom.b)
      ..setFloat(9, dayNight.night)
      ..setFloat(10, dayNight.dusk)
      ..setFloat(11, sun.dx)
      ..setFloat(12, sun.dy)
      ..setFloat(13, seed)
      ..setFloat(14, parallax);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(LandscapePainter old) => old.time != time || old.dayNight.phase != dayNight.phase;
}

/// Manzaranın ön planındaki canlılık: bozkırda çalışan uzak at kafaları ve
/// süzülen kuşlar.
class _LifePainter extends CustomPainter {
  _LifePainter({required this.dn, required this.time, required this.seed});
  final DayNight dn;
  final double time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rng = Random(seed + 21);
    final c = Color.lerp(const Color(0xFF2A211A), const Color(0xFF0C0F18), dn.night)!;
    for (var i = 0; i < 2; i++) {
      final x = w * (0.12 + rng.nextDouble() * 0.76);
      final y = h * 0.955;
      final s = h / 420;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s);
      final p = Paint()..color = c;
      canvas.drawPath(
        Path()
          ..moveTo(-10, 0)
          ..lineTo(0, -34)
          ..lineTo(10, 0)
          ..close(),
        p,
      );
      canvas.save();
      canvas.translate(0, -34);
      canvas.rotate(0.2 * sin(time * 2.2 + i * 2.1));
      canvas.drawRect(const Rect.fromLTWH(-38, -3, 70, 6), p);
      canvas.drawPath(
        Path()
          ..moveTo(-38, -5)
          ..quadraticBezierTo(-52, 4, -38, 16)
          ..lineTo(-34, 0)
          ..close(),
        p,
      );
      canvas.restore();
      canvas.restore();
      if (dn.lightsOn) {
        canvas.drawCircle(Offset(x, y - 34 * s - 2), 1.3, Paint()..color = Palette.lamp);
      }
    }
    if (dn.night < 0.5) {
      final bird = Paint()
        ..color = Colors.black.withValues(alpha: 0.5 * (1 - dn.night * 2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final fx = ((time * 0.022 + i * 0.06 + seed * 0.17) % 1.3) - 0.15;
        final p = Offset(fx * w + i * 10, h * (0.22 + 0.05 * sin(i * 1.9)) + sin(time * 0.7 + i) * 3);
        final flap = sin(time * 6.5 + i * 1.4) * 2.4;
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

  @override
  bool shouldRepaint(_LifePainter old) => old.time != time;
}

/// Kurak bozkır toprağı (shader). Statiktir; yalnızca gece tonu değişince
/// yeniden çizilir.
class SoilView extends ConsumerStatefulWidget {
  const SoilView({super.key, this.base = const Color(0xFF9C6E45), this.seed = 0, this.scale = 1});
  final Color base;
  final int seed;
  final double scale;

  @override
  ConsumerState<SoilView> createState() => _SoilViewState();
}

class _SoilViewState extends ConsumerState<SoilView> {
  final _slot = ShaderSlot();

  @override
  void dispose() {
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Gece tonunu 20 kademeye yuvarla: her saniye yeniden çizilmesin.
    final night = ref.watch(dayNightProvider.select((d) => (d.night * 20).round() / 20));
    final program = ref.watch(shaderBankProvider).soil;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SoilPainter(
          shader: _slot.of(program),
          night: night,
          base: widget.base,
          seed: widget.seed.toDouble(),
          scale: widget.scale,
        ),
      ),
    );
  }
}

class _SoilPainter extends CustomPainter {
  _SoilPainter({
    required this.shader,
    required this.night,
    required this.base,
    required this.seed,
    required this.scale,
  });
  final ui.FragmentShader? shader;
  final double night;
  final Color base;
  final double seed;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sh = shader;
    if (sh == null) {
      final c = PaintKit.nightTint(base, night);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [c, Color.lerp(c, Colors.black, 0.35)!]),
      );
      return;
    }
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, night)
      ..setFloat(3, seed)
      ..setFloat(4, scale)
      ..setFloat(5, base.r)
      ..setFloat(6, base.g)
      ..setFloat(7, base.b);
    canvas.drawRect(rect, Paint()..shader = sh);
  }

  @override
  bool shouldRepaint(_SoilPainter old) => old.night != night || old.base != base || old.shader != shader;
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
