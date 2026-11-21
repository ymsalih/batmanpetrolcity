import 'dart:math';
import 'dart:ui' as ui;

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
import '../../core/visuals/shaders.dart';
import '../../core/widgets/effect_layer.dart';
import '../site/tier_label.dart';
import 'cross_section_painter.dart';

/// Sondaj ekranı: yer altı kesiti, inen matkap, akan derinlik sayacı.
/// Ekrana dokunmak sondajı hızlandırır.
class DrillingScreen extends ConsumerStatefulWidget {
  const DrillingScreen({super.key, required this.siteId, required this.index});
  final String siteId;
  final int index;

  @override
  ConsumerState<DrillingScreen> createState() => _DrillingScreenState();
}

class _DrillingScreenState extends ConsumerState<DrillingScreen> with SingleTickerProviderStateMixin, FrameThrottle {
  int _taps = 0;
  bool _sawDrilling = false;
  double? _resultAt;
  final _oilSlot = ShaderSlot();
  final _geoSlot = ShaderSlot();
  final _geoCache = ShaderImageCache();

  @override
  void dispose() {
    _oilSlot.dispose();
    _geoCache.dispose();
    _geoSlot.dispose();
    super.dispose();
  }

  /// Büyük önbellek görüntüsünün piksel oranı grafik seviyesiyle sınırlı (bellek).
  double get _pixelRatio =>
      MediaQuery.devicePixelRatioOf(context).clamp(1.0, GraphicsMode.of(context).maxPixelRatio).toDouble();

  /// Jeoloji yalnızca boyut veya gece tonu (20 kademe) değişince çizilir.
  ui.Image? _geology(SiteConfig cfg, Size size, double night) {
    final program = ref.read(shaderBankProvider).geology;
    if (program == null || cfg.geology.length != 5) return null;
    final n = (night * 20).round() / 20;
    _geoCache.update(
      key: (size, cfg.id, n, _pixelRatio),
      size: size,
      pixelRatio: _pixelRatio,
      paint: (canvas, sz) => CrossSectionPainter.paintGeology(canvas, sz, _geoSlot.of(program)!, cfg.geology, n),
    );
    return _geoCache.image;
  }

  Parcel get _parcel => ref.read(gameControllerProvider).site(widget.siteId).parcels[widget.index];

