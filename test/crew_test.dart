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
import 'package:batman_petrol_agasi/features/crew/crew_lines.dart';
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

    test('unvanlar görevin gerçek kariyer basamaklarıdır', () {
      expect(w('sondor').rankTitle, 'Sondör Muavini');
      expect(w('sondor', rank: 3).rankTitle, 'Başsondör');
      expect(w('sondor', rank: 4).rankTitle, 'Sondaj Amiri');
      expect(w('derikmen').rankTitle, 'Masa İşçisi');
      expect(w('derikmen', rank: 2).rankTitle, 'Derikmen');
      expect(w('derikmen', rank: 2).nextRankTitle, 'Kıdemli Derikmen');
      expect(w('mekanik', rank: 1).rankTitle, 'Makinist');
      expect(w('sondor', rank: 4).isMaxRank, isTrue);
      for (final role in GameConfig.crewRoles) {
        expect(role.ranks.length, greaterThanOrEqualTo(3), reason: role.id);
        expect(role.ranks.toSet().length, role.ranks.length, reason: '${role.id} tekrar eden unvan');
      }
    });

    test('herkesin kişisel adı var; adlar ekipte tekrar etmez', () {
      expect(GameConfig.crewNames, contains(w('sondor').displayName));
      expect(w('sondor').copyWith(name: 'Şeyhmus').fullTitle, 'Şeyhmus · Sondör Muavini');
      final used = <String>[];
      for (var id = 1; id <= 30; id++) {
        final n = Worker.pickName(id, used);
        expect(used, isNot(contains(n)));
        used.add(n);
      }
    });

    test('kule mühendisi tüm ekibin etkisini büyütür', () {
      final base = Crew.of([w('pompaci')]).productionMultiplier - 1;
      final led = Crew.of([w('pompaci'), w('muhendis', id: 2, rank: 4)]).productionMultiplier - 1;
      expect(led, closeTo(base * 1.25, 1e-9));
      final repair = Crew.of([w('mekanik')]).autoRepairSeconds!;
      final ledRepair = Crew.of([w('mekanik'), w('muhendis', id: 2, rank: 4)]).autoRepairSeconds!;
      expect(ledRepair, lessThan(repair));
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

      expect(c.read(gameControllerProvider).workerById(id)!.name, isNotNull);
      for (var i = 0; i < GameConfig.crewRole('derikmen').maxRank; i++) {
        expect(ctrl.promote(id), ActionResult.ok);
      }
      expect(ctrl.promote(id), ActionResult.maxLevel);
      expect(c.read(gameControllerProvider).workerById(id)!.rankTitle, 'Sondör Muavini');

      ctrl.rename(id, '  Hamit Usta ile Uzun Bir İsim Denemesi  ');
      expect(c.read(gameControllerProvider).workerById(id)!.displayName.length, Worker.maxNameLength);
      ctrl.rename(id, '');
      expect(GameConfig.crewNames, contains(c.read(gameControllerProvider).workerById(id)!.displayName));

      ctrl.setPlayerName('Hamit');
      expect(c.read(gameControllerProvider).address, 'Hamit Ağa');
      ctrl.setPlayerName('  ');
      expect(c.read(gameControllerProvider).address, 'ağam');

      for (var i = 0; i < 6; i++) {
        expect(ctrl.hire('isci'), ActionResult.ok);
      }
      expect(ctrl.hire('isci'), ActionResult.maxLevel);
      final workers = c.read(gameControllerProvider).workers;
      expect(workers.where((x) => x.roleId == 'isci').map((x) => x.number), [1, 2, 3, 4, 5, 6]);
      final names = workers.map((x) => x.displayName).toList();
      expect(names.toSet().length, names.length, reason: 'her işçinin farklı adı olmalı');
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

  group('Replikler', () {
    test('her görevin her rütbe kademesi için sohbeti var', () {
      for (final role in GameConfig.crewRoles) {
        for (var rank = 0; rank <= role.maxRank; rank++) {
          final worker = w(role.id, rank: rank);
          expect(CrewLines.chatFor(worker), isNotEmpty, reason: '${role.id} rütbe $rank');
          expect(CrewLines.of(role.id, CrewTopic.hired), isNotEmpty, reason: '${role.id} işe alım');
        }
      }
    });

    test('rütbe kademeleri doğru ayrılır', () {
      expect(CrewLines.tierOf(w('sondor')), RankTier.junior);
      expect(CrewLines.tierOf(w('sondor', rank: 2)), RankTier.mid);
      expect(CrewLines.tierOf(w('sondor', rank: 3)), RankTier.senior);
    });

    test('şablonlar doldurulur, boş yer tutucu kalmaz', () {
      final worker = w('sondor', rank: 3).copyWith(name: 'Reşit');
      for (final tier in RankTier.values) {
        for (final line in CrewLines.promoted[tier]!) {
          final t = CrewLines.fill(line, address: 'Hamit Ağa', worker: worker);
          expect(t, isNot(contains('{')));
          expect(t, contains('Başsondör'));
        }
      }
      expect(CrewLines.fill('{ağa}, kuyu durdu!', address: 'ağam'), 'Ağam, kuyu durdu!');
    });
  });
}
