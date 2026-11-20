import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/economy/economy.dart';
import '../../core/game/game_controller.dart';
import '../../core/services/feedback.dart';
import '../../core/services/services.dart';
import '../../core/ui/premium.dart';
import '../../core/ui/premium_backdrop.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/effect_layer.dart';
import '../mascot/usta_controller.dart';
import 'price_chart_painter.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final now = s.lastTickMs;
    final eventMult = s.priceMultiplierAt(now);
    // Tüccar bonusu satış değerine dahil.
    final priceMult = eventMult * s.crew.priceMultiplier;
    final history = s.priceHistory;
    final prev = history.length > 1 ? history[history.length - 2] : s.oilPrice;
    final change = prev == 0 ? 0.0 : (s.oilPrice - prev) / prev * 100;
    final nextChange = Duration(milliseconds: (s.nextPriceChangeMs - now).clamp(0, 1 << 31));

    final pad = MediaQuery.paddingOf(context);
    return PremiumBackdrop(
      seed: 13,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, pad.bottom + 16),
        children: [
          // Fiyat kartı
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ham petrol', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sonraki değişim ${Fmt.clock(nextChange)}',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.price(s.oilPrice),
                        key: const Key('oil_price'),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const Text(' /varil', style: TextStyle(color: Colors.white54)),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${change >= 0 ? '▲' : '▼'} %${Fmt.decimal(change.abs(), 1)}',
                          style: TextStyle(
                            color: change >= 0 ? Palette.success : Palette.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (eventMult != 1)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Palette.success, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Fiyat uçtu! Satışlar x${Fmt.decimal(eventMult, 0)}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: CustomPaint(size: Size.infinite, painter: PriceChartPainter(history)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SellCard(
            title: 'Ham petrol sat',
            icon: Icons.oil_barrel,
            stock: s.crude,
            unitPrice: s.oilPrice * priceMult,
            unitLabel: 'varil',
            onSell: (amount) => ref.read(gameControllerProvider.notifier).sellCrude(amount),
            keyPrefix: 'crude',
          ),
          const SizedBox(height: 12),
          if (s.refineryUnlocked) ...[
            const _RefineCard(),
            const SizedBox(height: 12),
            _SellCard(
              title: 'Akaryakıt sat',
              icon: Icons.local_gas_station,
              stock: s.refined,
              unitPrice: Economy.refinedPrice(s.oilPrice) * priceMult,
              unitLabel: 'birim',
              onSell: (amount) => ref.read(gameControllerProvider.notifier).sellRefined(amount),
              keyPrefix: 'refined',
            ),
          ] else
            _Card(
              child: Row(
                children: [
                  const Icon(Icons.factory, color: Colors.white38, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rafineri kilitli. Haritadan "${GameConfig.sites.firstWhere((c) => c.unlocksRefinery).name}" '
                      'açılınca varilleri akaryakıta çevirip x${Fmt.decimal(GameConfig.refinedPriceMultiplier, 1)} '
                      'fiyata satabilirsin.',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassPanel(radius: 22, blur: 0, child: child);
}

class _SellCard extends ConsumerWidget {
  const _SellCard({
    required this.title,
    required this.icon,
    required this.stock,
    required this.unitPrice,
    required this.unitLabel,
    required this.onSell,
    required this.keyPrefix,
  });

  final String title;
  final IconData icon;
  final double stock;
  final double unitPrice;
  final String unitLabel;
  final double Function(double amount) onSell;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whole = stock.floorToDouble();

    void sell(BuildContext ctx, double amount) {
      final money = onSell(amount);
      if (money <= 0) return;
      ref.read(feedbackProvider).medium(SoundCue.sell);
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null) {
        final c = box.localToGlobal(box.size.center(Offset.zero));
        EffectLayer.maybeOf(context)
          ?..floatText(c - const Offset(0, 24), '+${Fmt.money(money)}', color: Palette.gold)
          ..burst(c, color: Palette.gold, count: 12);
      }
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Palette.sunsetLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: Text(
                  'Stok: ${Fmt.compact(whole)} $unitLabel',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hepsinin değeri: ${Fmt.money(whole * unitPrice)}  (${Fmt.price(unitPrice)}/$unitLabel)',
            style: const TextStyle(color: Palette.gold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (ctx) => PremiumButton(
                    key: Key('${keyPrefix}_sell_half'),
                    colors: Premium.steel,
                    shine: false,
                    height: 48,
                    label: 'Yarısını sat',
                    onPressed: whole >= 2 ? () => sell(ctx, (whole / 2).floorToDouble()) : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (ctx) => PremiumButton(
                    key: Key('${keyPrefix}_sell_all'),
                    height: 48,
                    icon: Icons.sell,
                    label: 'Hepsini sat',
                    onPressed: whole >= 1 ? () => sell(ctx, whole) : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefineCard extends ConsumerWidget {
  const _RefineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crude = ref.watch(gameControllerProvider.select((s) => s.crude.floorToDouble()));
    final cost = Economy.refineCost(crude);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.factory, color: Palette.lamp),
              SizedBox(width: 8),
              Text('Rafineri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '1 varil → ${Fmt.decimal(GameConfig.refinedPerBarrel, 1)} birim akaryakıt. '
            'İşleme bedeli ${Fmt.money(GameConfig.refineCostPerBarrel)}/varil. '
            'Akaryakıt ham petrolün x${Fmt.decimal(GameConfig.refinedPriceMultiplier, 1)} fiyatına satılır.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          PremiumButton(
            key: const Key('refine_all'),
            colors: Premium.steel,
            icon: Icons.autorenew,
            label: '${Fmt.compact(crude)} varili rafine et · ${Fmt.money(cost)}',
            onPressed: crude < 1
                ? null
                : () {
                    final r = ref.read(gameControllerProvider.notifier).refine(crude);
                    if (r == ActionResult.notEnoughMoney) {
                      ref.read(ustaProvider.notifier).noMoney();
                    } else if (r == ActionResult.ok) {
                      ref.read(feedbackProvider).medium(SoundCue.upgrade);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
