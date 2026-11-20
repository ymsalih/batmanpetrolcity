import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/effect_layer.dart';
import '../mascot/usta_avatar.dart';
import '../mascot/usta_controller.dart';
import '../mascot/usta_lines.dart';

/// "Sen yokken X varil çıktı" penceresi.
class OfflineReportOverlay extends ConsumerWidget {
  const OfflineReportOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(gameControllerProvider.select((s) => s.offlineReport));
    if (report == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Palette.panelLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.sunset, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 90, height: 90, child: UstaAvatar(mood: UstaMood.excited)),
            const SizedBox(height: 8),
            const Text(
              UstaLines.offline,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Sen yokken ${Fmt.integer(report.barrels.floor())} varil çıktı',
              key: const Key('offline_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.gold),
            ),
            const SizedBox(height: 6),
            Text('Yokluk süresi: ${Fmt.duration(report.away)}', style: const TextStyle(color: Colors.white70)),
            if (report.drillsFinished > 0)
              Text('${report.drillsFinished} sondaj tamamlandı', style: const TextStyle(color: Colors.white70)),
            if (report.storageFull)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Bazı depolar doldu! Kapasiteyi yükseltirsen daha çok birikir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.sunsetLight),
                ),
              ),
            const SizedBox(height: 16),
            Builder(
              builder: (ctx) {
                return FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Palette.sunset, minimumSize: const Size(200, 48)),
                  icon: const Icon(Icons.oil_barrel),
                  label: const Text('Hepsini topla'),
                  onPressed: () {
                    final box = ctx.findRenderObject() as RenderBox?;
                    final ctrl = ref.read(gameControllerProvider.notifier);
                    final amount = ctrl.collectAll();
                    ctrl.dismissOfflineReport();
                    if (box != null && amount > 0) {
                      final center = box.localToGlobal(box.size.center(Offset.zero));
                      EffectLayer.maybeOf(context)?.floatText(center, '+${Fmt.integer(amount)} varil');
                    }
                  },
                );
              },
            ),
            TextButton(
              onPressed: () => ref.read(gameControllerProvider.notifier).dismissOfflineReport(),
              child: const Text('Sonra'),
            ),
          ],
        ),
      ).animate().scale(begin: const Offset(0.85, 0.85), duration: 250.ms, curve: Curves.easeOutBack),
    );
  }
}
