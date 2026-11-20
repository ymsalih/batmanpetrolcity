import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/economy/economy.dart';
import '../../core/game/game_controller.dart';
import '../../core/models/parcel.dart';
import '../../core/services/feedback.dart';
import '../../core/services/services.dart';
import '../../core/utils/format.dart';
import '../../core/visuals/day_night.dart';
import '../../core/visuals/game_visuals.dart';
import '../../core/visuals/landscape.dart';
import '../mascot/usta_controller.dart';
import '../site/tier_label.dart';

/// Üretimdeki kuyunun ayrıntıları ve yükseltmeleri.
Future<void> showWellSheet(BuildContext context, String siteId, int index) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => WellSheet(siteId: siteId, index: index),
  );
}

class WellSheet extends ConsumerWidget {
  const WellSheet({super.key, required this.siteId, required this.index});
  final String siteId;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = GameConfig.site(siteId);
    final p = ref.watch(gameControllerProvider.select((s) => s.site(siteId).parcels[index]));
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    final dn = ref.watch(dayNightProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);
    if (p.status != ParcelStatus.producing) return const SizedBox(height: 120);

    final rate = Economy.productionPerSecond(cfg, p);
    final cap = Economy.storageCapacity(cfg, p);
    final pumpCost = Economy.pumpUpgradeCost(cfg, p.pumpLevel);
    final storageCost = Economy.storageUpgradeCost(cfg, p.storageLevel);

    void handle(ActionResult r) {
      switch (r) {
        case ActionResult.ok:
          ref.read(feedbackProvider).medium(SoundCue.upgrade);
        case ActionResult.notEnoughMoney:
          ref.read(ustaProvider.notifier).noMoney();
        case _:
          break;
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Yakın plan sahne: gökyüzü, tepeler ve büyük at kafası.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LandscapeBackdrop(seed: index + 5),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 34,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [dn.shade(Palette.earthLight), dn.shade(Palette.earth)],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: ref
                          .read(gameVisualsProvider)
                          .pumpjack(broken: p.broken, speed: 1 + p.pumpLevel * 0.15, night: dn.night, sunX: dn.sunX),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cfg.name} · Kuyu ${index + 1}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      TierLabel(tier: p.tier),
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.decimal(rate, 2)} varil/sn · Depo ${Fmt.compact(p.stored.floor())}/${Fmt.compact(cap)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Toplam üretim: ${Fmt.barrels(p.totalProduced)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _UpgradeRow(
              key: const Key('upgrade_pump'),
              icon: Icons.speed,
              title: 'Pompa seviyesi ${p.pumpLevel}/${GameConfig.pumpMaxLevel}',
              subtitle: p.pumpLevel >= GameConfig.pumpMaxLevel
                  ? 'En yüksek seviye'
                  : 'Üretim: ${Fmt.decimal(rate, 2)} → ${Fmt.decimal(Economy.productionPerSecond(cfg, p.copyWith(pumpLevel: p.pumpLevel + 1)), 2)} varil/sn',
              cost: p.pumpLevel >= GameConfig.pumpMaxLevel ? null : pumpCost,
              affordable: money >= pumpCost,
              onPressed: () => handle(ctrl.upgradePump(siteId, index)),
            ),
            const SizedBox(height: 10),
            _UpgradeRow(
              key: const Key('upgrade_storage'),
              icon: Icons.propane_tank,
              title: 'Depo seviyesi ${p.storageLevel}/${GameConfig.storageMaxLevel}',
              subtitle: p.storageLevel >= GameConfig.storageMaxLevel
                  ? 'En yüksek seviye'
                  : 'Kapasite: ${Fmt.compact(cap)} → ${Fmt.compact(Economy.storageCapacity(cfg, p.copyWith(storageLevel: p.storageLevel + 1)))} varil',
              cost: p.storageLevel >= GameConfig.storageMaxLevel ? null : storageCost,
              affordable: money >= storageCost,
              onPressed: () => handle(ctrl.upgradeStorage(siteId, index)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.affordable,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double? cost;
  final bool affordable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Palette.panelLight, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: Palette.sunsetLight, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (cost != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.sunset),
              onPressed: affordable ? onPressed : null,
              child: Text(Fmt.money(cost!)),
            ),
        ],
      ),
    );
  }
}
