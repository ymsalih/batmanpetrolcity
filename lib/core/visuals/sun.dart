import 'dart:math';

/// Güneşin gökteki konumu (NOAA güneş hesabı, yaklaşık ±0.5°).
class SunPosition {
  const SunPosition({
    required this.elevation,
    required this.azimuth,
    required this.trueSolarMinutes,
    required this.sunriseMinutes,
    required this.sunsetMinutes,
  });

  /// Ufkun üstündeki açı (derece). Negatif: güneş batmış.
  final double elevation;

  /// Pusula açısı (derece): 0 kuzey, 90 doğu, 180 güney, 270 batı.
  final double azimuth;

  /// Gerçek güneş zamanı (dakika, 0..1440; 720 = güneş öğlesi).
  final double trueSolarMinutes;

  /// Gün doğumu ve batımının gerçek güneş zamanı (dakika).
  final double sunriseMinutes;
  final double sunsetMinutes;

  bool get morning => trueSolarMinutes < 720;

  /// Oyunun gün fazı (0 gece yarısı, 0.25 gün doğumu, 0.5 öğle, 0.75 gün
  /// batımı): gerçek gün doğumu/batımı saatleri bu noktalara oturur.
  double get dayPhase {
    final t = trueSolarMinutes, s = sunriseMinutes, e = sunsetMinutes;
    if (t < s) return 0.25 * t / s;
    if (t < 720) return 0.25 + 0.25 * (t - s) / (720 - s);
    if (t < e) return 0.5 + 0.25 * (t - 720) / (e - 720);
    return 0.75 + 0.25 * (t - e) / (1440 - e);
  }

  /// Verilen an ve konum için güneşin konumu.
  static SunPosition at(DateTime time, {required double lat, required double lon}) {
    final utc = time.toUtc();
    final start = DateTime.utc(utc.year);
    final dayOfYear = utc.difference(start).inDays + 1;
    final hour = utc.hour + utc.minute / 60 + utc.second / 3600;
    final g = 2 * pi / 365 * (dayOfYear - 1 + (hour - 12) / 24);
    final eqTime =
        229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g));
    final decl =
        0.006918 -
        0.399912 * cos(g) +
        0.070257 * sin(g) -
        0.006758 * cos(2 * g) +
        0.000907 * sin(2 * g) -
        0.002697 * cos(3 * g) +
        0.00148 * sin(3 * g);
    final tst = ((hour * 60 + eqTime + 4 * lon) % 1440 + 1440) % 1440;
    final ha = (tst / 4 - 180) * pi / 180;
    final phi = lat * pi / 180;
    final cosZen = (sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(ha)).clamp(-1.0, 1.0);
    final zen = acos(cosZen);
    final elev = 90 - zen * 180 / pi;
    // Azimut (kuzeyden saat yönünde)
    final sinZen = sin(zen);
    var az = 180.0;
    if (sinZen.abs() > 1e-6) {
      final c = ((sin(phi) * cosZen - sin(decl)) / (cos(phi) * sinZen)).clamp(-1.0, 1.0);
      final a = acos(c) * 180 / pi;
      az = ha > 0 ? (a + 180) % 360 : (540 - a) % 360;
    }
    // Gün doğumu/batımı: güneş merkezi ufkun 0.833° altında (kırılma dahil)
    final cosHa0 = (cos(90.833 * pi / 180) / (cos(phi) * cos(decl)) - tan(phi) * tan(decl)).clamp(-1.0, 1.0);
    final ha0 = acos(cosHa0) * 180 / pi;
    return SunPosition(
      elevation: elev,
      azimuth: az,
      trueSolarMinutes: tst,
      sunriseMinutes: 720 - 4 * ha0,
      sunsetMinutes: 720 + 4 * ha0,
    );
  }

  /// Oyun fazından (0..1) yaklaşık güneş konumu: sabit saatli sahneler için.
  static SunPosition fromPhase(double phase) {
    final s = sin((phase - 0.25) * 2 * pi);
    return SunPosition(
      elevation: s * 52,
      azimuth: 90 + phase * 180,
      trueSolarMinutes: phase * 1440,
      sunriseMinutes: 360,
      sunsetMinutes: 1080,
    );
  }
}
