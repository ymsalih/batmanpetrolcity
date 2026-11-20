import 'dart:math';

import '../../config/game_config.dart';
import '../models/parcel.dart';

/// Saf ekonomi hesapları. Yan etkisi yoktur; unit testlerle doğrulanır.
abstract final class Economy {
  static double tierMultiplier(YieldTier? tier) => GameConfig.tierMultipliers[tier ?? YieldTier.medium]!;

  static double pumpMultiplier(int level) => 1 + GameConfig.pumpBonusPerLevel * level;

  static double storageMultiplier(int level) => 1 + GameConfig.storageBonusPerLevel * level;

  /// Bir kuyunun saniyedeki varil üretimi.
  static double productionPerSecond(SiteConfig site, Parcel parcel, {double effectMultiplier = 1}) {
    if (parcel.status != ParcelStatus.producing || parcel.broken) return 0;
    return site.baseBarrelsPerSecond *
        site.yieldMultiplier *
        tierMultiplier(parcel.tier) *
        pumpMultiplier(parcel.pumpLevel) *
        effectMultiplier;
  }

  static double storageCapacity(SiteConfig site, Parcel parcel) =>
      site.baseStorage * storageMultiplier(parcel.storageLevel);

  /// Depoyu [seconds] kadar doldurur, kapasiteyi aşmaz.
  static double fillStorage({
    required double stored,
    required double ratePerSecond,
    required double seconds,
    required double capacity,
  }) {
    if (seconds <= 0 || ratePerSecond <= 0) return min(stored, capacity);
    return min(capacity, stored + ratePerSecond * seconds);
  }

  static double pumpUpgradeCost(SiteConfig site, int currentLevel) =>
      (site.drillCost * GameConfig.pumpCostFactor * pow(GameConfig.pumpCostGrowth, currentLevel)).roundToDouble();

  static double storageUpgradeCost(SiteConfig site, int currentLevel) =>
      (site.drillCost * GameConfig.storageCostFactor * pow(GameConfig.storageCostGrowth, currentLevel)).roundToDouble();

  static double clearDryCost(SiteConfig site) => (site.drillCost * GameConfig.clearDryCostFactor).roundToDouble();

  static double dryChance(SiteConfig site, YieldTier tier) =>
      (site.dryChance * GameConfig.tierDryModifier[tier]!).clamp(0.0, GameConfig.maxDryChance);

  static YieldTier rollTier(Random rng) {
    final total = GameConfig.tierWeights.values.fold(0.0, (a, b) => a + b);
    var roll = rng.nextDouble() * total;
    for (final e in GameConfig.tierWeights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return YieldTier.medium;
  }

  static int drillDurationMs(SiteConfig site) =>
      site.drillSeconds.clamp(GameConfig.minDrillSeconds, GameConfig.maxDrillSeconds) * 1000;

  static int maxDrillBonusMs(int durationMs) => (durationMs * GameConfig.drillTapMaxFraction).round();

  static int drillTapBonusMs(int durationMs) => (durationMs * GameConfig.drillTapFraction).round();

  /// 0..1 sondaj ilerlemesi.
  static double drillProgress(Parcel parcel, int nowMs) {
    if (parcel.status != ParcelStatus.drilling || parcel.drillDurationMs <= 0) {
      return parcel.status == ParcelStatus.empty ? 0 : 1;
    }
    final elapsed = nowMs - parcel.drillStartMs + parcel.drillBonusMs;
    return (elapsed / parcel.drillDurationMs).clamp(0.0, 1.0);
  }

  /// Fiyat rastgele yürüyüş + ortalamaya dönüş.
  static double nextPrice(double current, Random rng) {
    final shock = (rng.nextDouble() * 2 - 1) * GameConfig.priceVolatility;
    final pull = (GameConfig.priceMean - current) / GameConfig.priceMean * GameConfig.priceReversion;
    final next = current * (1 + shock + pull);
    return double.parse(next.clamp(GameConfig.priceMin, GameConfig.priceMax).toStringAsFixed(2));
  }

  static double saleValue(double barrels, double price, {double priceMultiplier = 1}) =>
      barrels <= 0 ? 0 : barrels * price * priceMultiplier;

  static double refinedPrice(double oilPrice) => oilPrice * GameConfig.refinedPriceMultiplier;

  static double refineCost(double barrels) => barrels * GameConfig.refineCostPerBarrel;

  /// Çevrimdışı hesaplanacak süre (sn), [GameConfig.offlineMaxSeconds] ile sınırlı.
  static int offlineSeconds(int lastMs, int nowMs) => ((nowMs - lastMs) ~/ 1000).clamp(0, GameConfig.offlineMaxSeconds);
}
