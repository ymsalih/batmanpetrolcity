import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../features/events/effects_bar.dart';
import '../../features/mascot/usta_controller.dart';
import '../../features/mascot/usta_avatar.dart';
import '../game/game_controller.dart';
import '../utils/format.dart';

/// Üst bilgi çubuğu: para, varil, aktif olaylar, Usta kısayolu.
class GameHud extends ConsumerWidget {
  const GameHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    final crude = ref.watch(gameControllerProvider.select((s) => s.crude));
    final refined = ref.watch(gameControllerProvider.select((s) => s.refined));
    final refinery = ref.watch(gameControllerProvider.select((s) => s.refineryUnlocked));

    return Container(
      color: Palette.panel,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6, left: 12, right: 8, bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Stat(icon: Icons.payments, color: Palette.gold, text: Fmt.money(money), key: const Key('hud_money')),
              const SizedBox(width: 14),
              _Stat(icon: Icons.oil_barrel, color: Palette.sunsetLight, text: Fmt.compact(crude.floor())),
              if (refinery) ...[
                const SizedBox(width: 14),
                _Stat(icon: Icons.local_gas_station, color: Palette.success, text: Fmt.compact(refined.floor())),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(ustaProvider.notifier).tip(),
                child: const SizedBox(width: 40, height: 40, child: UstaAvatar()),
              ),
            ],
          ),
          const EffectsBar(),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }
}
