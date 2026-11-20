/// Oyunun TÜM denge değerleri burada durur.
///
/// Yeni bir saha eklemek için [GameConfig.sites] listesine yeni bir
/// [SiteConfig] satırı eklemek yeterlidir; harita, saha ekranı, kayıt sistemi
/// ve ekonomi otomatik olarak yeni sahayı tanır.
library;

import 'dart:ui' show Color;

/// Bir parselin gizli verim seviyesi. Etüt bunu oyuncuya ipucu olarak gösterir.
enum YieldTier { low, medium, high }

/// Yer altı kesitinde çizilen bir jeolojik katman.
class GeoLayer {
  const GeoLayer(this.name, this.color, this.thickness, this.pattern);

  final String name;
  final Color color;

  /// Toplam derinliğe göre göreli kalınlık (katmanlar normalize edilir).
  final double thickness;
  final GeoPattern pattern;
}

enum GeoPattern { soil, clay, rock, limestone, reservoir }

class SiteConfig {
  const SiteConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockCost,
    required this.surveyCost,
    required this.drillCost,
    required this.drillSeconds,
    required this.dryChance,
    required this.yieldMultiplier,
    required this.baseBarrelsPerSecond,
    required this.baseStorage,
    required this.targetDepthM,
    required this.mapX,
    required this.mapY,
    required this.latitude,
    required this.longitude,
    this.unlocksRefinery = false,
    this.geology = GameConfig.defaultGeology,
  });

  final String id;
  final String name;
  final String description;

  /// Sahayı açma bedeli (TL). 0 ise oyun başında açıktır.
  final double unlockCost;
  final double surveyCost;
  final double drillCost;

  /// Gerçek zamanlı sondaj süresi (sn). [GameConfig.minDrillSeconds] ve
  /// [GameConfig.maxDrillSeconds] arasında tutulur.
  final int drillSeconds;

  /// Ortalama verimli parselde kuru kuyu ihtimali (0..1). Sondaj zorluğunu
  /// süre + bu oran birlikte belirler.
  final double dryChance;
  final double yieldMultiplier;
  final double baseBarrelsPerSecond;
  final double baseStorage;
  final int targetDepthM;

  /// Haritadaki göreli konum (0..1).
  final double mapX;
  final double mapY;

  /// İleride GPS bonusu için gerçek konum.
  final double latitude;
  final double longitude;

  /// Bu saha açıldığında rafine etme özelliği açılır.
  final bool unlocksRefinery;
  final List<GeoLayer> geology;

  /// 1 (kolay) .. 5 (zor) arası gösterim amaçlı zorluk.
  int get difficulty {
    final score = drillSeconds / GameConfig.maxDrillSeconds * 2.5 + dryChance * 5;
    return score.round().clamp(1, 5);
  }
}

/// İşçinin oyuna etkisi.
enum CrewSkill {
  /// Sondaj süresini kısaltır.
  drillSpeed,

  /// Ekrana dokunuşun sondajı hızlandırma gücünü artırır.
  tapPower,

  /// Kuru kuyu ihtimalini düşürür.
  dryChance,

  /// Üretimi artırır.
  production,

  /// Arızalı kuyuları kendiliğinden tamir eder.
  autoRepair,

  /// Kuyu depolarını düzenli aralıklarla boşaltır.
  autoCollect,

  /// Satış fiyatını artırır.
  price,

  /// Kule mühendisi: tüm ekibin etkisini büyütür.
  leadership,
}

/// Bir ekip görevi (rolü). Yeni görev eklemek için [GameConfig.crewRoles]
/// listesine satır eklemek yeterlidir.
class CrewRoleConfig {
  const CrewRoleConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.skill,
    required this.perRank,
    required this.hireCost,
    required this.helmetColor,
    required this.ranks,
    this.base = 0,
    this.maxCount = 1,
  });

  final String id;

  /// Görev adı; işçiye isim verilmezse varsayılan ad olarak da kullanılır.
  final String title;
  final String description;
  final CrewSkill skill;

  /// Rütbe başına etki (oran veya saniye; [skill]'e göre).
  final double perRank;

  /// Süre tabanlı yetenekler için başlangıç değeri (sn).
  final double base;
  final double hireCost;

  /// Aynı görevden en fazla kaç kişi alınabilir.
  final int maxCount;

  /// Baret rengi (ARGB).
  final int helmetColor;

  /// Bu görevin gerçek kariyer basamakları (düşükten yükseğe). İşçinin
  /// rütbesi aynı zamanda sahadaki unvanıdır (ör. Sondör → Başsondör).
  final List<String> ranks;

  int get maxRank => ranks.length - 1;
}

