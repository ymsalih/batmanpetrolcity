import 'package:material_ui/material_ui.dart';

import '../ui/premium.dart';

/// Zamanla değişen bir [CustomPainter]'ı grafik seviyesinin kare hızıyla
/// (15/30/60 fps) çizer. Kendi [RepaintBoundary]'si vardır; yeniden çizim
/// üst widget'ları etkilemez. Gizli sekmede [TickerMode] ile durur.
class AnimatedPaint extends StatefulWidget {
  const AnimatedPaint({super.key, required this.painter, this.foregroundPainter, this.child});

  final CustomPainter Function(double seconds) painter;
  final CustomPainter Function(double seconds)? foregroundPainter;
  final Widget? child;

  @override
  State<AnimatedPaint> createState() => _AnimatedPaintState();
}

class _AnimatedPaintState extends State<AnimatedPaint> with SingleTickerProviderStateMixin, FrameThrottle {
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: widget.painter(seconds),
      foregroundPainter: widget.foregroundPainter?.call(seconds),
      child: widget.child,
    ),
  );
}
