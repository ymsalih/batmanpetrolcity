import 'dart:async';
import 'dart:math';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../core/game/game_controller.dart';
import '../../core/models/chat.dart';
import '../../core/models/worker.dart';
import '../../core/services/feedback.dart';
import '../../core/ui/premium.dart';
import '../../core/utils/format.dart';
import '../crew/worker_avatar.dart';
import '../mascot/usta_avatar.dart';
import 'chat_director.dart';
import 'chat_topics.dart';
import '../../core/ui/responsive.dart';

/// Saha Grubu: Usta ve ekibin yazıştığı grup sohbeti.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatOpenProvider.notifier).set(true);
      ref.read(gameControllerProvider.notifier).markChatRead();
      // Hiç sohbet yoksa grubu Usta açsın.
      if (ref.read(gameControllerProvider).chat.isEmpty) {
        ref.read(chatDirectorProvider.notifier).playSceneById('usta_tavsiye');
      }
    });
  }

  @override
  void deactivate() {
    // Ağaç kurulurken sağlayıcı değiştirilemez: çizim bitince kapat.
    final open = ref.read(chatOpenProvider.notifier);
    scheduleMicrotask(() => open.set(false));
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(gameControllerProvider.select((s) => s.chat));
    final typing = ref.watch(chatDirectorProvider);
    final pad = MediaQuery.paddingOf(context);
    // Ekran açıkken gelen mesajlar okunmuş sayılır.
    ref.listen(gameControllerProvider.select((s) => s.chatUnread), (_, n) {
      if (n > 0) ref.read(gameControllerProvider.notifier).markChatRead();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF15100D),
      extendBodyBehindAppBar: true,
      appBar: const _GroupAppBar(),
      body: Stack(
        children: [
          // Hafif doku: toprak tonlu radyal ışık
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.3,
                  colors: [Color(0xFF2B1F17), Color(0xFF120D0A)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    Responsive.hPad(context, 10),
                    pad.top + kToolbarHeight + 12,
                    Responsive.hPad(context, 10),
                    8,
                  ),
                  itemCount: chat.length + (typing != null ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (typing != null) {
                      if (i == 0) return _TypingRow(typing: typing);
                      i -= 1;
                    }
                    final idx = chat.length - 1 - i;
                    final msg = chat[idx];
                    final prev = idx > 0 ? chat[idx - 1] : null;
                    final grouped = prev != null && _sameSender(prev, msg) && msg.timeMs - prev.timeMs < 120000;
                    return _MessageRow(key: ValueKey(msg.id), msg: msg, grouped: grouped);
                  },
                ),
              ),
              const _BottomPanel(),
            ],
          ),
        ],
      ),
    );
  }

  bool _sameSender(ChatMessage a, ChatMessage b) =>
      a.speaker == b.speaker && (a.speaker != ChatSpeaker.worker || a.workerId == b.workerId);
}

