/// İleride eklenecek özellikler için takılabilir servis arayüzleri.
/// Şimdilik hepsinin "boş" (no-op) uygulaması var; gerçek uygulama hazır
/// olduğunda yalnızca ilgili provider override edilir.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';

// ------------------------------------------------------------------ Zaman

abstract interface class Clock {
  int nowMs();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());

// ------------------------------------------------------------------ Ses

enum SoundCue { tap, drillStart, drillTap, gusher, dryWell, collect, sell, upgrade, unlock, event, repair }

/// Ses efektleri için arayüz. Ses dosyaları eklenince bir AudioPlayer
/// uygulaması yazılıp [audioServiceProvider] override edilir.
abstract interface class AudioService {
  void play(SoundCue cue);
}

class SilentAudioService implements AudioService {
  const SilentAudioService();
  @override
  void play(SoundCue cue) {}
}

final audioServiceProvider = Provider<AudioService>((ref) => const SilentAudioService());

// --------------------------------------------------------------- Haptik

class HapticsService {
  const HapticsService();
  void light() => HapticFeedback.lightImpact();
  void medium() => HapticFeedback.mediumImpact();
  void heavy() => HapticFeedback.heavyImpact();
  void selection() => HapticFeedback.selectionClick();
}

final hapticsServiceProvider = Provider<HapticsService>((ref) => const HapticsService());

// ---------------------------------------------------------- GPS bonusu

/// İleride: oyuncu gerçekten sahaya (ör. Raman) gidince ekstra ödül.
abstract interface class LocationBonusService {
  bool get isAvailable;
  Future<bool> isPlayerAt(SiteConfig site, {double radiusKm = 3});
}

class DisabledLocationBonusService implements LocationBonusService {
  const DisabledLocationBonusService();
  @override
  bool get isAvailable => false;
  @override
  Future<bool> isPlayerAt(SiteConfig site, {double radiusKm = 3}) async => false;
}

final locationBonusServiceProvider = Provider<LocationBonusService>((ref) => const DisabledLocationBonusService());

// --------------------------------------------------------- Liderlik tablosu

class LeaderboardEntry {
  const LeaderboardEntry(this.name, this.score);
  final String name;
  final double score;
}

/// İleride: Supabase ile liderlik tablosu.
abstract interface class LeaderboardService {
  bool get isAvailable;
  Future<void> submitScore(double totalEarned);
  Future<List<LeaderboardEntry>> topScores({int limit = 20});
}

class OfflineLeaderboardService implements LeaderboardService {
  const OfflineLeaderboardService();
  @override
  bool get isAvailable => false;
  @override
  Future<void> submitScore(double totalEarned) async {}
  @override
  Future<List<LeaderboardEntry>> topScores({int limit = 20}) async => const [];
}

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) => const OfflineLeaderboardService());

// ---------------------------------------------------------- Ödüllü reklam

/// İleride: ödüllü reklam izleyince 2 saat üretim x2.
/// Ödül, GameController.grantBoost ile ActiveEffect olarak uygulanır.
abstract interface class RewardedAdService {
  bool get isAvailable;
  Future<bool> showRewardedAd();
}

class NoAdsService implements RewardedAdService {
  const NoAdsService();
  @override
  bool get isAvailable => false;
  @override
  Future<bool> showRewardedAd() async => false;
}

final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) => const NoAdsService());

abstract final class AdRewardConfig {
  static const Duration boostDuration = Duration(hours: 2);
  static const double productionMultiplier = 2;
}
