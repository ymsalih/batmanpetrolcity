import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/services/services.dart';
import '../../core/ui/premium.dart';
import '../../core/utils/format.dart';
import '../../core/visuals/game_visuals.dart';
import '../../core/visuals/landscape.dart';
import '../../core/visuals/painters/derrick_painter.dart';
import '../mascot/usta_avatar.dart';
import 'cinematic_painters.dart';
import 'intro_gate.dart' show EmblemPainter;

/// Sinematiğin bir bölümü.
class _Chapter {
  const _Chapter({
    required this.year,
    required this.title,
    required this.text,
    required this.seconds,
    this.fromYear,
    this.yearLabel,
  });

  final int? year;

  /// Yıl sayacının başladığı değer (ör. 1957 → 1990).
  final int? fromYear;

  /// Yıl yerine gösterilecek etiket.
  final String? yearLabel;
  final String title;
  final String text;

  /// 0 = otomatik ilerlemez (son bölüm).
  final double seconds;
}

/// Açılış sinematiği: Batman'ın petrol tarihi ve şehrin tanıtımı.
/// Bilgiler kamuya açık kaynaklardan derlenmiştir (bkz. README).
class CinematicIntro extends ConsumerStatefulWidget {
  const CinematicIntro({super.key, required this.onDone});
  final VoidCallback onDone;

  static const chapters = <_Chapter>[
    _Chapter(
      year: 1940,
      fromYear: 1900,
      title: 'İlk damla',
      text: 'Raman Dağı\'nın eteğinde açılan Raman-1 kuyusunda, Türkiye\'nin ilk ekonomik petrol rezervi keşfedildi.',
      seconds: 8,
    ),
    _Chapter(
      year: 1948,
      title: 'Kara altın akıyor',
      text: 'Raman\'dan petrol üretimi törenle başladı. At kafaları bu topraklarda ilk kez sallanmaya başladı.',
      seconds: 7.5,
    ),
    _Chapter(
      year: 1955,
      title: 'İlk modern rafineri',
      text: 'Türkiye\'nin ilk modern rafinerisi Batman\'da çalışmaya başladı. Geceleri yanan ışıkları şehrin simgesi oldu.',
      seconds: 7.5,
    ),
    _Chapter(
      year: 1990,
      fromYear: 1957,
      title: 'Köyden şehre',
      text: 'Petrol, küçük İluh köyünü büyüttü. 1957\'de ilçe olup Batman adını aldı; 1990\'da il oldu.',
      seconds: 8.5,
    ),
    _Chapter(
      year: 1961,
      title: 'Batı Raman',
      text: 'Batı Raman\'da keşfedilen saha bugün Türkiye\'nin en büyük petrol sahası. Hikâye hâlâ sürüyor.',
      seconds: 7.5,
    ),
    _Chapter(
      year: null,
      yearLabel: 'BATMAN',
      title: 'Batman\'ı tanı',
      text: 'Dicle ile Batman Çayı\'nın buluştuğu topraklarda binlerce yıllık bir tarih yaşar.',
      seconds: 13,
    ),
    _Chapter(
      year: null,
      yearLabel: 'SIRA SENDE',
      title: 'Hikâyeyi sen yaz',
      text: 'Bu topraklarda petrol bir hikâyedir. Şimdi o hikâyeyi sen yazacaksın, ağam.',
      seconds: 0,
    ),
  ];

  @override
  ConsumerState<CinematicIntro> createState() => _CinematicIntroState();
}

class _CinematicIntroState extends ConsumerState<CinematicIntro> with TickerProviderStateMixin {
  int _i = 0;
  late AnimationController _scene;
  late final Ticker _clock;
  double _time = 0;
  bool _chimed = false;

  _Chapter get _c => CinematicIntro.chapters[_i];
  bool get _last => _i == CinematicIntro.chapters.length - 1;

  @override
  void initState() {
    super.initState();
    _clock = createTicker(_onClock)..start();
    _scene = _makeController();
    _scene.forward();
    _sound(SoundCue.whoosh);
  }

