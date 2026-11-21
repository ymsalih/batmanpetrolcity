import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Cihaz sınıfları ve ekran ölçüleri. Oyun telefon (dikey) için tasarlandı;
/// tablet ve masaüstünde içerik ortalanır ve rahat bir okuma genişliğinde
/// tutulur, kısa ekranlarda (küçük telefon, yatay) sıkışık düzene geçilir.
abstract final class Responsive {
  /// İçerik sütununun en fazla genişliği (tablet/masaüstü).
  static const contentMaxWidth = 640.0;

  /// Alt sayfaların (bottom sheet) en fazla genişliği.
  static const sheetMaxWidth = 560.0;

  /// Yazı büyütme sınırı: erişilebilirlik ayarı korunur ama düzen bozulmaz.
  static const minTextScale = 0.85;
  static const maxTextScale = 1.3;

  static Size _size(BuildContext c) => MediaQuery.sizeOf(c);

  /// En kısa kenar ≥ 600: tablet (veya masaüstü penceresi).
  static bool isTablet(BuildContext c) => _size(c).shortestSide >= 600;

  /// Dar telefon (ör. iPhone SE 1. nesil, 320 pt).
  static bool isNarrow(BuildContext c) => _size(c).width < 360;

  /// Yatay: genişlik yüksekliğin belirgin şekilde üstünde.
  static bool isLandscape(BuildContext c) {
    final s = _size(c);
    return s.width > s.height * 1.15;
  }

  /// Dikeyde kısa ekran (ör. 568 pt): başlık ve butonlar sıkışık çizilir.
  static bool isShort(BuildContext c) => _size(c).height < 700;

  /// Kaydırılan listelerin yatay boşluğu: geniş ekranda içerik
  /// [contentMaxWidth] genişliğinde ortalanır, kaydırma tüm ekranda çalışır.
  static double hPad(BuildContext c, [double base = 12]) => max(base, (_size(c).width - contentMaxWidth) / 2);

  /// Genişliğe göre ölçek (360 pt referans), 0.85..1.25 arası.
  static double scale(BuildContext c) => (min(_size(c).width, contentMaxWidth) / 360).clamp(0.85, 1.25);
}

/// İçeriği yatayda ortalar ve [maxWidth] ile sınırlar. Telefonda etkisizdir.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = Responsive.contentMaxWidth});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Sistem yazı büyüklüğünü makul aralıkta tutar (bkz. [Responsive.maxTextScale]).
class TextScaleClamp extends StatelessWidget {
  const TextScaleClamp({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: Responsive.minTextScale,
          maxScaleFactor: Responsive.maxTextScale,
        ),
      ),
      child: child,
    );
  }
}

/// Tüm cihazlarda düzgün görünen alt sayfa: yüksekliği aşarsa kaydırılır,
/// tablette ortalanır ve [Responsive.sheetMaxWidth] ile sınırlanır.
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool scrollable = true,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    showDragHandle: showDragHandle,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: scrollable ? (ctx) => SingleChildScrollView(child: builder(ctx)) : builder,
  );
}
