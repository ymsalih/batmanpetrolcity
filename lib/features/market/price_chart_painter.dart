import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../core/utils/format.dart';

/// Basit petrol fiyatı çizgi grafiği.
class PriceChartPainter extends CustomPainter {
  PriceChartPainter(this.history);
  final List<double> history;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 44.0;
    const padB = 8.0;
    const padT = 10.0;
    final chart = Rect.fromLTRB(padL, padT, size.width - 8, size.height - padB);

    final data = history.length == 1 ? [history.first, history.first] : history;
    var lo = data.reduce(min);
    var hi = data.reduce(max);
    if (hi - lo < 4) {
      lo -= 2;
      hi += 2;
    }
    final range = hi - lo;

    // Izgara ve etiketler
    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final v = hi - range * i / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: Fmt.decimal(v, 0),
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chart.left - tp.width - 6, y - tp.height / 2));
    }

    Offset point(int i) =>
        Offset(chart.left + chart.width * i / (data.length - 1), chart.bottom - chart.height * (data[i] - lo) / range);

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < data.length; i++) {
      final p = point(i);
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();

    final up = data.last >= data[data.length - 2];
    final color = up ? Palette.success : Palette.danger;
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(chart),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final last = point(data.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = color);
    canvas.drawCircle(last, 9, Paint()..color = color.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(PriceChartPainter old) => old.history != history;
}
