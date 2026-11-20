import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/navigation.dart';
import 'usta_bubble.dart';
import 'usta_controller.dart';

class TutorialStep {
  const TutorialStep(this.tab, this.text, this.mood);
  final AppTab tab;
  final String text;
  final UstaMood mood;
}

/// İlk açılıştaki 5 adımlık rehber.
const tutorialSteps = [
  TutorialStep(AppTab.map,
      'Hoş geldin bıra! Ben Usta. 1940\'ta Raman\'dan ilk petrol fışkırdığından beri bu topraklardayım. Seni Batman\'ın petrol ağası yapacağız!',
      UstaMood.excited),
  TutorialStep(AppTab.map,
      'Burası harita. Raman sahası açık. Batı Raman, Garzan ve Rafineri Bölgesi\'ni TL biriktirip açarsın.',
      UstaMood.happy),
  TutorialStep(AppTab.site,
      'Her sahada 9 parsel var. Önce etüt yaptır, verimi kestir. Sonra sondaja başla; ekrana dokundukça matkap hızlanır!',
      UstaMood.thinking),
  TutorialStep(AppTab.site,
      'Petrol çıkarsa at kafası kurulur ve varil üretir. Depo dolunca kuyuya dokun, topla. Kuru çıkarsa da üzülme, olur öyle.',
      UstaMood.happy),
  TutorialStep(AppTab.market,
      'Varilleri Pazarda satarsın. Fiyat birkaç dakikada bir oynar, iyi anı kolla lo! Hadi bakalım, kolay gelsin!',
      UstaMood.excited),
];

class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTab());
  }

  void _syncTab() {
    final step = ref.read(gameControllerProvider).tutorialStep.clamp(0, tutorialSteps.length - 1);
    ref.read(navProvider.notifier).go(tutorialSteps[step].tab);
  }

  void _next() {
    final ctrl = ref.read(gameControllerProvider.notifier);
    ctrl.advanceTutorial(tutorialSteps.length);
    if (ref.read(gameControllerProvider).tutorialDone) {
      ref.read(navProvider.notifier).go(AppTab.site);
      ctrl.save();
    } else {
      _syncTab();
    }
  }

  void _skip() {
    ref.read(gameControllerProvider.notifier).skipTutorial();
    ref.read(navProvider.notifier).go(AppTab.site);
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = ref.watch(gameControllerProvider.select((s) => s.tutorialStep)).clamp(0, tutorialSteps.length - 1);
    final step = tutorialSteps[stepIndex];
    final last = stepIndex == tutorialSteps.length - 1;

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: UstaSpeech(
        key: ValueKey(stepIndex),
        text: step.text,
        mood: step.mood,
        avatarSize: 84,
        footer: Row(
          children: [
            Text('${stepIndex + 1} / ${tutorialSteps.length}',
                style: const TextStyle(color: Palette.earth, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!last) TextButton(onPressed: _skip, child: const Text('Geç', style: TextStyle(color: Palette.earth))),
            FilledButton(
              key: const Key('tutorial_next'),
              style: FilledButton.styleFrom(backgroundColor: Palette.sunset),
              onPressed: _next,
              child: Text(last ? 'Başlayalım!' : 'Devam'),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.2, end: 0),
    );
  }
}
