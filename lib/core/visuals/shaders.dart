import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'day_night.dart';

/// Uygulama açılışında yüklenen fragment shader programları.
/// Yüklenemezse (ör. test ortamı) null kalır ve gradyan yedeğine düşülür.
class ShaderBank {
  const ShaderBank({this.sky, this.heatHaze, this.oilSheen, this.landscape, this.soil, this.geology});

  final ui.FragmentProgram? sky;
  final ui.FragmentProgram? heatHaze;
  final ui.FragmentProgram? oilSheen;
  final ui.FragmentProgram? landscape;
  final ui.FragmentProgram? soil;
  final ui.FragmentProgram? geology;

  static Future<ShaderBank> load() async {
    Future<ui.FragmentProgram?> tryLoad(String path) async {
      try {
        return await ui.FragmentProgram.fromAsset(path);
      } catch (e) {
        debugPrint('Shader yüklenemedi ($path): $e');
        return null;
      }
    }

    final results = await Future.wait([
      tryLoad('shaders/sky.frag'),
      tryLoad('shaders/heat_haze.frag'),
      tryLoad('shaders/oil_sheen.frag'),
      tryLoad('shaders/landscape.frag'),
      tryLoad('shaders/soil.frag'),
      tryLoad('shaders/geology.frag'),
    ]);
    return ShaderBank(
      sky: results[0],
      heatHaze: results[1],
      oilSheen: results[2],
      landscape: results[3],
      soil: results[4],
      geology: results[5],
    );
  }
}

final shaderBankProvider = Provider<ShaderBank>((ref) => const ShaderBank());

/// Bir widget'ın kalıcı shader örneği.
///
/// Her çizimde yeni FragmentShader oluşturmak, önbelleğe alınmış (statik)
/// resimlerde shader çöpe gidince uniform'ların bozulmasına yol açar.
/// Bu yüzden her widget kendi örneğini saklar ve yalnızca uniform'ları
/// günceller.
class ShaderSlot {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  ui.FragmentShader? of(ui.FragmentProgram? program) {
    if (program == null) return null;
    if (!identical(program, _program)) {
      _shader?.dispose();
      _program = program;
      _shader = program.fragmentShader();
    }
    return _shader;
  }

  void dispose() {
    _shader?.dispose();
    _shader = null;
    _program = null;
  }
}

/// Sürekli artan saniye değeri veren yardımcı mixin.
mixin TimeTicker<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _timeTicker;
  double seconds = 0;

  @override
  void initState() {
    super.initState();
    _timeTicker = createTicker((elapsed) => setState(() => seconds = elapsed.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _timeTicker.dispose();
    super.dispose();
  }
}

/// Bulutlu, güneşli/yıldızlı prosedürel gökyüzü.
class SkyView extends ConsumerStatefulWidget {
  const SkyView({super.key});

  @override
  ConsumerState<SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends ConsumerState<SkyView> with SingleTickerProviderStateMixin, TimeTicker {
  final _slot = ShaderSlot();

  @override
  void dispose() {
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dn = ref.watch(dayNightProvider);
    final program = ref.watch(shaderBankProvider).sky;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: SkyPainter(shader: _slot.of(program), dayNight: dn, time: seconds),
      ),
    );
  }
}

class SkyPainter extends CustomPainter {
  SkyPainter({required this.shader, required this.dayNight, required this.time});

  final ui.FragmentShader? shader;
  final DayNight dayNight;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sh = shader;
    if (sh == null) {
      canvas.drawRect(
        rect,
        Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [dayNight.skyTop, dayNight.skyBottom]),
      );
      return;
    }
    final sun = dayNight.sunPosition;
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, dayNight.skyTop.r)
      ..setFloat(4, dayNight.skyTop.g)
      ..setFloat(5, dayNight.skyTop.b)
      ..setFloat(6, dayNight.skyBottom.r)
      ..setFloat(7, dayNight.skyBottom.g)
      ..setFloat(8, dayNight.skyBottom.b)
      ..setFloat(9, dayNight.night)
      ..setFloat(10, dayNight.dusk)
      ..setFloat(11, sun.dx)
      ..setFloat(12, sun.dy);
    canvas.drawRect(rect, Paint()..shader = sh);
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.time != time || old.dayNight.phase != dayNight.phase;
}

/// Batman sıcağında ekranı kaplayan ısı dalgası katmanı.
class HeatHazeOverlay extends ConsumerStatefulWidget {
  const HeatHazeOverlay({super.key, required this.strength});
  final double strength;

  @override
  ConsumerState<HeatHazeOverlay> createState() => _HeatHazeOverlayState();
}

class _HeatHazeOverlayState extends ConsumerState<HeatHazeOverlay> with SingleTickerProviderStateMixin, TimeTicker {
  final _slot = ShaderSlot();

  @override
  void dispose() {
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(shaderBankProvider).heatHaze;
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _HeatPainter(_slot.of(program), seconds, widget.strength)),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.shader, this.time, this.strength);
  final ui.FragmentShader? shader;
  final double time;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sh = shader;
    if (sh == null) {
      // Yedek: titreşen sıcak ton
      final a = 0.08 + 0.03 * sin(time * 2);
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFF9E40).withValues(alpha: a * strength));
      return;
    }
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, strength);
    canvas.drawRect(rect, Paint()..shader = sh);
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.time != time;
}

/// Petrol yüzeyi shader'ını verilen yol içine çizer (yoksa düz koyu renk).
void paintOilSurface(Canvas canvas, Path clip, Rect bounds, ui.FragmentShader? shader, double time) {
  canvas.save();
  canvas.clipPath(clip);
  final sh = shader;
  if (sh == null) {
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF14110F));
  } else {
    canvas.translate(bounds.left, bounds.top);
    sh
      ..setFloat(0, bounds.width)
      ..setFloat(1, bounds.height)
      ..setFloat(2, time);
    canvas.drawRect(Offset.zero & bounds.size, Paint()..shader = sh);
  }
  canvas.restore();
}
