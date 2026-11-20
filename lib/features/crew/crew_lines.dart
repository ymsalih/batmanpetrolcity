import '../../core/models/worker.dart';

/// İşçilerin replikleri: göreve ve rütbeye göre, hafif Batman ağzıyla.
///
/// Şablonlar: {ağa} → oyuncuya hitap ("Hamit Ağa" ya da "ağam"),
/// {unvan} → işçinin unvanı, {ad} → işçinin adı.
enum CrewTopic {
  hired,
  promoted,
  chat,
  drillStart,
  strike,
  dry,
  breakdown,
  repaired,
  collected,
  storageFull,
  sold,
  heatWave,
  priceSpike,
}

/// Rütbe kademesi: yeni (ilk iki basamak), orta, kıdemli (son iki basamak).
enum RankTier { junior, mid, senior }

abstract final class CrewLines {
  static RankTier tierOf(Worker w) {
    if (w.rank <= 1) return RankTier.junior;
    if (w.rank >= w.role.maxRank - 1) return RankTier.senior;
    return RankTier.mid;
  }

  /// Olay replikleri (göreve göre).
  static const Map<String, Map<CrewTopic, List<String>>> byRole = {
    'muhendis': {
      CrewTopic.hired: ['Kule mühendisi sahada. Planı yaparız {ağa}, ekip de uygular.'],
      CrewTopic.strike: ['Rapora yazıyorum: kuyu üretime hazır. Tebrikler {ağa}!'],
      CrewTopic.dry: ['Kuyuyu terk ediyoruz. Veriler bir sonraki lokasyon için kıymetli.'],
      CrewTopic.breakdown: ['Arıza kaydı açıldı, makinisti yönlendiriyorum.'],
      CrewTopic.priceSpike: ['Piyasa yükselişte, satış planını öne çekelim {ağa}.'],
    },
    'sondor': {
      CrewTopic.hired: ['Vinç başına geçtim {ağa}! Matkabı bana bırak.'],
      CrewTopic.drillStart: ['Halatlar gergin, motor sıcak, iniyoruz!', 'Hele bir inek bakalım aşağıda ne var.'],
      CrewTopic.strike: ['Fışkırdı! Ömrümde gördüğüm en güzel siyah bu lo!'],
      CrewTopic.dry: ['Kuru çıktı... matkabın günahı yok {ağa}, toprak böyle.'],
    },
    'derikmen': {
      CrewTopic.hired: ['Kuleye çıktım {ağa}! Boru dizmek bende.'],
      CrewTopic.drillStart: ['Boru hazır! Sen dokun, ben dizerim!'],
      CrewTopic.strike: ['Tepeden gördüm, kara altın fışkırıyor!'],
    },
    'jeolog': {
      CrewTopic.hired: ['Jeolog geldi. Katmanlar bana sır vermez, ben onlara sorarım.'],
      CrewTopic.strike: ['Söylemiştim! Kubbenin tam tepesine denk geldik.'],
      CrewTopic.dry: ['Tabakalar yanılttı bizi. Bir dahakine daha dikkatli bakarım.'],
    },
    'pompaci': {
      CrewTopic.hired: ['Pompacı iş başında! At kafaları bana emanet.'],
      CrewTopic.storageFull: ['Depo doldu {ağa}, pompa boşa çalışıyor!'],
      CrewTopic.heatWave: ['Bu sıcakta pompa da ben de ağırdan alıyoruz.'],
    },
    'mekanik': {
      CrewTopic.hired: ['Makinist geldi! Bozuk motor ne varsa getirin.'],
      CrewTopic.breakdown: ['Arıza mı? Durun, alet çantamı alıyorum!'],
      CrewTopic.repaired: ['Tamam {ağa}, kuyu yine çalışıyor.', 'Bir cıvata gevşemiş, sıktım. Hallettik lo!'],
    },
    'sofor': {
      CrewTopic.hired: ['Tanker şoförü hazır! Yol benden, petrol senden.'],
      CrewTopic.collected: ['Depoları boşalttım, varil depoda!', 'Tanker doldu {ağa}, petrol yerinde.'],
      CrewTopic.storageFull: ['Depolar dolmuş, hemen yola çıkıyorum!'],
    },
    'tuccar': {
      CrewTopic.hired: ['Tüccar burada! Pazarlığı bana bırak {ağa}.'],
      CrewTopic.sold: ['İyi pazarlık ettim, bereketli olsun!', 'Bu fiyata kimse vermezdi, ben aldırdım lo!'],
      CrewTopic.priceSpike: ['Fiyat uçtu! Şimdi satmanın tam zamanı!'],
    },
    'isci': {
      CrewTopic.hired: ['İşe başladım {ağa}! Ne iş olsa yaparım.', 'Selamün aleyküm! Kolları sıvadım bile.'],
      CrewTopic.heatWave: ['Kırk beş derece lo! Bir bardak ayran olsa...', 'Gölge yok, su yok, sıcak çok!'],
      CrewTopic.strike: ['Fışkırdı! Maşallah!'],
      CrewTopic.breakdown: ['{ağa}, kuyu durdu! Koşun!'],
    },
  };

