import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../core/game/game_controller.dart';
import '../../core/game/game_events.dart';
import '../../core/models/chat.dart';
import '../../core/models/game_state.dart';
import '../../core/models/worker.dart';
import '../../core/services/services.dart';
import '../crew/crew_lines.dart';
import '../mascot/usta_controller.dart';
import '../mascot/usta_lines.dart';
import 'chat_topics.dart';
import 'scenes.dart';

/// "… yazıyor" göstergesi.
class TypingState {
  const TypingState({required this.name, this.workerId});
  final String name;
  final int? workerId;
  bool get isUsta => workerId == null;
}

/// Sohbet ekranı açık mı (açıksa önizleme balonu gösterilmez).
final chatOpenProvider = NotifierProvider<ChatOpenController, bool>(ChatOpenController.new);

class ChatOpenController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

/// Testlerde kendiliğinden sohbet zamanlayıcısını kapatmak için.
final chatAutoProvider = Provider<bool>((ref) => true);

/// Mesaj yazma gecikmesini ölçekler (testlerde 0).
final chatTypingScaleProvider = Provider<double>((ref) => 1);

final chatDirectorProvider = NotifierProvider<ChatDirector, TypingState?>(ChatDirector.new);

/// Saha grubunu yöneten "yönetmen": sahneleri seçer, satır satır yazdırır,
/// oyuncunun seçimlerini ve birebir sohbetleri işler.
class ChatDirector extends Notifier<TypingState?> {
  final _rng = Random();
  final _lastAsk = <int, int>{};
  Timer? _idle;
  bool _busy = false;
  bool _disposed = false;
  final _queue = <Future<void> Function()>[];

  GameController get _ctrl => ref.read(gameControllerProvider.notifier);
  GameState get _game => ref.read(gameControllerProvider);

  @override
  TypingState? build() {
    final sub = _ctrl.events.listen(_onEvent);
    if (ref.read(chatAutoProvider)) _scheduleIdle();
    ref.onDispose(() {
      _disposed = true;
      _idle?.cancel();
      sub.cancel();
    });
    return null;
  }

  // ------------------------------------------------------------ Zamanlama

  void _scheduleIdle() {
    const minS = GameConfig.chatSceneMinGapSeconds;
    const maxS = GameConfig.chatSceneMaxGapSeconds;
    _idle?.cancel();
    _idle = Timer(Duration(seconds: minS + _rng.nextInt(maxS - minS + 1)), () {
      _tryScene(SceneTrigger.idle);
      if (!_disposed) _scheduleIdle();
    });
  }

  void _onEvent(GameEvent e) {
    final (trigger, chance) = switch (e) {
      DrillFinished(:final struck) => (struck ? SceneTrigger.strike : SceneTrigger.dry, 0.75),
      CrewChanged(:final promoted) => (promoted ? SceneTrigger.promoted : SceneTrigger.hired, 1.0),
      RandomEventStarted(:final config) => (
        switch (config.kind) {
          GameEventKind.heatWave => SceneTrigger.heatWave,
          GameEventKind.priceSpike => SceneTrigger.priceSpike,
          GameEventKind.breakdown => SceneTrigger.breakdown,
        },
        0.7,
      ),
      _ => (null, 0.0),
    };
    if (trigger == null || _rng.nextDouble() > chance) return;
    // Olay balonu önce görünsün, grup sohbeti biraz sonra başlasın.
    Future.delayed(_scaled(const Duration(milliseconds: 2500)), () => _tryScene(trigger));
  }

  /// Uygun bir sahne seçip sıraya koyar. Oynatıldıysa true.
  bool _tryScene(SceneTrigger trigger) {
    if (_disposed) return false;
    final game = _game;
    if (!game.tutorialDone) return false;
    // Cevap bekleyen soru varken yeni gündelik sohbet açılmaz.
    if (trigger == SceneTrigger.idle && (game.pendingChoice != null || _busy)) return false;
    final pool = Scenes.all.where((s) => s.trigger == trigger && _eligible(s, game)).toList();
    if (pool.isEmpty) return false;
    final scene = _weighted(pool);
    _enqueue(() => _playScene(scene));
    return true;
  }

