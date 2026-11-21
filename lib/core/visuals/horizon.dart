import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'day_night.dart';
import 'sun.dart';

/// Batman semalarından Raman sırtı ve Kozluk-Sason dağlarına bakan, gerçek
/// arazi verisinden render edilmiş manzara. Güneşin yüksekliğine göre gün
/// doğumu, gündüz, gün batımı ve gece görüntüleri arasında yumuşak geçiş.
///
/// Her karede çizim yok: görüntüler bir kez çözülür, geçiş yalnızca
/// saydamlıkla yapılır (güneş 30 sn'de bir güncellenir).
class HorizonBackdrop extends ConsumerWidget {
  const HorizonBackdrop({super.key, this.phase, this.parallax = 0, this.alignY = -0.05});

  /// Sabit gün fazı (sinematik sahneler); null ise gerçek güneş.
  final double? phase;

  /// -1..1 yatay kaydırma.
  final double parallax;

  /// Dikey hizalama: ufkun ekrandaki yeri.
  final double alignY;

  static const _dir = 'assets/game/horizon';
  static const keys = ['gece', 'safak', 'gunduz', 'aksam'];

  /// Güneşe göre her görüntünün ağırlığı (toplam 1).
  static Map<String, double> weights(SunPosition sun) {
    double ss(double a, double b, double x) {
      final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    final el = sun.elevation;
    final day = ss(5, 16, el);
    final golden = ss(-6, -1, el) * (1 - ss(5, 16, el));
    final night = 1 - ss(-9, -2, el);
    final total = day + golden + night;
    return {
      'gece': night / total,
      'safak': sun.morning ? golden / total : 0,
      'aksam': sun.morning ? 0 : golden / total,
      'gunduz': day / total,
    };
  }

  static void precache(BuildContext context) {
    for (final k in keys) {
      precacheImage(AssetImage('$_dir/$k.jpg'), context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SunPosition sun;
    if (phase != null) {
      sun = SunPosition.fromPhase(phase!);
    } else {
      // Yalnızca ağırlık gözle görülür değiştiğinde yeniden kurulur.
      sun = ref.watch(dayNightProvider.select((d) => d.sunPos));
    }
    final w = weights(sun);
    final align = Alignment(parallax.clamp(-1.0, 1.0) * 0.6, alignY);
    // Ağırlıklar katman katman: önce tam opak taban, üstüne normalize saydamlık.
    final layers = <Widget>[];
    var acc = 0.0;
    for (final k in keys) {
      final wk = w[k]!;
      if (wk < 0.004) continue;
      acc += wk;
      final opacity = layers.isEmpty ? 1.0 : (wk / acc).clamp(0.0, 1.0);
      layers.add(
        Opacity(
          key: ValueKey(k),
          opacity: opacity,
          child: Image.asset(
            '$_dir/$k.jpg',
            fit: BoxFit.cover,
            alignment: align,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: layers),
    );
  }
}
