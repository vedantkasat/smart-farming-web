import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farming/data/farm.dart';
import 'package:smart_farming/main.dart';

void main() {
  testWidgets('app shell shows all six screens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final farm = Farm();
    await tester.pumpWidget(FarmScope(farm: farm, child: const SmartFarmingApp()));
    await tester.pump();
    for (final t in ['Dashboard', 'History', 'Leaf check', 'Alerts', 'Ask an expert', 'Field setup']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.text('Irrigation pump'), findsOneWidget);
    await tester.tap(find.text('Field setup').first);
    await tester.pump();
    expect(find.text('Irrigation threshold'), findsOneWidget);
  });
}
