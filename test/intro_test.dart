import 'package:batman_petrol_agasi/app.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/persistence/save_repository.dart';
import 'package:batman_petrol_agasi/features/intro/cinematic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> frames(WidgetTester tester, int n, [int ms = 100]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Widget app(InMemorySaveRepository repo) => ProviderScope(
  overrides: [saveRepositoryProvider.overrideWithValue(repo), autoTickProvider.overrideWithValue(false)],
  child: const PetrolAgasiApp(),
);

void main() {
  setUp(() {});

  testWidgets('ilk açılışta sinematik oynar; bölümler gezilir, Başla ile kapanır ve kaydedilir', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 820 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = InMemorySaveRepository();
    await tester.pumpWidget(app(repo));
    await frames(tester, 5);
    expect(find.byType(CinematicIntro), findsOneWidget);
    expect(find.byKey(const Key('intro_skip')), findsOneWidget);

    // Her bölümde: dokun (metni tamamla), dokun (sonraki bölüm).
    for (var k = 0; k < CinematicIntro.chapters.length - 1; k++) {
      await tester.tapAt(const Offset(200, 400));
      await frames(tester, 3);
      await tester.tapAt(const Offset(200, 400));
      await frames(tester, 14);
    }
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('intro_start')), findsOneWidget);
    await frames(tester, 20);
    await tester.tap(find.byKey(const Key('intro_start')));
    await frames(tester, 10);
    expect(find.byType(CinematicIntro), findsNothing);
    expect(repo.data?['is'], isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Geç butonu sinematiği hemen kapatır', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(InMemorySaveRepository()));
    await frames(tester, 5);
    await tester.tap(find.byKey(const Key('intro_skip')));
    await frames(tester, 5);
    expect(find.byType(CinematicIntro), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('sinematik izlendiyse kısa açılış görünür ve kendiliğinden kapanır', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 820 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(InMemorySaveRepository({'is': true})));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CinematicIntro), findsNothing);
    expect(find.text('PETROL AĞASI'), findsOneWidget);
    await frames(tester, 50);
    expect(find.text('PETROL AĞASI'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
