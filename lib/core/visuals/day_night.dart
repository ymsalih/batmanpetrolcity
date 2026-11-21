import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../services/services.dart';
import 'sun.dart';

/// Gün-gece döngüsünün anlık durumu.
class DayNight {
  const DayNight(this.phase, {this.sun});

  /// Gerçek güneş konumu (gerçek saat modunda); yoksa fazdan türetilir.
  final SunPosition? sun;

  SunPosition get sunPos => sun ?? SunPosition.fromPhase(phase);

  /// 0..1: 0 = gece yarısı, 0.25 = gün doğumu, 0.5 = öğle, 0.75 = gün batımı.
  final double phase;

  /// 0 = tam gündüz, 1 = tam gece.
  double get night {
    final sun = sin((phase - 0.25) * 2 * pi); // -1 gece, 1 öğle
    return ((0.25 - sun) / 0.6).clamp(0.0, 1.0);
  }

  /// Gün doğumu/batımı yoğunluğu (turuncu tonlar için).
  double get dusk {
    final sun = sin((phase - 0.25) * 2 * pi);
    return (1 - (sun.abs() / 0.45)).clamp(0.0, 1.0);
  }

  bool get lightsOn => night > 0.45;

  /// Güneşin gökyüzü alanındaki göreli konumu (y>1: ufkun altında).
  Offset get sunPosition {
    final a = phase * 2 * pi - pi / 2;
    return Offset(0.5 - 0.42 * cos(a), 1 - 0.85 * sin(a));
  }

  /// Güneşin yatay yönü (-1 sol .. 1 sağ). Gölgeler ters yöne düşer.
  double get sunX => ((sunPosition.dx - 0.5) / 0.42).clamp(-1.0, 1.0);

  Color get skyTop {
    final day = Color.lerp(Palette.sky, Palette.sunset, dusk * 0.5)!;
    return Color.lerp(day, Palette.night, night)!;
  }

  Color get skyBottom {
    final day = Color.lerp(Palette.skyLight, Palette.sunsetLight, dusk)!;
    return Color.lerp(day, Palette.nightLight, night)!;
  }

  /// Zemin renklerini geceye göre karartır.
  Color shade(Color c) => Color.lerp(c, const Color(0xFF0B0E1C), night * 0.55)!;

  String get label => night > 0.6
      ? 'Gece'
      : dusk > 0.5
      ? (phase < 0.5 ? 'Şafak' : 'Akşam')
      : 'Gündüz';
}

/// 4 saniyede bir güncellenen gün-gece durumu (8 dakikalık günde fark
/// edilmez, gereksiz yeniden kurulumları azaltır).
final dayNightProvider = NotifierProvider<DayNightController, DayNight>(DayNightController.new);

class DayNightController extends Notifier<DayNight> {
  @override
  DayNight build() {
    // Gerçek güneş yavaş ilerler: 30 sn'de bir güncellemek yeterli.
    final timer = Timer.periodic(Duration(seconds: GameConfig.realTimeSun ? 30 : 4), (_) => state = _compute());
    ref.onDispose(timer.cancel);
    return _compute();
  }

  DayNight _compute() {
    final now = ref.read(clockProvider).nowMs();
    if (GameConfig.realTimeSun) {
      // Batman'ın gerçek güneşi: gün doğumu/batımı gerçek saatinde.
      final sun = SunPosition.at(
        DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
        lat: GameConfig.batmanLat,
        lon: GameConfig.batmanLon,
      );
      return DayNight(sun.dayPhase, sun: sun);
    }
    const len = GameConfig.dayLengthSeconds * 1000;
    // Oyun başlarken sabah olsun diye faz kaydırılır.
    return DayNight(((now % len) / len + 0.3) % 1.0);
  }
}
