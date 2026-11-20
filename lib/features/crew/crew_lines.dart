/// İşçilerin replikleri: göreve göre, hafif Batman ağzıyla.
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

abstract final class CrewLines {
  static const Map<String, Map<CrewTopic, List<String>>> byRole = {
    'sondor': {
      CrewTopic.hired: ['Sondör geldi ağam! Matkabı bana bırak.', 'Kırk yıllık sondörüm bıra, Raman benden sorulur.'],
      CrewTopic.promoted: ['Rütbe yükseldi, matkap daha da hızlı döner lo!'],
      CrewTopic.chat: [
        'Matkap sesi bana türkü gibi gelir.',
        'Yavaş acele et derler bıra, sondaj da öyle.',
        'Kireçtaşına gelince yavaşlarız, korkma hele.',
      ],
      CrewTopic.drillStart: ['Halatlar gergin, motor sıcak, iniyoruz!', 'Hele bir inek bakalım aşağıda ne var.'],
      CrewTopic.strike: ['Fışkırdı! Ömrümde gördüğüm en güzel siyah bu lo!'],
      CrewTopic.dry: ['Kuru çıktı... matkabın günahı yok ağam, toprak böyle.'],
    },
    'derikmen': {
      CrewTopic.hired: ['Derikmen hazır! Kulenin tepesi benim evim bıra.'],
      CrewTopic.promoted: ['Boruları artık gözü kapalı dizerim!'],
      CrewTopic.chat: [
        'Yukarıdan Raman Dağı avucumun içi gibi görünür.',
        'Rüzgâr esince kule sallanır, ben sallanmam lo.',
        'Sen ekrana dokun, ben boruyu yetiştireyim!',
      ],
      CrewTopic.drillStart: ['Boru hazır! Sen dokun, ben dizerim!'],
      CrewTopic.strike: ['Tepeden gördüm, kara altın fışkırıyor!'],
    },
    'jeolog': {
      CrewTopic.hired: ['Jeolog geldi. Katmanlar bana sır vermez, ben onlara sorarım.'],
      CrewTopic.promoted: ['Artık kireçtaşını kokusundan tanırım!'],
      CrewTopic.chat: [
        'Garzan\'ın kayaları serttir ama cömerttir.',
        'Etüt yaptırmadan sondaj, haritasız yola çıkmak gibi bıra.',
        'Rezervuar kubbe gibidir, petrol tepede toplanır.',
      ],
      CrewTopic.strike: ['Söylemiştim! Kubbenin tam tepesine denk geldik.'],
      CrewTopic.dry: ['Tabakalar yanılttı bizi. Bir dahakine daha dikkatli bakarım.'],
    },
    'pompaci': {
      CrewTopic.hired: ['Pompacı iş başında! At kafaları bana emanet.'],
      CrewTopic.promoted: ['Pompalar daha tatlı çalışıyor, duyuyon mu?'],
      CrewTopic.chat: [
        'At kafası sallandıkça içim rahatlar lo.',
        'Yağlamayı aksatmayacaksın, makine de insan gibi bıra.',
        'Gece pompa sesi ninni gibidir.',
      ],
      CrewTopic.storageFull: ['Depo doldu ağam, pompa boşa çalışıyor!'],
      CrewTopic.heatWave: ['Bu sıcakta pompa da ben de ağırdan alıyoruz.'],
    },
    'mekanik': {
      CrewTopic.hired: ['Mekanikçi geldi! Bozuk ne varsa getirin.'],
      CrewTopic.promoted: ['Anahtar takımı yenilendi, tamir daha hızlı!'],
      CrewTopic.chat: [
        'Her cıvatanın bir hikâyesi var bıra.',
        'Arıza haber vermez, ben de beklemem.',
        'Yağ, su, sabır. Mekaniğin üç kuralı.',
      ],
      CrewTopic.breakdown: ['Arıza mı? Durun, alet çantamı alıyorum!'],
      CrewTopic.repaired: ['Tamam ağam, kuyu yine çalışıyor.', 'Bir cıvata gevşemiş, sıktım. Hallettik lo!'],
    },
    'sofor': {
      CrewTopic.hired: ['Tanker şoförü hazır! Yol benden, petrol senden.'],
      CrewTopic.promoted: ['Yeni tanker geldi, daha sık uğrarım!'],
      CrewTopic.chat: [
        'Batman-Raman yolunu gözüm kapalı sürerim.',
        'Tankeri doldurdum mu, içim rahat eder.',
        'Sen yokken de gelir giderim, merak etme bıra.',
      ],
      CrewTopic.collected: ['Depoları boşalttım, varil depoda!', 'Tanker doldu ağam, petrol yerinde.'],
      CrewTopic.storageFull: ['Depolar dolmuş, hemen yola çıkıyorum!'],
    },
    'tuccar': {
      CrewTopic.hired: ['Tüccar burada! Pazarlığı bana bırak ağam.'],
      CrewTopic.promoted: ['Artık İstanbul\'daki alıcılar bile beni tanır!'],
      CrewTopic.chat: [
        'Ucuza satan pişman olur, pahalıya satan kâr eder.',
        'Fiyatı kolla, aceleci tüccarın kesesi boştur.',
        'Petrol kaçmaz, alıcı kaçar bıra.',
      ],
      CrewTopic.sold: ['İyi pazarlık ettim, bereketli olsun!', 'Bu fiyata kimse vermezdi, ben aldırdım lo!'],
      CrewTopic.priceSpike: ['Fiyat uçtu! Şimdi satmanın tam zamanı!'],
    },
    'isci': {
      CrewTopic.hired: ['İşe başladım ağam! Ne iş olsa yaparım.', 'Selamün aleyküm! Kolları sıvadım bile.'],
      CrewTopic.promoted: ['Sağ ol ağam, emeğimi gördün!'],
      CrewTopic.chat: [
        'Sabah ezanıyla sahadayız bıra.',
        'Çay demlendi, ister misin ağam?',
        'Bu toprak bizim, bu petrol bizim!',
        'Akşam Batman Çayı kenarında balık tutarız.',
      ],
      CrewTopic.heatWave: ['Kırk beş derece lo! Bir bardak ayran olsa...', 'Gölge yok, su yok, sıcak çok!'],
      CrewTopic.strike: ['Fışkırdı! Maşallah!'],
      CrewTopic.breakdown: ['Ağam, kuyu durdu! Koşun!'],
    },
  };

  static List<String> of(String roleId, CrewTopic topic) => byRole[roleId]?[topic] ?? const [];
}
