import '../../core/models/worker.dart';
import '../crew/crew_lines.dart';

/// Oyuncunun bir işçiyle birebir açabileceği konular.
enum ChatTopic { halHatir, isNasil, memleket, tavsiye, hikaye }

extension ChatTopicUi on ChatTopic {
  String get label => switch (this) {
    ChatTopic.halHatir => 'Nasılsın?',
    ChatTopic.isNasil => 'İş nasıl gidiyor?',
    ChatTopic.memleket => 'Memleket nere?',
    ChatTopic.tavsiye => 'Bir tavsiye ver',
    ChatTopic.hikaye => 'Bir hikâye anlat',
  };

  String get emoji => switch (this) {
    ChatTopic.halHatir => '👋',
    ChatTopic.isNasil => '🛠️',
    ChatTopic.memleket => '🏡',
    ChatTopic.tavsiye => '💡',
    ChatTopic.hikaye => '📖',
  };
}

abstract final class ChatTopics {
  /// Oyuncunun soru cümleleri.
  static const questions = {
    ChatTopic.halHatir: ['{ad}, nasılsın? Keyifler yerinde mi?', 'Hayırlı işler {ad}, nasıl gidiyor?'],
    ChatTopic.isNasil: ['İşler nasıl {ad}?', '{ad}, sahada durum ne?'],
    ChatTopic.memleket: ['{ad}, memleket nere?', 'Sen nerelisin {ad}?'],
    ChatTopic.tavsiye: ['{ad}, bana bir tavsiye ver.', 'Senin işinde neye dikkat edeyim {ad}?'],
    ChatTopic.hikaye: ['{ad}, anlat hele bir hikâye.', 'Eski günlerden bir şey anlat {ad}.'],
  };

  /// Hal hatır: moral iyiyse/kötüyse farklı.
  static const halHatirGood = {
    RankTier.junior: [
      'Çok iyiyim {ağa}! İş öğreniyorum, ekmeğimi kazanıyorum.',
      'Elhamdülillah {ağa}, sen sorunca daha iyi oldum.',
    ],
    RankTier.mid: ['İyiyim {ağa}, ekip sağlam, iş yolunda.', 'Keyfim yerinde, çayım sıcak. Daha ne isterim?'],
    RankTier.senior: [
      'Bu yaşta sağlık olsun {ağa}. Sahada olmak bana iyi geliyor.',
      'Kırk yıldır bu topraktayım, her gün şükrediyorum.',
    ],
  };
  static const halHatirBad = {
    RankTier.junior: [
      'Biraz yorgunum {ağa}, ama şikâyet etmiyorum.',
      'Ekip biraz gergin bugünlerde, bilmem farkında mısın?',
    ],
    RankTier.mid: [
      'Moraller pek iyi değil {ağa}. Bir çay molası iyi gelirdi.',
      'İdare ediyoruz {ağa}, ama ekip yorgun.',
    ],
    RankTier.senior: [
      'Ekip bıkkın {ağa}. Bir gönül al, gerisi gelir.',
      'Gençler yoruldu. Ağa dediğin arada bir halini sorar.',
    ],
  };

  /// Memleketler: işçinin kimliğine göre sabit seçilir.
  static const hometowns = [
    'Kozluk\'tanım {ağa}. Bizim oranın dağları yeşil olur, burası gibi değil.',
    'Sason\'luyum. Bizim köyde ceviz ağaçları vardı, şimdi petrol kuyuları.',
    'Beşiri\'den geliyorum {ağa}. Babam da bu sahalarda çalıştı.',
    'Hasankeyf\'liyim. Dicle kenarında büyüdüm, suyu çok severim.',
    'Gercüş\'lüyüm. Oranın üzümü meşhurdur, bir gün getiririm sana.',
    'Batman merkezdenim {ağa}, Raman mahallesinde doğdum. Petrolün yanında büyüdüm.',
    'Siirt\'tenim aslen, ama yirmi yıldır Batman\'dayım. Artık buralıyım.',
    'Diyarbakır\'dan geldim. Sur\'un içinde büyüdüm, burası da ikinci evim oldu.',
    'Mardin\'denim {ağa}. Taş evlerimiz vardır, akşamları serin olur.',
    'Kurtalan\'lıyım. Trenle gelirdik eskiden, şimdi yol kolay.',
  ];

