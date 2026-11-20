import 'dart:ui' as ui;

import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/visuals/game_visuals.dart';
import 'package:batman_petrol_agasi/core/visuals/painters/derrick_painter.dart';
import 'package:batman_petrol_agasi/core/visuals/painters/pumpjack_painter.dart';
import 'package:batman_petrol_agasi/features/well/cross_section_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void paintOnce(CustomPainter p, [Size size = const Size(400, 700)]) {
  final recorder = ui.PictureRecorder();
  p.paint(Canvas(recorder), size);
  recorder.endRecording();
}

void main() {
  test('painter\'lar istisnasız çizer', () {
    for (final outcome in [null, true, false]) {
      for (final progress in [0.0, 0.4, 1.0]) {
        paintOnce(
          CrossSectionPainter(
            progress: progress,
            layers: GameConfig.defaultGeology,
            targetDepthM: 1300,
            time: 3.3,
            outcome: outcome,
            oilRise: 0.5,
            night: 0.7,
            lightsOn: true,
          ),
        );
      }
    }
    for (var ph = 0.0; ph < 1; ph += 0.05) {
      paintOnce(PumpjackPainter(phase: ph, time: ph * 10, night: 0.6), const Size(120, 90));
      paintOnce(PumpjackPainter(phase: ph, broken: true), const Size(120, 90));
    }
    paintOnce(DerrickPainter(spin: 0.3, time: 4, lightsOn: true, night: 0.8), const Size(80, 120));
  });

  testWidgets('fışkırma ve animasyonlu görseller kare kare hatasız çalışır', (tester) async {
    const v = PainterGameVisuals();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            SizedBox(height: 300, width: 400, child: v.gusher()),
            SizedBox(height: 90, width: 140, child: v.pumpjack(night: 0.7, sunX: -0.5)),
            SizedBox(height: 120, width: 80, child: v.derrick(lightsOn: true, night: 0.8)),
          ],
        ),
      ),
    );
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('at kafası mekanizması tüm turda çözülür ve kiriş makul açıda sallanır', () {
    var minA = 10.0, maxA = -10.0;
    for (var ph = 0.0; ph < 1; ph += 0.01) {
      final a = PumpjackPainter.beamAngle(ph);
      minA = a < minA ? a : minA;
      maxA = a > maxA ? a : maxA;
    }
    expect(minA, greaterThan(-0.35));
    expect(maxA, lessThan(0.35));
    expect(maxA - minA, greaterThan(0.25));
  });
}
