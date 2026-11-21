import 'dart:ui' as ui;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../utils/format.dart';

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

  Widget _content(BuildContext context, BorderRadius r) {
    // Bulanıklık mobilde pahalıdır: listelerde (blur: 0) ve düşük grafik
    // modunda kapatılır, yerine daha opak bir zemin kullanılır.
    final useBlur = blur > 0 && GraphicsMode.of(context).blur;
    final o = useBlur ? opacity : (opacity + 0.22).clamp(0.0, 0.95);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tint, Colors.white, 0.08)!.withValues(alpha: o),
            tint.withValues(alpha: (o + 0.12).clamp(0.0, 1.0)),
          ],
        ),
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: child,
    );
    if (!useBlur) return box;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: box,
    );
  }

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
      child: ClipRRect(borderRadius: r, child: _content(context, r)),
    );
  }
}

/// Grafik kalitesi kademeleri. Telefonlarda ısınma/donmayı önlemek için
/// varsayılan [balanced]: animasyonlar saniyede 30 kare, bulanıklık yok.
enum GraphicsLevel {
  low('Pil tasarrufu', fps: 15, particles: 0.35, maxPixelRatio: 1.0),
  balanced('Dengeli', fps: 30, particles: 0.6, maxPixelRatio: 1.5),
  high('Yüksek', fps: 60, particles: 1, maxPixelRatio: 3);

  const GraphicsLevel(this.label, {required this.fps, required this.particles, required this.maxPixelRatio});

  final String label;

  /// Sürekli animasyonların en yüksek yeniden çizim hızı.
  final int fps;

  /// Parçacık sayısı çarpanı.
  final double particles;

  /// Önbelleğe çizilen büyük görüntülerin en yüksek piksel oranı (bellek).
  final double maxPixelRatio;

  /// Bulanıklık (BackdropFilter, MaskFilter) yalnızca yüksek kalitede.
  bool get blur => this == high;

  /// Bulut gölgeleri, motor titreşimi gibi ince süslemeler.
  bool get detail => this == high;

  Duration get frameInterval => Duration(microseconds: 1000000 ~/ fps);

  static GraphicsLevel fromIndex(int? i) =>
      i == null || i < 0 || i >= values.length ? GraphicsLevel.balanced : values[i];
}

/// Arkasını bulanıklaştıran katman; yalnızca Yüksek grafik kalitesinde
/// gerçek bulanıklık uygular (BackdropFilter telefonda çok pahalıdır).
class QualityBlur extends StatelessWidget {
  const QualityBlur({super.key, required this.sigma, required this.child});
  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!GraphicsMode.of(context).blur) return child;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

/// Oyuncunun grafik seviyesini alt ağaca iletir.
class GraphicsMode extends InheritedWidget {
  const GraphicsMode({super.key, required this.level, required super.child});
  final GraphicsLevel level;

  static GraphicsLevel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GraphicsMode>()?.level ?? GraphicsLevel.balanced;

  static bool isLow(BuildContext context) => of(context) == GraphicsLevel.low;

  @override
  bool updateShouldNotify(GraphicsMode old) => old.level != level;
}

/// Sürekli animasyonlu widget'lar için kare hızı sınırlı zaman sayacı.
///
/// Ticker her vsync'te çalışır ama `setState` yalnızca grafik seviyesinin
/// izin verdiği aralıkta çağrılır (15/30/60 fps). Ticker, gizli sekmelerde
/// [TickerMode] ile otomatik susturulur.
mixin FrameThrottle<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _throttleTicker;
  Duration _lastFrame = Duration.zero;
  Duration _interval = GraphicsLevel.balanced.frameInterval;

  /// Başlangıçtan bu yana geçen süre (sn).
  double seconds = 0;

  /// Son yeniden çizimden bu yana geçen süre (sn).
  double frameDelta = 0;

  /// Kare çizilmeden hemen önce çağrılır (durum ilerletmek için).
  void onFrame(double dt) {}

  /// False dönerse bu kare yeniden çizilmez (görüntü değişmiyorsa).
  bool shouldRebuild() => true;

  /// False dönerse ticker durur (ör. animasyon gerekmiyorsa).
  bool get wantsTicks => true;

  @override
  void initState() {
    super.initState();
    _throttleTicker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _interval = GraphicsMode.of(context).frameInterval;
    syncTicker();
  }

  /// [wantsTicks] değişince çağrılmalı.
  void syncTicker() {
    if (wantsTicks && !_throttleTicker.isActive) {
      _lastFrame = Duration.zero;
      _throttleTicker.start();
    } else if (!wantsTicks && _throttleTicker.isActive) {
      _throttleTicker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final since = elapsed - _lastFrame;
    if (_lastFrame != Duration.zero && since < _interval) return;
    final dt = _lastFrame == Duration.zero ? 0.0 : since.inMicroseconds / 1e6;
    _lastFrame = elapsed;
    // Uzun duraklamalardan (arka plan, gizli sekme) sonra sıçrama olmasın.
    frameDelta = dt > 0.5 ? 0 : dt;
    seconds += frameDelta;
    onFrame(frameDelta);
    if (shouldRebuild()) setState(() {});
  }

  @override
  void dispose() {
    _throttleTicker.dispose();
    super.dispose();
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

    // Sürekli parlama her karede yeniden çizim demek: yalnızca yüksek kalitede.
    if (enabled && widget.shine && GraphicsMode.of(context).detail) {
      body = RepaintBoundary(
        child: body
            .animate(onPlay: (c) => c.repeat())
            .shimmer(delay: 2400.ms, duration: 1100.ms, color: Colors.white.withValues(alpha: 0.35), angle: 0.5),
      );
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
          Text(Fmt.upperTr(text), style: Premium.overline.copyWith(color: Palette.sunsetLight)),
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
