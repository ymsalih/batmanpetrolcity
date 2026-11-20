import 'dart:math';

import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/game/game_events.dart';
import 'package:batman_petrol_agasi/core/game/simulation.dart';
import 'package:batman_petrol_agasi/core/models/game_state.dart';
import 'package:batman_petrol_agasi/core/models/parcel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const t0 = 1000000000;
  final raman = GameConfig.site('raman');

  GameState withParcel(Parcel p) => GameState.initial(t0).updateParcel('raman', 0, p);

  test('sondaj bitince petrol bulunursa üretime geçer ve kalan sürede üretir', () {
    final s = withParcel(
      const Parcel(
        status: ParcelStatus.drilling,
        tier: YieldTier.medium,
        willStrike: true,
        drillStartMs: t0,
        drillDurationMs: 30000,
      ),
    );
    final r = Simulation.advance(s, t0 + 40000, Random(1), allowRandomEvents: false);
    final p = r.state.site('raman').parcels[0];
    expect(p.status, ParcelStatus.producing);
    // Tamamlandıktan sonraki 10 sn üretim.
    // Başlangıç morali üretime küçük bir katkı verir.
    expect(p.stored, closeTo(10 * raman.baseBarrelsPerSecond * s.moraleMultiplier, 1e-6));
    expect(r.events.whereType<DrillFinished>().single.struck, isTrue);
  });

  test('kuru kuyu istatistiğe yazılır', () {
    final s = withParcel(
      const Parcel(status: ParcelStatus.drilling, willStrike: false, drillStartMs: t0, drillDurationMs: 30000),
    );
    final r = Simulation.advance(s, t0 + 31000, Random(1), allowRandomEvents: false);
    expect(r.state.site('raman').parcels[0].status, ParcelStatus.dry);
    expect(r.state.stats.dryWells, 1);
  });

  test('Batman sıcağı üretimi %20 düşürür', () {
    final base = withParcel(const Parcel(status: ParcelStatus.producing, tier: YieldTier.medium));
    final (hot, _) = Simulation.startRandomEvent(base, t0, Random(1), force: GameEventKind.heatWave);
    final normal = Simulation.advance(base, t0 + 10000, Random(1), allowRandomEvents: false);
    final heat = Simulation.advance(hot, t0 + 10000, Random(1), allowRandomEvents: false);
    expect(heat.produced, closeTo(normal.produced * 0.8, 1e-6));
  });

  test('arıza üretimdeki bir kuyuyu durdurur', () {
    final s = withParcel(const Parcel(status: ParcelStatus.producing));
    final (broken, e) = Simulation.startRandomEvent(s, t0, Random(1), force: GameEventKind.breakdown);
    expect(broken.site('raman').parcels[0].broken, isTrue);
    expect(e?.index, 0);
  });

  test('çevrimdışı kazanç 4 saatle sınırlıdır ve rapor üretir', () {
    final s = withParcel(const Parcel(status: ParcelStatus.producing, storageLevel: 10));
    final (state, report) = Simulation.catchUp(s, t0 + 10 * 3600 * 1000, Random(1));
    expect(report, isNotNull);
    expect(report!.away.inHours, 10);
    // Üretim 4 saatlik üretimi veya depo kapasitesini aşamaz.
    final maxBy4h = raman.baseBarrelsPerSecond * GameConfig.offlineMaxSeconds;
    expect(report.barrels, lessThanOrEqualTo(maxBy4h));
    expect(state.site('raman').parcels[0].stored, report.barrels);
    expect(report.storageFull, isTrue);
  });

  test('kısa yoklukta rapor çıkmaz', () {
    final s = withParcel(const Parcel(status: ParcelStatus.producing));
    final (_, report) = Simulation.catchUp(s, t0 + 5000, Random(1));
    expect(report, isNull);
  });

  test('fiyat zamanı gelince değişir ve geçmiş sınırlı kalır', () {
    final s = GameState.initial(t0);
    final r = Simulation.advance(
      s,
      t0 + GameConfig.priceChangeSeconds * 1000 * 50,
      Random(3),
      allowRandomEvents: false,
    );
    expect(r.state.priceHistory.length, GameConfig.priceHistoryLength);
    expect(r.state.nextPriceChangeMs, greaterThan(t0 + GameConfig.priceChangeSeconds * 1000 * 50));
  });

  test('kayıt JSON gidiş-dönüşü durumu korur', () {
    final s = withParcel(const Parcel(status: ParcelStatus.producing, tier: YieldTier.high, pumpLevel: 3, stored: 12.5))
        .copyWith(money: 4242, crude: 17, tutorialDone: true);
    final restored = GameState.fromJson(s.toJson(), t0);
    final p = restored.site('raman').parcels[0];
    expect(restored.money, 4242);
    expect(restored.crude, 17);
    expect(restored.tutorialDone, isTrue);
    expect(p.tier, YieldTier.high);
    expect(p.pumpLevel, 3);
    expect(p.stored, 12.5);
    expect(restored.sites.length, GameConfig.sites.length);
  });

  test('moral üretimi etkiler ve zamanla dinlenme değerine döner', () {
    final base = withParcel(const Parcel(status: ParcelStatus.producing));
    final happy = Simulation.advance(base.copyWith(morale: 100), t0 + 10000, Random(1), allowRandomEvents: false);
    final sad = Simulation.advance(base.copyWith(morale: 0), t0 + 10000, Random(1), allowRandomEvents: false);
    expect(happy.produced / sad.produced, closeTo(1.05 / 0.95, 1e-3));
    final later = Simulation.advance(base.copyWith(morale: 100), t0 + 3600 * 1000, Random(1), allowRandomEvents: false);
    expect(later.state.morale, lessThan(100));
    expect(later.state.morale, greaterThan(GameConfig.moraleRest));
  });
}
