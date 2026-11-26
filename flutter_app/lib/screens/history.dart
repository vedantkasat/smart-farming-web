import 'package:material_ui/material_ui.dart';

import '../i18n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_chart.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context), L = f.lang;
    final runs = f.runs.take(10).toList();
    TextStyle th = Furrow.body(13, color: Furrow.muted, weight: FontWeight.w500);
    TextStyle td = Furrow.mono(13.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHead(
          tr(L, 'hist'),
          trailing: Text('One point every 5 minutes, from sensors/history', style: Furrow.body(13, color: Furrow.muted)),
        ),
        Panel(
          title: tr(L, 'soil'),
          child: LineChart(
            data: f.hist,
            value: (p) => p.moisture,
            color: Furrow.water,
            ref: f.t.dry,
            shadePump: true,
            label: 'Soil moisture history',
          ),
        ),
        const SizedBox(height: 16),
        Columns([
          (
            6,
            Panel(
              title: tr(L, 'temp'),
              child: LineChart(data: f.hist, value: (p) => p.temperature, color: Furrow.contour, label: 'Temperature history'),
            ),
          ),
          (
            6,
            Panel(
              title: tr(L, 'hum'),
              child: LineChart(data: f.hist, value: (p) => p.humidity, color: Furrow.green, label: 'Humidity history'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Panel(
          sheet: true,
          title: 'Pump runs',
          child: runs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No pump runs yet. They appear here when the pump starts, in either mode.',
                    style: Furrow.body(14, color: Furrow.muted),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    horizontalMargin: 0,
                    columnSpacing: 28,
                    dividerThickness: 1,
                    border: const TableBorder(horizontalInside: BorderSide(color: Furrow.rule)),
                    headingTextStyle: th,
                    columns: const [
                      DataColumn(label: Text('Started')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Mode')),
                      DataColumn(label: Text('Moisture at start')),
                    ],
                    rows: [
                      for (final r in runs)
                        DataRow(
                          cells: [
                            DataCell(Text(fmtTime(r.t), style: td)),
                            DataCell(Text('${r.dur} min', style: td)),
                            DataCell(Text('${r.mode}${r.why.isNotEmpty ? ', ${r.why}' : ''}', style: Furrow.body(13.5))),
                            DataCell(Text('${r.moistureAtStart.toStringAsFixed(1)} %', style: td)),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
