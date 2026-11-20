import '../../config/game_config.dart';
import 'active_effect.dart';
import 'parcel.dart';
import 'site_state.dart';

class GameStats {
  const GameStats({this.totalBarrels = 0, this.totalEarned = 0, this.wellsDrilled = 0, this.dryWells = 0});

  final double totalBarrels;
  final double totalEarned;
  final int wellsDrilled;
  final int dryWells;

  GameStats copyWith({double? totalBarrels, double? totalEarned, int? wellsDrilled, int? dryWells}) => GameStats(
    totalBarrels: totalBarrels ?? this.totalBarrels,
    totalEarned: totalEarned ?? this.totalEarned,
    wellsDrilled: wellsDrilled ?? this.wellsDrilled,
    dryWells: dryWells ?? this.dryWells,
  );

  Map<String, dynamic> toJson() => {'tb': totalBarrels, 'te': totalEarned, 'wd': wellsDrilled, 'dw': dryWells};

  factory GameStats.fromJson(Map<String, dynamic> j) => GameStats(
    totalBarrels: (j['tb'] as num?)?.toDouble() ?? 0,
    totalEarned: (j['te'] as num?)?.toDouble() ?? 0,
    wellsDrilled: (j['wd'] as num?)?.toInt() ?? 0,
    dryWells: (j['dw'] as num?)?.toInt() ?? 0,
  );
}

/// Uygulama açılışında hesaplanan çevrimdışı kazanç özeti (kaydedilmez).
class OfflineReport {
  const OfflineReport({
    required this.away,
    required this.barrels,
    required this.drillsFinished,
    required this.storageFull,
  });

  final Duration away;
  final double barrels;
  final int drillsFinished;
  final bool storageFull;
}

class GameState {
  const GameState({
    required this.money,
    required this.crude,
    required this.refined,
    required this.sites,
    required this.selectedSiteId,
    required this.oilPrice,
    required this.priceHistory,
    required this.nextPriceChangeMs,
    required this.effects,
    required this.nextEventMs,
    required this.lastTickMs,
    this.tutorialStep = 0,
    this.tutorialDone = false,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.stats = const GameStats(),
    this.offlineReport,
  });

  factory GameState.initial(int nowMs) => GameState(
    money: GameConfig.startMoney,
    crude: 0,
    refined: 0,
    sites: {for (final s in GameConfig.sites) s.id: SiteState.initial(s)},
    selectedSiteId: GameConfig.startSiteId,
    oilPrice: GameConfig.priceStart,
    priceHistory: const [GameConfig.priceStart],
    nextPriceChangeMs: nowMs + GameConfig.priceChangeSeconds * 1000,
    effects: const [],
    nextEventMs: nowMs + GameConfig.eventMaxGapSeconds * 1000,
    lastTickMs: nowMs,
  );

  final double money;

  /// Satılmayı bekleyen ham petrol (varil).
  final double crude;

  /// Rafine edilmiş akaryakıt (birim).
  final double refined;
  final Map<String, SiteState> sites;
  final String selectedSiteId;
  final double oilPrice;
  final List<double> priceHistory;
  final int nextPriceChangeMs;
  final List<ActiveEffect> effects;
  final int nextEventMs;

  /// Simülasyonun en son ilerletildiği an (çevrimdışı hesap için kaydedilir).
  final int lastTickMs;
  final int tutorialStep;
  final bool tutorialDone;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final GameStats stats;

  /// Geçici: kaydedilmez.
  final OfflineReport? offlineReport;

  SiteState site(String id) => sites[id] ?? SiteState.initial(GameConfig.site(id));
  SiteState get selectedSite => site(selectedSiteId);

  bool get refineryUnlocked => GameConfig.sites.any((s) => s.unlocksRefinery && (sites[s.id]?.unlocked ?? false));

  double productionMultiplierAt(int nowMs) =>
      effects.where((e) => e.isActiveAt(nowMs)).fold(1.0, (m, e) => m * e.productionMultiplier);

  double priceMultiplierAt(int nowMs) =>
      effects.where((e) => e.isActiveAt(nowMs)).fold(1.0, (m, e) => m * e.priceMultiplier);

  Iterable<({String siteId, int index, Parcel parcel})> get allParcels sync* {
    for (final s in sites.values) {
      for (var i = 0; i < s.parcels.length; i++) {
        yield (siteId: s.id, index: i, parcel: s.parcels[i]);
      }
    }
  }

