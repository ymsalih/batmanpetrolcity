import '../../config/game_config.dart';

/// Parselin yaşam döngüsü: Boş → (Etüt) → Sondaj → Kuru / Üretimde.
enum ParcelStatus { empty, drilling, dry, producing }

class Parcel {
  const Parcel({
    this.status = ParcelStatus.empty,
    this.tier,
    this.surveyed = false,
    this.willStrike = false,
    this.drillStartMs = 0,
    this.drillDurationMs = 0,
    this.drillBonusMs = 0,
    this.pumpLevel = 0,
    this.storageLevel = 0,
    this.stored = 0,
    this.broken = false,
    this.repairProgress = 0,
    this.totalProduced = 0,
    this.brokenAtMs = 0,
  });

  static const empty = Parcel();

  final ParcelStatus status;

  /// Gizli verim seviyesi. Etüt veya sondaj başlayınca belirlenir.
  final YieldTier? tier;
  final bool surveyed;

  /// Sondaj başlarken belirlenir, sonunda açığa çıkar.
  final bool willStrike;
  final int drillStartMs;
  final int drillDurationMs;

  /// Oyuncunun dokunarak kazandığı süre.
  final int drillBonusMs;

  final int pumpLevel;
  final int storageLevel;

  /// Kuyu deposundaki varil.
  final double stored;
  final bool broken;
  final int repairProgress;
  final double totalProduced;

  /// Arızanın başladığı an (mekanikçinin otomatik tamiri için).
  final int brokenAtMs;

  int get drillCompleteMs => drillStartMs + drillDurationMs - drillBonusMs;

  Parcel copyWith({
    ParcelStatus? status,
    YieldTier? tier,
    bool? surveyed,
    bool? willStrike,
    int? drillStartMs,
    int? drillDurationMs,
    int? drillBonusMs,
    int? pumpLevel,
    int? storageLevel,
    double? stored,
    bool? broken,
    int? repairProgress,
    double? totalProduced,
    int? brokenAtMs,
  }) {
    return Parcel(
      status: status ?? this.status,
      tier: tier ?? this.tier,
      surveyed: surveyed ?? this.surveyed,
      willStrike: willStrike ?? this.willStrike,
      drillStartMs: drillStartMs ?? this.drillStartMs,
      drillDurationMs: drillDurationMs ?? this.drillDurationMs,
      drillBonusMs: drillBonusMs ?? this.drillBonusMs,
      pumpLevel: pumpLevel ?? this.pumpLevel,
      storageLevel: storageLevel ?? this.storageLevel,
      stored: stored ?? this.stored,
      broken: broken ?? this.broken,
      repairProgress: repairProgress ?? this.repairProgress,
      totalProduced: totalProduced ?? this.totalProduced,
      brokenAtMs: brokenAtMs ?? this.brokenAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    's': status.name,
    if (tier != null) 't': tier!.name,
    'sv': surveyed,
    'ws': willStrike,
    'ds': drillStartMs,
    'dd': drillDurationMs,
    'db': drillBonusMs,
    'pl': pumpLevel,
    'sl': storageLevel,
    'st': stored,
    'br': broken,
    'rp': repairProgress,
    'tp': totalProduced,
    'ba': brokenAtMs,
  };

  factory Parcel.fromJson(Map<String, dynamic> j) {
    return Parcel(
      status: _enumByName(ParcelStatus.values, j['s'], ParcelStatus.empty),
      tier: j['t'] == null ? null : _enumByName(YieldTier.values, j['t'], YieldTier.medium),
      surveyed: j['sv'] as bool? ?? false,
      willStrike: j['ws'] as bool? ?? false,
      drillStartMs: (j['ds'] as num?)?.toInt() ?? 0,
      drillDurationMs: (j['dd'] as num?)?.toInt() ?? 0,
      drillBonusMs: (j['db'] as num?)?.toInt() ?? 0,
      pumpLevel: (j['pl'] as num?)?.toInt() ?? 0,
      storageLevel: (j['sl'] as num?)?.toInt() ?? 0,
      stored: (j['st'] as num?)?.toDouble() ?? 0,
      broken: j['br'] as bool? ?? false,
      repairProgress: (j['rp'] as num?)?.toInt() ?? 0,
      totalProduced: (j['tp'] as num?)?.toDouble() ?? 0,
      brokenAtMs: (j['ba'] as num?)?.toInt() ?? 0,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