enum GameEventKind { heatWave, priceSpike, breakdown }

class EventConfig {
  const EventConfig({
    required this.kind,
    required this.title,
    required this.description,
    required this.durationSeconds,
    required this.weight,
    this.productionMultiplier = 1,
    this.priceMultiplier = 1,
  });

  final GameEventKind kind;
  final String title;
  final String description;
  final int durationSeconds;
  final double weight;
  final double productionMultiplier;
  final double priceMultiplier;
}

abstract final class GameConfig {
  // ---------------------------------------------------------------- Genel
  static const int saveVersion = 1;
  static const double startMoney = 1500;
  static const int gridSize = 3;
  static const int tickMs = 250;
  static const int autoSaveSeconds = 10;
  static const int offlineMaxSeconds = 4 * 60 * 60;

  /// Bu süreden kısa yokluklarda "Sen yokken" penceresi açılmaz.
  static const int offlineReportMinSeconds = 60;

  // -------------------------------------------------------------- Sondaj
  static const int minDrillSeconds = 30;
  static const int maxDrillSeconds = 300;

  /// Her dokunuş, toplam sürenin bu oranı kadar sondajı hızlandırır.
  static const double drillTapFraction = 0.01;

  /// Dokunarak kazanılabilecek en fazla hızlanma (toplam sürenin oranı).
  static const double drillTapMaxFraction = 0.6;

  // -------------------------------------------------------------- Verim
  static const Map<YieldTier, double> tierMultipliers = {
    YieldTier.low: 0.6,
    YieldTier.medium: 1.0,
    YieldTier.high: 1.6,
  };
  static const Map<YieldTier, double> tierWeights = {YieldTier.low: 0.4, YieldTier.medium: 0.4, YieldTier.high: 0.2};

  /// Verimsiz parselde kuru kuyu daha olası.
  static const Map<YieldTier, double> tierDryModifier = {
    YieldTier.low: 1.4,
    YieldTier.medium: 1.0,
    YieldTier.high: 0.6,
  };
  static const double maxDryChance = 0.9;

  // --------------------------------------------------------- Yükseltmeler
  static const int pumpMaxLevel = 10;
  static const double pumpCostFactor = 0.8; // sondaj bedelinin katı
  static const double pumpCostGrowth = 1.6;
  static const double pumpBonusPerLevel = 0.35;

  static const int storageMaxLevel = 10;
  static const double storageCostFactor = 0.5;
  static const double storageCostGrowth = 1.5;
  static const double storageBonusPerLevel = 0.5;

  /// Kuru parseli temizleme bedeli (sondaj bedelinin oranı).
  static const double clearDryCostFactor = 0.3;

  /// Arızalı kuyuyu tamir etmek için gereken dokunuş sayısı.
  static const int repairTaps = 3;

  // --------------------------------------------------------------- Pazar
  static const double priceStart = 40;
  static const double priceMean = 42;
  static const double priceMin = 15;
  static const double priceMax = 110;
  static const double priceVolatility = 0.12;
  static const double priceReversion = 0.15;
  static const int priceChangeSeconds = 120;
  static const int priceHistoryLength = 30;

  // ------------------------------------------------------------ Rafineri
  static const double refinedPerBarrel = 1.0;
  static const double refinedPriceMultiplier = 1.8;
  static const double refineCostPerBarrel = 4;

