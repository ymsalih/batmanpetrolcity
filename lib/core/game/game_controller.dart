import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../economy/economy.dart';
import '../models/active_effect.dart';
import '../models/game_state.dart';
import '../models/parcel.dart';
import '../persistence/save_repository.dart';
import '../services/services.dart';
import 'game_events.dart';
import 'simulation.dart';

enum ActionResult { ok, notEnoughMoney, invalid, maxLevel }

final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => throw UnimplementedError('saveRepositoryProvider main() içinde override edilmeli'),
);

final randomProvider = Provider<Random>((ref) => Random());

/// Testlerde zamanlayıcıyı kapatmak için false yapılır.
final autoTickProvider = Provider<bool>((ref) => true);

final gameControllerProvider = NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  Timer? _timer;
  int _lastSaveMs = 0;
  final _events = StreamController<GameEvent>.broadcast();

  /// Arayüzün tepki verdiği olay akışı (Usta, ses, efektler).
  Stream<GameEvent> get events => _events.stream;

  Clock get _clock => ref.read(clockProvider);
  Random get _rng => ref.read(randomProvider);
  SaveRepository get _repo => ref.read(saveRepositoryProvider);
  int get now => _clock.nowMs();

  @override
  GameState build() {
    final nowMs = now;
    final saved = _repo.load();
    var s = saved == null ? GameState.initial(nowMs) : GameState.fromJson(saved, nowMs);
    final (caught, report) = Simulation.catchUp(s, nowMs, _rng);
    s = caught.copyWith(offlineReport: report);
    _lastSaveMs = nowMs;

    if (ref.read(autoTickProvider)) {
      _timer = Timer.periodic(const Duration(milliseconds: GameConfig.tickMs), (_) => tick());
    }
    ref.onDispose(() {
      _timer?.cancel();
      _events.close();
    });
    return s;
  }

  // ------------------------------------------------------------ Zaman

  void tick() {
    final nowMs = now;
    final result = Simulation.advance(state, nowMs, _rng);
    state = result.state;
    for (final e in result.events) {
      _emit(e);
    }
    if (nowMs - _lastSaveMs >= GameConfig.autoSaveSeconds * 1000) {
      save();
    }
  }

  /// Uygulama tekrar öne gelince: arka planda geçen süreyi hesapla.
  void resume() {
    final (caught, report) = Simulation.catchUp(state, now, _rng);
    state = caught.copyWith(offlineReport: report ?? state.offlineReport);
  }

  Future<void> save() async {
    _lastSaveMs = now;
    await _repo.save(state.copyWith(lastTickMs: now).toJson());
  }

  void _emit(GameEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  bool _spend(double cost) {
    if (state.money + 1e-9 < cost) return false;
    state = state.copyWith(money: state.money - cost);
    return true;
  }

  Parcel _parcel(String siteId, int index) => state.site(siteId).parcels[index];

  // ------------------------------------------------------------- Saha

  void selectSite(String siteId) {
    if (state.site(siteId).unlocked) state = state.copyWith(selectedSiteId: siteId);
  }

  ActionResult unlockSite(String siteId) {
    final site = state.site(siteId);
    if (site.unlocked) return ActionResult.invalid;
    if (!_spend(site.config.unlockCost)) return ActionResult.notEnoughMoney;
    state = state.copyWith(
      sites: {...state.sites, siteId: site.copyWith(unlocked: true)},
      selectedSiteId: siteId,
    );
    _emit(SiteUnlocked(siteId));
    return ActionResult.ok;
  }

  ActionResult survey(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (p.status != ParcelStatus.empty || p.surveyed) return ActionResult.invalid;
    if (!_spend(GameConfig.site(siteId).surveyCost)) return ActionResult.notEnoughMoney;
    state = state.updateParcel(siteId, index, p.copyWith(surveyed: true, tier: p.tier ?? Economy.rollTier(_rng)));
    return ActionResult.ok;
  }

  ActionResult startDrill(String siteId, int index) {
    final p = _parcel(siteId, index);
    final cfg = GameConfig.site(siteId);
    if (p.status != ParcelStatus.empty) return ActionResult.invalid;
    if (!_spend(cfg.drillCost)) return ActionResult.notEnoughMoney;
    final tier = p.tier ?? Economy.rollTier(_rng);
    final willStrike = _rng.nextDouble() >= Economy.dryChance(cfg, tier);
    state = state
        .updateParcel(
          siteId,
          index,
          p.copyWith(
            status: ParcelStatus.drilling,
            tier: tier,
            willStrike: willStrike,
            drillStartMs: now,
            drillDurationMs: Economy.drillDurationMs(cfg),
            drillBonusMs: 0,
          ),
        )
        .copyWith(stats: state.stats.copyWith(wellsDrilled: state.stats.wellsDrilled + 1));
    return ActionResult.ok;
  }

  /// Dokunuşla sondajı hızlandırır. Hızlanma uygulandıysa true.
  bool tapDrill(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (p.status != ParcelStatus.drilling) return false;
    final maxBonus = Economy.maxDrillBonusMs(p.drillDurationMs);
    if (p.drillBonusMs >= maxBonus) return false;
    final bonus = min(maxBonus, p.drillBonusMs + Economy.drillTapBonusMs(p.drillDurationMs));
    state = state.updateParcel(siteId, index, p.copyWith(drillBonusMs: bonus));
    if (now >= p.copyWith(drillBonusMs: bonus).drillCompleteMs) tick();
    return true;
  }

  ActionResult clearDry(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (p.status != ParcelStatus.dry) return ActionResult.invalid;
    if (!_spend(Economy.clearDryCost(GameConfig.site(siteId)))) return ActionResult.notEnoughMoney;
    state = state.updateParcel(siteId, index, Parcel.empty);
    return ActionResult.ok;
  }

  // ------------------------------------------------------------ Kuyu

  /// Kuyunun deposunu toplar; toplanan varil miktarını döndürür.
  double collect(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (p.status != ParcelStatus.producing || p.stored < 1) return 0;
    final amount = p.stored.floorToDouble();
    state = state
        .updateParcel(siteId, index, p.copyWith(stored: p.stored - amount))
        .copyWith(crude: state.crude + amount);
    return amount;
  }

  double collectAll() {
    var total = 0.0;
    for (final e in state.allParcels.toList()) {
      total += collect(e.siteId, e.index);
    }
    return total;
  }

  /// Arızalı kuyuya bir dokunuş. Tamir tamamlandıysa true.
  bool repairTap(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (!p.broken) return false;
    final progress = p.repairProgress + 1;
    final fixed = progress >= GameConfig.repairTaps;
    state = state.updateParcel(siteId, index, p.copyWith(broken: !fixed, repairProgress: fixed ? 0 : progress));
    return fixed;
  }

  ActionResult upgradePump(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (p.status != ParcelStatus.producing) return ActionResult.invalid;
    if (p.pumpLevel >= GameConfig.pumpMaxLevel) return ActionResult.maxLevel;
    if (!_spend(Economy.pumpUpgradeCost(GameConfig.site(siteId), p.pumpLevel))) return ActionResult.notEnoughMoney;
    state = state.updateParcel(siteId, index, p.copyWith(pumpLevel: p.pumpLevel + 1));
    return ActionResult.ok;
  }

  ActionResult upgradeStorage(String siteId, int index) {
    final p = _parcel(siteId, index);
    if (p.status != ParcelStatus.producing) return ActionResult.invalid;
    if (p.storageLevel >= GameConfig.storageMaxLevel) return ActionResult.maxLevel;
    if (!_spend(Economy.storageUpgradeCost(GameConfig.site(siteId), p.storageLevel))) {
      return ActionResult.notEnoughMoney;
    }
    state = state.updateParcel(siteId, index, p.copyWith(storageLevel: p.storageLevel + 1));
    return ActionResult.ok;
  }

  // ----------------------------------------------------------- Pazar

  double sellCrude(double barrels) {
    final amount = min(barrels, state.crude).floorToDouble();
    if (amount <= 0) return 0;
    final money = Economy.saleValue(amount, state.oilPrice, priceMultiplier: state.priceMultiplierAt(now));
    state = state.copyWith(
      crude: state.crude - amount,
      money: state.money + money,
      stats: state.stats.copyWith(totalEarned: state.stats.totalEarned + money),
    );
    _emit(Sold(amount, money));
    return money;
  }

  double sellRefined(double units) {
    final amount = min(units, state.refined).floorToDouble();
    if (amount <= 0) return 0;
    final money = Economy.saleValue(
      amount,
      Economy.refinedPrice(state.oilPrice),
      priceMultiplier: state.priceMultiplierAt(now),
    );
    state = state.copyWith(
      refined: state.refined - amount,
      money: state.money + money,
      stats: state.stats.copyWith(totalEarned: state.stats.totalEarned + money),
    );
    _emit(Sold(amount, money));
    return money;
  }

  ActionResult refine(double barrels) {
    if (!state.refineryUnlocked) return ActionResult.invalid;
    final amount = min(barrels, state.crude).floorToDouble();
    if (amount <= 0) return ActionResult.invalid;
    if (!_spend(Economy.refineCost(amount))) return ActionResult.notEnoughMoney;
    state = state.copyWith(
      crude: state.crude - amount,
      refined: state.refined + amount * GameConfig.refinedPerBarrel,
    );
    return ActionResult.ok;
  }

  // ------------------------------------------------------- Etkiler

  /// İleride reklam / GPS ödülleri için genel güçlendirme.
  void grantBoost({
    required String title,
    required EffectSource source,
    required Duration duration,
    double productionMultiplier = 1,
    double priceMultiplier = 1,
  }) {
    final t = now;
    state = state.copyWith(effects: [
      ...state.effects,
      ActiveEffect(
        id: '${source.name}_$t',
        title: title,
        source: source,
        startMs: t,
        endMs: t + duration.inMilliseconds,
        productionMultiplier: productionMultiplier,
        priceMultiplier: priceMultiplier,
      ),
    ]);
  }

  /// Hata ayıklama / test için olay tetikler.
  void triggerEvent(GameEventKind kind) {
    final (s, e) = Simulation.startRandomEvent(state, now, _rng, force: kind);
    state = s;
    if (e != null) _emit(e);
  }

  // ---------------------------------------------- Rehber & Ayarlar

  void dismissOfflineReport() => state = state.copyWith(clearOfflineReport: true);

  void advanceTutorial(int totalSteps) {
    final next = state.tutorialStep + 1;
    state = state.copyWith(tutorialStep: next, tutorialDone: next >= totalSteps);
  }

  void skipTutorial() => state = state.copyWith(tutorialDone: true);

  void restartTutorial() => state = state.copyWith(tutorialStep: 0, tutorialDone: false);

  void setHaptics(bool v) => state = state.copyWith(hapticsEnabled: v);

  void setSound(bool v) => state = state.copyWith(soundEnabled: v);

  Future<void> resetGame() async {
    await _repo.clear();
    state = GameState.initial(now);
    await save();
  }
}
