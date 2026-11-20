import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/models/active_effect.dart';
import '../../core/services/services.dart';
import '../../core/ui/premium.dart';
import '../../core/ui/premium_backdrop.dart';
import '../../core/utils/format.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);
    final ads = ref.watch(rewardedAdServiceProvider);
    final leaderboard = ref.watch(leaderboardServiceProvider);
    final gps = ref.watch(locationBonusServiceProvider);

    final pad = MediaQuery.paddingOf(context);
    return PremiumBackdrop(
      seed: 17,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, pad.bottom + 16),
        children: [
          _section('Ayarlar'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('player_name'),
                  leading: const Icon(Icons.badge),
                  title: const Text('Ağa adın'),
                  subtitle: Text(
                    s.playerName == null
                        ? 'İşçiler sana "ağam" diyor. Adını yaz, adınla çağırsınlar.'
                        : 'İşçiler sana "${s.address}" diyor.',
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  minVerticalPadding: 12,
                  onTap: () => _editPlayerName(context, ref, s.playerName),
                ),
                SwitchListTile(
                  title: const Text('Titreşim'),
                  secondary: const Icon(Icons.vibration),
                  value: s.hapticsEnabled,
                  onChanged: ctrl.setHaptics,
                ),
                SwitchListTile(
                  key: const Key('low_graphics'),
                  title: const Text('Pil tasarrufu (düşük grafik)'),
                  subtitle: const Text('Bulanıklık, bulut gölgeleri ve parçacıklar azalır'),
                  secondary: const Icon(Icons.battery_saver),
                  value: s.lowGraphics,
                  onChanged: ctrl.setLowGraphics,
                ),
                SwitchListTile(
                  title: const Text('Ses efektleri'),
                  subtitle: const Text('Kodla üretilen efektler ve ortam sesi'),
                  secondary: const Icon(Icons.volume_up),
                  value: s.soundEnabled,
                  onChanged: ctrl.setSound,
                ),
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('Usta\'nın rehberini tekrar izle'),
                  onTap: ctrl.restartTutorial,
                ),
                ListTile(
                  leading: const Icon(Icons.save),
                  title: const Text('Şimdi kaydet'),
                  subtitle: Text(
                    'Oyun her ${GameConfig.autoSaveSeconds} sn\'de ve uygulama arka plana geçince otomatik kaydedilir.',
                  ),
                  onTap: () async {
                    await ctrl.save();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
                    }
                  },
                ),
              ],
            ),
          ),
          _section('İstatistikler'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _stat('Toplam üretim', Fmt.barrels(s.stats.totalBarrels)),
                  _stat('Toplam kazanç', Fmt.money(s.stats.totalEarned)),
                  _stat('Açılan kuyu', Fmt.integer(s.stats.wellsDrilled)),
                  _stat('Kuru kuyu', Fmt.integer(s.stats.dryWells)),
                ],
              ),
            ),
          ),
          _section('Yakında'),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: ads.isAvailable,
                  leading: const Icon(Icons.smart_display),
                  title: const Text('Reklam izle: 2 saat üretim x2'),
                  subtitle: const Text('Yakında'),
                  onTap: () async {
                    if (await ads.showRewardedAd()) {
                      ctrl.grantBoost(
                        title: 'Reklam bonusu',
                        source: EffectSource.ad,
                        duration: AdRewardConfig.boostDuration,
                        productionMultiplier: AdRewardConfig.productionMultiplier,
                      );
                    }
                  },
                ),
                ListTile(
                  enabled: leaderboard.isAvailable,
                  leading: const Icon(Icons.leaderboard),
                  title: const Text('Liderlik tablosu'),
                  subtitle: const Text('Yakında'),
                ),
                ListTile(
                  enabled: gps.isAvailable,
                  leading: const Icon(Icons.location_on),
                  title: const Text('Raman\'a git, bonus kazan (GPS)'),
                  subtitle: const Text('Yakında'),
                ),
              ],
            ),
          ),
          _section('Tehlikeli bölge'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Palette.danger),
              title: const Text('Oyunu sıfırla'),
              onTap: () => _confirmReset(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Batman Petrol Ağası, Batman ilinin petrol tarihinden ilham alan bir hayran oyunudur. '
            'DC Comics veya herhangi bir çizgi roman karakteriyle ilgisi yoktur.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _editPlayerName(BuildContext context, WidgetRef ref, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ağa adın'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 18,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Ör. Hamit',
            helperText: 'İleride kullanıcı adın olarak da kullanılabilir',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Kaydet')),
        ],
      ),
    );
    controller.dispose();
    if (result != null) ref.read(gameControllerProvider.notifier).setPlayerName(result);
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misin?'),
        content: const Text('Tüm ilerlemen silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(gameControllerProvider.notifier).resetGame();
  }

  Widget _section(String title) => SectionHeader(title);

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
