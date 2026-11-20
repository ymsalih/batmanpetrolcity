import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_controller.dart';
import 'services.dart';

/// Ses + titreşimi oyuncu ayarlarına göre tek noktadan tetikler.
class GameFeedback {
  GameFeedback(this._ref);
  final Ref _ref;

  bool get _haptics => _ref.read(gameControllerProvider).hapticsEnabled;
  bool get _sound => _ref.read(gameControllerProvider).soundEnabled;

  void _play(SoundCue cue) {
    if (_sound) _ref.read(audioServiceProvider).play(cue);
  }

  void light([SoundCue cue = SoundCue.tap]) {
    if (_haptics) _ref.read(hapticsServiceProvider).light();
    _play(cue);
  }

  void medium(SoundCue cue) {
    if (_haptics) _ref.read(hapticsServiceProvider).medium();
    _play(cue);
  }

  void heavy(SoundCue cue) {
    if (_haptics) _ref.read(hapticsServiceProvider).heavy();
    _play(cue);
  }
}

final feedbackProvider = Provider<GameFeedback>(GameFeedback.new);
