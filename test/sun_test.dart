import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/visuals/horizon.dart';
import 'package:batman_petrol_agasi/core/visuals/sun.dart';
import 'package:flutter_test/flutter_test.dart';

SunPosition batman(DateTime utc) => SunPosition.at(utc, lat: GameConfig.batmanLat, lon: GameConfig.batmanLon);

void main() {
  test('yaz gündönümünde öğle güneşi ~75.5° (90 - enlem + 23.44)', () {
    // Batman'da güneş öğlesi ~09:13 UTC (12:13 yerel)
    final noon = batman(DateTime.utc(2026, 6, 21, 9, 13));
    expect(noon.elevation, closeTo(90 - GameConfig.batmanLat + 23.44, 1.0));
    expect(noon.azimuth, closeTo(180, 6));
  });

  test('kış gündönümünde öğle güneşi ~28.7°', () {
    final noon = batman(DateTime.utc(2026, 12, 21, 9, 15));
    expect(noon.elevation, closeTo(90 - GameConfig.batmanLat - 23.44, 1.0));
  });

  test('gece yarısı güneş ufkun çok altında, sabah doğuda akşam batıda', () {
    expect(batman(DateTime.utc(2026, 11, 21, 21, 0)).elevation, lessThan(-30)); // 00:00 yerel
    final morning = batman(DateTime.utc(2026, 11, 21, 4, 30)); // 07:30 yerel
    expect(morning.morning, isTrue);
    expect(morning.azimuth, inInclusiveRange(100, 135));
    final evening = batman(DateTime.utc(2026, 11, 21, 13, 30)); // 16:30 yerel
    expect(evening.morning, isFalse);
    expect(evening.azimuth, inInclusiveRange(220, 255));
  });

  test('gün doğumu/batımı gerçek saatte, oyun fazına doğru oturur', () {
    final s = batman(DateTime.utc(2026, 11, 21, 9, 0));
    // Kasım sonunda gün ~9.8 saat
    expect((s.sunsetMinutes - s.sunriseMinutes) / 60, closeTo(9.8, 0.4));
    expect(s.dayPhase, closeTo(0.5, 0.02));
  });

  test('manzara ağırlıkları: toplam 1, saate göre doğru görüntü', () {
    for (final h in [0, 4, 5, 9, 13, 14, 18]) {
      final w = HorizonBackdrop.weights(batman(DateTime.utc(2026, 11, 21, h, 10)));
      expect(w.values.reduce((a, b) => a + b), closeTo(1, 1e-9));
    }
    expect(HorizonBackdrop.weights(batman(DateTime.utc(2026, 11, 21, 21)))['gece'], closeTo(1, 1e-6));
    expect(HorizonBackdrop.weights(batman(DateTime.utc(2026, 11, 21, 9)))['gunduz'], closeTo(1, 1e-6));
    final dawn = HorizonBackdrop.weights(batman(DateTime.utc(2026, 11, 21, 4, 0)));
    expect(dawn['safak']!, greaterThan(0.4));
    expect(dawn['aksam'], 0);
  });
}
