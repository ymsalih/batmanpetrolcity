import 'package:batman_petrol_agasi/app.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/persistence/save_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Key, Size, SizedBox;

/// Sonsuz animasyonlar olduğu için pumpAndSettle yerine kare kare ilerletir.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('uygulama açılır, rehber ilerler ve saha ekranı görünür', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 820 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          autoTickProvider.overrideWithValue(false),
        ],
        child: const PetrolAgasiApp(),
      ),
    );
    // İlk açılışta sinematik oynar: Geç ile atla.
    await settle(tester);
    await tester.tap(find.byKey(const Key('intro_skip')));
    await settle(tester);
    expect(find.textContaining('Hoş geldin'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('tutorial_next')));
      await settle(tester);
    }
    expect(find.byKey(const Key('tutorial_next')), findsNothing);
    expect(find.text('Boş parsel'), findsNWidgets(9));
    expect(find.text('1.500 ₺'), findsOneWidget);

    // Animasyonlu ağacı kaldırıp bekleyen zamanlayıcıları temizle.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