class _GroupAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _GroupAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(gameControllerProvider.select((s) => s.workers));
    final morale = ref.watch(gameControllerProvider.select((s) => s.morale));
    final label = ref.watch(gameControllerProvider.select((s) => s.moraleLabel));
    return ClipRect(
      child: QualityBlur(
        sigma: 16,
        child: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              SizedBox(
                width: 64,
                height: 40,
                child: Stack(
                  children: [
                    const Positioned(left: 0, child: SizedBox(width: 36, height: 36, child: UstaAvatar())),
                    for (var i = 0; i < workers.length.clamp(0, 2); i++)
                      Positioned(
                        left: 16.0 + i * 14,
                        top: 4,
                        child: SizedBox(width: 32, height: 32, child: WorkerAvatar(worker: workers[i])),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saha Grubu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(
                      'Usta ve ${workers.length} kişi · Moral: $label (${morale.round()})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: _MoraleBar(value: morale / 100),
          ),
        ),
      ),
    );
  }
}

class _MoraleBar extends StatelessWidget {
  const _MoraleBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(Palette.danger, Palette.success, value)!;
    return SizedBox(
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 600),
          widthFactor: value.clamp(0.02, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.4), color])),
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends ConsumerWidget {
  const _MessageRow({super.key, required this.msg, required this.grouped});
  final ChatMessage msg;
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateTime.fromMillisecondsSinceEpoch(msg.timeMs);
    final hhmm = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    // Geniş ekranda balonlar okunaklı genişlikte kalsın.
    final maxW = min(MediaQuery.sizeOf(context).width, Responsive.contentMaxWidth) * 0.74;

    if (msg.speaker == ChatSpeaker.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Text(msg.text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        ),
      );
    }

    final mine = msg.speaker == ChatSpeaker.player;
    final isUsta = msg.speaker == ChatSpeaker.usta;
    final worker = msg.workerId == null || mine
        ? null
        : ref.watch(gameControllerProvider.select((s) => s.workerById(msg.workerId!)));
    final addressee = mine && msg.workerId != null
        ? ref.watch(gameControllerProvider.select((s) => s.workerById(msg.workerId!)))
        : null;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        gradient: mine
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: Premium.sunset)
            : null,
        color: mine ? null : (isUsta ? const Color(0xFFFFF1D6) : const Color(0xFF2C2420)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : (grouped ? 18 : 4)),
          bottomRight: Radius.circular(mine ? (grouped ? 18 : 4) : 18),
        ),
        border: isUsta ? Border.all(color: Palette.gold.withValues(alpha: 0.7)) : null,
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine && !grouped)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: msg.name ?? worker?.displayName ?? 'Usta',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _nameColor(isUsta, worker)),
                    ),
                    if (msg.title != null)
                      TextSpan(
                        text: '  ${msg.title}',
                        style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600),
                      ),
                    if (isUsta)
                      const TextSpan(
                        text: '  Usta',
                        style: TextStyle(fontSize: 11, color: Palette.earth, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
          if (addressee != null)
            Text(
              '@${addressee.displayName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF3A2508)),
            ),
          Text(msg.text, style: TextStyle(fontSize: 15, height: 1.3, color: isUsta ? Palette.oil : Colors.white)),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              hhmm,
              style: TextStyle(fontSize: 10, color: isUsta ? Palette.earth : Colors.white.withValues(alpha: 0.55)),
            ),
          ),
        ],
      ),
    );

    final avatar = SizedBox(
      width: 34,
      height: 34,
      child: grouped
          ? null
          : isUsta
          ? const UstaAvatar()
          : worker != null
          ? WorkerAvatar(worker: worker)
          : const Icon(Icons.person, color: Colors.white38),
    );

    return Padding(
      padding: EdgeInsets.only(top: grouped ? 2 : 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[avatar, const SizedBox(width: 6)],
          Flexible(child: bubble),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOut);
  }
}

/// Ad rengi görevin baret rengi; çok açık renkler (beyaz baret) okunmadığı
/// için turuncuya çekilir.
Color _nameColor(bool isUsta, Worker? w) {
  if (isUsta) return Palette.sunset;
  final c = Color(w?.role.helmetColor ?? 0xFFF5C542);
  final lum = c.computeLuminance();
  if (lum > 0.7) return Palette.sunsetLight;
  if (lum < 0.05) return Colors.white70;
  return c;
}

class _TypingRow extends ConsumerWidget {
  const _TypingRow({required this.typing});
  final TypingState typing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = typing.workerId == null
        ? null
        : ref.watch(gameControllerProvider.select((s) => s.workerById(typing.workerId!)));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(width: 34, height: 34, child: worker == null ? const UstaAvatar() : WorkerAvatar(worker: worker)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF2C2420), borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                      )
                      .animate(onPlay: (c) => c.repeat(), delay: (i * 160).ms)
                      .moveY(begin: 0, end: -4, duration: 300.ms, curve: Curves.easeOut)
                      .then()
                      .moveY(begin: -4, end: 0, duration: 300.ms),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${typing.name} yazıyor…',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt panel: bekleyen soru varsa seçenekler, yoksa hızlı eylemler.
