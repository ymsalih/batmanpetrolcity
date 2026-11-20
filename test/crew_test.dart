import 'dart:math';

import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/economy/crew.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/game/game_events.dart';
import 'package:batman_petrol_agasi/core/game/simulation.dart';
import 'package:batman_petrol_agasi/core/models/game_state.dart';
import 'package:batman_petrol_agasi/core/models/parcel.dart';
import 'package:batman_petrol_agasi/core/models/worker.dart';
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

Worker w(String role, {int rank = 0, int id = 1, int number = 1}) =>
    Worker(id: id, roleId: role, number: number, rank: rank);

void main() {
  const t0 = 1000000000;

  group('Ekip etkileri', () {
    test('boş ekip etkisizdir', () {
      final c = Crew.of(const []);
      expect(c.productionMultiplier, 1);
      expect(c.autoCollectSeconds, isNull);
    });

    test('rütbe yükseldikçe etki büyür', () {
      final r0 = Crew.of([w('pompaci')]).productionMultiplier;
      final r4 = Crew.of([w('pompaci', rank: 4)]).productionMultiplier;
      expect(r0, closeTo(1.08, 1e-9));
      expect(r4, closeTo(1 + 0.08 * 5, 1e-9));
    });

    test('etkiler toplanır ve sınırlanır', () {
      final c = Crew.of([
        w('isci', id: 1),
        w('isci', id: 2, number: 2),
        w('sondor', rank: 4, id: 3),
        w('jeolog', rank: 4, id: 4),
      ]);
      expect(c.productionMultiplier, closeTo(1.06, 1e-9));
      expect(c.drillTimeMultiplier, closeTo(0.6, 1e-9));
      expect(c.dryMultiplier, greaterThanOrEqualTo(0.4));
    });

    test('mekanikçi ve şoför rütbeyle daha sık çalışır', () {
      final m0 = Crew.of([w('mekanik')]).autoRepairSeconds!;
      final m4 = Crew.of([w('mekanik', rank: 4)]).autoRepairSeconds!;
      expect(m4, lessThan(m0));
      expect(Crew.of([w('sofor', rank: 4)]).autoCollectSeconds, greaterThanOrEqualTo(10));
    });

    test('işe alma ve terfi bedelleri artar', () {
      final role = GameConfig.crewRole('isci');
      expect(Crew.hireCost(role, 1), greaterThan(Crew.hireCost(role, 0)));
      expect(Crew.promoteCost(w('isci', rank: 1)), greaterThan(Crew.promoteCost(w('isci'))));
    });

    test('varsayılan ad görev adıdır; isim verilince o görünür', () {
      expect(w('derikmen').displayName, 'Derikmen');
      expect(w('isci', number: 3).displayName, 'İşçi 3');
      expect(w('sondor').copyWith(name: 'Şeyhmus').displayName, 'Şeyhmus');
      expect(w('sondor', rank: 2).subtitle, 'Sondör · Usta');
    });
  });

  group('Simülasyonda ekip', () {
    GameState producing({List<Worker> workers = const []}) =>
        GameState.initial(t0)
            .updateParcel('raman', 0, const Parcel(status: ParcelStatus.producing))
            .copyWith(workers: workers);

    test('pompacı üretimi artırır', () {
      final base = Simulation.advance(producing(), t0 + 10000, Random(1), allowRandomEvents: false);
      final crew = Simulation.advance(
        producing(workers: [w('pompaci')]),
        t0 + 10000,
        Random(1),
        allowRandomEvents: false,
      );
      expect(crew.produced, closeTo(base.produced * 1.08, 1e-6));
    });

    test('tanker şoförü depoları boşaltır', () {
      final s0 = producing(workers: [w('sofor')]).copyWith(nextAutoCollectMs: t0 + 5000);
      final r = Simulation.advance(s0, t0 + 10000, Random(1), allowRandomEvents: false);
      expect(r.state.crude, greaterThan(0));
      expect(r.state.site('raman').parcels[0].stored, lessThan(1));
      expect(r.events.whereType<AutoCollected>(), isNotEmpty);
    });

    test('şoför varken çevrimdışı üretim depo sınırına takılmaz', () {
      final without = Simulation.catchUp(producing(), t0 + 3600 * 1000, Random(1)).$2!;
      final withDriver = Simulation.catchUp(producing(workers: [w('sofor')]), t0 + 3600 * 1000, Random(1)).$2!;
      expect(withDriver.barrels, greaterThan(without.barrels * 5));
    });

    test('mekanikçi arızayı kendisi tamir eder', () {
      final s0 = GameState.initial(t0)
          .updateParcel('raman', 0, const Parcel(status: ParcelStatus.producing, broken: true, brokenAtMs: t0))
          .copyWith(workers: [w('mekanik')]);
      final early = Simulation.advance(s0, t0 + 10000, Random(1), allowRandomEvents: false);
      expect(early.state.site('raman').parcels[0].broken, isTrue);
      final late = Simulation.advance(s0, t0 + 80000, Random(1), allowRandomEvents: false);
      expect(late.state.site('raman').parcels[0].broken, isFalse);
    });

    test('ekip kayıttan aynen geri yüklenir', () {
      final s = GameState.initial(t0).copyWith(
        workers: [
          w('derikmen', rank: 2).copyWith(name: 'Reşit'),
          w('isci', id: 2, number: 2),
        ],
        nextWorkerId: 3,
      );
      final r = GameState.fromJson(s.toJson(), t0);
      expect(r.workers.length, 2);
      expect(r.workers.first.displayName, 'Reşit');
      expect(r.workers.first.rank, 2);
      expect(r.nextWorkerId, 3);
    });
  });

  group('Kontrolcü', () {
    ProviderContainer make() => ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(t0)),
        saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        autoTickProvider.overrideWithValue(false),
      ],
    );

    test('işe al, terfi ettir, isim ver; sınırlar uygulanır', () {
      final c = make();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.state = c.read(gameControllerProvider).copyWith(money: 1e7);

      expect(ctrl.hire('derikmen'), ActionResult.ok);
      expect(ctrl.hire('derikmen'), ActionResult.maxLevel);
      final id = c.read(gameControllerProvider).workers.single.id;

      for (var i = 0; i < GameConfig.crewRanks.length - 1; i++) {
        expect(ctrl.promote(id), ActionResult.ok);
      }
      expect(ctrl.promote(id), ActionResult.maxLevel);
      expect(c.read(gameControllerProvider).workerById(id)!.rankTitle, 'Şef');

      ctrl.rename(id, '  Hamit Usta ile Uzun Bir İsim Denemesi  ');
      expect(c.read(gameControllerProvider).workerById(id)!.displayName.length, Worker.maxNameLength);
      ctrl.rename(id, '');
      expect(c.read(gameControllerProvider).workerById(id)!.displayName, 'Derikmen');

      for (var i = 0; i < 6; i++) {
        expect(ctrl.hire('isci'), ActionResult.ok);
      }
      expect(ctrl.hire('isci'), ActionResult.maxLevel);
      final numbers = c.read(gameControllerProvider).workers.where((x) => x.roleId == 'isci').map((x) => x.number);
      expect(numbers, [1, 2, 3, 4, 5, 6]);
    });

    test('yetersiz bakiyede işe alınamaz', () {
      final c = make();
      final ctrl = c.read(gameControllerProvider.notifier);
      expect(ctrl.hire('tuccar'), ActionResult.notEnoughMoney);
      expect(c.read(gameControllerProvider).workers, isEmpty);
    });

    test('sondör sondaj süresini kısaltır', () {
      final c = make();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.state = c.read(gameControllerProvider).copyWith(money: 1e6, workers: [w('sondor', rank: 4)]);
      ctrl.startDrill('raman', 0);
      final p = c.read(gameControllerProvider).site('raman').parcels[0];
      expect(p.drillDurationMs, (GameConfig.site('raman').drillSeconds * 1000 * 0.6).round());
    });
  });
}
