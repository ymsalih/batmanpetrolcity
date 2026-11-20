import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/models/active_effect.dart';
import '../../core/services/services.dart';
import '../../core/utils/format.dart';

/// Aktif olay / güçlendirmeleri kalan süreleriyle gösterir.
class EffectsBar extends ConsumerWidget {
  const EffectsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(gameControllerProvider.select((s) => s.effects));
    final brokenCount = ref.watch(
        gameControllerProvider.select((s) => s.allParcels.where((e) => e.parcel.broken).length));
    // Geri sayım için saniyede bir yeniden çizilir.
    ref.watch(gameControllerProvider.select((s) => s.lastTickMs ~/ 1000));
    final now = ref.read(clockProvider).nowMs();
    final active = effects.where((e) => e.isActiveAt(now)).toList();
    if (active.isEmpty && brokenCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 30,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final e in active) _chip(_icon(e), _color(e), '${e.title} · ${Fmt.clock(e.remaining(now))}'),
            if (brokenCount > 0)
              _chip(Icons.build, Palette.danger, 'Arıza: $brokenCount kuyu durdu'),
          ],
        ),
      ),
    );
  }

  IconData _icon(ActiveEffect e) => switch (e.eventKind) {
        GameEventKind.heatWave => Icons.wb_sunny,
        GameEventKind.priceSpike => Icons.trending_up,
        _ => Icons.bolt,
      };

  Color _color(ActiveEffect e) => e.productionMultiplier < 1 ? Palette.sunset : Palette.success;

  Widget _chip(IconData icon, Color color, String text) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}
