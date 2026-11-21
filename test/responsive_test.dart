import 'package:batman_petrol_agasi/app.dart';
import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/models/game_state.dart';
import 'package:batman_petrol_agasi/core/models/parcel.dart';
import 'package:batman_petrol_agasi/core/navigation.dart';
import 'package:batman_petrol_agasi/core/persistence/save_repository.dart';
import 'package:batman_petrol_agasi/features/chat/chat_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Farklı cihaz boyutları (mantıksal piksel) ve yazı büyüklükleri.
const _devices = <(String, Size, double)>[
  ('küçük telefon (iPhone SE 1)', Size(320, 568), 1.0),
  ('Android orta', Size(360, 640), 1.0),
  ('büyük telefon', Size(430, 932), 1.0),
  ('büyük yazı tipi', Size(360, 740), 1.3),
  ('tablet dikey', Size(768, 1024), 1.0),
  ('tablet yatay', Size(1180, 820), 1.0),
  ('telefon yatay', Size(780, 360), 1.0),
  ('masaüstü tarayıcı', Size(1440, 900), 1.0),
  ('dar + büyük yazı', Size(320, 640), 1.3),
];

Map<String, dynamic> _seed() {
  final now = DateTime.now().millisecondsSinceEpoch;
  var s = GameState.initial(now).copyWith(tutorialDone: true, introSeen: true, money: 250000);
  for (var i = 0; i < 9; i++) {
    s = s.updateParcel('raman', i, switch (i % 4) {
      0 => Parcel(status: ParcelStatus.producing, tier: YieldTier.high, stored: 40, pumpLevel: 2),
      1 => const Parcel(status: ParcelStatus.producing, tier: YieldTier.low, broken: true),
      2 => const Parcel(status: ParcelStatus.dry),
      _ => const Parcel(),
    });
  }
  return s.toJson();
}

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  for (final (name, size, textScale) in _devices) {
    testWidgets('taşma yok: $name ${size.width.toInt()}x${size.height.toInt()} yazı x$textScale', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final problems = <String>[];
      var where = 'açılış';
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        // Hatanın hangi widget'ta olduğunu (dosya:satır) yakala.
        final loc = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
        problems.add('[$where] ${d.exceptionAsString().split('\n').first} @ $loc');
      };

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              saveRepositoryProvider.overrideWithValue(InMemorySaveRepository(_seed())),
              autoTickProvider.overrideWithValue(false),
            ],
            child: const PetrolAgasiApp(),
          ),
        );
        await tester.pump(const Duration(seconds: 4));
        await _frames(tester);
        final container = ProviderScope.containerOf(tester.element(find.byType(GameShell)));
        final ctrl = container.read(gameControllerProvider.notifier);
        for (final role in ['sondor', 'derikmen', 'muhendis']) {
          ctrl.hire(role);
        }

        for (final tab in AppTab.values) {
          where = tab.name;
          container.read(navProvider.notifier).go(tab);
          await _frames(tester);
        }

        // Sohbet ekranı
        where = 'sohbet';
        container.read(navProvider.notifier).go(AppTab.site);
        await _frames(tester, 3);
        await tester.tap(find.byKey(const Key('hud_chat')));
        await _frames(tester);
        expect(find.byType(ChatScreen), findsOneWidget, reason: 'sohbet açılmalı');
        // Sohbetin özel üst çubuğu var: doğrudan geri dön.
        await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
        await _frames(tester);

        // Parsel ayrıntısı (alt sayfa)
        where = 'parsel sayfası';
        await tester.tap(find.byKey(const Key('parcel_raman_3')));
        await _frames(tester);
        expect(find.byKey(const Key('btn_survey')), findsOneWidget, reason: 'parsel sayfası açılmalı');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
        FlutterError.onError = old;
      }
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
