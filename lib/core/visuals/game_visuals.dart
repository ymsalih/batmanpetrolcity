import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'painters/derrick_painter.dart';
import 'painters/gusher_painter.dart';
import 'painters/pumpjack_painter.dart';
import 'painters/usta_painter.dart';

/// Oyunun animasyonlu görsellerinin tek giriş noktası.
///
/// Şimdi CustomPainter ile çiziliyor ([PainterGameVisuals]). İleride Rive
/// animasyonlarına geçmek için bu arayüzü uygulayan bir `RiveGameVisuals`
/// yazıp [gameVisualsProvider]'ı override etmek yeterli.
abstract class GameVisuals {
  const GameVisuals();

  Widget pumpjack({bool running = true, bool broken = false, double speed = 1, double night = 0});
  Widget derrick({bool drilling = true, bool lightsOn = false});
  Widget gusher({Offset origin = const Offset(0.5, 1), double intensity = 1});
  Widget mascot({int mood = 0});
}

final gameVisualsProvider = Provider<GameVisuals>((ref) => const PainterGameVisuals());

class PainterGameVisuals extends GameVisuals {
  const PainterGameVisuals();

  @override
  Widget pumpjack({bool running = true, bool broken = false, double speed = 1, double night = 0}) =>
      _Looping(
        period: Duration(milliseconds: (2600 / speed.clamp(0.3, 4)).round()),
        running: running && !broken,
        builder: (t) => CustomPaint(painter: PumpjackPainter(phase: t, broken: broken, night: night)),
      );

  @override
  Widget derrick({bool drilling = true, bool lightsOn = false}) => _Looping(
        period: const Duration(milliseconds: 600),
        running: drilling,
        builder: (t) => CustomPaint(painter: DerrickPainter(spin: t, lightsOn: lightsOn)),
      );

  @override
  Widget gusher({Offset origin = const Offset(0.5, 1), double intensity = 1}) => _Looping(
        period: const Duration(seconds: 10),
        builder: (t) => CustomPaint(painter: GusherPainter(t: t * 10, origin: origin, intensity: intensity)),
      );

  @override
  Widget mascot({int mood = 0}) => _Looping(
        period: const Duration(milliseconds: 3500),
        builder: (t) {
          // Ara sıra göz kırpar.
          final blink = t > 0.94 ? sin((t - 0.94) / 0.06 * pi) : 0.0;
          return CustomPaint(painter: UstaPainter(mood: mood, blink: blink));
        },
      );
}

/// Sürekli dönen 0..1 animasyon değeri üreten yardımcı.
class _Looping extends StatefulWidget {
  const _Looping({required this.period, required this.builder, this.running = true});
  final Duration period;
  final bool running;
  final Widget Function(double t) builder;

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat();
  }

  @override
  void didUpdateWidget(_Looping old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) _c.duration = widget.period;
    if (widget.running && (!_c.isAnimating || old.period != widget.period)) {
      _c.repeat();
    } else if (!widget.running && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (_, _) => widget.builder(_c.value));
}