  // -------------------------------------------------------------- Olaylar
  static const int eventMinGapSeconds = 90;
  static const int eventMaxGapSeconds = 200;
  static const List<EventConfig> events = [
    EventConfig(
      kind: GameEventKind.heatWave,
      title: 'Batman sıcağı',
      description: 'Termometre 45°C! Üretim %20 düştü.',
      durationSeconds: 120,
      weight: 3,
      productionMultiplier: 0.8,
    ),
    EventConfig(
      kind: GameEventKind.priceSpike,
      title: 'Fiyat uçtu',
      description: 'Petrol fiyatı tavan! Satışlar x2.',
      durationSeconds: 60,
      weight: 2,
      priceMultiplier: 2,
    ),
    EventConfig(
      kind: GameEventKind.breakdown,
      title: 'Arıza',
      description: 'Bir kuyu durdu. Tamir için kuyuya dokun!',
      durationSeconds: 0,
      weight: 2,
    ),
  ];

  // ---------------------------------------------------------- Gün / Gece
  static const int dayLengthSeconds = 8 * 60;

  // ------------------------------------------------------------- Jeoloji
  static const List<GeoLayer> defaultGeology = [
    GeoLayer('Toprak', Color(0xFF8B5A2B), 0.12, GeoPattern.soil),
    GeoLayer('Kil', Color(0xFFA0522D), 0.15, GeoPattern.clay),
    GeoLayer('Kaya', Color(0xFF6E6259), 0.28, GeoPattern.rock),
    GeoLayer('Kireçtaşı', Color(0xFFCFC3A6), 0.33, GeoPattern.limestone),
    GeoLayer('Rezervuar', Color(0xFF2B2622), 0.12, GeoPattern.reservoir),
  ];

  // --------------------------------------------------------------- Sahalar
  static const String startSiteId = 'raman';

  static const List<SiteConfig> sites = [
    SiteConfig(
      id: 'raman',
      name: 'Raman',
      description: 'Türkiye\'nin ilk petrolünün fışkırdığı efsane saha.',
      unlockCost: 0,
      surveyCost: 150,
      drillCost: 500,
      drillSeconds: 30,
      dryChance: 0.25,
      yieldMultiplier: 1.0,
      baseBarrelsPerSecond: 0.5,
      baseStorage: 80,
      targetDepthM: 1300,
      mapX: 0.30,
      mapY: 0.36,
      latitude: 37.80,
      longitude: 41.17,
    ),
    SiteConfig(
      id: 'bati_raman',
      name: 'Batı Raman',
      description: 'Ağır petrol, sabır ister ama bol verir.',
      unlockCost: 15000,
      surveyCost: 600,
      drillCost: 2500,
      drillSeconds: 75,
      dryChance: 0.35,
      yieldMultiplier: 1.6,
      baseBarrelsPerSecond: 0.5,
      baseStorage: 120,
      targetDepthM: 1350,
      mapX: 0.12,
      mapY: 0.52,
      latitude: 37.78,
      longitude: 41.05,
      geology: [
        GeoLayer('Toprak', Color(0xFF8B5A2B), 0.10, GeoPattern.soil),
        GeoLayer('Kil', Color(0xFFA0522D), 0.12, GeoPattern.clay),
        GeoLayer('Kaya', Color(0xFF5F554E), 0.30, GeoPattern.rock),
        GeoLayer('Kireçtaşı', Color(0xFFC2B595), 0.34, GeoPattern.limestone),
        GeoLayer('Rezervuar', Color(0xFF2B2622), 0.14, GeoPattern.reservoir),
      ],
    ),
    SiteConfig(
      id: 'garzan',
      name: 'Garzan',
      description: 'Derin ve sert kayalar. Riskli ama cömert.',
      unlockCost: 60000,
      surveyCost: 2000,
      drillCost: 9000,
      drillSeconds: 150,
      dryChance: 0.45,
      yieldMultiplier: 2.6,
      baseBarrelsPerSecond: 0.5,
      baseStorage: 160,
      targetDepthM: 1700,
      mapX: 0.78,
      mapY: 0.30,
      latitude: 37.95,
      longitude: 41.45,
      geology: [
        GeoLayer('Toprak', Color(0xFF7A4E26), 0.08, GeoPattern.soil),
        GeoLayer('Kaya', Color(0xFF5A504A), 0.30, GeoPattern.rock),
        GeoLayer('Kil', Color(0xFF94502B), 0.10, GeoPattern.clay),
        GeoLayer('Kireçtaşı', Color(0xFFBFB08F), 0.40, GeoPattern.limestone),
        GeoLayer('Rezervuar', Color(0xFF2B2622), 0.12, GeoPattern.reservoir),
      ],
    ),
    SiteConfig(
      id: 'rafineri',
      name: 'Rafineri Bölgesi',
      description: 'Açınca varilleri akaryakıta çevirip daha pahalı satarsın.',
      unlockCost: 150000,
      surveyCost: 5000,
      drillCost: 20000,
      drillSeconds: 300,
      dryChance: 0.30,
      yieldMultiplier: 4.0,
      baseBarrelsPerSecond: 0.5,
      baseStorage: 250,
      targetDepthM: 2000,
      mapX: 0.60,
      mapY: 0.70,
      latitude: 37.88,
      longitude: 41.12,
      unlocksRefinery: true,
    ),
  ];

