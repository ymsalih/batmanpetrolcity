import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/economy/economy.dart';
import '../../core/game/game_controller.dart';
import '../../core/navigation.dart';
import '../../core/services/feedback.dart';
import '../../core/services/services.dart';
import '../../core/utils/format.dart';
import '../../core/ui/premium.dart';
import '../../core/visuals/animated_paint.dart';
import '../../core/visuals/day_night.dart';
import '../../core/visuals/landscape.dart';
import '../../core/widgets/effect_layer.dart';
import 'parcel_tile.dart';

class SiteScreen extends ConsumerWidget {
  const SiteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteId = ref.watch(gameControllerProvider.select((s) => s.selectedSiteId));
    final unlocked = ref.watch(
      gameControllerProvider.select(
        (s) => GameConfig.sites.where((c) => s.site(c.id).unlocked).map((c) => c.id).join(','),
      ),
    );
    // Tüm ekran her saniye yeniden kurulmasın: gece değeri kademeli izlenir.
    final night = ref.watch(dayNightProvider.select((d) => (d.night * 10).round() / 10));
    final cfg = GameConfig.site(siteId);

    final siteIndex = GameConfig.sites.indexWhere((c) => c.id == siteId);
    return Stack(
      children: [
        Positioned.fill(
          child: _SiteBackground(
            night: night,
            seed: siteIndex,
            parallax: siteIndex / max(1, GameConfig.sites.length - 1) * 2 - 1,
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              // Saha seçici
              SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in GameConfig.sites)
                      if (unlocked.split(',').contains(c.id))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: c.id == siteId,
                            selectedColor: Palette.sunset,
                            onSelected: (_) => ref.read(gameControllerProvider.notifier).selectSite(c.id),
                          ),
                        ),
                    ActionChip(
                      avatar: const Icon(Icons.map, size: 18),
                      label: const Text('Yeni saha'),
                      onPressed: () => ref.read(navProvider.notifier).go(AppTab.map),
                    ),
                  ],
                ),
              ),
              _SiteHeader(cfg: cfg),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.count(
                        crossAxisCount: GameConfig.gridSize,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 0; i < GameConfig.gridSize * GameConfig.gridSize; i++)
                            ParcelTile(key: ValueKey('$siteId-$i'), siteId: siteId, index: i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _CollectAllButton(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// Üstte paralaks manzara, altta bulut gölgeleri gezinen toprak zemin.
class _SiteBackground extends StatelessWidget {
  const _SiteBackground({required this.night, required this.seed, required this.parallax});
  final double night;
  final int seed;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final widget = this;
    return LayoutBuilder(
      builder: (context, box) {
        final band = box.maxHeight * 0.30;
        return Stack(
          children: [
            Positioned(
              top: band,
              left: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SoilView(seed: widget.seed, base: const Color(0xFFA0714A)),
                  // Bulut gölgeleri yalnızca yüksek kalitede (bulanıklık pahalı).
                  if (GraphicsMode.of(context).detail)
                    AnimatedPaint(
                      painter: (t) => CloudShadowPainter(time: t, night: night),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: band + 1,
              child: LandscapeBackdrop(seed: widget.seed, parallax: widget.parallax),
            ),
          ],
        );
      },
    );
  }
}

class _SiteHeader extends ConsumerWidget {
  const _SiteHeader({required this.cfg});
  final SiteConfig cfg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(
      gameControllerProvider.select((s) {
        final mult = s.productionMultiplierAt(s.lastTickMs);
        return s
            .site(cfg.id)
            .parcels
            .fold(0.0, (a, p) => a + Economy.productionPerSecond(cfg, p, effectMultiplier: mult));
      }),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
                Text(
                  cfg.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${Fmt.decimal(rate, 1)} varil/sn',
                  style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Zorluk ${'●' * cfg.difficulty}${'○' * (5 - cfg.difficulty)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectAllButton extends ConsumerWidget {
  const _CollectAllButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      gameControllerProvider.select((s) => s.allParcels.fold(0.0, (a, e) => a + e.parcel.stored.floor())),
    );
    return Builder(
      builder: (ctx) {
        return SizedBox(
          width: 280,
          child: PremiumButton(
            key: const Key('collect_all'),
            colors: Premium.gold,
            foreground: const Color(0xFF3A2508),
            icon: Icons.oil_barrel,
            label: 'Tüm kuyuları topla (${Fmt.compact(total)})',
            onPressed: total < 1
                ? null
                : () {
                    final amount = ref.read(gameControllerProvider.notifier).collectAll();
                    ref.read(feedbackProvider).medium(SoundCue.collect);
                    final box = ctx.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final c = box.localToGlobal(box.size.center(Offset.zero));
                      EffectLayer.maybeOf(context)
                        ?..floatText(c - const Offset(0, 20), '+${Fmt.compact(amount)} varil')
                        ..burst(c, count: 16);
                    }
                  },
          ),
        );
      },
    );
  }
}
