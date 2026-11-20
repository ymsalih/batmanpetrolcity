import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../core/game/game_controller.dart';
import '../../core/game/game_events.dart';
import '../../core/models/chat.dart';
import '../../core/models/worker.dart';
import '../crew/crew_lines.dart';
import 'usta_lines.dart';

enum UstaMood { happy, excited, worried, thinking }

/// Konuşma balonundaki mesaj. [workerId] null ise konuşan Usta'dır.
class UstaMessage {
  const UstaMessage(this.text, this.mood, this.id, {this.workerId});
  final String text;
  final UstaMood mood;
  final int id;
  final int? workerId;
}

final ustaProvider = NotifierProvider<UstaController, UstaMessage?>(UstaController.new);

/// Oyun olaylarını dinleyip Usta'yı ve ekibi konuşturur. Bir olayla ilgili
/// görevde işçi varsa çoğunlukla o konuşur, yoksa Usta.
class UstaController extends Notifier<UstaMessage?> {
  final _rng = Random();
  Timer? _hide;
  int _seq = 0;
  int _lastStorageWarnMs = 0;
  int _lastCollectTalkMs = 0;

  @override
  UstaMessage? build() {
    final sub = ref.read(gameControllerProvider.notifier).events.listen(_onEvent);
    ref.onDispose(() {
      sub.cancel();
      _hide?.cancel();
    });
    return null;
  }

  String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  void say(
    String text, {
    UstaMood mood = UstaMood.happy,
    Duration duration = const Duration(seconds: 4),
    int? workerId,
    bool log = true,
  }) {
    _hide?.cancel();
    final game = ref.read(gameControllerProvider);
    final worker = workerId == null ? null : game.workerById(workerId);
    final filled = CrewLines.fill(text, address: game.address, worker: worker);
    state = UstaMessage(filled, mood, _seq++, workerId: workerId);
    _hide = Timer(duration, dismiss);
    // Olay replikleri saha grubunun geçmişine de düşer (balonda görüldüğü
    // için okunmamış sayılmaz).
    if (log && game.tutorialDone) {
      ref
          .read(gameControllerProvider.notifier)
          .addChat(
            speaker: worker == null ? ChatSpeaker.usta : ChatSpeaker.worker,
            text: filled,
            workerId: worker?.id,
            name: worker?.displayName ?? 'Usta',
            title: worker?.rankTitle,
            unread: false,
          );
    }
  }

  void dismiss() {
    _hide?.cancel();
    state = null;
  }

  void tip() => say(_pick(UstaLines.tips), mood: UstaMood.thinking, duration: const Duration(seconds: 5));

  void drillStarted() {
    if (_crewSay(const ['sondor', 'derikmen'], CrewTopic.drillStart, UstaMood.excited)) return;
    say(_pick(UstaLines.drillStart), mood: UstaMood.excited, duration: const Duration(seconds: 3));
  }

  void noMoney() => say(_pick(UstaLines.noMoney), mood: UstaMood.worried);

  /// Ekip ekranında karta dokununca işçi rütbesine uygun sohbet eder.
  void chatWith(Worker w) {
    final lines = CrewLines.chatFor(w);
    if (lines.isEmpty) return;
    say(_pick(lines), mood: UstaMood.happy, workerId: w.id, duration: const Duration(seconds: 4));
  }

  /// İlgili görevlerdeki işçilerden biri konuşursa true.
  bool _crewSay(
    List<String> roles,
    CrewTopic topic,
    UstaMood mood, {
    double chance = GameConfig.crewTalkChance,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (_rng.nextDouble() > chance) return false;
    final game = ref.read(gameControllerProvider);
    final candidates = <Worker>[
      for (final role in roles)
        if (CrewLines.of(role, topic).isNotEmpty) ...game.workers.where((w) => w.roleId == role),
    ];
    if (candidates.isEmpty) return false;
    final w = candidates[_rng.nextInt(candidates.length)];
    say(_pick(CrewLines.of(w.roleId, topic)), mood: mood, workerId: w.id, duration: duration);
    return true;
  }

  void _onEvent(GameEvent e) {
    switch (e) {
      case DrillFinished(:final struck):
        if (struck) {
          if (!_crewSay(const ['jeolog', 'sondor', 'derikmen', 'isci'], CrewTopic.strike, UstaMood.excited)) {
            say(_pick(UstaLines.strike), mood: UstaMood.excited);
          }
        } else if (!_crewSay(const ['jeolog', 'sondor'], CrewTopic.dry, UstaMood.worried)) {
          say(_pick(UstaLines.dry), mood: UstaMood.worried);
        }
      case RandomEventStarted(:final config):
        final (roles, topic, lines) = switch (config.kind) {
          GameEventKind.heatWave => (const ['isci', 'pompaci'], CrewTopic.heatWave, UstaLines.heatWave),
          GameEventKind.priceSpike => (const ['tuccar'], CrewTopic.priceSpike, UstaLines.priceSpike),
          GameEventKind.breakdown => (const ['mekanik', 'isci'], CrewTopic.breakdown, UstaLines.breakdown),
        };
        final mood = config.kind == GameEventKind.priceSpike ? UstaMood.excited : UstaMood.worried;
        if (!_crewSay(roles, topic, mood, duration: const Duration(seconds: 5))) {
          say(_pick(lines), mood: mood, duration: const Duration(seconds: 5));
        }
      case StorageFull():
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastStorageWarnMs > 60000) {
          _lastStorageWarnMs = now;
          if (!_crewSay(const ['sofor', 'pompaci'], CrewTopic.storageFull, UstaMood.thinking)) {
            say(_pick(UstaLines.storageFull), mood: UstaMood.thinking);
          }
        }
      case SiteUnlocked():
        say(_pick(UstaLines.unlock), mood: UstaMood.excited);
      case Sold(:final money) when money > 0:
        if (!_crewSay(const ['tuccar'], CrewTopic.sold, UstaMood.happy, chance: 0.5) && _rng.nextDouble() < 0.35) {
          say(_pick(UstaLines.sold));
        }
      case AutoRepaired():
        _crewSay(const ['mekanik'], CrewTopic.repaired, UstaMood.happy, chance: 0.8);
      case AutoCollected():
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastCollectTalkMs > 90000) {
          _lastCollectTalkMs = now;
          _crewSay(const ['sofor'], CrewTopic.collected, UstaMood.happy, chance: 0.7);
        }
      case CrewChanged(:final workerId, :final promoted):
        final w = ref.read(gameControllerProvider).workerById(workerId);
        if (w == null) return;
        final lines = promoted ? CrewLines.promotedFor(w) : CrewLines.of(w.roleId, CrewTopic.hired);
        if (lines.isNotEmpty) say(_pick(lines), mood: UstaMood.excited, workerId: w.id);
      case _:
        break;
    }
  }
}