  // ---------------------------------------------------------------- Ekip
  //
  // Unvanlar Türkiye'deki kara sondaj sahalarında kullanılan kadrolardan
  // alınmıştır. Klasik kariyer yolu: vasıfsız işçi → anahtarcı (masa işçisi)
  // → derikmen → sondör muavini → sondör → başsondör → sondaj amiri
  // (tulpuşer). Sahanın başında kule mühendisi bulunur.

  /// Terfi bedeli = işe alma bedeli x büyüme^(mevcut rütbe + 1).
  static const double crewPromoteGrowth = 2.2;

  /// Aynı görevden ikinci, üçüncü... kişiyi almak her seferinde pahalanır.
  static const double crewHireGrowth = 1.7;

  /// Ekibin konuşma olasılığı (olay başına); kalan durumlarda Usta konuşur.
  static const double crewTalkChance = 0.65;

  /// İşe alınan işçiye verilen varsayılan adlar (oyuncu değiştirebilir).
  static const List<String> crewNames = [
    'Şeyhmus',
    'Abdulkadir',
    'Mehmet Emin',
    'Hamit',
    'Reşit',
    'Nurettin',
    'Selahattin',
    'Cemil',
    'Ramazan',
    'Hüseyin',
    'Abdullah',
    'Mahmut',
    'Zeki',
    'Fahri',
    'Sait',
    'Necmettin',
    'Kadri',
    'Bedirhan',
    'Halil',
    'İbrahim',
    'Yusuf',
    'Ömer',
    'Musa',
    'Cihan',
    'Serhat',
    'Baran',
    'Diyar',
    'Zeynep',
    'Ayşe',
    'Leyla',
    'Gülistan',
    'Rojda',
    'Berfin',
    'Hatice',
    'Nazlı',
    'Fatma',
    'Vedat',
    'Kemal',
    'Süleyman',
    'Ferhat',
    'Mirza',
    'Nasır',
    'Yasin',
  ];

