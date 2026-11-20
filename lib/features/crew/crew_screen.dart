import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/economy/crew.dart';
import '../../core/game/game_controller.dart';
import '../../core/models/worker.dart';
import '../../core/services/feedback.dart';
import '../../core/services/services.dart';
import '../../core/ui/premium.dart';
import '../../core/ui/premium_backdrop.dart';
import '../../core/utils/format.dart';
import '../../core/visuals/game_visuals.dart';
import '../mascot/usta_bubble.dart';
import '../mascot/usta_controller.dart';
import 'worker_avatar.dart';

/// Ekip ekranı: işçiler, görevleri, rütbeleri; işe alma ve terfi.
class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(gameControllerProvider.select((s) => s.workers));
    final pad = MediaQuery.paddingOf(context);

    return PremiumBackdrop(
      seed: 19,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, pad.bottom + 16),
        children: [
          const _CrewSummary(),
          const SectionHeader('Ekibin'),
          if (workers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: UstaSpeech(
                text: 'Ekip kurmadan petrol ağası olunmaz bıra! Aşağıdan ilk işçini al, gerisi gelir.',
                mood: UstaMood.thinking,
              ),
            )
          else
            for (final w in workers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkerCard(workerId: w.id),
              ),
          const SectionHeader('İşe al'),
          for (final role in GameConfig.crewRoles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HireCard(role: role),
            ),
        ],
      ),
    );
  }
}

/// Ekibin toplam etkisi: küçük çipler.
class _CrewSummary extends ConsumerWidget {
  const _CrewSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = ref.watch(gameControllerProvider.select((s) => s.crew));
    final count = ref.watch(gameControllerProvider.select((s) => s.workers.length));
    String pct(double v) => '%${Fmt.decimal(v * 100, 0)}';
    final chips = <(IconData, String)>[
      if (crew.productionMultiplier > 1) (Icons.trending_up, 'Üretim +${pct(crew.productionMultiplier - 1)}'),
      if (crew.drillTimeMultiplier < 1) (Icons.timer, 'Sondaj -${pct(1 - crew.drillTimeMultiplier)}'),
      if (crew.tapMultiplier > 1) (Icons.touch_app, 'Dokunuş +${pct(crew.tapMultiplier - 1)}'),
      if (crew.dryMultiplier < 1) (Icons.water_drop, 'Kuru kuyu -${pct(1 - crew.dryMultiplier)}'),
      if (crew.priceMultiplier > 1) (Icons.sell, 'Fiyat +${pct(crew.priceMultiplier - 1)}'),
      if (crew.autoRepairSeconds != null) (Icons.build, 'Oto tamir ${Fmt.integer(crew.autoRepairSeconds!)} sn'),
      if (crew.autoCollectSeconds != null)
        (Icons.local_shipping, 'Oto toplama ${Fmt.integer(crew.autoCollectSeconds!)} sn'),
    ];

