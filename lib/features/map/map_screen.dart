import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/economy/economy.dart';
import '../../core/game/game_controller.dart';
import '../../core/models/parcel.dart';
import '../../core/navigation.dart';
import '../../core/services/feedback.dart';
import '../../core/services/services.dart';
import '../../core/utils/format.dart';
import '../../core/ui/premium.dart';
import '../../core/visuals/day_night.dart';
import '../../core/visuals/landscape.dart';
import '../mascot/usta_controller.dart';
import 'map_painter.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 60))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dn = ref.watch(dayNightProvider);
    final unlocked = ref.watch(
      gameControllerProvider.select(
        (s) => GameConfig.sites.where((c) => s.site(c.id).unlocked).map((c) => c.id).toSet().join(','),
      ),
    );
    final unlockedSet = unlocked.split(',').toSet();

    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: box.maxHeight * MapPainter.horizon + 2,
              child: const LandscapeBackdrop(seed: 1),
            ),
            Positioned(
              top: box.maxHeight * MapPainter.horizon,
              left: 0,
              right: 0,
              bottom: 0,
              child: const SoilView(seed: 2, base: Color(0xFFB88B5C), scale: 1.4),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, _) => CustomPaint(
                    painter: MapPainter(
                      dayNight: dn,
                      unlocked: unlockedSet,
                      time: _anim.value * 60,
                      skyFromShader: true,
                    ),
                    foregroundPainter: GraphicsMode.isLow(context)
                        ? null
                        : CloudShadowPainter(time: _anim.value * 60, night: dn.night, top: MapPainter.horizon),
                  ),
                ),
              ),
            ),
            for (final site in GameConfig.sites)
              Positioned(
                left: (site.mapX * box.maxWidth - 60).clamp(4.0, box.maxWidth - 124),
                top: site.mapY * box.maxHeight - 34,
                width: 120,
                child: _SiteMarker(site: site, unlocked: unlockedSet.contains(site.id)),
              ),
            Positioned(
              left: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(dn.night > 0.5 ? Icons.nightlight_round : Icons.wb_sunny, size: 16, color: Palette.lamp),
                    const SizedBox(width: 6),
                    Text(dn.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SiteMarker extends ConsumerWidget {
  const _SiteMarker({required this.site, required this.unlocked});
  final SiteConfig site;
  final bool unlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wells = ref.watch(
      gameControllerProvider.select(
        (s) => s.site(site.id).parcels.where((p) => p.status == ParcelStatus.producing).length,
      ),
    );
    final selected = ref.watch(gameControllerProvider.select((s) => s.selectedSiteId == site.id));
    final color = unlocked ? Palette.sunset : Palette.steel;

    final pin = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? Palette.gold : Colors.white, width: selected ? 3 : 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Icon(
        unlocked ? (site.unlocksRefinery ? Icons.factory : Icons.oil_barrel) : Icons.lock,
        color: Colors.white,
      ),
    );

    return GestureDetector(
      key: Key('site_marker_${site.id}'),
      onTap: () {
        ref.read(feedbackProvider).light();
        if (unlocked) {
          ref.read(gameControllerProvider.notifier).selectSite(site.id);
          ref.read(navProvider.notifier).go(AppTab.site);
        } else {
          showDialog<void>(
            context: context,
            builder: (_) => _UnlockDialog(site: site),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          unlocked
              ? pin
              : pin
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 900.ms),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  site.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                Text(
                  unlocked ? '$wells kuyu' : Fmt.money(site.unlockCost),
                  style: TextStyle(color: unlocked ? Colors.white70 : Palette.gold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockDialog extends ConsumerWidget {
  const _UnlockDialog({required this.site});
  final SiteConfig site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    final canAfford = money >= site.unlockCost;
    final rate = site.baseBarrelsPerSecond * site.yieldMultiplier;

    Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(a, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return AlertDialog(
      backgroundColor: Palette.panel,
      title: Text(site.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(site.description),
          const SizedBox(height: 12),
          row('Verim çarpanı', 'x${Fmt.decimal(site.yieldMultiplier, 1)}'),
          row('Ortalama kuyu', '${Fmt.decimal(rate, 2)} varil/sn'),
          row('Sondaj süresi', Fmt.duration(Duration(milliseconds: Economy.drillDurationMs(site)))),
          row('Kuru kuyu ihtimali', '%${(site.dryChance * 100).round()}'),
          row('Sondaj bedeli', Fmt.money(site.drillCost)),
          if (site.unlocksRefinery) row('Bonus', 'Rafineri açılır'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        PremiumButton(
          key: const Key('unlock_confirm'),
          expand: false,
          height: 46,
          colors: canAfford ? Premium.gold : Premium.steel,
          foreground: canAfford ? const Color(0xFF3A2508) : Colors.white,
          label: canAfford ? 'Aç · ${Fmt.money(site.unlockCost)}' : 'Yetersiz bakiye',
          onPressed: canAfford
              ? () {
                  final r = ref.read(gameControllerProvider.notifier).unlockSite(site.id);
                  if (r == ActionResult.ok) {
                    ref.read(feedbackProvider).heavy(SoundCue.unlock);
                    Navigator.pop(context);
                    ref.read(navProvider.notifier).go(AppTab.site);
                  }
                }
              : () => ref.read(ustaProvider.notifier).noMoney(),
        ),
      ],
    );
  }
}
