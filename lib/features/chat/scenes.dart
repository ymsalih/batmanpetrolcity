/// Saha grubundaki çok turlu sohbet sahneleri.
///
/// Konuşmacı ([SceneLine.who]):
/// - 'usta': Usta
/// - görev kodu ('sondor', 'derikmen', ...): o görevdeki en kıdemli işçi
/// - 'junior': ekibin en yeni/düşük rütbeli işçisi, 'senior': en kıdemlisi
/// - 'any': rastgele bir işçi
///
/// Metin şablonları: {ağa} oyuncuya hitap; {sondor}, {derikmen}, {jeolog},
/// {pompaci}, {mekanik}, {sofor}, {tuccar}, {isci}, {muhendis} o görevdeki
/// işçinin adı; {junior}, {senior} adları; {unvan} konuşanın unvanı.
library;

class SceneLine {
  const SceneLine(this.who, this.text);
  final String who;
  final String text;
}

class SceneChoice {
  const SceneChoice(this.text, {this.morale = 0, this.cost = 0, this.replies = const []});

  /// Oyuncunun gruba yazdığı cevap.
  final String text;
  final double morale;
  final double cost;
  final List<SceneLine> replies;
}

enum SceneTrigger { idle, strike, dry, promoted, hired, heatWave, priceSpike, breakdown }

class ChatScene {
  const ChatScene({
    required this.id,
    required this.lines,
    this.trigger = SceneTrigger.idle,
    this.roles = const [],
    this.choices = const [],
    this.minCrew = 0,
    this.weight = 1,
  });

  final String id;
  final SceneTrigger trigger;

  /// Sahnenin oynanması için ekipte bulunması gereken görevler.
  final List<String> roles;
  final List<SceneLine> lines;
  final List<SceneChoice> choices;
  final int minCrew;
  final double weight;
}

