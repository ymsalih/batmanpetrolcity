import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'painters/derrick_painter.dart';
import 'painters/pumpjack_painter.dart';
import 'painters/usta_painter.dart';
import 'particles.dart';

/// Oyunun animasyonlu görsellerinin tek giriş noktası.
///
/// Şimdi CustomPainter, parçacık sistemi ve shader'larla çiziliyor
/// ([PainterGameVisuals]). İleride Rive animasyonlarına geçmek için bu
/// arayüzü uygulayan bir `RiveGameVisuals` yazıp [gameVisualsProvider]'ı
/// override etmek yeterli.
abstract class GameVisuals {
  const GameVisuals();

  Widget pumpjack({bool running = true, bool broken = false, double speed = 1, double night = 0, double sunX = 0.4});
  Widget derrick({bool drilling = true, bool lightsOn = false, double night = 0});
  Widget gusher({Offset origin = const Offset(0.5, 0.9), double groundY = 0.92, double intensity = 1});
  Widget mascot({int mood = 0});
}

final gameVisualsProvider = Provider<GameVisuals>((ref) => const PainterGameVisuals());

class PainterGameVisuals extends GameVisuals {
  const PainterGameVisuals();

  @override
  Widget pumpjack({bool running = true, bool broken = false, double speed = 1, double night = 0, double sunX = 0.4}) =>
      _Looping(
        // Gerçek at kafaları dakikada ~6-12 strok yapar; oyunda biraz hızlı.
        period: Duration(milliseconds: (3200 / speed.clamp(0.3, 4)).round()),
        running: running && !broken,
        builder: (t, seconds) => CustomPaint(
          painter: PumpjackPainter(phase: t, time: seconds, broken: broken, night: night, sunX: sunX, running: running),
        ),
      );

  @override
  Widget derrick({bool drilling = true, bool lightsOn = false, double night = 0}) => _Looping(
    period: const Duration(milliseconds: 700),
    builder: (t, seconds) => CustomPaint(
      painter: DerrickPainter(spin: t, time: seconds, lightsOn: lightsOn, night: night, drilling: drilling),
    ),
  );

  @override
  Widget gusher({Offset origin = const Offset(0.5, 0.9), double groundY = 0.92, double intensity = 1}) =>
      GusherEffect(origin: origin, groundY: groundY, intensity: intensity);

  @override
  Widget mascot({int mood = 0}) => _Looping(
    period: const Duration(milliseconds: 3500),
    builder: (t, _) {
      // Ara sıra göz kırpar.
      final blink = t > 0.94 ? sin((t - 0.94) / 0.06 * pi) : 0.0;
      return CustomPaint(
        painter: UstaPainter(mood: mood, blink: blink),
      );
    },
  );
}

/// Sürekli dönen 0..1 faz ve geçen toplam süre (sn) üreten yardımcı.
class _Looping extends StatefulWidget {
  const _Looping({required this.period, required this.builder, this.running = true});
  final Duration period;
  final bool running;
  final Widget Function(double t, double seconds) builder;

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(hours: 1));
  // Her kuyu farklı fazda başlar: hepsi aynı anda sallanmasın.
  double _phase = Random().nextDouble();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.repeat();
  }

  void _onTick() {
    final now = _c.lastElapsedDuration ?? Duration.zero;
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    // Faz hızı periyottan bağımsız birikir: hız değişince sıçrama olmaz.
    if (widget.running && dt > 0 && dt < 0.5) {
      _phase = (_phase + dt / (widget.period.inMicroseconds / 1e6)) % 1.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => widget.builder(_phase, (_c.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6),
  );
}
