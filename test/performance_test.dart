import 'package:batman_petrol_agasi/core/models/game_state.dart';
import 'package:batman_petrol_agasi/core/ui/premium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Her yeniden çizimi sayan, kare sınırlı test widget'ı.
class _Counter extends StatefulWidget {
  const _Counter({required this.builds});
  final List<double> builds;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> with SingleTickerProviderStateMixin, FrameThrottle {
  @override
  Widget build(BuildContext context) {
    widget.builds.add(seconds);
    return const SizedBox();
  }
}

Future<int> _buildsPerSecond(WidgetTester tester, GraphicsLevel level, {bool tickers = true}) async {
  final builds = <double>[];
  await tester.pumpWidget(
    GraphicsMode(
      level: level,
      child: TickerMode(
        enabled: tickers,
        child: _Counter(builds: builds),
      ),
    ),
  );
  builds.clear();
  // 60 Hz ekranı taklit et: 1 saniye boyunca 16.7 ms'lik kareler.
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(microseconds: 16667));
  }
  return builds.length;
}

void main() {
  testWidgets('animasyonlar grafik seviyesinin kare hızıyla sınırlı', (tester) async {
    final low = await _buildsPerSecond(tester, GraphicsLevel.low);
    final balanced = await _buildsPerSecond(tester, GraphicsLevel.balanced);
    final high = await _buildsPerSecond(tester, GraphicsLevel.high);
    expect(low, inInclusiveRange(13, 16));
    expect(balanced, inInclusiveRange(28, 31));
    expect(high, greaterThanOrEqualTo(55));
  });

  testWidgets('gizli sekmede (TickerMode kapalı) hiç yeniden çizilmez', (tester) async {
    expect(await _buildsPerSecond(tester, GraphicsLevel.high, tickers: false), 0);
  });

  test('varsayılan grafik seviyesi dengeli; yalnızca yüksekte bulanıklık', () {
    expect(GraphicsLevel.fromIndex(null), GraphicsLevel.balanced);
    expect(GraphicsLevel.fromIndex(9), GraphicsLevel.balanced);
    expect(GraphicsLevel.low.blur, isFalse);
    expect(GraphicsLevel.balanced.blur, isFalse);
    expect(GraphicsLevel.high.blur, isTrue);
    expect(GraphicsLevel.low.maxPixelRatio, lessThan(GraphicsLevel.high.maxPixelRatio));
  });

  test('grafik seviyesi kaydedilir; eski "düşük grafik" kaydı pil tasarrufuna döner', () {
    final s = GameState.initial(0).copyWith(graphicsLevel: 2);
    expect(GameState.fromJson(s.toJson(), 0).graphicsLevel, 2);

    final legacy = GameState.initial(0).toJson()
      ..remove('gq')
      ..['lg'] = true;
    expect(GameState.fromJson(legacy, 0).graphicsLevel, 0);

    final fresh = GameState.initial(0).toJson()..remove('gq');
    expect(GameState.fromJson(fresh, 0).graphicsLevel, 1);
  });
}