  void _onTap(TapDownDetails d) {
    if (_parcel.status != ParcelStatus.drilling) return;
    final ok = ref.read(gameControllerProvider.notifier).tapDrill(widget.siteId, widget.index);
    if (!ok) return;
    _taps++;
    ref.read(feedbackProvider).light(SoundCue.drillTap);
    final layer = EffectLayer.maybeOf(context);
    layer?.burst(d.globalPosition, color: Palette.earthLight, count: 8, spread: 40);
    if (_taps % 5 == 0) layer?.floatText(d.globalPosition, 'Hızlan!', color: Palette.sunsetLight);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = GameConfig.site(widget.siteId);
    final parcel = ref.watch(gameControllerProvider.select((s) => s.site(widget.siteId).parcels[widget.index]));
    final dayNight = ref.watch(dayNightProvider);

    ref.listen(gameControllerProvider.select((s) => s.site(widget.siteId).parcels[widget.index].status), (prev, next) {
      if (prev != ParcelStatus.drilling) return;
      final fb = ref.read(feedbackProvider);
      if (next == ParcelStatus.producing) {
        fb.heavy(SoundCue.gusher);
      } else if (next == ParcelStatus.dry) {
        fb.medium(SoundCue.dryWell);
      }
    });

    final finished = parcel.status != ParcelStatus.drilling;
    final bool? outcome = switch (parcel.status) {
      ParcelStatus.producing => true,
      ParcelStatus.dry => false,
      _ => null,
    };

    return Scaffold(
      backgroundColor: Palette.oil,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Sondaj · ${cfg.name} · Parsel ${widget.index + 1}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.15)],
                ),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: finished ? null : _onTap,
        child: LayoutBuilder(
          builder: (context, box) => Builder(
            builder: (context) {
              final now = ref.read(clockProvider).nowMs();
              final progress = finished ? 1.0 : Economy.drillProgress(parcel, now);
              final depth = (progress * cfg.targetDepthM).floor();
              final remaining = Duration(milliseconds: (parcel.drillCompleteMs - now).clamp(0, 1 << 31));

              // Sonuç anını işaretle: ekran açıkken bittiyse sahnelenir,
              // önceden bitmişse doğrudan son hâli gösterilir.
              if (!finished) {
                _sawDrilling = true;
                _resultAt = null;
              } else {
                _resultAt ??= _sawDrilling ? seconds : seconds - 100;
              }
              final since = _resultAt == null ? 0.0 : seconds - _resultAt!;
              final oilRise = outcome == true ? (since / 1.4).clamp(0.0, 1.0) : 0.0;
              final showGusher = outcome == true && since > 1.3;
              final showCard = finished && since > (outcome == true ? 2.8 : 0.8);

              // Ekran sarsıntısı: fışkırma anında güçlü, kuru kuyuda hafif.
              var amp = 0.0;
              if (outcome == true && since > 1.2 && since < 3.2) amp = 7 * (1 - (since - 1.2) / 2.0);
              if (outcome == false && since < 0.5) amp = 3 * (1 - since / 0.5);
              if (!finished && progress > 0) amp = 0.6;
              final shake = Offset(sin(seconds * 93) * amp, cos(seconds * 71) * amp);
              final surfaceH = box.maxHeight * CrossSectionPainter.surfaceFraction;

              return Stack(
                children: [
                  Transform.translate(
                    offset: shake,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: surfaceH + 2,
                          child: const LandscapeBackdrop(seed: 3),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CrossSectionPainter(
                              progress: progress,
                              layers: cfg.geology,
                              targetDepthM: cfg.targetDepthM,
                              time: seconds,
                              outcome: outcome,
                              lightsOn: dayNight.lightsOn,
                              night: dayNight.night,
                              oilRise: oilRise,
                              oilShader: _oilSlot.of(ref.read(shaderBankProvider).oilSheen),
                              topInset: MediaQuery.paddingOf(context).top + kToolbarHeight + 6,
                              geoImage: _geology(cfg, Size(box.maxWidth, box.maxHeight), dayNight.night),
                            ),
                          ),
                        ),
                        if (showGusher)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: surfaceH,
                            child: IgnorePointer(
                              child: ref
                                  .read(gameVisualsProvider)
                                  .gusher(origin: const Offset(0.5, 0.97), groundY: 0.985),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                    left: 10,
                    child: _DepthCounter(
                      depth: depth,
                      target: cfg.targetDepthM,
                      layer: CrossSectionPainter.layerAt(cfg.geology, progress),
                    ),
                  ),
                  if (!finished)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 16,
                      child: _DrillStatus(parcel: parcel, progress: progress, remaining: remaining),
                    ),
                  if (showCard)
                    // Ortada: alttaki Usta balonuyla çakışmasın.
                    Align(
                      alignment: const Alignment(0, 0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ResultCard(siteId: widget.siteId, parcel: parcel),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DepthCounter extends StatelessWidget {
  const _DepthCounter({required this.depth, required this.target, required this.layer});
  final int depth;
  final int target;
  final String layer;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DERİNLİK', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5)),
          Text(
            '${Fmt.integer(depth)} m',
            key: const Key('depth_counter'),
            style: const TextStyle(
              color: Palette.gold,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text('Hedef ${Fmt.integer(target)} m · $layer', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DrillStatus extends StatelessWidget {
  const _DrillStatus({required this.parcel, required this.progress, required this.remaining});
  final Parcel parcel;
  final double progress;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final bonusFraction = parcel.drillDurationMs == 0 ? 0.0 : parcel.drillBonusMs / parcel.drillDurationMs;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app, color: Palette.sunsetLight),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ekrana dokun, matkap hızlansın!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                Fmt.clock(remaining),
                style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: Palette.sunset,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dokunuş hızlandırması: %${(bonusFraction * 100).round()} / %${(GameConfig.drillTapMaxFraction * 100).round()}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds, color: Colors.white10);
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.siteId, required this.parcel});
  final String siteId;
  final Parcel parcel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = GameConfig.site(siteId);
    final struck = parcel.status == ParcelStatus.producing;
    final color = struck ? Palette.success : Palette.danger;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            struck ? 'PETROL BULUNDU!' : 'KURU KUYU',
            key: const Key('drill_result'),
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1),
          ).animate().scale(begin: const Offset(0.5, 0.5), duration: 450.ms, curve: Curves.elasticOut),
          const SizedBox(height: 8),
          if (struck) ...[
            SizedBox(height: 90, width: 150, child: ref.read(gameVisualsProvider).pumpjack()),
            const SizedBox(height: 6),
            TierLabel(tier: parcel.tier),
            Text(
              'Üretim: ${Fmt.decimal(Economy.productionPerSecond(cfg, parcel), 2)} varil/sn',
              style: const TextStyle(color: Colors.white70),
            ),
          ] else
            Text(
              'Sondaj bedeli ${Fmt.money(cfg.drillCost)} toprağa gömüldü.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: 250,
            child: PremiumButton(
              key: const Key('drill_result_ok'),
              colors: struck ? Premium.gold : Premium.steel,
              foreground: struck ? const Color(0xFF3A2508) : Colors.white,
              icon: struck ? Icons.precision_manufacturing : Icons.arrow_back,
              label: struck ? 'At kafasını kur' : 'Sahaya dön',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.4, end: 0, duration: 350.ms, curve: Curves.easeOut).fadeIn();
  }
}