  Duration _lastFrame = Duration.zero;
  Duration _interval = GraphicsLevel.balanced.frameInterval;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _interval = GraphicsMode.of(context).frameInterval;
  }

  /// Sinematik saati grafik seviyesinin kare hızıyla ilerler (15/30/60 fps).
  void _onClock(Duration d) {
    if (d - _lastFrame < _interval) return;
    _lastFrame = d;
    setState(() => _time = d.inMicroseconds / 1e6);
  }

  AnimationController _makeController() {
    final secs = _c.seconds > 0 ? _c.seconds : 6;
    final c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (secs * 1000).round()),
    );
    c.addListener(() {
      if (!_chimed && c.value > 0.3) {
        _chimed = true;
        if (_c.year != null) _sound(SoundCue.chime);
      }
    });
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_last) _go(_i + 1);
    });
    return c;
  }

  void _sound(SoundCue cue) {
    if (ref.read(gameControllerProvider).soundEnabled) ref.read(audioServiceProvider).play(cue);
  }

  void _go(int next) {
    if (next >= CinematicIntro.chapters.length) return;
    final old = _scene;
    setState(() {
      _i = next;
      _chimed = false;
      _scene = _makeController()..forward();
    });
    old.dispose();
    _sound(SoundCue.whoosh);
  }

  /// Dokununca: metin yazılıyorsa tamamla, yazıldıysa sonraki bölüm.
  void _tap() {
    if (_last) return;
    if (_scene.value < _typingEnd) {
      _scene.value = _typingEnd;
    } else {
      _go(_i + 1);
    }
  }

  static const _typingEnd = 0.62;

  @override
  void dispose() {
    _scene.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        // Sahne ilerlemesi her vsync'te değil, kare sınırlı saatle çizilir.
        child: Builder(
          builder: (context) {
            final t = _scene.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Sahne görseli: bölümler arasında yumuşak geçiş, yavaş yakınlaşma.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1100),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(_i),
                    child: Transform.scale(scale: 1.0 + 0.07 * Curves.easeInOut.transform(t), child: _visual(_i, t)),
                  ),
                ),
                // Okunabilirlik için alttan karartma
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xE6000000)],
                        stops: [0, 0.22, 0.5, 0.86],
                      ),
                    ),
                  ),
                ),
                IgnorePointer(child: CustomPaint(painter: _FilmPainter(_time))),
                if (!_last) _caption(t, pad),
                if (_last) _finale(t, pad),
                _topBar(t, pad),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Görseller

  Widget _visual(int i, double t) {
    final visuals = ref.read(gameVisualsProvider);
    switch (i) {
      case 0: // 1940: şafakta kule, sonra fışkırma
        final struck = t > 0.55;
        final shake = struck && t < 0.72 ? (1 - (t - 0.55) / 0.17) * 6 : 0.0;
        return LayoutBuilder(
          builder: (context, box) {
            final h = box.maxHeight;
            return Transform.translate(
              offset: Offset(sin(_time * 90) * shake, cos(_time * 70) * shake),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const LandscapeBackdrop(seed: 7, phase: 0.27),
                  Positioned(
                    left: box.maxWidth / 2 - h * 0.13,
                    width: h * 0.26,
                    top: h * 0.56,
                    height: h * 0.4,
                    child: CustomPaint(
                      painter: DerrickPainter(spin: (_time * 1.5) % 1, time: _time, drilling: !struck, night: 0.15),
                    ),
                  ),
                  if (struck)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: h * 0.94,
                      child: IgnorePointer(child: visuals.gusher(origin: const Offset(0.5, 0.995), groundY: 0.998)),
                    ),
                ],
              ),
            );
          },
        );
      case 1: // 1948: at kafaları beliriyor
        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            const spots = [
              (0.5, 0.86, 0.34),
              (0.18, 0.8, 0.2),
              (0.8, 0.79, 0.19),
              (0.34, 0.76, 0.13),
              (0.66, 0.75, 0.12),
            ];
            return Stack(
              fit: StackFit.expand,
              children: [
                const LandscapeBackdrop(seed: 8, phase: 0.36),
                for (var k = spots.length - 1; k >= 0; k--)
                  Positioned(
                    left: w * spots[k].$1 - h * spots[k].$3 * 0.8,
                    top: h * spots[k].$2 - h * spots[k].$3,
                    width: h * spots[k].$3 * 1.6,
                    height: h * spots[k].$3,
                    child: Opacity(
                      opacity: ((t - k * 0.1) / 0.15).clamp(0.0, 1.0),
                      child: visuals.pumpjack(night: 0.05, sunX: -0.6),
                    ),
                  ),
              ],
            );
          },
        );
      case 2: // 1955: gecede rafineri
        return Stack(
          fit: StackFit.expand,
          children: [
            const LandscapeBackdrop(seed: 9, phase: 0.02),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.7,
                widthFactor: 1,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(
                  painter: RefineryPainter(time: _time, night: 0.45, reveal: (t * 1.7).clamp(0.0, 1.0)),
                ),
              ),
            ),
          ],
        );
      case 3: // Köyden şehre
        return Stack(
          fit: StackFit.expand,
          children: [
            const LandscapeBackdrop(seed: 10, phase: 0.74),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.66,
                widthFactor: 1,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(
                  painter: CityGrowthPainter(
                    growth: Curves.easeInOut.transform(t),
                    time: _time,
                    night: 0.05 + 0.45 * t,
                  ),
                ),
              ),
            ),
          ],
        );
      case 4: // Batı Raman: at kafası tarlası
        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final rng = Random(4);
            return Stack(
              fit: StackFit.expand,
              children: [
                const LandscapeBackdrop(seed: 12, phase: 0.48),
                for (var k = 0; k < 14; k++)
                  () {
                    final depth = rng.nextDouble();
                    final size = h * (0.08 + 0.2 * depth);
                    final y = h * (0.66 + 0.2 * depth);
                    final x = w * rng.nextDouble();
                    return Positioned(
                      left: x - size * 0.8,
                      top: y - size,
                      width: size * 1.6,
                      height: size,
                      child: Opacity(
                        opacity: ((t * 1.6 - k * 0.05)).clamp(0.0, 1.0),
                        child: visuals.pumpjack(night: 0, sunX: 0.2, speed: 0.7 + depth),
                      ),
                    );
                  }(),
              ],
            );
          },
        );
      case 5: // Batman'ı tanı
        return Stack(
          fit: StackFit.expand,
          children: [
            const LandscapeBackdrop(seed: 13, phase: 0.7),
            const ColoredBox(color: Color(0x66000000)),
            _facts(t),
          ],
        );
      default: // Final
        return const LandscapeBackdrop(seed: 7, phase: 0.26);
    }
  }

  Widget _facts(double t) {
    final facts = [
      (
        'Hasankeyf',
        'Dicle kıyısında, kayalara oyulmuş evleri ve binlerce yıllık geçmişiyle dünyanın en eski yerleşimlerinden.',
        const CustomPaint(painter: CliffTownPainter()),
      ),
      (
        'Malabadi Köprüsü',
        '12. yüzyıldan kalma taş kemeriyle Batman Çayı üzerinde yüzyıllardır ayakta.',
        CustomPaint(painter: BridgePainter(_time)),
      ),
      (
        'Sofra ve kültür',
        'İçli köfte, kaburga dolması, demli çay; tribünde Batman Petrolspor coşkusu.',
        const Center(child: Icon(Icons.restaurant, color: Palette.gold, size: 40)),
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 70, 18, 0),
        child: Column(
          children: [
            for (var k = 0; k < facts.length; k++)
              if (t > k * 0.2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    radius: 20,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 84,
                            height: 64,
                            child: ColoredBox(color: const Color(0xFF2A211A), child: facts[k].$3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                facts[k].$1,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Palette.gold),
                              ),
                              const SizedBox(height: 2),
                              Text(facts[k].$2, style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Katmanlar

  Widget _topBar(double t, EdgeInsets pad) {
    final n = CinematicIntro.chapters.length;
    return Positioned(
      top: pad.top + 10,
      left: 14,
      right: 8,
      child: Row(
        children: [
          // Hikâye tarzı ilerleme çubukları
          Expanded(
            child: Row(
              children: [
                for (var k = 0; k < n; k++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: k < _i ? 1 : (k == _i ? (_last ? 1 : t) : 0),
                        child: Container(
                          decoration: BoxDecoration(color: Palette.gold, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!_last)
            TextButton(
              key: const Key('intro_skip'),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                backgroundColor: Colors.black38,
                shape: const StadiumBorder(),
              ),
              onPressed: widget.onDone,
              child: const Text(
                'Geç',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _caption(double t, EdgeInsets pad) {
    final c = _c;
    final typed = (t / _typingEnd).clamp(0.0, 1.0);
    final shown = c.text.substring(0, (c.text.length * typed).round());
    final yearT = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));
    final from = c.fromYear ?? (c.year == null ? 0 : c.year! - 8);
    final yearText = c.year == null ? c.yearLabel! : '${(from + (c.year! - from) * yearT).round()}';

    return Positioned(
      left: 22,
      right: 22,
      bottom: pad.bottom + 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Premium.goldText(yearText, size: c.year == null ? 30 : 60, spacing: c.year == null ? 4 : 2),
          const SizedBox(height: 2),
          Text(
            Fmt.upperTr(c.title),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 36, height: 36, child: UstaAvatar()),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.4,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: t > _typingEnd ? 0.6 : 0,
            child: const Text('Devam etmek için dokun', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _finale(double t, EdgeInsets pad) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          children: [
            const Spacer(flex: 3),
            const SizedBox(width: 140, height: 140, child: CustomPaint(painter: EmblemPainter()))
                .animate()
                .fadeIn(duration: 700.ms)
                .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack, duration: 900.ms),
            const SizedBox(height: 18),
            Text(
              'BATMAN',
              style: Premium.overline.copyWith(fontSize: 14, letterSpacing: 10, color: Colors.white70),
            ).animate().fadeIn(delay: 300.ms),
            Premium.goldText(
              'PETROL AĞASI',
              size: 38,
              spacing: 2,
            ).animate().fadeIn(delay: 500.ms).then(delay: 300.ms).shimmer(duration: 1500.ms, color: Colors.white70),
            const SizedBox(height: 14),
            Text(
              _c.text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            ).animate().fadeIn(delay: 900.ms),
            const Spacer(flex: 2),
            SizedBox(
              width: 280,
              child: PremiumButton(
                key: const Key('intro_start'),
                height: 56,
                colors: Premium.gold,
                foreground: const Color(0xFF3A2508),
                icon: Icons.play_arrow_rounded,
                label: 'Hikâyeni yazmaya başla',
                onPressed: widget.onDone,
              ),
            ).animate().fadeIn(delay: 1300.ms).slideY(begin: 0.4, end: 0),
            const SizedBox(height: 12),
            const Text(
              'Tarihler kamuya açık kaynaklardan derlenmiştir.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            SizedBox(height: pad.bottom > 0 ? 8 : 20),
          ],
        ),
      ),
    );
  }
}

/// Sinema bantları, vinyet ve film greni.
class _FilmPainter extends CustomPainter {
  _FilmPainter(this.time);
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Vinyet
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.75,
          [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          const [0.55, 1],
        ),
    );
    // Gren
    final rng = Random((time * 24).floor());
    final grain = Paint();
    for (var i = 0; i < 260; i++) {
      grain.color = (rng.nextBool() ? Colors.white : Colors.black).withValues(alpha: 0.05 + rng.nextDouble() * 0.05);
      canvas.drawRect(Rect.fromLTWH(rng.nextDouble() * size.width, rng.nextDouble() * size.height, 1.4, 1.4), grain);
    }
    // Sinema bantları
    final bar = size.height * 0.045;
    final black = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, bar), black);
    canvas.drawRect(Rect.fromLTWH(0, size.height - bar, size.width, bar), black);
  }

  @override
  bool shouldRepaint(_FilmPainter old) => old.time != time;
}
