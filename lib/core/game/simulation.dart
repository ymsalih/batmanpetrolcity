import 'dart:math';

import '../../config/game_config.dart';
import '../economy/economy.dart';
import '../models/active_effect.dart';
import '../models/game_state.dart';
import '../models/parcel.dart';
import '../models/site_state.dart';
import 'game_events.dart';

class SimulationResult {
  const SimulationResult(this.state, this.events, this.produced, this.drillsFinished, this.anyStorageFull);
  final GameState state;
  final List<GameEvent> events;
  final double produced;
  final int drillsFinished;
  final bool anyStorageFull;
}

/// Oyunun zaman ilerletme mantığı. Saf fonksiyondur: hem canlı tick hem de
/// çevrimdışı kazanç hesabı aynı kodu kullanır.
abstract final class Simulation {
  static SimulationResult advance(GameState s, int nowMs, Random rng, {bool allowRandomEvents = true}) {
    final fromMs = s.lastTickMs;
    if (nowMs <= fromMs) return SimulationResult(s, const [], 0, 0, false);

    final events = <GameEvent>[];
    final crew = s.crew;
    final prodMult = _effectiveProductionMultiplier(s.effects, fromMs, nowMs) * crew.productionMultiplier;
    final collectMs = crew.autoCollectSeconds == null ? null : (crew.autoCollectSeconds! * 1000).round();
    final repairMs = crew.autoRepairSeconds == null ? null : (crew.autoRepairSeconds! * 1000).round();
    var produced = 0.0;
    var drillsFinished = 0;
    var anyFull = false;
    var stats = s.stats;

    final sites = <String, SiteState>{};
    for (final entry in s.sites.entries) {
      final cfg = GameConfig.site(entry.key);
      final parcels = <Parcel>[];
      var changed = false;
      for (var i = 0; i < entry.value.parcels.length; i++) {
        var p = entry.value.parcels[i];
        var producingFrom = fromMs;

        if (p.status == ParcelStatus.drilling && nowMs >= p.drillCompleteMs) {
          drillsFinished++;
          changed = true;
          if (p.willStrike) {
            p = p.copyWith(status: ParcelStatus.producing);
            producingFrom = max(fromMs, p.drillCompleteMs);
          } else {
            p = p.copyWith(status: ParcelStatus.dry);
            stats = stats.copyWith(dryWells: stats.dryWells + 1);
          }
          events.add(
            DrillFinished(siteId: cfg.id, index: i, struck: p.willStrike, lost: p.willStrike ? 0 : cfg.drillCost),
          );
        }

        // Mekanikçi arızayı kendisi tamir eder.
        if (p.broken && repairMs != null && nowMs - p.brokenAtMs >= repairMs) {
          p = p.copyWith(broken: false, repairProgress: 0);
          changed = true;
          events.add(AutoRepaired(cfg.id, i));
        }

        if (p.status == ParcelStatus.producing && !p.broken) {
          var cap = Economy.storageCapacity(cfg, p);
          // Tanker şoförü uzun aralıklarda (ör. çevrimdışı) depoyu defalarca
          // boşaltır: depo sınırı uğrama sayısı kadar genişler.
          if (collectMs != null && nowMs - producingFrom > collectMs) {
            cap *= 1 + (nowMs - producingFrom) / collectMs;
          }
          final rate = Economy.productionPerSecond(cfg, p, effectMultiplier: prodMult);
          final next = Economy.fillStorage(
            stored: p.stored,
            ratePerSecond: rate,
            seconds: (nowMs - producingFrom) / 1000,
            capacity: cap,
          );
          final delta = next - p.stored;
          if (delta > 0) {
            produced += delta;
            p = p.copyWith(stored: next, totalProduced: p.totalProduced + delta);
            changed = true;
            if (next >= cap && collectMs == null) {
              anyFull = true;
              events.add(StorageFull(cfg.id, i));
            }
          }
        }
        parcels.add(p);
      }
      sites[entry.key] = changed ? entry.value.copyWith(parcels: parcels) : entry.value;
    }

    // Tanker şoförü: depoları boşaltıp ham petrolü getirir.
    var crude = s.crude;
    var nextCollect = s.nextAutoCollectMs;
    if (collectMs != null) {
      if (nextCollect <= 0) nextCollect = nowMs + collectMs;
      if (nowMs >= nextCollect) {
        var picked = 0.0;
        for (final entry in sites.entries.toList()) {
          final parcels = [...entry.value.parcels];
          var changed = false;
          for (var k = 0; k < parcels.length; k++) {
            final amount = parcels[k].stored.floorToDouble();
            if (amount < 1) continue;
            picked += amount;
            parcels[k] = parcels[k].copyWith(stored: parcels[k].stored - amount);
            changed = true;
          }
          if (changed) sites[entry.key] = entry.value.copyWith(parcels: parcels);
        }
        crude += picked;
        nextCollect = nowMs + collectMs;
        if (picked > 0) events.add(AutoCollected(picked));
      }
    }

    // Süresi biten etkiler.
    final effects = <ActiveEffect>[];
    for (final e in s.effects) {
      if (e.endMs > nowMs) {
        effects.add(e);
      } else {
        events.add(EffectEnded(e.title));
      }
    }

    // Petrol fiyatı.
    var price = s.oilPrice;
    var history = s.priceHistory;
    var nextPriceMs = s.nextPriceChangeMs;
    if (nowMs >= nextPriceMs) {
      final old = price;
      history = [...history];
      while (nowMs >= nextPriceMs) {
        price = Economy.nextPrice(price, rng);
        history.add(price);
        nextPriceMs += GameConfig.priceChangeSeconds * 1000;
      }
      if (history.length > GameConfig.priceHistoryLength) {
        history = history.sublist(history.length - GameConfig.priceHistoryLength);
      }
      events.add(PriceChanged(old, price));
    }

    var next = s.copyWith(
      sites: sites,
      crude: crude,
      nextAutoCollectMs: nextCollect,
      effects: effects,
      oilPrice: price,
      priceHistory: history,
      nextPriceChangeMs: nextPriceMs,
      lastTickMs: nowMs,
      stats: stats.copyWith(totalBarrels: stats.totalBarrels + produced),
    );

    // Rastgele olaylar.
    if (nowMs >= next.nextEventMs) {
      if (allowRandomEvents) {
        final r = startRandomEvent(next, nowMs, rng);
        next = r.$1;
        if (r.$2 != null) events.add(r.$2!);
      }
      next = next.copyWith(nextEventMs: nowMs + nextEventGapMs(rng));
    }

    return SimulationResult(next, events, produced, drillsFinished, anyFull);
  }

