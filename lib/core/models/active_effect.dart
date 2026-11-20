import '../../config/game_config.dart';

/// Etkinin kaynağı. Olaylar şimdi; reklam ve GPS ileride aynı mekanizmayı
/// kullanacak (ör. reklam: 2 saat boyunca üretim x2).
enum EffectSource { event, ad, gps, other }

/// Süreli bir çarpan (üretim ve/veya satış fiyatı).
class ActiveEffect {
  const ActiveEffect({
    required this.id,
    required this.title,
    required this.source,
    required this.startMs,
    required this.endMs,
    this.eventKind,
    this.productionMultiplier = 1,
    this.priceMultiplier = 1,
  });

  final String id;
  final String title;
  final EffectSource source;
  final GameEventKind? eventKind;
  final int startMs;
  final int endMs;
  final double productionMultiplier;
  final double priceMultiplier;

  bool isActiveAt(int nowMs) => nowMs >= startMs && nowMs < endMs;

  Duration remaining(int nowMs) => Duration(milliseconds: (endMs - nowMs).clamp(0, 1 << 31));

  Map<String, dynamic> toJson() => {
        'id': id,
        'ti': title,
        'so': source.name,
        if (eventKind != null) 'ek': eventKind!.name,
        'sm': startMs,
        'em': endMs,
        'pm': productionMultiplier,
        'prm': priceMultiplier,
      };

  factory ActiveEffect.fromJson(Map<String, dynamic> j) => ActiveEffect(
        id: j['id'] as String? ?? '',
        title: j['ti'] as String? ?? '',
        source: EffectSource.values.firstWhere((e) => e.name == j['so'], orElse: () => EffectSource.other),
        eventKind: GameEventKind.values.where((e) => e.name == j['ek']).firstOrNull,
        startMs: (j['sm'] as num?)?.toInt() ?? 0,
        endMs: (j['em'] as num?)?.toInt() ?? 0,
        productionMultiplier: (j['pm'] as num?)?.toDouble() ?? 1,
        priceMultiplier: (j['prm'] as num?)?.toDouble() ?? 1,
      );
}
