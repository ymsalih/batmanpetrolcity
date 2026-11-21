import 'package:flutter_animate/flutter_animate.dart';
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
import '../../core/visuals/day_night.dart';
import '../../core/visuals/game_visuals.dart';
import '../../core/visuals/landscape.dart';
import '../../core/visuals/painters/ground_painter.dart';
import '../../core/widgets/effect_layer.dart';
import '../well/drilling_screen.dart';
import '../well/well_sheet.dart';
import 'parcel_sheet.dart';
import 'tier_label.dart';

/// 3x3 ızgaradaki tek parsel.
class ParcelTile extends ConsumerWidget {
  const ParcelTile({super.key, required this.siteId, required this.index});
  final String siteId;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcel = ref.watch(gameControllerProvider.select((s) => s.site(siteId).parcels[index]));
    // Kademeli: kutucuklar her saniye değil, ışık gözle görülür değişince kurulur.
    final night = ref.watch(dayNightProvider.select((d) => (d.night * 20).round() / 20));
    final sunX = ref.watch(dayNightProvider.select((d) => (d.sunX * 10).round() / 10));
    final cfg = GameConfig.site(siteId);

    return GestureDetector(
      key: Key('parcel_${siteId}_$index'),
      onTapUp: (d) => _onTap(context, ref, parcel, d.globalPosition),
      onLongPress: parcel.status == ParcelStatus.producing ? () => showWellSheet(context, siteId, index) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gerçekçi toprak (shader) + sürülmüş parsel izleri ve kenar gölgesi.
            SoilView(
              seed: index * 7 + 3,
              base: parcel.status == ParcelStatus.dry ? const Color(0xFFA89580) : const Color(0xFF8C5A34),
              scale: 0.8,
            ),
            CustomPaint(
              painter: PlotOverlayPainter(
                seed: index * 31 + siteId.hashCode,
                cracked: parcel.status == ParcelStatus.dry,
                tilled: parcel.status == ParcelStatus.empty,
                night: night,
                highlight: parcel.surveyed && parcel.status == ParcelStatus.empty ? parcel.tier?.color : null,
              ),
            ),
            ..._content(context, ref, parcel, cfg, night, sunX),
            Positioned(
              left: 6,
              top: 4,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, Parcel p, SiteConfig cfg, double night, double sunX) {
    final visuals = ref.read(gameVisualsProvider);
    switch (p.status) {
      case ParcelStatus.empty:
        return [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p.surveyed ? Icons.add_location_alt : Icons.search, color: Colors.white70, size: 28),
                const SizedBox(height: 4),
                Text(
                  p.surveyed ? 'Sondaja hazır' : 'Boş parsel',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (p.surveyed) Positioned(right: 4, top: 4, child: TierLabel(tier: p.tier, compact: true)),
        ];

      case ParcelStatus.drilling:
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
            child: visuals.derrick(lightsOn: night > 0.45, night: night),
          ),
          Positioned(left: 6, right: 6, bottom: 6, child: _DrillProgress(parcel: p)),
        ];

      case ParcelStatus.dry:
        return [
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, color: Colors.white70, size: 26),
                Text(
                  'Kuru kuyu',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ];

      case ParcelStatus.producing:
        final cap = Economy.storageCapacity(cfg, p);
        final fill = (p.stored / cap).clamp(0.0, 1.0);
        final full = fill >= 0.999;
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 11, 15),
            child: visuals.pumpjack(broken: p.broken, speed: 1 + p.pumpLevel * 0.15, night: night, sunX: sunX),
          ),
          // Depo göstergesi
          Positioned(
            right: 4,
            top: 8,
            bottom: 20,
            width: 7,
            child: _VerticalGauge(value: fill, color: full ? Palette.sunset : Palette.gold),
          ),
          Positioned(
            left: 4,
            right: 4,
            bottom: 3,
            child: Text(
              '${Fmt.compact(p.stored.floor())}/${Fmt.compact(cap)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: full ? Palette.sunsetLight : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            // Mobilde parmakla rahat basılsın: 40x40 dokunma alanı.
            child: GestureDetector(
              key: Key('well_settings_${siteId}_$index'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showWellSheet(context, siteId, index),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Align(
                  alignment: Alignment(0.6, -0.6),
                  child: Icon(Icons.tune, size: 18, color: Colors.white70),
                ),
              ),
            ),
          ),
          if (full && !p.broken) const Positioned.fill(child: IgnorePointer(child: _FullGlow())),
          if (p.broken)
            Positioned.fill(
              child: Container(
                color: Palette.danger.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.build,
                      color: Colors.white,
                      size: 26,
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.05, end: 0.05, duration: 300.ms),
                    Text(
                      'Tamir ${p.repairProgress}/${GameConfig.repairTaps}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ];
    }
  }

  void _onTap(BuildContext context, WidgetRef ref, Parcel p, Offset pos) {
    final ctrl = ref.read(gameControllerProvider.notifier);
    final fb = ref.read(feedbackProvider);
    final fx = EffectLayer.maybeOf(context);
    switch (p.status) {
      case ParcelStatus.empty:
        fb.light();
        showParcelSheet(context, siteId, index);
      case ParcelStatus.drilling:
        fb.light();
        Navigator.of(context).push(premiumRoute(DrillingScreen(siteId: siteId, index: index)));
      case ParcelStatus.dry:
        fb.light();
        showParcelSheet(context, siteId, index);
      case ParcelStatus.producing:
        if (p.broken) {
          final fixed = ctrl.repairTap(siteId, index);
          fb.medium(SoundCue.repair);
          fx?.burst(pos, color: Palette.steelLight, count: 8, spread: 40);
          if (fixed) fx?.floatText(pos, 'Tamir edildi!', color: Palette.success);
          return;
        }
        final amount = ctrl.collect(siteId, index);
        if (amount > 0) {
          fb.light(SoundCue.collect);
          fx?.floatText(pos, '+${Fmt.compact(amount)} varil');
          fx?.burst(pos, count: (6 + amount / 10).clamp(6, 20).round());
        } else {
          showWellSheet(context, siteId, index);
        }
    }
  }
}

class _DrillProgress extends ConsumerWidget {
  const _DrillProgress({required this.parcel});
  final Parcel parcel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gameControllerProvider.select((s) => s.lastTickMs));
    final now = ref.read(clockProvider).nowMs();
    final progress = Economy.drillProgress(parcel, now);
    final remaining = Duration(milliseconds: (parcel.drillCompleteMs - now).clamp(0, 1 << 31));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fmt.clock(remaining),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 3, color: Colors.black)],
          ),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: Palette.sunset,
            backgroundColor: Colors.black38,
          ),
        ),
      ],
    );
  }
}

class _VerticalGauge extends StatelessWidget {
  const _VerticalGauge({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: value,
        widthFactor: 1,
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

class _FullGlow extends StatelessWidget {
  const _FullGlow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.sunset, width: 3),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 700.ms);
  }
}
