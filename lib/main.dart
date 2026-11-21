import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/game/game_controller.dart';
import 'core/persistence/save_repository.dart';
import 'core/services/services.dart';
import 'core/services/synth_audio_service.dart';
import 'core/visuals/shaders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mobil öncelikli: telefonda dikey kilit; tablette (en kısa kenar ≥ 600)
  // her yön serbest, düzen yatay ekrana uyum sağlar. Kenardan kenara çizim.
  if (!kIsWeb) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
    await SystemChrome.setPreferredOrientations(
      shortest >= 600 ? DeviceOrientation.values : [DeviceOrientation.portraitUp],
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  final shaders = await ShaderBank.load();
  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(SharedPrefsSaveRepository(prefs)),
        shaderBankProvider.overrideWithValue(shaders),
        audioServiceProvider.overrideWithValue(SynthAudioService()),
      ],
      child: const PetrolAgasiApp(),
    ),
  );
}