abstract final class Scenes {
  static const all = <ChatScene>[
    // ------------------------------------------------------------ Gündelik
    ChatScene(
      id: 'cay_molasi',
      minCrew: 1,
      weight: 2,
      lines: [
        SceneLine('usta', 'Çay demlendi, ince belli bardaklar hazır. Kim içer?'),
        SceneLine('any', 'Ben içerim Usta! Tavşan kanı olsun.'),
        SceneLine('senior', 'Bir de şeker getir, bu sıcakta tatlı çay iyi gider.'),
      ],
      choices: [
        SceneChoice(
          'Herkese çay benden! ☕',
          morale: 6,
          cost: 50,
          replies: [
            SceneLine('any', 'Eyvallah {ağa}! Gönlüne sağlık.'),
            SceneLine('usta', 'Bak hele, ağanın eli açık. Böyle ağaya can kurban.'),
          ],
        ),
        SceneChoice(
          'Önce iş, sonra çay.',
          morale: -3,
          replies: [
            SceneLine('any', 'Peki {ağa}... Çay soğumasın bari.'),
            SceneLine('usta', 'Ağa haklı, ama bıraz dinlenen işçi iki kat çalışır, unutma.'),
          ],
        ),
      ],
    ),
    ChatScene(
      id: 'hiz_tartismasi',
      roles: ['sondor', 'derikmen'],
      weight: 1.5,
      lines: [
        SceneLine('derikmen', '{sondor} abi, biraz daha hızlı insek? Borular hazır bekliyor.'),
        SceneLine('sondor', 'Acele işe şeytan karışır {derikmen}. Kireçtaşında matkap yanar.'),
        SceneLine('derikmen', 'Ama {ağa} bugün bitsin istiyor...'),
        SceneLine('sondor', 'Ağaya soralım o zaman. {ağa}, ne dersin?'),
      ],
      choices: [
        SceneChoice(
          'Emniyet önce gelir, sondör haklı.',
          morale: 4,
          replies: [
            SceneLine('sondor', 'Sağ ol {ağa}. Yavaş ama sağlam ineriz.'),
            SceneLine('derikmen', 'Tamam abi, sen bilirsin. Ben boruları dizerim.'),
          ],
        ),
        SceneChoice(
          'Derikmen haklı, hızlanalım!',
          morale: 1,
          replies: [
            SceneLine('derikmen', 'Duydun mu abi! Hadi bakalım!'),
            SceneLine('sondor', 'Peki {ağa}... ama ekrana sen de dokun, yardım et bari.'),
          ],
        ),
      ],
    ),
    ChatScene(
      id: 'raman_1940',
      weight: 1.2,
      lines: [
        SceneLine('usta', 'Size bir hikâye anlatayım mı? 1940 yılıydı...'),
        SceneLine('usta', 'Raman Dağı\'nın eteğinde ilk kuyu fışkırdığında bütün köy toplandı.'),
        SceneLine(
          'usta',
          'Kimse ne olduğunu bilmiyordu. Kara, yağlı bir su dediler. O kara su bu memleketin kaderini değiştirdi.',
        ),
        SceneLine('any', 'Usta, sen de orada mıydın?'),
        SceneLine('usta', 'Ha ha! O kadar da yaşlı değilim lo. Ama babam oradaydı, bana o anlattı.'),
      ],
    ),
    ChatScene(
      id: 'petrolspor',
      roles: ['isci'],
      minCrew: 2,
      lines: [
        SceneLine('isci', 'Akşam Petrolspor\'un maçı var, kim geliyor?'),
        SceneLine('senior', 'Ben gelirim. Ama vardiya biterse.'),
        SceneLine('isci', '{ağa}, sen de gel! Tribünde bağırırız beraber.'),
      ],
      choices: [
        SceneChoice(
          'Biletler benden, hep beraber gidelim!',
          morale: 8,
          cost: 300,
          replies: [
            SceneLine('isci', 'Yaşa {ağa}! Bu akşam stat bizim!'),
            SceneLine('usta', 'Ben de gelirim o zaman, atkımı bulayım.'),
          ],
        ),
        SceneChoice(
          'Siz gidin, ben sahada kalayım.',
          morale: 1,
          replies: [SceneLine('isci', 'Peki {ağa}, golleri sana mesajla atarız!')],
        ),
      ],
    ),
    ChatScene(
      id: 'aksam_yemegi',
      minCrew: 1,
      lines: [
        SceneLine('any', 'Akşam yemeğinde ne var Usta?'),
        SceneLine('usta', 'Kamp aşçısı kaburga dolması yapmış, yanında da içli köfte.'),
        SceneLine('senior', 'Hele! Bugün işler bitmeden kimse sofraya oturmasın.'),
        SceneLine('any', 'Kokusu sondaj kulesine kadar geliyor lo...'),
      ],
    ),
    ChatScene(
      id: 'hasankeyf',
      minCrew: 2,
      lines: [
        SceneLine('junior', 'Hafta sonu izinde Hasankeyf\'e gitmeyi düşünüyorum.'),
        SceneLine('senior', 'Git, git. Dicle kenarında oturursun, kafan dinlenir.'),
        SceneLine('usta', 'Hasankeyf binlerce yıllık. Bizim petrol onun yanında dün doğmuş çocuk.'),
      ],
      choices: [
        SceneChoice(
          'Git, iyi dinlen. İzin senin.',
          morale: 4,
          replies: [SceneLine('junior', 'Sağ ol {ağa}! Size Hasankeyf\'ten fotoğraf atarım.')],
        ),
        SceneChoice(
          'Bu hafta iş çok, sonra gidersin.',
          morale: -2,
          replies: [SceneLine('junior', 'Anladım {ağa}... Sonraki haftaya inşallah.')],
        ),
      ],
    ),
    ChatScene(
      id: 'yeni_cocuk',
      minCrew: 2,
      weight: 1.3,
      lines: [
        SceneLine('senior', '{junior}, anahtarı yine ters tutmuşsun lo!'),
        SceneLine('junior', 'Abi ben öyle öğrendim...'),
        SceneLine('senior', 'Gel buraya, göstereyim. Biz de böyle başladık, utanma.'),
        SceneLine('usta', 'Kıdemli dediğin böyle olur. Bildiğini öğretecek.'),
      ],
    ),
    ChatScene(
      id: 'jeoloji_dersi',
      roles: ['jeolog'],
      lines: [
        SceneLine('jeolog', 'Bugün çamurdan çıkan kırıntılara baktım. Kireçtaşına girdik.'),
        SceneLine('any', 'Bu iyi mi kötü mü {jeolog}?'),
        SceneLine('jeolog', 'Rezervuarımız genelde kireçtaşının altında. Yani kokusunu aldık diyebilirim.'),
        SceneLine('usta', 'Jeolog konuştuysa iş ciddi. Kulaklarınızı açın.'),
      ],
    ),
    ChatScene(
      id: 'sofor_yol',
      roles: ['sofor'],
      lines: [
        SceneLine('sofor', 'Kozluk yolunda bir sürü koyun vardı, tankerle yarım saat bekledim.'),
        SceneLine('any', 'Çoban yol vermedi mi?'),
        SceneLine('sofor', 'Verdi de, koyunlar vermedi lo! Ama petrol yerine ulaştı, merak etme {ağa}.'),
      ],
    ),
    ChatScene(
      id: 'tuccar_piyasa',
      roles: ['tuccar'],
      lines: [
        SceneLine('tuccar', 'Piyasa dalgalı {ağa}. Bugün satarsak az kazanırız, beklersek belki çok.'),
        SceneLine('usta', 'Tüccar gibi konuş, tüccar gibi düşün. Ama sabrı da elden bırakma.'),
      ],
      choices: [
        SceneChoice(
          'Sana güveniyorum, en iyi anı sen kolla.',
          morale: 3,
          replies: [SceneLine('tuccar', 'Güvenine layık olacağım {ağa}.')],
        ),
        SceneChoice(
          'Fiyatı ben takip ederim.',
          replies: [SceneLine('tuccar', 'Peki {ağa}, grafiği sana bırakıyorum.')],
        ),
      ],
    ),
    ChatScene(
      id: 'makinist_ses',
      roles: ['mekanik'],
      lines: [
        SceneLine('mekanik', '3 numaralı at kafası garip ses yapıyor, dinlediniz mi?'),
        SceneLine('any', 'Ben bir şey duymadım ki.'),
        SceneLine('mekanik', 'Sen duymazsın, ben duyarım. Yarın sabah yağını değiştiririm.'),
        SceneLine('usta', 'Makinistin kulağı motorun kalbidir.'),
      ],
    ),
    ChatScene(
      id: 'emniyet_toplantisi',
      roles: ['muhendis'],
      lines: [
        SceneLine('muhendis', 'Arkadaşlar, vardiya başı emniyet toplantısı. Baret, eldiven, kemer!'),
        SceneLine('any', '{muhendis} yine başladı...'),
        SceneLine('muhendis', 'Gülme. Bu sahada kimse yaralanmayacak, benim sözüm bu.'),
        SceneLine('muhendis', '{ağa}, toplantıya katılır mısın? Ekip seni görünce ciddiye alır.'),
      ],
      choices: [
        SceneChoice(
          'Katılıyorum, emniyet herkesin işi.',
          morale: 5,
          replies: [
            SceneLine('muhendis', 'Teşekkürler {ağa}. Ekip, duydunuz!'),
            SceneLine('senior', 'Ağa da kemer taktıysa bize laf düşmez.'),
          ],
        ),
        SceneChoice(
          'Sen hallet, sana güveniyorum.',
          morale: 1,
          replies: [SceneLine('muhendis', 'Tamam {ağa}, raporu sana atarım.')],
        ),
      ],
    ),
    ChatScene(
      id: 'gece_vardiyasi',
      roles: ['pompaci'],
      lines: [
        SceneLine('pompaci', 'Gece vardiyası uzun geçiyor ama at kafalarının sesi insanı uyutmuyor.'),
        SceneLine('any', 'Ben radyo açıyorum, Dengbêj dinliyorum.'),
        SceneLine('pompaci', 'Hele bir türkü söyle o zaman, sabah olsun.'),
      ],
    ),
    ChatScene(
      id: 'usta_tavsiye',
      weight: 1.2,
      lines: [
        SceneLine('usta', '{ağa}, bir tavsiye vereyim mi?'),
        SceneLine('usta', 'Depoları büyütmeden kuyu sayısını artırma. Dolu depo, boşa dönen pompa demek.'),
        SceneLine('usta', 'Bir de etüt yaptırmadan Garzan\'da sondaja girme. Orası naz eder.'),
      ],
    ),
    ChatScene(
      id: 'memleket_ozlemi',
      minCrew: 2,
      lines: [
        SceneLine('junior', 'Annem aradı, köye ne zaman geleceğimi soruyor.'),
        SceneLine('senior', 'Ben de ilk yıllarda çok özlerdim. Sonra burası da memleket oldu.'),
        SceneLine('usta', 'Bu saha bir aile, oğlum. Kimse yalnız değil burada.'),
      ],
      choices: [
        SceneChoice(
          'Bayramda herkese izin, ailelerinize gidin.',
          morale: 7,
          replies: [
            SceneLine('junior', 'Allah razı olsun {ağa}!'),
            SceneLine('senior', 'Böyle ağa her yerde bulunmaz, kıymetini bilin.'),
          ],
        ),
        SceneChoice(
          'Anneni bizden selamla.',
          morale: 2,
          replies: [SceneLine('junior', 'Selamlarım {ağa}, çok sevinir.')],
        ),
      ],
    ),
    ChatScene(
      id: 'sondor_hatira',
      roles: ['sondor'],
      lines: [
        SceneLine('sondor', 'Bir keresinde 2000 metrede matkap sıkıştı. Üç gün uğraştık.'),
        SceneLine('any', 'Nasıl kurtardınız abi?'),
        SceneLine('sondor', 'Sabır, çamur ve dua. Bir de Usta\'nın bir taktiği vardı ama sır.'),
        SceneLine('usta', 'Sır kalsın lo. Her sondörün bir sırrı olmalı.'),
      ],
    ),
    ChatScene(
      id: 'derikmen_ruzgar',
      roles: ['derikmen'],
      lines: [
        SceneLine('derikmen', 'Bugün kulenin tepesinde rüzgâr öyle bir esti ki bareti tuttum.'),
        SceneLine('any', 'Korkmadın mı?'),
        SceneLine('derikmen', 'Korkan kuleye çıkmaz. Ama kemerimi iki kere kontrol ettim, o ayrı.'),
      ],
    ),

    // -------------------------------------------------- Olaylara bağlı
    ChatScene(
      id: 'petrol_kutlama',
      trigger: SceneTrigger.strike,
      minCrew: 1,
      lines: [
        SceneLine('any', 'Gördünüz mü?! Fışkırdı, kara altın fışkırdı!'),
        SceneLine('senior', 'Maşallah! Ekibin emeği bu.'),
        SceneLine('usta', 'Bu akşam kutlama yapmamız lazım. Ne dersin {ağa}?'),
      ],
      choices: [
        SceneChoice(
          'Herkese baklava benden! 🎉',
          morale: 10,
          cost: 400,
          replies: [
            SceneLine('any', 'Yaşasın {ağa}! Antep fıstıklı olsun!'),
            SceneLine('usta', 'İşte ağa böyle olur. Ekip bunu unutmaz.'),
          ],
        ),
        SceneChoice(
          'Kutlama sonra, sıradaki kuyuya!',
          morale: 2,
          replies: [SceneLine('senior', 'Gözünü seveyim {ağa}, işkoliksin. Hadi bakalım!')],
        ),
      ],
    ),
    ChatScene(
      id: 'kuru_moral',
      trigger: SceneTrigger.dry,
      minCrew: 1,
      lines: [
        SceneLine('any', 'Kuru çıktı... Bunca emek boşa gitti.'),
        SceneLine('usta', 'Boşa gitmez evlat. Her kuru kuyu bir sonrakinin yolunu gösterir.'),
      ],
      choices: [
        SceneChoice(
          'Moralinizi bozmayın, birlikte başaracağız.',
          morale: 5,
          replies: [SceneLine('senior', 'Sağ ol {ağa}. Ekip seninle.')],
        ),
        SceneChoice(
          'Daha dikkatli olmalıyız.',
          morale: -1,
          replies: [SceneLine('any', 'Haklısın {ağa}, bir dahakine etüdü atlamayalım.')],
        ),
      ],
    ),
    ChatScene(
      id: 'sicak_sikayet',
      trigger: SceneTrigger.heatWave,
      minCrew: 1,
      lines: [
        SceneLine('any', 'Termometre 45\'i gösteriyor lo! Kuleye çıkılmaz bu sıcakta.'),
        SceneLine('usta', 'Batman sıcağı böyledir. Bol su için, gölgede dinlenin.'),
      ],
      choices: [
        SceneChoice(
          'Herkese soğuk ayran ve karpuz! 🍉',
          morale: 7,
          cost: 120,
          replies: [SceneLine('any', 'Hayatımı kurtardın {ağa}!')],
        ),
        SceneChoice(
          'Biraz daha dayanın, sıcak geçecek.',
          morale: -2,
          replies: [SceneLine('any', 'Dayanırız {ağa}, başka çare yok.')],
        ),
      ],
    ),
    ChatScene(
      id: 'fiyat_ucusu',
      trigger: SceneTrigger.priceSpike,
      lines: [
        SceneLine('usta', 'Fiyatlar uçtu! Depoda ne varsa şimdi değerlenir.'),
        SceneLine('any', 'Pazara koşalım mı {ağa}?'),
      ],
    ),
    ChatScene(
      id: 'ariza_panik',
      trigger: SceneTrigger.breakdown,
      lines: [
        SceneLine('any', 'Kuyu durdu! Motor sustu!'),
        SceneLine('usta', 'Panik yok. Makinist yoksa kuyuya dokunun, birlikte tamir ederiz.'),
      ],
    ),
    ChatScene(
      id: 'terfi_tebrik',
      trigger: SceneTrigger.promoted,
      lines: [
        SceneLine('usta', 'Hayırlı olsun! Emeğin karşılığını aldın.'),
        SceneLine('any', 'Tebrikler! Bu akşam çaylar senden!'),
      ],
    ),
    ChatScene(
      id: 'hosgeldin',
      trigger: SceneTrigger.hired,
      lines: [
        SceneLine('usta', 'Ekibe hoş geldin. Burada herkes birbirine sahip çıkar.'),
        SceneLine('senior', 'Hoş geldin kardeşim. Bir sorun olursa bana gel.'),
      ],
    ),
  ];
}
