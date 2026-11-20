import '../../config/game_config.dart';
import 'parcel.dart';

class SiteState {
  const SiteState({required this.id, required this.unlocked, required this.parcels});

  factory SiteState.initial(SiteConfig config) => SiteState(
        id: config.id,
        unlocked: config.unlockCost <= 0,
        parcels: List.filled(GameConfig.gridSize * GameConfig.gridSize, Parcel.empty),
      );

  final String id;
  final bool unlocked;
  final List<Parcel> parcels;

  SiteConfig get config => GameConfig.site(id);

  SiteState copyWith({bool? unlocked, List<Parcel>? parcels}) => SiteState(
        id: id,
        unlocked: unlocked ?? this.unlocked,
        parcels: parcels ?? this.parcels,
      );

  SiteState updateParcel(int index, Parcel parcel) {
    final list = [...parcels];
    list[index] = parcel;
    return copyWith(parcels: list);
  }

  Map<String, dynamic> toJson() => {
        'u': unlocked,
        'p': parcels.map((p) => p.toJson()).toList(),
      };

  factory SiteState.fromJson(String id, Map<String, dynamic> j) {
    final count = GameConfig.gridSize * GameConfig.gridSize;
    final raw = (j['p'] as List?) ?? const [];
    final parcels = List<Parcel>.generate(
      count,
      (i) => i < raw.length ? Parcel.fromJson(Map<String, dynamic>.from(raw[i] as Map)) : Parcel.empty,
    );
    return SiteState(id: id, unlocked: j['u'] as bool? ?? false, parcels: parcels);
  }
}
