import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'services.dart';
import 'synth.dart';

/// Kodla üretilen sesleri (bkz. [Synth]) çalan ses servisi. Ses dosyası
/// kullanılmaz; WAV byte'ları bellekte üretilip çalınır.
class SynthAudioService implements AudioService {
  SynthAudioService();

  /// Tüm efektlerin paylaştığı küçük oynatıcı havuzu. Her yerel oynatıcı
  /// telefonda bellek ve bir ses kanalı tutar; Android'de çok sayıda açmak
  /// çökmeye yol açabilir. 4 eşzamanlı efekt fazlasıyla yeterli.
  static const _poolSize = 4;

  /// Aynı efekt bu süreden sık tetiklenirse atlanır (hızlı dokunuşlar).
  static const _minGapMs = 45;

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
    SoundCue.message: 0.35,
    SoundCue.whoosh: 0.4,
    SoundCue.chime: 0.45,
  };

  final _pool = <AudioPlayer>[];
  var _next = 0;
  final _lastPlayed = <SoundCue, int>{};
  Uint8List? _ambientBytes;
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
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - (_lastPlayed[cue] ?? 0) < _minGapMs) return;
      _lastPlayed[cue] = now;
      if (_pool.length < _poolSize) _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      final player = _pool[_next % _pool.length];
      _next = (_next + 1) % _poolSize;
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
      final bytes = _ambientBytes ??= Synth.ambientLoop();
      await p.play(BytesSource(bytes, mimeType: 'audio/wav'), volume: 0.16);
    } catch (e) {
      _ambientPlaying = false;
      debugPrint('Ortam sesi başlatılamadı: $e');
    }
  }

  @override
  void dispose() {
    for (final p in _pool) {
      unawaited(p.dispose());
    }
    unawaited(_ambient?.dispose());
  }
}
