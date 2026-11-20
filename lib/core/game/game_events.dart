import '../../config/game_config.dart';

/// Simülasyonun ve eylemlerin ürettiği, arayüzün (Usta, efektler, ses)
/// tepki verdiği olaylar.
sealed class GameEvent {
  const GameEvent();
}

class DrillFinished extends GameEvent {
  const DrillFinished({required this.siteId, required this.index, required this.struck, required this.lost});
  final String siteId;
  final int index;
  final bool struck;
  final double lost;
}

class RandomEventStarted extends GameEvent {
  const RandomEventStarted(this.config, {this.siteId, this.index});
  final EventConfig config;
  final String? siteId;
  final int? index;
}

class EffectEnded extends GameEvent {
  const EffectEnded(this.title);
  final String title;
}

class PriceChanged extends GameEvent {
  const PriceChanged(this.oldPrice, this.newPrice);
  final double oldPrice;
  final double newPrice;
}

class StorageFull extends GameEvent {
  const StorageFull(this.siteId, this.index);
  final String siteId;
  final int index;
}

class SiteUnlocked extends GameEvent {
  const SiteUnlocked(this.siteId);
  final String siteId;
}

class Sold extends GameEvent {
  const Sold(this.amount, this.money);
  final double amount;
  final double money;
}

/// Mekanikçi bir kuyuyu kendiliğinden tamir etti.
class AutoRepaired extends GameEvent {
  const AutoRepaired(this.siteId, this.index);
  final String siteId;
  final int index;
}

/// Tanker şoförü depolardan ham petrol topladı.
class AutoCollected extends GameEvent {
  const AutoCollected(this.amount);
  final double amount;
}

/// Ekibe yeni biri katıldı veya terfi etti.
class CrewChanged extends GameEvent {
  const CrewChanged(this.workerId, {this.promoted = false});
  final int workerId;
  final bool promoted;
}
