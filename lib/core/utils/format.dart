/// Türkçe sayı ve süre biçimlendirme (intl paketine gerek kalmadan).
abstract final class Fmt {
  /// 12345 → "12.345"
  static String integer(num value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buf';
  }

  /// 3.14159 → "3,14"
  static String decimal(num value, [int digits = 1]) => value.toStringAsFixed(digits).replaceAll('.', ',');

  /// Büyük sayıları kısaltır: 12.345 → "12.345", 2.500.000 → "2,50 Mn".
  static String compact(num value) {
    final v = value.abs();
    final sign = value < 0 ? '-' : '';
    if (v < 1e6) return '$sign${integer(v)}';
    if (v < 1e9) return '$sign${decimal(v / 1e6, 2)} Mn';
    return '$sign${decimal(v / 1e9, 2)} Mr';
  }

  static String money(num value) => '${compact(value)} ₺';

  static String price(num value) => '${decimal(value, 2)} ₺';

  static String barrels(num value) => '${compact(value.floor())} varil';

  static String duration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} sa ${d.inMinutes.remainder(60)} dk';
    if (d.inMinutes > 0) return '${d.inMinutes} dk ${d.inSeconds.remainder(60)} sn';
    return '${d.inSeconds} sn';
  }

  /// "01:45"
  static String clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