  GameState updateParcel(String siteId, int index, Parcel parcel) =>
      copyWith(sites: {...sites, siteId: site(siteId).updateParcel(index, parcel)});

  GameState copyWith({
    double? money,
    double? crude,
    double? refined,
    Map<String, SiteState>? sites,
    String? selectedSiteId,
    double? oilPrice,
    List<double>? priceHistory,
    int? nextPriceChangeMs,
    List<ActiveEffect>? effects,
    int? nextEventMs,
    int? lastTickMs,
    int? tutorialStep,
    bool? tutorialDone,
    bool? hapticsEnabled,
    bool? soundEnabled,
    GameStats? stats,
    OfflineReport? offlineReport,
    bool clearOfflineReport = false,
  }) {
    return GameState(
      money: money ?? this.money,
      crude: crude ?? this.crude,
      refined: refined ?? this.refined,
      sites: sites ?? this.sites,
      selectedSiteId: selectedSiteId ?? this.selectedSiteId,
      oilPrice: oilPrice ?? this.oilPrice,
      priceHistory: priceHistory ?? this.priceHistory,
      nextPriceChangeMs: nextPriceChangeMs ?? this.nextPriceChangeMs,
      effects: effects ?? this.effects,
      nextEventMs: nextEventMs ?? this.nextEventMs,
      lastTickMs: lastTickMs ?? this.lastTickMs,
      tutorialStep: tutorialStep ?? this.tutorialStep,
      tutorialDone: tutorialDone ?? this.tutorialDone,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      stats: stats ?? this.stats,
      offlineReport: clearOfflineReport ? null : (offlineReport ?? this.offlineReport),
    );
  }

  Map<String, dynamic> toJson() => {
    'v': GameConfig.saveVersion,
    'm': money,
    'c': crude,
    'r': refined,
    'sites': {for (final e in sites.entries) e.key: e.value.toJson()},
    'sel': selectedSiteId,
    'op': oilPrice,
    'ph': priceHistory,
    'npc': nextPriceChangeMs,
    'fx': effects.map((e) => e.toJson()).toList(),
    'ne': nextEventMs,
    'lt': lastTickMs,
    'ts': tutorialStep,
    'td': tutorialDone,
    'hp': hapticsEnabled,
    'snd': soundEnabled,
    'stats': stats.toJson(),
  };

  /// Eski kayıtlar ve config'e sonradan eklenen sahalar için toleranslı okuma.
  factory GameState.fromJson(Map<String, dynamic> j, int nowMs) {
    final base = GameState.initial(nowMs);
    final rawSites = Map<String, dynamic>.from((j['sites'] as Map?) ?? const {});
    final sites = <String, SiteState>{
      for (final cfg in GameConfig.sites)
        cfg.id: rawSites[cfg.id] is Map
            ? SiteState.fromJson(cfg.id, Map<String, dynamic>.from(rawSites[cfg.id] as Map))
            : SiteState.initial(cfg),
    };
    final selected = j['sel'] as String? ?? base.selectedSiteId;
    final history = ((j['ph'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
    return GameState(
      money: (j['m'] as num?)?.toDouble() ?? base.money,
      crude: (j['c'] as num?)?.toDouble() ?? 0,
      refined: (j['r'] as num?)?.toDouble() ?? 0,
      sites: sites,
      selectedSiteId: sites[selected]?.unlocked == true ? selected : GameConfig.startSiteId,
      oilPrice: (j['op'] as num?)?.toDouble() ?? base.oilPrice,
      priceHistory: history.isEmpty ? base.priceHistory : history,
      nextPriceChangeMs: (j['npc'] as num?)?.toInt() ?? base.nextPriceChangeMs,
      effects: ((j['fx'] as List?) ?? const [])
          .map((e) => ActiveEffect.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nextEventMs: (j['ne'] as num?)?.toInt() ?? base.nextEventMs,
      lastTickMs: (j['lt'] as num?)?.toInt() ?? nowMs,
      tutorialStep: (j['ts'] as num?)?.toInt() ?? 0,
      tutorialDone: j['td'] as bool? ?? false,
      hapticsEnabled: j['hp'] as bool? ?? true,
      soundEnabled: j['snd'] as bool? ?? true,
      stats: j['stats'] is Map ? GameStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map)) : const GameStats(),
    );
  }
}
