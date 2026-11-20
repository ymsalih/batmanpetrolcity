import 'package:batman_petrol_agasi/config/game_config.dart';
import 'package:batman_petrol_agasi/core/game/game_controller.dart';
import 'package:batman_petrol_agasi/core/models/chat.dart';
import 'package:batman_petrol_agasi/core/models/game_state.dart';
import 'package:batman_petrol_agasi/core/models/worker.dart';
import 'package:batman_petrol_agasi/core/persistence/save_repository.dart';
import 'package:batman_petrol_agasi/core/services/services.dart';
import 'package:batman_petrol_agasi/features/chat/chat_director.dart';
import 'package:batman_petrol_agasi/features/chat/chat_topics.dart';
import 'package:batman_petrol_agasi/features/chat/scenes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock implements Clock {
  FakeClock(this.ms);
  int ms;
  @override
  int nowMs() => ms;
}

void main() {
  const t0 = 1000000000;
  final validWho = {'usta', 'any', 'junior', 'senior', ...GameConfig.crewRoles.map((r) => r.id)};
  final validTokens = {'ağa', 'unvan', 'ad', 'junior', 'senior', ...GameConfig.crewRoles.map((r) => r.id)};
  final token = RegExp(r'\{([^}]+)\}');

  group('Sahne içeriği', () {
    test('kimlikler benzersiz, konuşmacılar ve şablonlar geçerli', () {
      final ids = Scenes.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(Scenes.all.length, greaterThanOrEqualTo(20));
      for (final s in Scenes.all) {
        expect(s.lines, isNotEmpty, reason: s.id);
        final allLines = [...s.lines, for (final c in s.choices) ...c.replies];
        for (final l in allLines) {
          expect(validWho, contains(l.who), reason: '${s.id}: ${l.who}');
          for (final m in token.allMatches(l.text)) {
            expect(validTokens, contains(m.group(1)), reason: '${s.id}: ${l.text}');
          }
        }
        for (final r in s.roles) {
          expect(GameConfig.crewRoles.map((x) => x.id), contains(r), reason: s.id);
        }
      }
    });

    test('her tetikleyicinin en az bir sahnesi var', () {
      for (final t in SceneTrigger.values) {
        expect(Scenes.all.where((s) => s.trigger == t), isNotEmpty, reason: t.name);
      }
    });

    test('her görevin tavsiyesi var, memleket sabit', () {
      for (final r in GameConfig.crewRoles) {
        expect(ChatTopics.advice[r.id], isNotEmpty, reason: r.id);
      }
      const w = Worker(id: 5, roleId: 'sondor', number: 1);
      expect(ChatTopics.hometownOf(w), ChatTopics.hometownOf(w));
    });
  });

  group('Sohbet yönetmeni', () {
    late ProviderContainer c;

    Future<void> settle() async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    setUp(() {
      c = ProviderContainer.test(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(t0)),
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          autoTickProvider.overrideWithValue(false),
          chatAutoProvider.overrideWithValue(false),
          chatTypingScaleProvider.overrideWithValue(0),
        ],
      );
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.state = c
          .read(gameControllerProvider)
          .copyWith(
            tutorialDone: true,
            money: 10000,
            playerName: 'Hamit',
            workers: const [
              Worker(id: 1, roleId: 'sondor', number: 1, rank: 3, name: 'Şeyhmus'),
              Worker(id: 2, roleId: 'derikmen', number: 1, name: 'Reşit'),
            ],
          );
    });

    test('sahne mesajları sırayla eklenir, şablonlar dolar, seçenek bekler', () async {
      c.read(chatDirectorProvider.notifier).playSceneById('hiz_tartismasi');
      await settle();
      final s = c.read(gameControllerProvider);
      expect(s.chat.length, 4);
      expect(s.chat.first.text, contains('Şeyhmus'));
      expect(s.chat.first.name, 'Reşit');
      expect(s.chat.every((m) => !m.text.contains('{')), isTrue);
      expect(s.chat.any((m) => m.text.contains('Hamit Ağa')), isTrue);
      expect(s.chat[1].title, 'Başsondör');
      expect(s.pendingChoice?.options.length, 2);
      expect(s.chatUnread, 4);
    });

    test('seçim moral değiştirir, cevaplar gelir, bekleyen soru kapanır', () async {
      final d = c.read(chatDirectorProvider.notifier);
      d.playSceneById('hiz_tartismasi');
      await settle();
      final before = c.read(gameControllerProvider).morale;
      expect(d.choose(0), isTrue);
      await settle();
      final s = c.read(gameControllerProvider);
      expect(s.pendingChoice, isNull);
      expect(s.morale, before + 4);
      expect(s.chat.where((m) => m.speaker == ChatSpeaker.player).single.text, contains('Emniyet'));
      expect(s.chat.last.speaker, ChatSpeaker.worker);
    });

    test('bedelli seçenekte para düşer; para yetmezse seçilemez', () async {
      final d = c.read(chatDirectorProvider.notifier);
      d.playSceneById('petrol_kutlama');
      await settle();
      final money = c.read(gameControllerProvider).money;
      expect(d.choose(0), isTrue);
      expect(c.read(gameControllerProvider).money, money - 400);

      d.playSceneById('petrol_kutlama');
      await settle();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.state = c.read(gameControllerProvider).copyWith(money: 10);
      expect(d.choose(0), isFalse);
      expect(c.read(gameControllerProvider).pendingChoice, isNotNull);
    });

    test('birebir sohbet: soru ve rütbeye uygun cevap', () async {
      final w = c.read(gameControllerProvider).workerById(1)!;
      c.read(chatDirectorProvider.notifier).ask(w, ChatTopic.tavsiye);
      await settle();
      final msgs = c.read(gameControllerProvider).chat;
      expect(msgs.length, 2);
      expect(msgs.first.speaker, ChatSpeaker.player);
      expect(msgs.first.workerId, 1);
      expect(msgs.first.text, contains('Şeyhmus'));
      expect(msgs.last.name, 'Şeyhmus');
    });

    test('çay ısmarlamak moral yükseltir ve beklemeye girer', () async {
      final d = c.read(chatDirectorProvider.notifier);
      final before = c.read(gameControllerProvider).morale;
      expect(d.tea(), ActionResult.ok);
      expect(c.read(gameControllerProvider).morale, before + GameConfig.teaMorale);
      expect(d.tea(), ActionResult.invalid);
    });

    test('okundu işareti ve geçmiş sınırı', () {
      final ctrl = c.read(gameControllerProvider.notifier);
      for (var i = 0; i < GameConfig.chatHistoryLimit + 10; i++) {
        ctrl.addChat(speaker: ChatSpeaker.usta, text: 'm$i');
      }
      expect(c.read(gameControllerProvider).chat.length, GameConfig.chatHistoryLimit);
      expect(c.read(gameControllerProvider).chat.last.text, 'm${GameConfig.chatHistoryLimit + 9}');
      ctrl.markChatRead();
      expect(c.read(gameControllerProvider).chatUnread, 0);
    });
  });

  test('sohbet, moral ve bekleyen soru kayıttan geri yüklenir', () {
    final s = GameState.initial(t0).copyWith(
      chat: const [
        ChatMessage(
          id: 3,
          speaker: ChatSpeaker.worker,
          text: 'Selam',
          timeMs: t0,
          workerId: 2,
          name: 'Reşit',
          title: 'Derikmen',
        ),
      ],
      chatUnread: 1,
      morale: 81,
      pendingChoice: const PendingChoice(sceneId: 'cay_molasi', options: ['A', 'B']),
    );
    final r = GameState.fromJson(s.toJson(), t0);
    expect(r.chat.single.name, 'Reşit');
    expect(r.chat.single.title, 'Derikmen');
    expect(r.morale, 81);
    expect(r.pendingChoice!.options, ['A', 'B']);
    expect(r.moraleLabel, 'Keyifli');
  });
}
