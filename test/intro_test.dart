import 'package:batman_petrol_agasi/app.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/persistence/save_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('açılış ekranı önce görünür, sonra kendiliğinden kapanır', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PETROL AĞASI'), findsOneWidget);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('PETROL AĞASI'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