  static int nextEventGapMs(Random rng) {
    const minS = GameConfig.eventMinGapSeconds;
    const maxS = GameConfig.eventMaxGapSeconds;
    return (minS + rng.nextInt(maxS - minS + 1)) * 1000;
  }

  /// Ağırlıklı rastgele olay seçer ve uygular.
  static (GameState, RandomEventStarted?) startRandomEvent(GameState s, int nowMs, Random rng, {GameEventKind? force}) {
    final cfg = force != null ? GameConfig.event(force) : _pickEvent(rng);

    if (cfg.kind == GameEventKind.breakdown) {
      final candidates = s.allParcels
          .where((e) => e.parcel.status == ParcelStatus.producing && !e.parcel.broken)
          .toList();
      if (candidates.isEmpty) return (s, null);
      final pick = candidates[rng.nextInt(candidates.length)];
      final broken = pick.parcel.copyWith(broken: true, repairProgress: 0, brokenAtMs: nowMs);
      return (
        s.updateParcel(pick.siteId, pick.index, broken),
        RandomEventStarted(cfg, siteId: pick.siteId, index: pick.index),
      );
    }

    // Aynı türden etki zaten aktifse süresini yenile.
    final effects = s.effects.where((e) => e.eventKind != cfg.kind).toList()
      ..add(
        ActiveEffect(
          id: '${cfg.kind.name}_$nowMs',
          title: cfg.title,
          source: EffectSource.event,
          eventKind: cfg.kind,
          startMs: nowMs,
          endMs: nowMs + cfg.durationSeconds * 1000,
          productionMultiplier: cfg.productionMultiplier,
          priceMultiplier: cfg.priceMultiplier,
        ),
      );
    return (s.copyWith(effects: effects), RandomEventStarted(cfg));
  }

  static EventConfig _pickEvent(Random rng) {
    final total = GameConfig.events.fold(0.0, (a, e) => a + e.weight);
    var roll = rng.nextDouble() * total;
    for (final e in GameConfig.events) {
      roll -= e.weight;
      if (roll <= 0) return e;
    }
    return GameConfig.events.first;
  }

  /// Aralık boyunca etkilerin üretime ortalama etkisi (kısmi örtüşme dahil).
  static double _effectiveProductionMultiplier(List<ActiveEffect> effects, int fromMs, int toMs) {
    final span = toMs - fromMs;
    if (span <= 0) return 1;
    var mult = 1.0;
    for (final e in effects) {
      if (e.productionMultiplier == 1) continue;
      final overlap = min(e.endMs, toMs) - max(e.startMs, fromMs);
      if (overlap <= 0) continue;
      mult *= 1 + (e.productionMultiplier - 1) * (overlap / span);
    }
    return mult;
  }

  /// Uygulama açılışında/öne gelişinde geçen süreyi hesaplar.
  static (GameState, OfflineReport?) catchUp(GameState s, int nowMs, Random rng) {
    final awayMs = nowMs - s.lastTickMs;
    if (awayMs <= 0) return (s.copyWith(lastTickMs: nowMs), null);
    final cappedFrom = nowMs - Economy.offlineSeconds(s.lastTickMs, nowMs) * 1000;
    final result = advance(s.copyWith(lastTickMs: cappedFrom), nowMs, rng, allowRandomEvents: false);
    final report =
        awayMs >= GameConfig.offlineReportMinSeconds * 1000 && (result.produced > 0.5 || result.drillsFinished > 0)
        ? OfflineReport(
            away: Duration(milliseconds: awayMs),
            barrels: result.produced,
            drillsFinished: result.drillsFinished,
            storageFull: result.anyStorageFull,
          )
        : null;
    return (result.state, report);
  }
}