  /// Sohbet replikleri: göreve ve rütbe kademesine göre. Yeni gelen
  /// heyecanlı ve saygılı, kıdemli olan otoriter ve öğretici konuşur.
  static const Map<String, Map<RankTier, List<String>>> chat = {
    'muhendis': {
      RankTier.junior: [
        'Okulda öğrendiklerimle sahadakiler pek benzemiyor {ağa}.',
        'Başsondöre soru sormaktan çekinmiyorum, en iyi hoca o.',
      ],
      RankTier.mid: [
        'Günlük sondaj raporunu bitirdim, her şey planlı gidiyor.',
        'Emniyet önce gelir {ağa}, sonra metre.',
      ],
      RankTier.senior: [
        'Bu sahada her kule benim sorumluluğumda. Rahat ol {ağa}.',
        'Bir kuyunun parası sondajda değil, planda kazanılır.',
      ],
    },
    'sondor': {
      RankTier.junior: [
        'Muavinlikten geldim {ağa}, vinci yeni yeni tutuyorum.',
        'Başsondör bakıyor, el titrememeli lo!',
      ],
      RankTier.mid: ['Yavaş acele et derler bıra, sondaj da öyle.', 'Kireçtaşına gelince yavaşlarız, korkma hele.'],
      RankTier.senior: [
        'Kırk yıllık sondörüm, Raman benden sorulur.',
        'Vardiyalar benden sorulur {ağa}, hiçbiri aksamaz.',
        'Matkap sesinden kaç metrede olduğumuzu bilirim.',
      ],
    },
    'derikmen': {
      RankTier.junior: [
        'Masada anahtar sallıyorum, bir gün kuleye çıkacağım inşallah!',
        'Ağır iş ama ekmek buradan çıkıyor {ağa}.',
      ],
      RankTier.mid: [
        'Yukarıdan Raman Dağı avucumun içi gibi görünür.',
        'Rüzgâr esince kule sallanır, ben sallanmam lo.',
      ],
      RankTier.senior: [
        'Boruları gözü kapalı dizerim. Sıra sondörlükte {ağa}!',
        'Gençlere emniyet kemerini ben öğretirim.',
      ],
    },
    'jeolog': {
      RankTier.junior: [
        'Çamurdaki kırıntıları tek tek inceliyorum, her biri bir hikâye.',
        'Mikroskop elimden düşmüyor {ağa}.',
      ],
      RankTier.mid: [
        'Garzan\'ın kayaları serttir ama cömerttir.',
        'Etüt yaptırmadan sondaj, haritasız yola çıkmak gibi bıra.',
      ],
      RankTier.senior: [
        'Rezervuar kubbe gibidir, petrol tepede toplanır. Ben yerini bilirim.',
        'Bu havzanın haritası kafamda {ağa}.',
      ],
    },
    'pompaci': {
      RankTier.junior: [
        'Yağ tabancası elimde, her at kafasını tek tek dolaşıyorum.',
        'İlk haftam {ağa}, gıcırtıları ezberliyorum.',
      ],
      RankTier.mid: [
        'At kafası sallandıkça içim rahatlar lo.',
        'Yağlamayı aksatmayacaksın, makine de insan gibi bıra.',
      ],
      RankTier.senior: [
        'Sahadaki her pompanın sesini tanırım, biri teklese anlarım.',
        'Üretim düşerse önce bana sor {ağa}.',
      ],
    },
    'mekanik': {
      RankTier.junior: [
        'Ustamın yanında anahtar tutuyorum, her gün yeni bir şey öğreniyorum.',
        'Motor yağını değiştirdim {ağa}!',
      ],
      RankTier.mid: ['Her cıvatanın bir hikâyesi var bıra.', 'Yağ, su, sabır. Makinistin üç kuralı.'],
      RankTier.senior: ['Bu motorları ben kurdum, ben bilirim {ağa}.', 'Arıza haber vermez ama ben önceden sezerim.'],
    },
    'sofor': {
      RankTier.junior: [
        'Tankerle ilk seferimdi {ağa}, viraj alırken dua ettim!',
        'Yolları öğreniyorum, Kozluk yolu biraz zor.',
      ],
      RankTier.mid: ['Batman-Raman yolunu gözüm kapalı sürerim.', 'Sen yokken de gelir giderim, merak etme bıra.'],
      RankTier.senior: [
        'Bütün filo benden sorulur {ağa}, tek damla petrol yolda kalmaz.',
        'Otuz yıl direksiyon sallamışım, yolu ben bilirim.',
      ],
    },
    'tuccar': {
      RankTier.junior: [
        'Pazarlığı öğreniyorum {ağa}, ilk satışımı unutmam.',
        'Alıcılar beni henüz ciddiye almıyor ama alacaklar!',
      ],
      RankTier.mid: [
        'Ucuza satan pişman olur, pahalıya satan kâr eder.',
        'Fiyatı kolla, aceleci tüccarın kesesi boştur.',
      ],
      RankTier.senior: ['İstanbul\'daki alıcılar bile beni tanır {ağa}.', 'Petrol kaçmaz, alıcı kaçar. Ben kaçırmam.'],
    },
    'isci': {
      RankTier.junior: ['Ne iş verirsen yaparım {ağa}, yeter ki ekmek çıksın.', 'Sabah ezanıyla sahadayız bıra.'],
      RankTier.mid: ['Çay demlendi, ister misin {ağa}?', 'Bu toprak bizim, bu petrol bizim!'],
      RankTier.senior: [
        'Gençleri ben yönlendiririm, sen merak etme {ağa}.',
        'Akşam Batman Çayı kenarında balık tutarız, gel sen de.',
      ],
    },
  };