  /// Hata ayıklama ve testler için belirli bir sahneyi başlatır.
  void playSceneById(String id) {
    final scene = Scenes.all.where((s) => s.id == id).firstOrNull;
    if (scene != null) _enqueue(() => _playScene(scene));
  }

  bool _eligible(ChatScene s, GameState g) {
    if (g.workers.length < s.minCrew) return false;
    for (final role in s.roles) {
      if (g.hiredCount(role) == 0) return false;
    }
    final needsWorker = s.lines.any((l) => l.who != 'usta');
    return !needsWorker || g.workers.isNotEmpty;
  }

  ChatScene _weighted(List<ChatScene> pool) {
    final total = pool.fold(0.0, (a, s) => a + s.weight);
    var roll = _rng.nextDouble() * total;
    for (final s in pool) {
      roll -= s.weight;
      if (roll <= 0) return s;
    }
    return pool.last;
  }

  void _enqueue(Future<void> Function() job) {
    _queue.add(job);
    if (!_busy) unawaited(_drain());
  }

  Future<void> _drain() async {
    _busy = true;
    while (_queue.isNotEmpty && !_disposed) {
      await _queue.removeAt(0)();
    }
    _busy = false;
  }

  // ------------------------------------------------------------- Sahneler

  /// Sahne boyunca konuşmacılar sabit kalsın diye bağlam.
  Map<String, Worker?> _context(GameState g) {
    final ctx = <String, Worker?>{};
    for (final role in GameConfig.crewRoles) {
      ctx[role.id] = g.leadOf(role.id);
    }
    if (g.workers.isNotEmpty) {
      final byRank = [...g.workers]
        ..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : b.hiredAtMs.compareTo(a.hiredAtMs));
      ctx['junior'] = byRank.first;
      ctx['senior'] = byRank.last;
    }
    return ctx;
  }

  Worker? _speaker(String who, Map<String, Worker?> ctx) {
    if (who == 'usta') return null;
    if (who == 'any') {
      final ws = _game.workers;
      return ws.isEmpty ? null : ws[_rng.nextInt(ws.length)];
    }
    return ctx[who] ?? ctx['senior'];
  }

  String _fillNames(String text, Map<String, Worker?> ctx) {
    var t = text;
    for (final e in ctx.entries) {
      t = t.replaceAll('{${e.key}}', e.value?.displayName ?? 'arkadaşlar');
    }
    return t;
  }

  Future<void> _playScene(ChatScene scene) async {
    final ctx = _context(_game);
    await _playLines(scene.lines, ctx, preview: true);
    if (scene.choices.isNotEmpty && !_disposed) {
      _ctrl.setPendingChoice(PendingChoice(sceneId: scene.id, options: scene.choices.map((c) => c.text).toList()));
    }
  }

  Future<void> _playLines(List<SceneLine> lines, Map<String, Worker?> ctx, {bool preview = false}) async {
    var first = true;
    for (final line in lines) {
      if (_disposed) return;
      final w = _speaker(line.who, ctx);
      if (line.who != 'usta' && w == null) continue; // ekipte kimse yoksa satır atlanır
      await _post(w, _fillNames(line.text, ctx), preview: preview && first);
      first = false;
    }
  }

  /// "Yazıyor" gösterip mesajı gruba ekler.
  Future<void> _post(Worker? w, String text, {bool preview = false}) async {
    final game = _game;
    final filled = CrewLines.fill(text, address: game.address, worker: w);
    state = TypingState(name: w?.displayName ?? 'Usta', workerId: w?.id);
    final ms = (600 + filled.length * 28).clamp(700, 2600);
    await Future.delayed(_scaled(Duration(milliseconds: ms)));
    if (_disposed) return;
    state = null;
    _ctrl.addChat(
      speaker: w == null ? ChatSpeaker.usta : ChatSpeaker.worker,
      text: filled,
      workerId: w?.id,
      name: w?.displayName ?? 'Usta',
      title: w?.rankTitle,
      unread: !ref.read(chatOpenProvider),
    );
    if (_game.soundEnabled) ref.read(audioServiceProvider).play(SoundCue.message);
    // Sohbet ekranı kapalıysa ilk mesajı kısa bir önizleme olarak göster.
    if (preview && !ref.read(chatOpenProvider)) {
      ref.read(ustaProvider.notifier).say(text, workerId: w?.id, log: false, duration: const Duration(seconds: 3));
    }
    await Future.delayed(_scaled(const Duration(milliseconds: 350)));
  }

  Duration _scaled(Duration d) => d * ref.read(chatTypingScaleProvider);

  // ---------------------------------------------------- Oyuncu etkileşimi

  /// Bekleyen sorudaki seçeneği seçer. Para yetmezse false.
  bool choose(int index) {
    final pc = _game.pendingChoice;
    if (pc == null) return false;
    final scene = Scenes.all.where((s) => s.id == pc.sceneId).firstOrNull;
    if (scene == null || index < 0 || index >= scene.choices.length) {
      _ctrl.setPendingChoice(null);
      return false;
    }
    final choice = scene.choices[index];
    if (!_ctrl.spend(choice.cost)) {
      ref.read(ustaProvider.notifier).noMoney();
      return false;
    }
    _ctrl.setPendingChoice(null);
    _ctrl.addChat(speaker: ChatSpeaker.player, text: choice.text, name: _game.playerName ?? 'Ağa', unread: false);
    if (choice.morale != 0) _ctrl.adjustMorale(choice.morale);
    final ctx = _context(_game);
    _enqueue(() => _playLines(choice.replies, ctx));
    return true;
  }

  /// Bir işçiyle birebir sohbet.
  void ask(Worker w, ChatTopic topic) {
    final game = _game;
    final q = ChatTopics.questions[topic]!;
    final question = q[_rng.nextInt(q.length)].replaceAll('{ad}', w.displayName);
    _ctrl.addChat(
      speaker: ChatSpeaker.player,
      text: question,
      workerId: w.id,
      name: game.playerName ?? 'Ağa',
      unread: false,
    );
    final tier = CrewLines.tierOf(w);
    final good = game.morale >= 45;
    final List<String> pool = switch (topic) {
      ChatTopic.halHatir => (good ? ChatTopics.halHatirGood : ChatTopics.halHatirBad)[tier]!,
      ChatTopic.isNasil => CrewLines.chatFor(w),
      ChatTopic.memleket => [ChatTopics.hometownOf(w)],
      ChatTopic.tavsiye => ChatTopics.advice[w.roleId] ?? const ['Gözünü dört aç {ağa}, gerisi kolay.'],
      ChatTopic.hikaye => ChatTopics.stories[tier]!,
    };
    final reply = pool[_rng.nextInt(pool.length)];
    // Hal hatır sormak gönül alır (işçi başına birkaç dakikada bir).
    final now = DateTime.now().millisecondsSinceEpoch;
    if (topic == ChatTopic.halHatir && now - (_lastAsk[w.id] ?? 0) > 180000) {
      _lastAsk[w.id] = now;
      _ctrl.adjustMorale(1.5);
    }
    _enqueue(() => _post(w, reply));
  }

  /// Ekibe çay ısmarlar.
  ActionResult tea() {
    final r = _ctrl.buyTea();
    if (r != ActionResult.ok) {
      if (r == ActionResult.notEnoughMoney) ref.read(ustaProvider.notifier).noMoney();
      return r;
    }
    _ctrl.addChat(
      speaker: ChatSpeaker.player,
      text: 'Herkese çay benden! ☕',
      name: _game.playerName ?? 'Ağa',
      unread: false,
    );
    final ctx = _context(_game);
    _enqueue(
      () => _playLines(const [
        SceneLine('any', 'Eyvallah {ağa}! Çay gibisi yok.'),
        SceneLine('usta', 'Çaysız petrol çıkmaz derler, doğrudur.'),
      ], ctx),
    );
    return r;
  }

  /// Usta'dan gruba bir ipucu.
  void ustaTip() {
    _ctrl.addChat(
      speaker: ChatSpeaker.player,
      text: 'Usta, bir ipucu ver.',
      name: _game.playerName ?? 'Ağa',
      unread: false,
    );
    final tips = UstaLines.tips;
    _enqueue(() => _post(null, tips[_rng.nextInt(tips.length)]));
  }
}
