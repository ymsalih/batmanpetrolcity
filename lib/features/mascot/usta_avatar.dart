import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/visuals/game_visuals.dart';
import 'usta_controller.dart';

class UstaAvatar extends ConsumerWidget {
  const UstaAvatar({super.key, this.mood});
  final UstaMood? mood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = mood ?? ref.watch(ustaProvider)?.mood ?? UstaMood.happy;
    return ref.watch(gameVisualsProvider).mascot(mood: current.index);
  }
}
