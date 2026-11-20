import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/models/parcel.dart';
import 'package:batman_petrol_agasi/core/persistence/save_repository.dart';
import 'package:batman_petrol_agasi/core/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock implements Clock {
  FakeClock(this.ms);
  int ms;
  @override
  int nowMs() => ms;
}

void main() {
  late FakeClock clock;
  late InMemorySaveRepository repo;

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(clock),
      saveRepositoryProvider.overrideWithValue(repo),
      autoTickProvider.overrideWithValue(false),
    ],
  );

  setUp(() {
    clock = FakeClock(1000000000);
    repo = InMemorySaveRepository();
  });

  test('sondaj parayı düşer, yetersiz bakiyede reddedilir', () {
    final c = makeContainer();
    final ctrl = c.read(gameControllerProvider.notifier);
    final raman = GameConfig.site('raman');

    expect(ctrl.startDrill('raman', 0), ActionResult.ok);
    expect(c.read(gameControllerProvider).money, GameConfig.startMoney - raman.drillCost);
    expect(c.read(gameControllerProvider).site('raman').parcels[0].status, ParcelStatus.drilling);

    expect(ctrl.startDrill('raman', 0), ActionResult.invalid);
    ctrl.startDrill('raman', 1);
    ctrl.startDrill('raman', 2);
    expect(ctrl.startDrill('raman', 3), ActionResult.notEnoughMoney);
  });

  test('dokunuş sondajı en fazla sınır kadar hızlandırır', () {
    final c = makeContainer();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startDrill('raman', 0);
    for (var i = 0; i < 500; i++) {
      ctrl.tapDrill('raman', 0);
    }
    final p = c.read(gameControllerProvider).site('raman').parcels[0];
    expect(p.drillBonusMs, (p.drillDurationMs * GameConfig.drillTapMaxFraction).round());
  });

  test('topla → sat akışı ve kayıt/yükleme', () async {
    final c = makeContainer();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startDrill('raman', 0);
    // Petrol bulunacak şekilde sonucu sabitle.
    final s = c.read(gameControllerProvider);
    ctrl.state = s.updateParcel('raman', 0, s.site('raman').parcels[0].copyWith(willStrike: true));

    clock.ms += 60 * 1000;
    ctrl.tick();
    final collected = ctrl.collect('raman', 0);
    expect(collected, greaterThan(0));
    expect(c.read(gameControllerProvider).crude, collected);

    final before = c.read(gameControllerProvider).money;
    final earned = ctrl.sellCrude(collected);
    expect(earned, closeTo(collected * c.read(gameControllerProvider).oilPrice, 1e-6));
    expect(c.read(gameControllerProvider).money, closeTo(before + earned, 1e-6));
    expect(c.read(gameControllerProvider).crude, 0);

    await ctrl.save();
    c.dispose();

    // Yeniden açılış: kayıttan yüklenir.
    clock.ms += 1000;
    final c2 = makeContainer();
    final loaded = c2.read(gameControllerProvider);
    expect(loaded.money, closeTo(before + earned, 1e-6));
    expect(loaded.site('raman').parcels[0].status, ParcelStatus.producing);
  });

  test('rafineri kilitliyken rafine edilemez; açılınca edilir', () {
    final c = makeContainer();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.state = c.read(gameControllerProvider).copyWith(crude: 100, money: 1e6);
    expect(ctrl.refine(50), ActionResult.invalid);

    expect(ctrl.unlockSite('rafineri'), ActionResult.ok);
    expect(ctrl.refine(50), ActionResult.ok);
    final s = c.read(gameControllerProvider);
    expect(s.crude, 50);
    expect(s.refined, 50 * GameConfig.refinedPerBarrel);
  });

  test('arıza 3 dokunuşta tamir edilir', () {
    final c = makeContainer();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.state = c
        .read(gameControllerProvider)
        .updateParcel('raman', 4, const Parcel(status: ParcelStatus.producing, broken: true));
    expect(ctrl.repairTap('raman', 4), isFalse);
    expect(ctrl.repairTap('raman', 4), isFalse);
    expect(ctrl.repairTap('raman', 4), isTrue);
    expect(c.read(gameControllerProvider).site('raman').parcels[4].broken, isFalse);
  });

  test('uzun yokluktan sonra açılışta çevrimdışı rapor oluşur', () async {
    final c = makeContainer();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.state = c
        .read(gameControllerProvider)
        .updateParcel('raman', 0, const Parcel(status: ParcelStatus.producing, tier: YieldTier.medium));
    await ctrl.save();
    c.dispose();

    clock.ms += 2 * 3600 * 1000;
    final c2 = makeContainer();
    final report = c2.read(gameControllerProvider).offlineReport;
    expect(report, isNotNull);
    expect(report!.barrels, greaterThan(0));
  });
}
