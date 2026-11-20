import 'dart:math';
import 'dart:typed_data';

import 'services.dart';

/// Ses dosyası kullanmadan, ses efektlerini matematiksel olarak üretir
/// (16-bit mono PCM WAV). Bir ses çalma paketi eklendiğinde [AudioService]
/// uygulaması bu byte'ları çalar.
abstract final class Synth {
  static const sampleRate = 22050;

  static final _cache = <SoundCue, Uint8List>{};

  static Uint8List wav(SoundCue cue) => _cache.putIfAbsent(cue, () => encodeWav(samples(cue)));

  /// -1..1 aralığında örnekler.
  static Float64List samples(SoundCue cue) {
    final rng = Random(cue.index + 1);
    double noise() => rng.nextDouble() * 2 - 1;

    switch (cue) {
      case SoundCue.tap:
        return _render(0.06, (t) => (sin(2 * pi * 1800 * t) * 0.5 + noise() * 0.3) * exp(-t * 90));
      case SoundCue.drillTap:
        return _render(0.16, (t) => (sin(2 * pi * (90 - t * 200) * t) * 0.9 + noise() * 0.25) * exp(-t * 28));
      case SoundCue.drillStart:
        // Motor devir alır: testere dalga + gürültü, frekans yükselir.
        return _render(1.1, (t) {
          final f = 38 + 80 * (1 - exp(-t * 3));
          final saw = 2 * ((f * t) % 1) - 1;
          final env = min(1.0, t * 6) * (t > 0.9 ? (1.1 - t) / 0.2 : 1);
          return (saw * 0.55 + noise() * 0.18) * env;
        });
      case SoundCue.gusher:
        // Fışkırma: alçak geçiren filtreli gürültü + derin gümbürtü.
        var lp = 0.0;
        return _render(1.8, (t) {
          lp += (noise() - lp) * 0.08;
          final env = min(1.0, t * 8) * exp(-max(0.0, t - 0.4) * 1.6);
          return (lp * 2.0 + sin(2 * pi * 48 * t) * 0.4) * env;
        });
      case SoundCue.dryWell:
        // "Womp": düşen üçgen dalga.
        return _render(0.7, (t) {
          final f = 330 * exp(-t * 2.2);
          final tri = 2 * (2 * ((f * t) % 1) - 1).abs() - 1;
          return tri * 0.6 * exp(-t * 3);
        });
      case SoundCue.collect:
        // Sıvı "glug": ardışık, perdesi düşen üç kabarcık.
        return _render(0.42, (t) {
          var v = 0.0;
          for (var k = 0; k < 3; k++) {
            final st = k * 0.11;
            if (t < st) continue;
            final lt = t - st;
            v += sin(2 * pi * (420 - k * 60 - lt * 900) * lt) * exp(-lt * 26);
          }
          return v * 0.5;
        });
      case SoundCue.sell:
        // Yazar kasa zili: iki parlak çan vuruşu.
        return _render(0.9, (t) {
          double bell(double st, double f) {
            if (t < st) return 0;
            final lt = t - st;
            return (sin(2 * pi * f * lt) + 0.5 * sin(2 * pi * f * 2.76 * lt)) * exp(-lt * 6);
          }

          return (bell(0, 1318.5) + bell(0.09, 1760)) * 0.3;
        });
      case SoundCue.upgrade:
        // Yükselen arpej.
        const notes = [523.25, 659.25, 783.99, 1046.5];
        return _render(0.6, (t) {
          final i = min(notes.length - 1, (t / 0.11).floor());
          final lt = t - i * 0.11;
          final sq = sin(2 * pi * notes[i] * t) + 0.3 * sin(2 * pi * notes[i] * 3 * t);
          return sq * 0.35 * exp(-lt * 9);
        });
      case SoundCue.unlock:
        // Fanfar: majör akor, yumuşak atak.
        return _render(1.4, (t) {
          const chord = [392.0, 493.88, 587.33, 783.99];
          var v = 0.0;
          for (final f in chord) {
            v += sin(2 * pi * f * t) + 0.25 * sin(2 * pi * f * 2 * t);
          }
          return v * 0.14 * min(1.0, t * 10) * exp(-t * 1.6);
        });
      case SoundCue.event:
        // Uyarı: iki tonlu ikili bip.
        return _render(0.75, (t) {
          final seg = (t / 0.18).floor();
          final f = seg.isEven ? 880.0 : 660.0;
          final lt = t % 0.18;
          return sin(2 * pi * f * t) * 0.4 * (lt < 0.14 ? 1 : 0) * min(1.0, lt * 200);
        });
      case SoundCue.repair:
        // Metal tıngırtısı: uyumsuz kısmi frekanslar.
        return _render(0.5, (t) {
          const partials = [520.0, 1234.0, 2110.0, 3320.0];
          var v = 0.0;
          for (var i = 0; i < partials.length; i++) {
            v += sin(2 * pi * partials[i] * t) * exp(-t * (10 + i * 6));
          }
          return (v * 0.25 + noise() * 0.2 * exp(-t * 60));
        });
    }
  }

  /// Ortam döngüsü: rüzgâr + uzaktan at kafası motor uğultusu. Uçları
  /// birbirine bağlanır, kesintisiz döner.
  static Uint8List ambientLoop({double seconds = 6}) {
    final rng = Random(99);
    var lp = 0.0;
    var lp2 = 0.0;
    final s = _render(seconds, (t) {
      lp += ((rng.nextDouble() * 2 - 1) - lp) * 0.015;
      lp2 += (lp - lp2) * 0.05;
      final gust = 0.6 + 0.4 * sin(2 * pi * t / seconds) * sin(2 * pi * 2 * t / seconds);
      final hum = sin(2 * pi * 55 * t) * 0.12 + sin(2 * pi * 110 * t) * 0.04;
      final stroke = 0.5 + 0.5 * sin(2 * pi * t / 3); // pompa strok ritmi
      return lp2 * 3.5 * gust + hum * stroke;
    });
    // Döngü dikişini yumuşat
    const fade = 2000;
    for (var i = 0; i < fade; i++) {
      final a = i / fade;
      s[s.length - fade + i] = s[s.length - fade + i] * (1 - a) + s[i] * a;
    }
    return encodeWav(Float64List.sublistView(s, fade));
  }

  static Float64List _render(double seconds, double Function(double t) fn) {
    final n = (seconds * sampleRate).round();
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = fn(i / sampleRate);
    }
    // Tıklamayı önlemek için kısa giriş/çıkış
    const ramp = 64;
    for (var i = 0; i < min(ramp, n); i++) {
      out[i] *= i / ramp;
      out[n - 1 - i] *= i / ramp;
    }
    return out;
  }

  static Uint8List encodeWav(Float64List samples) {
    final dataLen = samples.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
