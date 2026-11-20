import '../../config/game_config.dart';

/// Ekipteki bir işçi. Her işçinin bir adı, bir görevi (rol) ve görevine
/// özgü gerçek bir unvanı/rütbesi vardır (ör. Sondör Muavini → Başsondör).
/// Ad işe alınırken verilir; oyuncu dilediği zaman değiştirebilir.
/// İleride kullanıcı adları bu alana bağlanabilir.
class Worker {
  const Worker({
    required this.id,
    required this.roleId,
    required this.number,
    this.rank = 0,
    this.name,
    this.hiredAtMs = 0,
  });

  final int id;
  final String roleId;

  /// Aynı görevdeki sıra numarası (İşçi 1, İşçi 2...).
  final int number;

  /// Görevin [CrewRoleConfig.ranks] listesindeki basamak (0 = en alt).
  final int rank;
  final String? name;
  final int hiredAtMs;

  static const maxNameLength = 18;

  CrewRoleConfig get role => GameConfig.crewRole(roleId);

  /// Sahadaki unvanı (ör. "Başsondör").
  String get rankTitle => role.ranks[rank.clamp(0, role.maxRank)];

  /// Bir üst unvan (en üstteyse null).
  String? get nextRankTitle => isMaxRank ? null : role.ranks[rank + 1];

  bool get isMaxRank => rank >= role.maxRank;

  /// Görüntülenen ad.
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return defaultName(id);
  }

  /// "Şeyhmus · Başsondör" gibi tam künye.
  String get fullTitle => '$displayName · $rankTitle';

  /// Kimliğe göre deterministik varsayılan ad (eski kayıtlar için yedek).
  static String defaultName(int id) => GameConfig.crewNames[(id * 7) % GameConfig.crewNames.length];

  /// Ekipte kullanılmayan bir ad seçer.
  static String pickName(int id, Iterable<String> used) {
    final names = GameConfig.crewNames;
    final taken = used.toSet();
    final start = (id * 7) % names.length;
    for (var i = 0; i < names.length; i++) {
      final n = names[(start + i) % names.length];
      if (!taken.contains(n)) return n;
    }
    return '${names[start]} ${id ~/ names.length + 1}';
  }

  Worker copyWith({int? rank, String? name, bool clearName = false}) => Worker(
    id: id,
    roleId: roleId,
    number: number,
    rank: rank ?? this.rank,
    name: clearName ? null : (name ?? this.name),
    hiredAtMs: hiredAtMs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'r': roleId,
    'n': number,
    'k': rank,
    if (name != null) 'nm': name,
    'h': hiredAtMs,
  };

  factory Worker.fromJson(Map<String, dynamic> j) => Worker(
    id: (j['id'] as num?)?.toInt() ?? 0,
    roleId: j['r'] as String? ?? 'isci',
    number: (j['n'] as num?)?.toInt() ?? 1,
    rank: ((j['k'] as num?)?.toInt() ?? 0).clamp(0, GameConfig.crewRole(j['r'] as String? ?? 'isci').maxRank),
    name: j['nm'] as String?,
    hiredAtMs: (j['h'] as num?)?.toInt() ?? 0,
  );
}
