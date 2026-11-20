import 'package:batman_petrol_agasi/core/visuals/shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('pahalı çizim yalnızca anahtar değişince tekrarlanır', () {
    final cache = ShaderImageCache();
    var paints = 0;
    void paint(Canvas c, Size s) {
      paints++;
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF884422));
    }

    const size = Size(40, 20);
    expect(cache.update(key: (size, 1), size: size, pixelRatio: 2, paint: paint), isTrue);
    for (var frame = 0; frame < 120; frame++) {
      expect(cache.update(key: (size, 1), size: size, pixelRatio: 2, paint: paint), isFalse);
    }
    expect(paints, 1);
    expect(cache.image!.width, 80);

    // Gün-gece dilimi değişti: bir kez daha çizilir.
    expect(cache.update(key: (size, 2), size: size, pixelRatio: 2, paint: paint), isTrue);
    expect(paints, 2);
    cache.dispose();
  });
}
