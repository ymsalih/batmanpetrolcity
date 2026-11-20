import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../core/game/game_controller.dart';
import '../../core/game/game_events.dart';
import 'usta_lines.dart';

enum UstaMood { happy, excited, worried, thinking }

class UstaMessage {
  const UstaMessage(this.text, this.mood, this.id);
  final String text;
  final UstaMood mood;
  final int id;
}

final ustaProvider = NotifierProvider<UstaController, UstaMessage?>(UstaController.new);

/// Oyun olaylarını dinleyip Usta'yı konuşturur.
class UstaController extends Notifier<UstaMessage?> {
  final _rng = Random();
  Timer? _hide;
  int _seq = 0;
  int _lastStorageWarnMs = 0;

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

  void say(String text, {UstaMood mood = UstaMood.happy, Duration duration = const Duration(seconds: 4)}) {
    _hide?.cancel();
    state = UstaMessage(text, mood, _seq++);
    _hide = Timer(duration, dismiss);
  }

  void dismiss() {
    _hide?.cancel();
    state = null;
  }

  void tip() => say(_pick(UstaLines.tips), mood: UstaMood.thinking, duration: const Duration(seconds: 5));
  void drillStarted() => say(_pick(UstaLines.drillStart), mood: UstaMood.excited, duration: const Duration(seconds: 3));
  void noMoney() => say(_pick(UstaLines.noMoney), mood: UstaMood.worried);

  void _onEvent(GameEvent e) {
    switch (e) {
      case DrillFinished(:final struck):
        struck
            ? say(_pick(UstaLines.strike), mood: UstaMood.excited)
            : say(_pick(UstaLines.dry), mood: UstaMood.worried);
      case RandomEventStarted(:final config):
        final lines = switch (config.kind) {
          GameEventKind.heatWave => UstaLines.heatWave,
          GameEventKind.priceSpike => UstaLines.priceSpike,
          GameEventKind.breakdown => UstaLines.breakdown,
        };
        say(_pick(lines),
            mood: config.kind == GameEventKind.priceSpike ? UstaMood.excited : UstaMood.worried,
            duration: const Duration(seconds: 5));
      case StorageFull():
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastStorageWarnMs > 60000) {
          _lastStorageWarnMs = now;
          say(_pick(UstaLines.storageFull), mood: UstaMood.thinking);
        }
      case SiteUnlocked():
        say(_pick(UstaLines.unlock), mood: UstaMood.excited);
      case Sold(:final money) when money > 0:
        if (_rng.nextDouble() < 0.35) say(_pick(UstaLines.sold));
      case _:
        break;
    }
  }
}