  static const List<CrewRoleConfig> crewRoles = [
    CrewRoleConfig(
      id: 'muhendis',
      title: 'Kule Mühendisi',
      description: 'Sahayı yönetir, ekibi koordine eder. Tüm ekibin etkisini büyütür.',
      skill: CrewSkill.leadership,
      perRank: 0.05,
      hireCost: 15000,
      helmetColor: 0xFFFFFFFF,
      ranks: ['Stajyer Mühendis', 'Kule Mühendisi', 'Kıdemli Kule Mühendisi', 'Şirket Temsilcisi', 'Saha Müdürü'],
    ),
    CrewRoleConfig(
      id: 'sondor',
      title: 'Sondör',
      description: 'Vinç başında sondajı yönetir. Sondaj süresini kısaltır.',
      skill: CrewSkill.drillSpeed,
      perRank: 0.08,
      hireCost: 1200,
      helmetColor: 0xFFF5C542,
      ranks: ['Sondör Muavini', 'Sondör', 'Kıdemli Sondör', 'Başsondör', 'Sondaj Amiri'],
    ),
    CrewRoleConfig(
      id: 'derikmen',
      title: 'Derikmen',
      description: 'Kule tepesinde (monkey board) boruları dizer. Dokunuşların sondajı daha çok hızlandırır.',
      skill: CrewSkill.tapPower,
      perRank: 0.3,
      hireCost: 900,
      helmetColor: 0xFFE0E0E0,
      ranks: ['Masa İşçisi', 'Anahtarcı', 'Derikmen', 'Kıdemli Derikmen', 'Sondör Muavini'],
    ),
    CrewRoleConfig(
      id: 'jeolog',
      title: 'Jeolog',
      description: 'Kırıntıları ve katmanları okur. Kuru kuyu ihtimalini düşürür.',
      skill: CrewSkill.dryChance,
      perRank: 0.07,
      hireCost: 2500,
      helmetColor: 0xFF3D8BC9,
      ranks: ['Çamur Logcusu', 'Kuyu Jeoloğu', 'Kıdemli Jeolog', 'Baş Jeolog', 'Arama Müdürü'],
    ),
    CrewRoleConfig(
      id: 'pompaci',
      title: 'Pompacı',
      description: 'At kafalarının bakımını yapar. Üretimi artırır.',
      skill: CrewSkill.production,
      perRank: 0.08,
      hireCost: 3000,
      helmetColor: 0xFFF07A2A,
      ranks: ['Pompacı Yardımcısı', 'Pompacı', 'Üretim Operatörü', 'Kıdemli Operatör', 'Üretim Şefi'],
    ),
    CrewRoleConfig(
      id: 'mekanik',
      title: 'Makinist',
      description: 'Motorların ve pompaların bakımını yapar. Arızaları sen dokunmadan tamir eder.',
      skill: CrewSkill.autoRepair,
      base: 75,
      perRank: 12,
      hireCost: 4000,
      helmetColor: 0xFF3FAE5A,
      ranks: ['Makinist Yardımcısı', 'Makinist', 'Kıdemli Makinist', 'Baş Makinist', 'Bakım Şefi'],
    ),
    CrewRoleConfig(
      id: 'sofor',
      title: 'Tanker Şoförü',
      description: 'Kuyu depolarını düzenli boşaltıp ham petrolü getirir. Sen yokken de çalışır.',
      skill: CrewSkill.autoCollect,
      base: 90,
      perRank: 12,
      hireCost: 6000,
      helmetColor: 0xFF8E5BC2,
      ranks: ['Stajyer Şoför', 'Tanker Şoförü', 'Kıdemli Şoför', 'Filo Sorumlusu', 'Lojistik Şefi'],
    ),
    CrewRoleConfig(
      id: 'tuccar',
      title: 'Tüccar',
      description: 'Pazarda iyi pazarlık yapar. Satış fiyatını artırır.',
      skill: CrewSkill.price,
      perRank: 0.05,
      hireCost: 8000,
      helmetColor: 0xFF2B2622,
      ranks: ['Satış Elemanı', 'Tüccar', 'Kıdemli Tüccar', 'Satış Müdürü', 'Ticaret Müdürü'],
    ),
    CrewRoleConfig(
      id: 'isci',
      title: 'Saha İşçisi',
      description: 'Sahada her işe koşar (roustabout). Üretime küçük ama sürekli katkı verir.',
      skill: CrewSkill.production,
      perRank: 0.03,
      hireCost: 600,
      maxCount: 6,
      helmetColor: 0xFFD64541,
      ranks: ['Vasıfsız İşçi', 'Saha İşçisi', 'Kıdemli Saha İşçisi', 'Ekip Başı', 'Saha Formeni'],
    ),
  ];

  static CrewRoleConfig crewRole(String id) => crewRoles.firstWhere((r) => r.id == id, orElse: () => crewRoles.last);

  static SiteConfig site(String id) => sites.firstWhere((s) => s.id == id, orElse: () => sites.first);

  static EventConfig event(GameEventKind kind) => events.firstWhere((e) => e.kind == kind);
}
