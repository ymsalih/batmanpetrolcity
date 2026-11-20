import 'dart:math';

import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/economy/economy.dart';
import 'package:batman_petrol_agasi/core/models/parcel.dart';
import 'package:batman_petrol_agasi/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raman = GameConfig.site('raman');
  const producing = Parcel(status: ParcelStatus.producing, tier: YieldTier.medium);

  group('Üretim', () {
    test('saniyedeki üretim = taban x saha x verim x pompa', () {
      expect(Economy.productionPerSecond(raman, producing), closeTo(0.5, 1e-9));
      final upgraded = producing.copyWith(pumpLevel: 2, tier: YieldTier.high);
      // 0.5 * 1.0 * 1.6 * (1 + 0.35*2)
      expect(Economy.productionPerSecond(raman, upgraded), closeTo(0.5 * 1.6 * 1.7, 1e-9));
    });

    test('olay çarpanı üretime uygulanır', () {
      expect(Economy.productionPerSecond(raman, producing, effectMultiplier: 0.8), closeTo(0.4, 1e-9));
    });

    test('arızalı veya üretimde olmayan kuyu üretmez', () {
      expect(Economy.productionPerSecond(raman, producing.copyWith(broken: true)), 0);
      expect(Economy.productionPerSecond(raman, Parcel.empty), 0);
      expect(Economy.productionPerSecond(raman, const Parcel(status: ParcelStatus.dry)), 0);
    });

    test('depo kapasitesi aşılmaz', () {
      final cap = Economy.storageCapacity(raman, producing);
      expect(cap, raman.baseStorage);
      expect(Economy.fillStorage(stored: 10, ratePerSecond: 1, seconds: 5, capacity: cap), 15);
      expect(Economy.fillStorage(stored: 10, ratePerSecond: 1, seconds: 10000, capacity: cap), cap);
      expect(Economy.storageCapacity(raman, producing.copyWith(storageLevel: 2)), raman.baseStorage * 2);
    });
  });

  group('Yükseltme bedelleri', () {
    test('her seviyede üstel artar', () {
      final c0 = Economy.pumpUpgradeCost(raman, 0);
      final c1 = Economy.pumpUpgradeCost(raman, 1);
      final c2 = Economy.pumpUpgradeCost(raman, 2);
      expect(c0, raman.drillCost * GameConfig.pumpCostFactor);
      expect(c1, closeTo(c0 * GameConfig.pumpCostGrowth, 1));
      expect(c2, greaterThan(c1));
      expect(Economy.storageUpgradeCost(raman, 0), raman.drillCost * GameConfig.storageCostFactor);
    });
  });

  group('Sondaj', () {
    test('kuru kuyu ihtimali verime göre değişir ve sınırlıdır', () {
      expect(Economy.dryChance(raman, YieldTier.high), lessThan(Economy.dryChance(raman, YieldTier.low)));
      for (final s in GameConfig.sites) {
        for (final t in YieldTier.values) {
          expect(Economy.dryChance(s, t), inInclusiveRange(0, GameConfig.maxDryChance));
        }
      }
    });

    test('sondaj süresi config sınırları içinde', () {
      for (final s in GameConfig.sites) {
        final ms = Economy.drillDurationMs(s);
        expect(ms, inInclusiveRange(GameConfig.minDrillSeconds * 1000, GameConfig.maxDrillSeconds * 1000));
      }
    });

    test('ilerleme dokunuş bonusunu hesaba katar', () {
      const p = Parcel(status: ParcelStatus.drilling, drillStartMs: 1000, drillDurationMs: 10000);
      expect(Economy.drillProgress(p, 1000), 0);
      expect(Economy.drillProgress(p, 6000), closeTo(0.5, 1e-9));
      expect(Economy.drillProgress(p.copyWith(drillBonusMs: 2000), 6000), closeTo(0.7, 1e-9));
      expect(Economy.drillProgress(p, 99999), 1);
    });

    test('verim zarı ağırlıklara yakın dağılır', () {
      final rng = Random(42);
      final counts = {for (final t in YieldTier.values) t: 0};
      for (var i = 0; i < 10000; i++) {
        final t = Economy.rollTier(rng);
        counts[t] = counts[t]! + 1;
      }
      expect(counts[YieldTier.high]! / 10000, closeTo(GameConfig.tierWeights[YieldTier.high]!, 0.03));
    });
  });

  group('Pazar', () {
    test('fiyat her zaman sınırlar içinde kalır', () {
      final rng = Random(1);
      var price = GameConfig.priceStart;
      for (var i = 0; i < 5000; i++) {
        price = Economy.nextPrice(price, rng);
        expect(price, inInclusiveRange(GameConfig.priceMin, GameConfig.priceMax));
      }
    });

    test('satış değeri fiyat çarpanını uygular', () {
      expect(Economy.saleValue(10, 40), 400);
      expect(Economy.saleValue(10, 40, priceMultiplier: 2), 800);
      expect(Economy.saleValue(0, 40), 0);
      expect(Economy.saleValue(-5, 40), 0);
    });

    test('rafine ürün daha değerli', () {
      expect(Economy.refinedPrice(40), 40 * GameConfig.refinedPriceMultiplier);
      expect(Economy.refineCost(10), 10 * GameConfig.refineCostPerBarrel);
    });
  });

  group('Çevrimdışı', () {
    test('en fazla 4 saat hesaplanır', () {
      expect(Economy.offlineSeconds(0, 60 * 1000), 60);
      expect(Economy.offlineSeconds(0, 24 * 3600 * 1000), GameConfig.offlineMaxSeconds);
      expect(Economy.offlineSeconds(1000, 0), 0);
    });
  });

  group('Biçimlendirme', () {
    test('Türkçe sayı biçimi', () {
      expect(Fmt.integer(1234567), '1.234.567');
      expect(Fmt.compact(15000), '15.000');
      expect(Fmt.compact(2500000), '2,50 Mn');
      expect(Fmt.decimal(3.14159, 2), '3,14');
      expect(Fmt.money(1500), '1.500 ₺');
      expect(Fmt.upperTr('Ekibin işe alım'), 'EKİBİN İŞE ALIM');
      expect(Fmt.lowerTr('IŞIK İZİ'), 'ışık izi');
    });
  });
}