    return GlassPanel(
      blur: 0,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Premium.goldText('Ekip', size: 26),
              const SizedBox(width: 10),
              Text(
                '$count kişi',
                style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Her işçinin bir görevi ve rütbesi var. Terfi ettikçe işini daha iyi yapar. '
            'Avatara dokun, konuşsun; kaleme dokun, adını sen koy.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (icon, text) in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Palette.success.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Palette.success.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: Palette.success),
                        const SizedBox(width: 4),
                        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkerCard extends ConsumerWidget {
  const _WorkerCard({required this.workerId});
  final int workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(gameControllerProvider.select((s) => s.workerById(workerId)));
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    if (w == null) return const SizedBox.shrink();
    final cost = Crew.promoteCost(w);
    final role = w.role;

    return GlassPanel(
      blur: 0,
      radius: 22,
      padding: const EdgeInsets.all(12),
      borderColor: Color(role.helmetColor).withValues(alpha: 0.35),
      child: Column(
        children: [
          Row(
            children: [
              // Avatara dokun: işçi konuşur.
              Semantics(
                button: true,
                label: '${w.displayName} ile konuş',
                child: GestureDetector(
                  key: Key('worker_avatar_${w.id}'),
                  onTap: () {
                    ref.read(feedbackProvider).light();
                    ref.read(ustaProvider.notifier).chatWith(w);
                  },
                  child: SizedBox(width: 64, height: 64, child: WorkerAvatar(worker: w)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            role.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(role.helmetColor).withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RankBadge(rank: w.rank),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(Crew.effectText(role, w.rank), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              // İsim ver (48dp dokunma alanı)
              IconButton(
                key: Key('worker_rename_${w.id}'),
                tooltip: 'İsim ver',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.edit, color: Colors.white60, size: 20),
                onPressed: () => _rename(context, ref, w),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (w.isMaxRank)
            const Text(
              'En yüksek rütbede: Şef',
              style: TextStyle(color: Palette.gold, fontWeight: FontWeight.w800),
            )
          else
            PremiumButton(
              key: Key('worker_promote_${w.id}'),
              height: 48,
              colors: Premium.gold,
              foreground: const Color(0xFF3A2508),
              shine: money >= cost,
              icon: Icons.military_tech,
              label: '${GameConfig.crewRanks[w.rank + 1]} yap · ${Fmt.money(cost)}',
              onPressed: money >= cost
                  ? () {
                      final r = ref.read(gameControllerProvider.notifier).promote(w.id);
                      if (r == ActionResult.ok) ref.read(feedbackProvider).medium(SoundCue.upgrade);
                    }
                  : null,
            ),
          if (!w.isMaxRank)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Terfiden sonra: ${Crew.effectText(role, w.rank + 1)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Worker w) async {
    final controller = TextEditingController(text: w.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İsim ver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${w.role.title} · ${w.rankTitle}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: Worker.maxNameLength,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: w.role.maxCount > 1 ? '${w.role.title} ${w.number}' : w.role.title,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Görev adına dön')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Kaydet')),
        ],
      ),
    );
    controller.dispose();
    if (result != null) ref.read(gameControllerProvider.notifier).rename(w.id, result);
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: Premium.gold),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i <= rank; i++) const Icon(Icons.star, size: 10, color: Color(0xFF3A2508)),
          const SizedBox(width: 4),
          Text(
            GameConfig.crewRanks[rank],
            style: const TextStyle(color: Color(0xFF3A2508), fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HireCard extends ConsumerWidget {
  const _HireCard({required this.role});
  final CrewRoleConfig role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(gameControllerProvider.select((s) => s.hiredCount(role.id)));
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    final full = count >= role.maxCount;
    final cost = Crew.hireCost(role, count);

    return GlassPanel(
      blur: 0,
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Opacity(
              opacity: full ? 0.5 : 1,
              child: ref
                  .watch(gameVisualsProvider)
                  .worker(seed: 1000 + role.id.hashCode % 997, helmetColor: Color(role.helmetColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        role.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (role.maxCount > 1) ...[
                      const SizedBox(width: 6),
                      Text('$count/${role.maxCount}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(role.description, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(
                  'Çırak: ${Crew.effectText(role, 0)}',
                  style: const TextStyle(color: Palette.success, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (full)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.check_circle, color: Palette.success),
            )
          else
            PremiumButton(
              key: Key('hire_${role.id}'),
              expand: false,
              height: 48,
              fontSize: 14,
              shine: false,
              label: Fmt.money(cost),
              icon: Icons.person_add,
              onPressed: money >= cost
                  ? () {
                      final r = ref.read(gameControllerProvider.notifier).hire(role.id);
                      if (r == ActionResult.ok) ref.read(feedbackProvider).medium(SoundCue.unlock);
                    }
                  : () => ref.read(ustaProvider.notifier).noMoney(),
            ),
        ],
      ),
    );
  }
}
