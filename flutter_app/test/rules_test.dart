import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farming/data/rules.dart';

void main() {
  test('dry limit = FC - p x (FC - WP), report 6.2', () {
    final c = FieldConfig(crop: 'tomato', stage: 'vegetative', soil: 'loam');
    final t = c.thresholds;
    expect(t.fc, 25);
    expect(t.wp, 12);
    expect(t.p, .40);
    expect(t.dry, 19.8); // 25 - 0.4 * 13
    expect(t.stop, 25);
  });

  test('sensitive stage cuts p by 25%', () {
    final t = FieldConfig(crop: 'tomato', stage: 'flowering', soil: 'loam').thresholds;
    expect(t.sensitive, isTrue);
    expect(t.p, .30);
    expect(t.dry, 21.1); // 25 - 0.3 * 13
  });

  test('soils and crops match Tables 6.2 and 6.3', () {
    expect([soils['sandy']!.fc, soils['sandy']!.wp], [12, 5]);
    expect([soils['clay']!.fc, soils['clay']!.wp], [36, 22]);
    expect(crops['onion']!.p, .30);
    expect(crops['maize']!.p, .55);
  });

  test('invalid stage falls back to the crop first stage', () {
    final c = FieldConfig(crop: 'onion', stage: 'flowering')..normalise();
    expect(c.stage, 'establishment');
  });

  test('config doc has the Table 7.1 fields', () {
    final d = FieldConfig().toDoc(0);
    for (final k in ['crop', 'stage', 'soil', 'fc', 'wp', 'p', 'dryLimit', 'maxRunMin', 'loc', 'area']) {
      expect(d.containsKey(k), isTrue, reason: k);
    }
  });
}
