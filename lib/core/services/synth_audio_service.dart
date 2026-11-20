import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'services.dart';
import 'synth.dart';

/// Kodla üretilen sesleri (bkz. [Synth]) çalan ses servisi. Ses dosyası
/// kullanılmaz; WAV byte'ları bellekte üretilip çalınır.
class SynthAudioService implements AudioService {
  SynthAudioService();

  /// Her ses için küçük bir oynatıcı havuzu: hızlı ardışık dokunuşlar
  /// birbirini kesmesin.
  static const _poolSize = 4;

  static const _volumes = {
    SoundCue.tap: 0.35,
    SoundCue.drillTap: 0.5,
    SoundCue.drillStart: 0.55,
    SoundCue.gusher: 0.7,
    SoundCue.dryWell: 0.5,
    SoundCue.collect: 0.55,
    SoundCue.sell: 0.5,
    SoundCue.upgrade: 0.45,
    SoundCue.unlock: 0.5,
    SoundCue.event: 0.45,
    SoundCue.repair: 0.45,
  };

  final _pools = <SoundCue, List<AudioPlayer>>{};
  final _next = <SoundCue, int>{};
  AudioPlayer? _ambient;
  bool _ambientWanted = false;
  bool _ambientPlaying = false;
  bool _unlocked = false;

  @override
  void play(SoundCue cue) {
    // Tarayıcılar sesi ancak ilk kullanıcı dokunuşundan sonra açar; ilk
    // efekt çaldığında ortam sesi de başlatılır.
    _unlocked = true;
    unawaited(_play(cue));
    if (_ambientWanted && !_ambientPlaying) unawaited(_startAmbient());
  }

  Future<void> _play(SoundCue cue) async {
    try {
      final pool = _pools.putIfAbsent(
        cue,
        () => List.generate(_poolSize, (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop)),
      );
      final i = _next[cue] ?? 0;
      _next[cue] = (i + 1) % pool.length;
      final player = pool[i];
      await player.stop();
      await player.play(BytesSource(Synth.wav(cue), mimeType: 'audio/wav'), volume: _volumes[cue] ?? 0.5);
    } catch (e) {
      // Hızlı ardışık dokunuşta yeni ses eskisini keser; bu beklenen bir durum.
      if (!e.toString().contains('AbortError')) debugPrint('Ses çalınamadı ($cue): $e');
    }
  }

  @override
  void setAmbient(bool on) {
    _ambientWanted = on;
    if (!on) {
      _ambientPlaying = false;
      unawaited(_ambient?.pause());
    } else if (_unlocked && !_ambientPlaying) {
      unawaited(_startAmbient());
    }
  }

  Future<void> _startAmbient() async {
    if (_ambientPlaying) return;
    _ambientPlaying = true;
    try {
      final p = _ambient ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await p.play(BytesSource(Synth.ambientLoop(), mimeType: 'audio/wav'), volume: 0.16);
    } catch (e) {
      _ambientPlaying = false;
      debugPrint('Ortam sesi başlatılamadı: $e');
    }
  }

  @override
  void dispose() {
    for (final pool in _pools.values) {
      for (final p in pool) {
        unawaited(p.dispose());
      }
    }
    unawaited(_ambient?.dispose());
  }
}
