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
import '../../core/ui/premium.dart';
import '../mascot/usta_controller.dart';
import '../well/drilling_screen.dart';
import 'tier_label.dart';

/// Boş veya kuru parsel için işlemler: etüt, sondaj, temizlik.
Future<void> showParcelSheet(BuildContext context, String siteId, int index) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    builder: (_) => ParcelSheet(siteId: siteId, index: index),
  );
}

class ParcelSheet extends ConsumerWidget {
  const ParcelSheet({super.key, required this.siteId, required this.index});
  final String siteId;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = GameConfig.site(siteId);
    final parcel = ref.watch(gameControllerProvider.select((s) => s.site(siteId).parcels[index]));
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    final ctrl = ref.read(gameControllerProvider.notifier);

    void handle(ActionResult r, {VoidCallback? onOk}) {
      if (r == ActionResult.ok) {
        onOk?.call();
      } else if (r == ActionResult.notEnoughMoney) {
        ref.read(ustaProvider.notifier).noMoney();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz bakiye')));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${cfg.name} · Parsel ${index + 1}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Hedef derinlik ${Fmt.integer(cfg.targetDepthM)} m · Sondaj süresi ${Fmt.duration(Duration(milliseconds: Economy.drillDurationMs(cfg)))}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (parcel.status == ParcelStatus.empty) ...[
              _surveyInfo(cfg, parcel),
              const SizedBox(height: 16),
              if (!parcel.surveyed)
                PremiumButton(
                  key: const Key('btn_survey'),
                  icon: Icons.search,
                  label: 'Etüt yap · ${Fmt.money(cfg.surveyCost)}',
                  colors: Premium.steel,
                  shine: false,
                  height: 48,
                  onPressed: money >= cfg.surveyCost
                      ? () => handle(ctrl.survey(siteId, index), onOk: () => ref.read(feedbackProvider).light())
                      : null,
                ),
              const SizedBox(height: 10),
              PremiumButton(
                key: const Key('btn_drill'),
                icon: Icons.hardware,
                label: 'Sondaja başla · ${Fmt.money(cfg.drillCost)}',
                height: 56,
                onPressed: () => handle(
                  ctrl.startDrill(siteId, index),
                  onOk: () {
                    ref.read(feedbackProvider).medium(SoundCue.drillStart);
                    ref.read(ustaProvider.notifier).drillStarted();
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(premiumRoute(DrillingScreen(siteId: siteId, index: index)));
                  },
                ),
              ),
            ],
            if (parcel.status == ParcelStatus.dry) ...[
              const Text(
                'Bu parsel kuru çıktı. Temizleyip yeniden deneyebilirsin; verim yeniden belirlenir.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              PremiumButton(
                key: const Key('btn_clear'),
                icon: Icons.cleaning_services,
                label: 'Parseli temizle · ${Fmt.money(Economy.clearDryCost(cfg))}',
                colors: Premium.steel,
                onPressed: () => handle(ctrl.clearDry(siteId, index), onOk: () => Navigator.of(context).pop()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _surveyInfo(SiteConfig cfg, Parcel parcel) {
    if (!parcel.surveyed || parcel.tier == null) {
      return Text(
        'Etüt yapılmadı. Kuru kuyu ihtimali ortalama %${(cfg.dryChance * 100).round()}. '
        'Etüt, verimi (düşük/orta/yüksek) gösterir.',
        style: const TextStyle(color: Colors.white),
      );
    }
    final chance = Economy.dryChance(cfg, parcel.tier!);
    return Row(
      children: [
        TierLabel(tier: parcel.tier),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Kuru kuyu ihtimali ~%${(chance * 100).round()}', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
