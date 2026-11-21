import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/premium.dart';
import 'painters/derrick_painter.dart';
import 'painters/pumpjack_painter.dart';
import 'painters/usta_painter.dart';
import 'painters/worker_painter.dart';
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
  Widget worker({required int seed, required Color helmetColor, int rank = 0, int mood = 0});
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
        // Duran kuyu boşuna yeniden çizilmez; arızalıda yalnızca kıvılcım hızında.
        frameKey: running && !broken ? null : (_, seconds) => broken ? (seconds * 8).floor() : 0,
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
    frameKey: (t, _) => t > 0.94 ? (t * 400).round() : -1,
    builder: (t, _) {
      // Ara sıra göz kırpar.
      final blink = t > 0.94 ? sin((t - 0.94) / 0.06 * pi) : 0.0;
      return CustomPaint(
        painter: UstaPainter(mood: mood, blink: blink),
      );
    },
  );

  @override
  Widget worker({required int seed, required Color helmetColor, int rank = 0, int mood = 0}) => _Looping(
    // Her işçi farklı zamanda göz kırpar.
    period: Duration(milliseconds: 3000 + (seed * 377) % 2500),
    frameKey: (t, _) => t > 0.95 ? (t * 400).round() : -1,
    builder: (t, _) {
      final blink = t > 0.95 ? sin((t - 0.95) / 0.05 * pi) : 0.0;
      return CustomPaint(
        painter: WorkerPainter(seed: seed, helmetColor: helmetColor, rank: rank, mood: mood, blink: blink),
      );
    },
  );
}

/// Sürekli dönen 0..1 faz ve geçen toplam süre (sn) üreten yardımcı.
///
/// Kare hızı grafik seviyesiyle sınırlıdır; [frameKey] verilirse yalnızca
/// anahtar değiştiğinde yeniden çizilir (ör. göz kırpma anı dışında boşta).
class _Looping extends StatefulWidget {
  const _Looping({required this.period, required this.builder, this.running = true, this.frameKey});
  final Duration period;
  final bool running;
  final Widget Function(double t, double seconds) builder;
  final int Function(double t, double seconds)? frameKey;

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping> with SingleTickerProviderStateMixin, FrameThrottle {
  // Her kuyu farklı fazda başlar: hepsi aynı anda sallanmasın.
  double _phase = Random().nextDouble();
  int? _lastKey;

  @override
  void onFrame(double dt) {
    // Faz hızı periyottan bağımsız birikir: hız değişince sıçrama olmaz.
    if (widget.running && dt > 0) {
      _phase = (_phase + dt / (widget.period.inMicroseconds / 1e6)) % 1.0;
    }
  }

  @override
  bool shouldRebuild() {
    final k = widget.frameKey;
    if (k == null) return true;
    final key = k(_phase, seconds);
    if (key == _lastKey) return false;
    _lastKey = key;
    return true;
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: widget.builder(_phase, seconds));
}
