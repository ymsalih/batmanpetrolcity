import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'config/game_config.dart';
import 'config/palette.dart';
import 'core/game/game_controller.dart';
import 'core/navigation.dart';
import 'core/visuals/shaders.dart';
import 'core/widgets/effect_layer.dart';
import 'core/widgets/hud.dart';
import 'features/events/offline_dialog.dart';
import 'features/map/map_screen.dart';
import 'features/market/market_screen.dart';
import 'features/mascot/tutorial_overlay.dart';
import 'features/mascot/usta_bubble.dart';
import 'features/settings/settings_screen.dart';
import 'features/site/site_screen.dart';

class PetrolAgasiApp extends StatelessWidget {
  const PetrolAgasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Palette.sunset, brightness: Brightness.dark, surface: Palette.panel);
    return MaterialApp(
      title: 'Batman Petrol Ağası',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.oil,
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      // Efekt katmanı ve Usta balonu Navigator'ın üstünde: tüm ekranlarda görünür.
      builder: (context, child) => EffectLayer(
        child: Stack(
          children: [
            child!,
            const Positioned.fill(child: _HeatLayer()),
            const Positioned(left: 8, right: 8, bottom: 88, child: UstaBubble()),
          ],
        ),
      ),
      home: const GameShell(),
    );
  }
}

class GameShell extends ConsumerStatefulWidget {
  const GameShell({super.key});

  @override
  ConsumerState<GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<GameShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Arka plana geçince kaydet, geri gelince geçen süreyi hesapla.
    _lifecycle = AppLifecycleListener(
      onHide: _save,
      onPause: _save,
      onInactive: _save,
      onDetach: _save,
      onResume: () => ref.read(gameControllerProvider.notifier).resume(),
    );
  }

  void _save() => ref.read(gameControllerProvider.notifier).save();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(navProvider);
    final hasOfflineReport = ref.watch(gameControllerProvider.select((s) => s.offlineReport != null));
    final tutorialDone = ref.watch(gameControllerProvider.select((s) => s.tutorialDone));

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const GameHud(),
              Expanded(
                child: IndexedStack(
                  index: tab.index,
                  children: const [MapScreen(), SiteScreen(), MarketScreen(), SettingsScreen()],
                ),
              ),
            ],
          ),
          if (!tutorialDone) const Positioned.fill(child: TutorialOverlay()),
          if (hasOfflineReport && tutorialDone) const Positioned.fill(child: OfflineReportOverlay()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        backgroundColor: Palette.panel,
        indicatorColor: Palette.sunset.withValues(alpha: 0.35),
        onDestinationSelected: (i) => ref.read(navProvider.notifier).go(AppTab.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Harita'),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Saha',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Pazar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

/// Batman sıcağı aktifken tüm ekranı kaplayan ısı dalgası.
class _HeatLayer extends ConsumerWidget {
  const _HeatLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      gameControllerProvider.select(
        (s) => s.effects.any((e) => e.eventKind == GameEventKind.heatWave && e.isActiveAt(s.lastTickMs)),
      ),
    );
    if (!active) return const SizedBox.shrink();
    return const HeatHazeOverlay(strength: 1);
  }
}
