import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/worker.dart';
import '../../core/visuals/game_visuals.dart';
import '../mascot/usta_controller.dart';

class WorkerAvatar extends ConsumerWidget {
  const WorkerAvatar({super.key, required this.worker, this.mood = UstaMood.happy});
  final Worker worker;
  final UstaMood mood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(gameVisualsProvider)
        .worker(seed: worker.id, helmetColor: Color(worker.role.helmetColor), rank: worker.rank, mood: mood.index);
  }
}
