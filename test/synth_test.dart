import 'dart:typed_data';

import 'package:batman_petrol_agasi/core/services/services.dart';
import 'package:batman_petrol_agasi/core/services/synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('her ses geçerli, kırpılmamış ve sessiz olmayan bir WAV üretir', () {
    for (final cue in SoundCue.values) {
      final wav = Synth.wav(cue);
      final b = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF', reason: cue.name);
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(b.getUint32(24, Endian.little), Synth.sampleRate);
      final samples = Synth.samples(cue);
      final peak = samples.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);
      expect(peak, greaterThan(0.05), reason: '${cue.name} çok sessiz');
      expect(peak, lessThanOrEqualTo(1.2), reason: '${cue.name} aşırı yüksek');
      expect(samples.first.abs(), lessThan(0.01), reason: '${cue.name} tıkla başlıyor');
    }
  });

  test('ortam döngüsü üretilir', () {
    final loop = Synth.ambientLoop(seconds: 2);
    expect(loop.length, greaterThan(44 + Synth.sampleRate * 2));
  });
}