class _BottomPanel extends ConsumerWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(gameControllerProvider.select((s) => s.pendingChoice));
    final pad = MediaQuery.paddingOf(context);
    // Çay bekleme süresini saniyede bir güncelle.
    ref.watch(gameControllerProvider.select((s) => s.lastTickMs ~/ 1000));
    final ctrl = ref.read(gameControllerProvider.notifier);
    final director = ref.read(chatDirectorProvider.notifier);

    return ClipRect(
      child: QualityBlur(
        sigma: 14,
        child: Container(
          padding: EdgeInsets.fromLTRB(Responsive.hPad(context, 10), 10, Responsive.hPad(context, 10), pad.bottom + 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: pending != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Cevabın?', style: Premium.overline),
                    ),
                    for (var i = 0; i < pending.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PremiumButton(
                          key: Key('chat_choice_$i'),
                          height: 48,
                          fontSize: 14,
                          shine: i == 0,
                          colors: i == 0 ? Premium.sunset : Premium.steel,
                          label: pending.options[i],
                          onPressed: () {
                            ref.read(feedbackProvider).light();
                            director.choose(i);
                          },
                        ),
                      ),
                  ],
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0)
              : Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        key: const Key('chat_tea'),
                        height: 48,
                        fontSize: 14,
                        shine: false,
                        colors: Premium.gold,
                        foreground: const Color(0xFF3A2508),
                        label: ctrl.teaReady
                            ? 'Çay ısmarla · ${Fmt.money(GameConfig.teaCost)}'
                            : 'Çay demleniyor ${Fmt.clock(ctrl.teaCooldown)}',
                        icon: Icons.local_cafe,
                        onPressed: ctrl.teaReady
                            ? () {
                                ref.read(feedbackProvider).light();
                                director.tea();
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PremiumButton(
                      key: const Key('chat_tip'),
                      expand: false,
                      height: 48,
                      shine: false,
                      colors: Premium.steel,
                      icon: Icons.lightbulb,
                      label: 'İpucu',
                      fontSize: 14,
                      onPressed: () {
                        ref.read(feedbackProvider).light();
                        director.ustaTip();
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Bir işçiyle birebir sohbet penceresi (ekip kartından açılır).
Future<void> showPersonalChat(BuildContext context, Worker w) {
  return showResponsiveSheet(
    context: context,
    // Kendi kaydırılan mesaj listesi var.
    scrollable: false,
    builder: (_) => _PersonalChat(workerId: w.id),
  );
}

class _PersonalChat extends ConsumerWidget {
  const _PersonalChat({required this.workerId});
  final int workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(gameControllerProvider.select((s) => s.workerById(workerId)));
    final msgs = ref.watch(gameControllerProvider.select((s) => s.chat.where((m) => m.workerId == workerId).toList()));
    final typing = ref.watch(chatDirectorProvider);
    if (w == null) return const SizedBox(height: 100);
    final h = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: SizedBox(
        height: h * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  SizedBox(width: 52, height: 52, child: WorkerAvatar(worker: w)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.displayName, style: Premium.title),
                        Text(
                          '${w.rankTitle} · ${w.role.title} hattı',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(10),
                itemCount: msgs.length + (typing?.workerId == workerId ? 1 : 0),
                itemBuilder: (context, i) {
                  if (typing?.workerId == workerId) {
                    if (i == 0) return _TypingRow(typing: typing!);
                    i -= 1;
                  }
                  final idx = msgs.length - 1 - i;
                  return _MessageRow(key: ValueKey(msgs[idx].id), msg: msgs[idx], grouped: false);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final t in ChatTopic.values)
                    ActionChip(
                      key: Key('topic_${t.name}'),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      backgroundColor: Palette.panelLight,
                      side: BorderSide(color: Palette.sunset.withValues(alpha: 0.5)),
                      label: Text('${t.emoji} ${t.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        ref.read(feedbackProvider).light();
                        ref.read(chatDirectorProvider.notifier).ask(w, t);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
