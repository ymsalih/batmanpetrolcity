import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';

extension YieldTierUi on YieldTier {
  String get label => switch (this) {
    YieldTier.low => 'Düşük',
    YieldTier.medium => 'Orta',
    YieldTier.high => 'Yüksek',
  };

  Color get color => switch (this) {
    YieldTier.low => Palette.danger,
    YieldTier.medium => Palette.gold,
    YieldTier.high => Palette.success,
  };
}

class TierLabel extends StatelessWidget {
  const TierLabel({super.key, required this.tier, this.compact = false});
  final YieldTier? tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = tier;
    if (t == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: t.color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
      child: Text(
        compact ? t.label : 'Verim: ${t.label}',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: compact ? 10 : 13),
      ),
    );
  }
}
