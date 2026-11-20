import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import 'usta_avatar.dart';
import 'usta_controller.dart';

/// Ekranın altında beliren Usta konuşma balonu.
class UstaBubble extends ConsumerWidget {
  const UstaBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = ref.watch(ustaProvider);
    if (msg == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => ref.read(ustaProvider.notifier).dismiss(),
      child: UstaSpeech(text: msg.text, mood: msg.mood),
    )
        .animate(key: ValueKey(msg.id))
        .slideY(begin: 0.6, end: 0, duration: 260.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 200.ms);
  }
}

class UstaSpeech extends StatelessWidget {
  const UstaSpeech({super.key, required this.text, this.mood = UstaMood.happy, this.avatarSize = 56, this.footer});
  final String text;
  final UstaMood mood;
  final double avatarSize;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: avatarSize, height: avatarSize, child: UstaAvatar(mood: mood)),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: Palette.sunset, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Usta', style: TextStyle(color: Palette.sunset, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(color: Palette.oil, fontSize: 15, height: 1.25)),
                  if (footer != null) ...[const SizedBox(height: 8), footer!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