  /// Göreve göre oyun ipuçları.
  static const advice = {
    'muhendis': [
      'Ekip büyüdükçe etkisi katlanır {ağa}. Önce sondör ve şoför, sonra gerisi.',
      'Moral düşerse üretim düşer. Arada çay ısmarla, gönül al.',
    ],
    'sondor': [
      'Uzun sondajlarda ekrana sık sık dokun, matkap hızlanır.',
      'Garzan\'ın sondajı uzun sürer. Orada beni terfi ettirirsen zaman kazanırsın.',
    ],
    'derikmen': [
      'Ben kıdem kazandıkça her dokunuşun daha çok iş görür {ağa}.',
      'Sondajın ilk yarısında hızlı dokun, son yarıda zaten bitiyor.',
    ],
    'jeolog': [
      'Etütte "Yüksek" çıkan parsele mutlaka sondaj yap, kuru çıkma ihtimali düşüktür.',
      '"Düşük" verimli parseli boşuna delme {ağa}, başka parsel dene.',
    ],
    'pompaci': [
      'Pompa seviyesini yükselt ama depoyu unutma. Dolu depo boşa çalışmak demek.',
      'Yüksek verimli kuyunun pompasını önce yükselt, en çok o kazandırır.',
    ],
    'mekanik': [
      'Arızayı ben hallederim ama beni terfi ettirirsen daha çabuk yetişirim.',
      'Batman sıcağında motorlar zorlanır, o zaman üretim düşer. Telaşlanma.',
    ],
    'sofor': [
      'Uzun süre oyunda olmayacaksan merak etme, ben depoları boşaltırım.',
      'Ben varken depo kapasitesi o kadar önemli değil, ama yine de büyüt.',
    ],
    'tuccar': [
      'Fiyat ortalamanın altındayken satma {ağa}, iki dakika bekle.',
      '"Fiyat uçtu" olunca her şeyi sat. Rafineri varsa önce rafine et, sonra sat.',
    ],
    'isci': [
      'Kuyulara sık uğra {ağa}, dolu depoya dokunmak yeter.',
      'Ne kadar çok işçi, o kadar çok el. Altı kişiye kadar alabilirsin.',
    ],
  };

  /// Hikâyeler: kıdemliler daha uzun anlatır.
  static const stories = {
    RankTier.junior: [
      'İlk günüm sahaya geldiğimde baretimi ters takmışım {ağa}. Bütün ekip güldü, şimdi ben de gülüyorum.',
      'Geçen hafta ilk defa kuleye çıktım. Aşağı bakmadım, yalnız gökyüzüne baktım.',
    ],
    RankTier.mid: [
      'Bir kış öyle kar yağdı ki tankerler gelemedi. Petrolü varillere doldurup traktörle taşıdık.',
      'Bir gece jeneratör bozuldu, fenerlerle çalıştık. Sabah olduğunda kuyu hâlâ dönüyordu.',
    ],
    RankTier.senior: [
      'Yetmişli yıllarda bu saha bir köydü {ağa}. İlk kuleyi kurduğumuzda çocuklar etrafımızda koşardı. Şimdi o çocukların çocukları burada çalışıyor.',
      'Bir keresinde kuyu kontrolden çıkacaktı. Başsondör bağırdı, herkes yerine koştu. O gece kimse uyumadı ama kimseye bir şey olmadı. Ekip dediğin budur.',
    ],
  };

  static String hometownOf(Worker w) => hometowns[(w.id * 3 + w.roleId.length) % hometowns.length];
}
