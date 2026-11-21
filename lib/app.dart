import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'config/game_config.dart';
import 'config/palette.dart';
import 'core/game/game_controller.dart';
import 'core/navigation.dart';
import 'core/services/services.dart';
import 'core/ui/premium.dart';
import 'core/visuals/painters/paint_kit.dart';
import 'core/visuals/shaders.dart';
import 'core/widgets/effect_layer.dart';
import 'core/widgets/hud.dart';
import 'features/chat/chat_director.dart';
import 'features/crew/crew_screen.dart';
import 'features/events/effects_bar.dart';
import 'features/events/offline_dialog.dart';
import 'features/intro/intro_gate.dart';
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
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.panelLight,
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xF2201A16),
          modalBackgroundColor: const Color(0xF2201A16),
          showDragHandle: true,
          dragHandleColor: Colors.white24,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Palette.panelLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          titleTextStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: Palette.panel.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
      ),
      // Efekt katmanı ve Usta balonu Navigator'ın üstünde: tüm ekranlarda görünür.
      builder: (context, child) => _GraphicsScope(
        child: EffectLayer(
          child: Stack(
            children: [
              child!,
              const Positioned.fill(child: _HeatLayer()),
              const Positioned(left: 8, right: 8, bottom: 88, child: UstaBubble()),
            ],
          ),
        ),
      ),
      home: const IntroGate(child: GameShell()),
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
      onHide: _toBackground,
      onPause: _toBackground,
      onInactive: _save,
      onDetach: _save,
      onResume: () {
        ref.read(gameControllerProvider.notifier).resume();
        _syncAmbient();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAmbient();
      // Saha grubu yönetmenini başlat (sahneleri kendiliğinden açar).
      ref.read(chatDirectorProvider);
    });
  }

  void _toBackground() {
    _save();
    ref.read(audioServiceProvider).setAmbient(false);
  }

  /// Ortam sesi yalnızca ses açıksa ve uygulama öndeyken çalar.
  void _syncAmbient() => ref.read(audioServiceProvider).setAmbient(ref.read(gameControllerProvider).soundEnabled);

  void _save() => ref.read(gameControllerProvider.notifier).save();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(navProvider);
    ref.listen(gameControllerProvider.select((s) => s.soundEnabled), (_, on) {
      ref.read(audioServiceProvider).setAmbient(on);
    });
    final hasOfflineReport = ref.watch(gameControllerProvider.select((s) => s.offlineReport != null));
    final tutorialDone = ref.watch(gameControllerProvider.select((s) => s.tutorialDone));

    // İçerik tam ekran; HUD ve alt menü üstünde buzlu cam olarak yüzer.
    final mq = MediaQuery.of(context);
    final contentPadding = mq.padding.copyWith(top: ShellMetrics.hud(context), bottom: ShellMetrics.nav(context));

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(padding: contentPadding),
              child: IndexedStack(
                index: tab.index,
                // Görünmeyen sekmelerin animasyonları durdurulur (CPU/pil).
                children: [
                  for (final (i, screen) in const [
                    MapScreen(),
                    SiteScreen(),
                    CrewScreen(),
                    MarketScreen(),
                    SettingsScreen(),
                  ].indexed)
                    TickerMode(enabled: i == tab.index, child: screen),
                ],
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: GameHud()),
          Positioned(top: ShellMetrics.hud(context), left: 12, right: 12, child: const EffectsBar()),
          const Positioned(left: 0, right: 0, bottom: 0, child: GlassNavBar()),
          if (!tutorialDone) const Positioned.fill(child: TutorialOverlay()),
          if (hasOfflineReport && tutorialDone) const Positioned.fill(child: OfflineReportOverlay()),
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

/// Oyuncunun grafik ayarını alt ağaca iletir.
class _GraphicsScope extends ConsumerWidget {
  const _GraphicsScope({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(gameControllerProvider.select((s) => s.graphicsLevel));
    final g = GraphicsLevel.fromIndex(level);
    PaintKit.highQuality = g.detail;
    return GraphicsMode(level: g, child: child);
  }
}