  /// Terfi replikleri: yeni unvanı söyler.
  static const Map<RankTier, List<String>> promoted = {
    RankTier.junior: ['Artık {unvan} oldum {ağa}! Sağ ol, emeğimi gördün.', '{unvan} oldum! Annem duysa sevinir.'],
    RankTier.mid: [
      '{unvan} oldum {ağa}! Sorumluluk büyüdü, ben de büyüdüm.',
      'Yeni unvan: {unvan}. Ekibe ben de akıl vereceğim artık.',
    ],
    RankTier.senior: [
      '{unvan}! Bu sahada benden kıdemlisi yok {ağa}.',
      'Kırk yılın emeği: {unvan}. Allah razı olsun {ağa}.',
    ],
  };

  static List<String> of(String roleId, CrewTopic topic) => byRole[roleId]?[topic] ?? const [];

  /// İşçinin rütbesine uygun sohbet replikleri.
  static List<String> chatFor(Worker w) => chat[w.roleId]?[tierOf(w)] ?? const [];

  static List<String> promotedFor(Worker w) => promoted[tierOf(w)]!;

  /// Şablonu doldurur.
  static String fill(String text, {required String address, Worker? worker}) {
    var t = text.replaceAll('{ağa}', address);
    if (worker != null) {
      t = t.replaceAll('{unvan}', worker.rankTitle).replaceAll('{ad}', worker.displayName);
    }
    // Cümle başına gelen hitabı büyük harfle başlat.
    if (t.isNotEmpty && t.startsWith('ağam')) t = 'Ağam${t.substring(4)}';
    return t;
  }
}
