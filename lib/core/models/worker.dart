import '../../config/game_config.dart';

/// Ekipteki bir işçi. Her işçinin bir görevi (rol) ve rütbesi vardır.
/// [name] boşsa görev adı kullanılır (ör. "Derikmen", "İşçi 2"); oyuncu
/// dilediği zaman kendi ismini verebilir.
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

  /// 0 = Çırak ... [GameConfig.crewRanks] uzunluğu - 1 = Şef.
  final int rank;
  final String? name;
  final int hiredAtMs;

  static const maxNameLength = 18;

  CrewRoleConfig get role => GameConfig.crewRole(roleId);

  String get rankTitle => GameConfig.crewRanks[rank.clamp(0, GameConfig.crewRanks.length - 1)];

  bool get isMaxRank => rank >= GameConfig.crewRanks.length - 1;

  /// Görüntülenen ad: verilen isim ya da görev adı (+ numara).
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return role.maxCount > 1 ? '${role.title} $number' : role.title;
  }

  /// "Derikmen · Kalfa" gibi alt başlık.
  String get subtitle => '${role.title} · $rankTitle';

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
    rank: ((j['k'] as num?)?.toInt() ?? 0).clamp(0, GameConfig.crewRanks.length - 1),
    name: j['nm'] as String?,
    hiredAtMs: (j['h'] as num?)?.toInt() ?? 0,
  );
}
