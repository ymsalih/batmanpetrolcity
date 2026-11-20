import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../services/services.dart';

/// Gün-gece döngüsünün anlık durumu.
class DayNight {
  const DayNight(this.phase);

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

/// Saniyede bir güncellenen gün-gece durumu.
final dayNightProvider = NotifierProvider<DayNightController, DayNight>(DayNightController.new);

class DayNightController extends Notifier<DayNight> {
  @override
  DayNight build() {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) => state = _compute());
    ref.onDispose(timer.cancel);
    return _compute();
  }

  DayNight _compute() {
    const len = GameConfig.dayLengthSeconds * 1000;
    final now = ref.read(clockProvider).nowMs();
    // Oyun başlarken sabah olsun diye faz kaydırılır.
    return DayNight(((now % len) / len + 0.3) % 1.0);
  }
}
