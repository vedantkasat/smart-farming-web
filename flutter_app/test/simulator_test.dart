import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farming/data/expert.dart';
import 'package:smart_farming/data/farm.dart';

void main() {
  late Farm f;
  setUp(() => f = Farm());

  test('Auto starts the pump at the dry limit and stops it at field capacity', () {
    f.simulateFault('dry');
    f.tickForTest(1);
    expect(f.pump, isTrue);
    expect(f.alerts.any((a) => a.type == 'dry'), isTrue);
    for (var i = 0; i < 40 && f.pump; i++) {
      f.tickForTest(1);
    }
    expect(f.pump, isFalse);
    expect(f.runs, isNotEmpty);
    expect(f.soil, greaterThanOrEqualTo(f.t.stop));
  });

  test('maximum run stops a manual pump', () {
    f.cfg.maxRunMin = 5;
    f.pumpCommand('ON');
    expect(f.pump, isTrue);
    expect(f.mode, 'manual');
    for (var i = 0; i < 6; i++) {
      f.tickForTest(1);
    }
    expect(f.pump, isFalse);
    expect(f.runs.first.why, 'maximum run time');
  });

  test('no reading for 3 cycles is a fault and switches the pump off', () {
    f.pumpCommand('ON');
    f.simulateFault('off');
    for (var i = 0; i < 3; i++) {
      f.tickForTest(1);
    }
    expect(f.fault.code, 'nodata');
    expect(f.pump, isFalse);
  });

  test('out-of-range reading is rejected as a fault', () {
    f.simulateFault('range');
    f.tickForTest(1);
    expect(f.fault.code, 'range');
  });

  test('stuck sensor with pump ON for 30 min is a fault', () {
    f.cfg.maxRunMin = 120;
    f.simulateFault('stuck');
    f.pumpCommand('ON');
    for (var i = 0; i < 32 && f.fault.ok; i++) {
      f.tickForTest(1);
    }
    expect(f.fault.code, 'stuck');
    expect(f.pump, isFalse);
  });

  test('Return to Auto ends manual mode', () {
    f.pumpCommand('ON');
    f.pumpCommand('AUTO');
    expect(f.mode, 'auto');
    expect(f.pump, isFalse);
  });

  test('the expert never gives doses', () {
    for (final q in ['how much fungicide should I spray', 'which pesticide dose for blight', 'spray for leaf curl']) {
      final a = answer(f, q);
      expect(a, contains('I do not give products or doses'));
      expect(a, contains('1800-180-1551'));
    }
  });

  test('the expert explains the dry limit from config', () {
    expect(answer(f, 'what is the dry limit'), contains('= 19.8%'));
  });
}
