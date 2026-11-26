/// Reference data and rules from the Stage-I report.
/// Soils: Table 6.2. Crops and depletion fraction p: Table 6.3.
/// Dry limit: section 6.2. Faults: Table 6.4.
library;

class Soil {
  final String name;
  final double fc, wp;
  const Soil(this.name, this.fc, this.wp);
}

class Stage {
  final String key, name;
  final bool sensitive;
  const Stage(this.key, this.name, this.sensitive);
}

class Crop {
  final String name;
  final double p;
  final List<Stage> stages;
  const Crop(this.name, this.p, this.stages);
}

const soils = <String, Soil>{
  'sandy': Soil('Sandy', 12, 5),
  'loam': Soil('Loam', 25, 12),
  'clay': Soil('Clay or black cotton soil', 36, 22),
};

const crops = <String, Crop>{
  'tomato': Crop('Tomato', .40, [
    Stage('seedling', 'Seedling', false),
    Stage('transplanting', 'Transplanting', true),
    Stage('vegetative', 'Vegetative', false),
    Stage('flowering', 'Flowering', true),
    Stage('fruitset', 'Fruit set', true),
    Stage('ripening', 'Ripening', false),
  ]),
  'onion': Crop('Onion', .30, [
    Stage('establishment', 'Establishment', false),
    Stage('vegetative', 'Vegetative', false),
    Stage('bulb', 'Bulb formation', true),
    Stage('maturity', 'Maturity', false),
  ]),
  'maize': Crop('Maize', .55, [
    Stage('seedling', 'Seedling', false),
    Stage('vegetative', 'Vegetative', false),
    Stage('tasseling', 'Tasseling', true),
    Stage('silking', 'Silking', true),
    Stage('maturity', 'Maturity', false),
  ]),
};

/// Maximum pump run in minutes (report: 30 min).
const defaultMaxRunMin = 30;

/// Kisan Call Centre.
const kccNumber = '1800-180-1551';

/// Disease results below this confidence are rejected.
const minLeafConfidence = 0.70;

double _round(double v, int places) {
  final f = places == 1 ? 10 : 1000;
  return (v * f).roundToDouble() / f;
}

class FieldConfig {
  String crop;
  String stage;
  String soil;
  String loc;
  int maxRunMin;

  FieldConfig({this.crop = 'tomato', this.stage = 'vegetative', this.soil = 'loam', this.loc = '', this.maxRunMin = defaultMaxRunMin});

  Crop get cropInfo => crops[crop] ?? crops['tomato']!;
  Soil get soilInfo => soils[soil] ?? soils['loam']!;

  Stage get stageInfo => cropInfo.stages.firstWhere((s) => s.key == stage, orElse: () => cropInfo.stages.first);

  /// Keeps crop, soil and stage valid after any change.
  void normalise() {
    if (!crops.containsKey(crop)) crop = 'tomato';
    if (!soils.containsKey(soil)) soil = 'loam';
    if (!cropInfo.stages.any((s) => s.key == stage)) stage = cropInfo.stages.first.key;
    if (maxRunMin < 1) maxRunMin = defaultMaxRunMin;
  }

  Thresholds get thresholds {
    final s = soilInfo, c = cropInfo, sens = stageInfo.sensitive;
    final p = _round(c.p * (sens ? .75 : 1), 3);
    return Thresholds(fc: s.fc, wp: s.wp, p: p, sensitive: sens, dry: _round(s.fc - p * (s.fc - s.wp), 1), stop: s.fc);
  }

  /// `config` document, report Table 7.1.
  Map<String, Object?> toDoc(int now) {
    final t = thresholds;
    return {
      'crop': crop,
      'stage': stage,
      'soil': soil,
      'fc': t.fc,
      'wp': t.wp,
      'p': t.p,
      'dryLimit': t.dry,
      'maxRunMin': maxRunMin,
      'loc': loc,
      'updatedAt': now,
    };
  }

  Map<String, Object?> toJson() => {'crop': crop, 'stage': stage, 'soil': soil, 'loc': loc, 'maxRunMin': maxRunMin};

  void apply(Map m) {
    crop = (m['crop'] ?? crop).toString();
    stage = (m['stage'] ?? stage).toString();
    soil = (m['soil'] ?? soil).toString();
    loc = (m['loc'] ?? '').toString();
    maxRunMin = (m['maxRunMin'] is num) ? (m['maxRunMin'] as num).toInt() : defaultMaxRunMin;
    normalise();
  }
}

class Thresholds {
  final double fc, wp, p, dry, stop;
  final bool sensitive;
  const Thresholds({required this.fc, required this.wp, required this.p, required this.dry, required this.stop, required this.sensitive});
}

String fmtNum(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
