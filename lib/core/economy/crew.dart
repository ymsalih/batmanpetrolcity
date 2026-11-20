import 'dart:math';

import '../../config/game_config.dart';
import '../models/worker.dart';
import '../utils/format.dart';

/// Ekibin toplam etkisi. Saf hesaplama; unit testlerle doğrulanır.
class Crew {
  const Crew({
    this.drillTimeMultiplier = 1,
    this.tapMultiplier = 1,
    this.dryMultiplier = 1,
    this.productionMultiplier = 1,
    this.priceMultiplier = 1,
    this.autoRepairSeconds,
    this.autoCollectSeconds,
    this.leadership = 0,
  });

  static const none = Crew();

  final double drillTimeMultiplier;
  final double tapMultiplier;
  final double dryMultiplier;
  final double productionMultiplier;
  final double priceMultiplier;

  /// null: mekanikçi yok.
  final double? autoRepairSeconds;

  /// null: tanker şoförü yok.
  final double? autoCollectSeconds;

  /// Kule mühendisinin ekibe kattığı oran.
  final double leadership;

  /// Tek bir işçinin kendi görevindeki etki değeri (oran ya da saniye).
  static double skillValue(CrewRoleConfig role, int rank) {
    final level = rank + 1;
    return switch (role.skill) {
      CrewSkill.autoRepair || CrewSkill.autoCollect => max(10, role.base - role.perRank * rank),
      _ => role.perRank * level,
    };
  }

  factory Crew.of(List<Worker> workers) {
    if (workers.isEmpty) return none;
    // Kule mühendisi tüm ekibin etkisini büyütür.
    var lead = 0.0;
    for (final w in workers) {
      if (w.role.skill == CrewSkill.leadership) lead += skillValue(w.role, w.rank);
    }
    final amp = 1 + lead;
    var drill = 1.0;
    var tap = 0.0;
    var dry = 0.0;
    var prod = 0.0;
    var price = 0.0;
    double? repair;
    double? collect;
    for (final w in workers) {
      final role = w.role;
      final raw = skillValue(role, w.rank);
      final isTime = role.skill == CrewSkill.autoRepair || role.skill == CrewSkill.autoCollect;
      final v = isTime ? raw / amp : raw * amp;
      switch (role.skill) {
        case CrewSkill.leadership:
          break;
        case CrewSkill.drillSpeed:
          drill *= 1 - v.clamp(0.0, 0.9);
        case CrewSkill.tapPower:
          tap += v;
        case CrewSkill.dryChance:
          dry += v;
        case CrewSkill.production:
          prod += v;
        case CrewSkill.price:
          price += v;
        case CrewSkill.autoRepair:
          repair = repair == null ? v : min(repair, v);
        case CrewSkill.autoCollect:
          collect = collect == null ? v : min(collect, v);
      }
    }
    return Crew(
      drillTimeMultiplier: drill.clamp(0.35, 1.0),
      tapMultiplier: 1 + tap,
      dryMultiplier: (1 - dry).clamp(0.4, 1.0),
      productionMultiplier: 1 + prod,
      priceMultiplier: 1 + price,
      autoRepairSeconds: repair,
      autoCollectSeconds: collect,
      leadership: lead,
    );
  }

  /// İşe alma bedeli: aynı görevden kaçıncı kişi olduğuna göre artar.
  static double hireCost(CrewRoleConfig role, int alreadyHired) =>
      (role.hireCost * pow(GameConfig.crewHireGrowth, alreadyHired)).roundToDouble();

  /// Bir üst rütbeye terfi bedeli.
  static double promoteCost(Worker w) =>
      (w.role.hireCost * pow(GameConfig.crewPromoteGrowth, w.rank + 1)).roundToDouble();

  /// Kartlarda gösterilen etki metni.
  static String effectText(CrewRoleConfig role, int rank) {
    final v = skillValue(role, rank);
    String pct(double x) => '%${Fmt.decimal(x * 100, 0)}';
    // Kırılmaz boşluk + gerçek eksi işareti: dar ekranda "-" ile "%32"
    // farklı satırlara bölünmesin.
    const nb = '\u00A0';
    const minus = '\u2212';
    return switch (role.skill) {
      CrewSkill.drillSpeed => 'Sondaj süresi$nb$minus${pct(v)}',
      CrewSkill.tapPower => 'Dokunuş gücü$nb+${pct(v)}',
      CrewSkill.dryChance => 'Kuru kuyu ihtimali$nb$minus${pct(v)}',
      CrewSkill.production => 'Üretim$nb+${pct(v)}',
      CrewSkill.price => 'Satış fiyatı$nb+${pct(v)}',
      CrewSkill.autoRepair => 'Arızayı ${Fmt.integer(v)}${nb}sn içinde tamir eder',
      CrewSkill.autoCollect => 'Depoları her ${Fmt.integer(v)}${nb}sn boşaltır',
      CrewSkill.leadership => 'Tüm ekibin etkisi$nb+${pct(v)}',
    };
  }
}
