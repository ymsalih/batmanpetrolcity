import 'dart:ui' as ui;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';

/// Premium arayüz renk gradyanları.
abstract final class Premium {
  static const gold = [Color(0xFFFFE6A3), Color(0xFFF5C04A), Color(0xFFC98A1B)];
  static const sunset = [Color(0xFFFFB26B), Color(0xFFF07A2A), Color(0xFFB9481A)];
  static const success = [Color(0xFF7FE0A0), Color(0xFF3FAE5A), Color(0xFF237A3B)];
  static const steel = [Color(0xFF8A939D), Color(0xFF59616B), Color(0xFF353A40)];
  static const danger = [Color(0xFFFF8A80), Color(0xFFD64541), Color(0xFF8E2420)];

  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.3);
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: Colors.white60,
  );

  /// Altın gradyanlı metin.
  static Widget goldText(String text, {double size = 28, FontWeight weight = FontWeight.w900, double spacing = 0}) {
    return ShaderMask(
      shaderCallback: (r) =>
          const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gold).createShader(r),
      child: Text(
        text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: Colors.white, letterSpacing: spacing),
      ),
    );
  }
}

/// Buzlu cam panel: arka planı bulanıklaştırır, ince ışıklı kenarlık.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.blur = 16,
    this.tint = const Color(0xFF1C1612),
    this.opacity = 0.62,
    this.borderColor,
    this.glow,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color tint;
  final double opacity;
  final Color? borderColor;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.35), blurRadius: 24),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(tint, Colors.white, 0.08)!.withValues(alpha: opacity),
                  tint.withValues(alpha: opacity + 0.12),
                ],
              ),
              border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.12), width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradyanlı, parlama süpürmeli, basınca hafifçe küçülen premium buton.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = Premium.sunset,
    this.height = 52,
    this.expand = true,
    this.shine = true,
    this.fontSize = 16,
    this.foreground = Colors.white,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final double height;
  final bool expand;
  final bool shine;
  final double fontSize;
  final Color foreground;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final colors = enabled ? widget.colors : const [Color(0xFF4A4440), Color(0xFF3A3532), Color(0xFF2C2826)];
    final r = BorderRadius.circular(widget.height / 2);

    Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: enabled ? widget.foreground : Colors.white38, size: widget.fontSize + 4),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enabled ? widget.foreground : Colors.white38,
              fontWeight: FontWeight.w800,
              fontSize: widget.fontSize,
              letterSpacing: 0.3,
              shadows: enabled ? const [Shadow(blurRadius: 4, color: Colors.black38, offset: Offset(0, 1))] : null,
            ),
          ),
        ),
      ],
    );

    Widget body = Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        border: Border.all(color: Colors.white.withValues(alpha: enabled ? 0.25 : 0.06)),
        boxShadow: enabled
            ? [
                BoxShadow(color: colors[1].withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Üst parlama
          Positioned(
            top: 2,
            left: 10,
            right: 10,
            height: widget.height * 0.42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: enabled ? 0.35 : 0.05),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          content,
        ],
      ),
    );

    if (enabled && widget.shine) {
      body = body
          .animate(onPlay: (c) => c.repeat())
          .shimmer(delay: 2400.ms, duration: 1100.ms, color: Colors.white.withValues(alpha: 0.35), angle: 0.5);
    }

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Semantics(button: true, enabled: enabled, label: widget.label, child: body),
      ),
    );
  }
}

/// Değer değiştiğinde sayarak ilerleyen sayaç.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(format(v), style: style),
    );
  }
}

/// Premium sayfa geçişi: yumuşak solma + hafif yakınlaşma.
Route<T> premiumRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: child),
      );
    },
  );
}

/// Bölüm başlığı: küçük harf aralıklı üst yazı + ince altın çizgi.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: Premium.overline.copyWith(color: Palette.sunsetLight)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Palette.sunsetLight.withValues(alpha: 0.5), Colors.transparent]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
