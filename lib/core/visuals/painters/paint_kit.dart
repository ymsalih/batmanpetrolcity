import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Painter'ların ortak "malzeme" yardımcıları: metal gölgelendirme,
/// yumuşak gölge, gece tonlaması.
abstract final class PaintKit {
  /// [a]→[b] arasında, üst kenarı ışıklı, alt kenarı gölgeli profil çubuk.
  static void shadedBar(
    Canvas canvas,
    Offset a,
    Offset b,
    double thickness,
    Color base, {
    double night = 0,
    double highlight = 0.45,
    double shadow = 0.5,
    bool capped = false,
  }) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    var n = Offset(-d.dy, d.dx) / len * (thickness / 2);
    if (n.dy > 0) n = -n; // n her zaman yukarıyı gösterir (ışık yukarıdan).
    final path = Path()
      ..moveTo((a + n).dx, (a + n).dy)
      ..lineTo((b + n).dx, (b + n).dy)
      ..lineTo((b - n).dx, (b - n).dy)
      ..lineTo((a - n).dx, (a - n).dy)
      ..close();
    final c = nightTint(base, night);
    final mid = (a + b) / 2;
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          mid + n,
          mid - n,
          [Color.lerp(c, Colors.white, highlight)!, c, Color.lerp(c, Colors.black, shadow)!],
          const [0, 0.4, 1],
        ),
    );
    if (capped) {
      sphere(canvas, a, thickness * 0.55, Color.lerp(base, Colors.black, 0.2)!, night: night);
      sphere(canvas, b, thickness * 0.55, Color.lerp(base, Colors.black, 0.2)!, night: night);
    }
  }

  /// Ön yüzü gradyanlı, isteğe bağlı perspektif derinlikli kutu.
  static void box(Canvas canvas, Rect r, Color base, {double night = 0, double radius = 1.5, double depth = 0}) {
    final c = nightTint(base, night);
    if (depth > 0) {
      final dx = depth;
      final dy = -depth * 0.6;
      canvas.drawPath(
        Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.left + dx, r.top + dy)
          ..lineTo(r.right + dx, r.top + dy)
          ..lineTo(r.right, r.top)
          ..close(),
        Paint()..color = Color.lerp(c, Colors.white, 0.3)!,
      );
      canvas.drawPath(
        Path()
          ..moveTo(r.right, r.top)
          ..lineTo(r.right + dx, r.top + dy)
          ..lineTo(r.right + dx, r.bottom + dy)
          ..lineTo(r.right, r.bottom)
          ..close(),
        Paint()..color = Color.lerp(c, Colors.black, 0.4)!,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          [Color.lerp(c, Colors.white, 0.2)!, c, Color.lerp(c, Colors.black, 0.35)!],
          const [0, 0.5, 1],
        ),
    );
  }

  /// Yumuşak, bulanık zemin gölgesi.
  static void softShadow(Canvas canvas, Rect r, {double opacity = 0.35, double blur = 5}) {
    canvas.drawOval(
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  /// Küresel gölgelendirilmiş daire (yatak, göbek, damla).
  static void sphere(Canvas canvas, Offset c, double r, Color base, {double night = 0}) {
    if (r <= 0) return;
    final col = nightTint(base, night);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.35, -r * 0.45),
          r * 1.4,
          [Color.lerp(col, Colors.white, 0.55)!, col, Color.lerp(col, Colors.black, 0.55)!],
          const [0, 0.45, 1],
        ),
    );
  }

  /// Gece: ay ışığı altında mavimsi ve koyu.
  static Color nightTint(Color c, double night) {
    if (night <= 0) return c;
    final moon = Color.lerp(c, const Color(0xFF16203A), 0.6)!;
    return Color.lerp(c, moon, night.clamp(0.0, 1.0))!;
  }

  static Offset rotate(Offset v, double a) => Offset(v.dx * cos(a) - v.dy * sin(a), v.dx * sin(a) + v.dy * cos(a));

  /// İki çemberin kesişimi (dört-çubuk mekanizması için). [upper] true ise
  /// y'si küçük (yukarıdaki) çözümü döndürür.
  static Offset? circleIntersection(Offset c0, double r0, Offset c1, double r1, {bool upper = true}) {
    final d = (c1 - c0).distance;
    if (d > r0 + r1 || d < (r0 - r1).abs() || d == 0) return null;
    final a = (r0 * r0 - r1 * r1 + d * d) / (2 * d);
    final h = sqrt(max(0, r0 * r0 - a * a));
    final p = c0 + (c1 - c0) * (a / d);
    final off = Offset(-(c1.dy - c0.dy), c1.dx - c0.dx) * (h / d);
    final s1 = p + off;
    final s2 = p - off;
    return (upper ? (s1.dy < s2.dy) : (s1.dy > s2.dy)) ? s1 : s2;
  }
}
