import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../visuals/landscape.dart';

/// Liste ekranları için premium arka plan: üstte gerçekçi manzara, aşağı
/// doğru petrol siyahına yumuşak geçiş.
class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({super.key, required this.child, this.seed = 11});
  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Palette.oil)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height * 0.42,
          child: LandscapeBackdrop(seed: seed),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height * 0.42 + 2,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66000000), Palette.oil],
                stops: [0.25, 0.7, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
