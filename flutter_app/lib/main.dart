import 'package:material_ui/material_ui.dart';

import 'data/farm.dart';
import 'i18n.dart';
import 'screens/alerts.dart';
import 'screens/ask.dart';
import 'screens/dashboard.dart';
import 'screens/history.dart';
import 'screens/leaf_check.dart';
import 'screens/setup.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final farm = Farm()..start();
  runApp(FarmScope(farm: farm, child: const SmartFarmingApp()));
}

/// Gives every screen the shared [Farm] and rebuilds it when the farm changes.
class FarmScope extends InheritedNotifier<Farm> {
  const FarmScope({super.key, required Farm farm, required super.child}) : super(notifier: farm);
  static Farm of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FarmScope>()!.notifier!;
}

class SmartFarmingApp extends StatelessWidget {
  const SmartFarmingApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'Smart Farming', debugShowCheckedModeBanner: false, theme: Furrow.theme(), home: const Shell());
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int tab = 0;
  static const _keys = ['dash', 'hist', 'leaf', 'alerts', 'ask', 'setup'];
  static const _icons = [
    Icons.grass_outlined,
    Icons.show_chart,
    Icons.eco_outlined,
    Icons.notifications_outlined,
    Icons.forum_outlined,
    Icons.tune,
  ];

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final farm = FarmScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final screens = const [DashboardScreen(), HistoryScreen(), LeafCheckScreen(), AlertsScreen(), AskScreen(), SetupScreen()];
    Widget icon(int i) {
      final ic = Icon(_icons[i]);
      return i == 3 && farm.unacked > 0 ? Badge(label: Text('${farm.unacked}'), backgroundColor: Furrow.ink, child: ic) : ic;
    }

    final body = IndexedStack(
      index: tab,
      children: [
        for (final s in screens)
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 24, wide ? 32 : 16, 64),
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: s),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: wide ? 32 : 16,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Smart Farming'),
            const SizedBox(width: 8),
            if (wide) Text('Group B-18', style: Furrow.body(13, color: Furrow.muted)),
          ],
        ),
        actions: [
          const ConnChip(),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Language',
            initialValue: farm.lang,
            onSelected: farm.setLang,
            itemBuilder: (_) => [for (final e in languages.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.translate, size: 18),
                  const SizedBox(width: 4),
                  Text(languages[farm.lang]!, style: Furrow.body(13)),
                ],
              ),
            ),
          ),
          SizedBox(width: wide ? 24 : 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  onDestinationSelected: go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < 6; i++) NavigationRailDestination(icon: icon(i), label: Text(tr(farm.lang, _keys[i]))),
                  ],
                ),
                const VerticalDivider(width: 1, color: Furrow.rule),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: go,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [for (var i = 0; i < 6; i++) NavigationDestination(icon: icon(i), label: tr(farm.lang, _keys[i]))],
            ),
    );
  }
}

/// Connection state: offline demo, live simulator, live ESP32 or a fault.
class ConnChip extends StatelessWidget {
  const ConnChip({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context);
    final (text, kind) = !f.live
        ? (f.booted ? 'Offline demo' : 'Connecting', ChipKind.plain)
        : f.fault.code == 'nodata'
        ? ('ESP32 offline', ChipKind.bad)
        : !f.fault.ok
        ? ('Live, sensor fault', ChipKind.warn)
        : (f.owner ? 'Live, simulating here' : (f.deviceSource == 'esp32' ? 'Live, ESP32' : 'Live, simulated ESP32'), ChipKind.ok);
    final chip = StatusChip(f.connecting ? 'Connecting' : text, kind: kind);
    if (f.live || !f.booted) return chip;
    // Offline: tap to see why and try again.
    return InkWell(
      borderRadius: BorderRadius.circular(Furrow.radiusPill),
      onTap: () => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Not connected to Firebase'),
          content: Text(
            'The app is running the offline demo: the simulator runs on this device and nothing is synced.\n\n'
            'Reason: ${f.cloudError ?? 'unknown'}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                f.retryCloud();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      child: chip,
    );
  }
}
