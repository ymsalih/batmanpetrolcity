import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/mascot/usta_avatar.dart';
import '../../features/mascot/usta_controller.dart';
import '../game/game_controller.dart';
import '../navigation.dart';
import '../ui/premium.dart';
import '../utils/format.dart';

/// Kabuk ölçüleri: içerik bu boşlukları bırakır, HUD ve menü üstte yüzer.
abstract final class ShellMetrics {
  static double hud(BuildContext c) => MediaQuery.paddingOf(c).top + 70;
  static double nav(BuildContext c) => MediaQuery.paddingOf(c).bottom + 86;
}

/// Buzlu cam üst bilgi paneli: sayarak ilerleyen para, varil, akaryakıt.
class GameHud extends ConsumerWidget {
  const GameHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(gameControllerProvider.select((s) => s.money));
    final crude = ref.watch(gameControllerProvider.select((s) => s.crude));
    final refined = ref.watch(gameControllerProvider.select((s) => s.refined));
    final refinery = ref.watch(gameControllerProvider.select((s) => s.refineryUnlocked));

    return Padding(
      padding: EdgeInsets.fromLTRB(10, MediaQuery.paddingOf(context).top + 8, 10, 0),
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                key: const Key('hud_money'),
                icon: Icons.account_balance_wallet,
                colors: Premium.gold,
                value: money,
                format: Fmt.money,
              ),
            ),
            const SizedBox(width: 6),
            _Stat(icon: Icons.oil_barrel, colors: Premium.sunset, value: crude, format: (v) => Fmt.compact(v.floor())),
            if (refinery) ...[
              const SizedBox(width: 6),
              _Stat(
                icon: Icons.local_gas_station,
                colors: Premium.success,
                value: refined,
                format: (v) => Fmt.compact(v.floor()),
              ),
            ],
            const SizedBox(width: 6),
            const _ChatButton(),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => ref.read(ustaProvider.notifier).tip(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.gold.withValues(alpha: 0.7), width: 1.5),
                ),
                child: const UstaAvatar(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saha grubuna giriş: okunmamış mesaj rozeti ve bekleyen soru işareti.
class _ChatButton extends ConsumerWidget {
  const _ChatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(gameControllerProvider.select((s) => s.chatUnread));
    final pending = ref.watch(gameControllerProvider.select((s) => s.pendingChoice != null));
    return Semantics(
      button: true,
      label: 'Saha grubu, $unread okunmamış mesaj',
      child: GestureDetector(
        key: const Key('hud_chat'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(premiumRoute(const ChatScreen())),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.forum_rounded, color: Colors.white, size: 21),
              ),
              if (unread > 0 || pending)
                Positioned(
                  right: -2,
                  top: -2,
                  child:
                      Container(
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: Premium.danger),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Palette.panel, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              pending && unread == 0 ? '?' : (unread > 9 ? '9+' : '$unread'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          )
                          .animate(key: ValueKey(unread))
                          .scale(begin: const Offset(0.5, 0.5), duration: 250.ms, curve: Curves.easeOutBack),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.icon, required this.colors, required this.value, required this.format});
  final IconData icon;
  final List<Color> colors;
  final double value;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 4, right: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              boxShadow: [BoxShadow(color: colors[1].withValues(alpha: 0.5), blurRadius: 8)],
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedCounter(
                value: value,
                format: format,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Buzlu cam alt menü; seçili sekme parlayan gradyan hap.
class GlassNavBar extends ConsumerWidget {
  const GlassNavBar({super.key});

  static const _items = [
    (AppTab.map, Icons.map_outlined, Icons.map, 'Harita'),
    (AppTab.site, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Saha'),
    (AppTab.crew, Icons.groups_outlined, Icons.groups, 'Ekip'),
    (AppTab.market, Icons.storefront_outlined, Icons.storefront, 'Pazar'),
    (AppTab.settings, Icons.settings_outlined, Icons.settings, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(navProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.paddingOf(context).bottom + 10),
      child: GlassPanel(
        radius: 28,
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (final (t, icon, active, label) in _items)
              Expanded(
                child: _NavItem(
                  icon: tab == t ? active : icon,
                  label: label,
                  selected: tab == t,
                  onTap: () => ref.read(navProvider.notifier).go(t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: Premium.sunset)
                : null,
            boxShadow: selected ? [BoxShadow(color: Palette.sunset.withValues(alpha: 0.5), blurRadius: 14)] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.white60, size: 24)
                  .animate(target: selected ? 1 : 0)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 200.ms),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
