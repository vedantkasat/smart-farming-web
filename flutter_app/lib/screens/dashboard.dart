import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../data/rules.dart';
import '../i18n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_chart.dart';
import '../widgets/survey_map.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context);
    final c = f.cfg, th = f.t, st = c.stageInfo, L = f.lang;
    final cropLine =
        '${c.cropInfo.name}, ${st.name.toLowerCase()}${st.sensitive ? ' (sensitive)' : ''}, ${c.soilInfo.name.toLowerCase()} soil';
    final (soilText, soilKind) = !f.fault.ok
        ? ('Not trusted', ChipKind.bad)
        : f.soil <= th.dry
        ? ('At dry limit', ChipKind.warn)
        : f.soil >= th.fc
        ? ('At field capacity', ChipKind.ok)
        : ('In range', ChipKind.ok);

    final field = EntryCard(
      head: Text(tr(L, 'soil')),
      headTrailing: Flexible(
        child: Text('$cropLine, ${fmtTime(f.ts)}', overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
      ),
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Furrow.ink)),
          ),
          child: SurveyMap(
            plotName: '${c.loc.isNotEmpty ? '${c.loc}, ' : ''}${c.cropInfo.name} plot, ${fmtNum(c.area)} acre',
            pump: f.pump,
            ok: f.fault.ok,
            soil: f.soil,
            time: fmtTime(f.ts),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(f.soil.toStringAsFixed(1), style: Furrow.display(36).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text('%', style: Furrow.display(19, color: Furrow.muted)),
                  ),
                  const Spacer(),
                  StatusChip(soilText, kind: soilKind),
                ],
              ),
              const SizedBox(height: 20),
              MoistureScale(soil: f.soil, th: th),
              const SizedBox(height: 10),
              _Legend(th: th, lang: L),
            ],
          ),
        ),
      ],
    );

    final pump = Panel(
      title: tr(L, 'pump'),
      trailing: StatusChip(f.mode == 'auto' ? 'Auto' : 'Manual', kind: f.mode == 'auto' ? ChipKind.plain : ChipKind.warn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(f.pump ? tr(L, 'running') : tr(L, 'off'), style: Furrow.display(28)),
              StatusChip(f.pump ? '${f.runMinutes} min' : 'Idle', kind: f.pump ? ChipKind.on : ChipKind.plain, mono: f.pump),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            f.mode == 'auto'
                ? (f.fault.ok
                      ? 'Starts at ${fmtNum(th.dry)}%, stops at field capacity (${fmtNum(th.fc)}%).'
                      : 'Auto is blocked while a sensor fault is active.')
                : 'Manual: the pump follows your ON and OFF. Return to Auto when done.',
            style: Furrow.body(14, color: Furrow.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ConfirmButton(
                label: tr(L, 'pumpOn'),
                confirmLabel: '${tr(L, 'confirm')}: ${tr(L, 'pumpOn')}',
                primary: true,
                onConfirmed: f.pump || f.fault.code == 'nodata' ? null : () => f.pumpCommand('ON'),
              ),
              ConfirmButton(
                label: tr(L, 'pumpOff'),
                confirmLabel: '${tr(L, 'confirm')}: ${tr(L, 'pumpOff')}',
                onConfirmed: !f.pump && f.mode == 'manual' ? null : () => f.pumpCommand('OFF'),
              ),
              ConfirmButton(
                label: tr(L, 'auto'),
                confirmLabel: '${tr(L, 'confirm')}: ${tr(L, 'auto')}',
                onConfirmed: f.mode == 'auto' ? null : () => f.pumpCommand('AUTO'),
              ),
            ],
          ),
          Note(
            'A manual command takes priority over Auto. The pump stops itself after ${c.maxRunMin} min in either mode, '
            'and a sensor fault switches it off and blocks Auto.',
          ),
        ],
      ),
    );

    final readings = Panel(
      title: tr(L, 'readings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RuledRow(top: true, label: Text(tr(L, 'temp')), value: _Val(fmtNum(f.temp), '°C')),
          RuledRow(label: Text(tr(L, 'hum')), value: _Val(fmtNum(f.hum), '%')),
          RuledRow(
            label: Text(tr(L, 'sensor')),
            value: StatusChip(f.fault.ok ? 'OK' : 'Fault', kind: f.fault.ok ? ChipKind.ok : ChipKind.bad),
          ),
          const SizedBox(height: 8),
          Text(f.fault.msg, style: Furrow.body(14, color: Furrow.muted)),
        ],
      ),
    );

    final hist = f.hist;
    final chart = Panel(
      title: tr(L, 'live'),
      trailing: Text('Shaded where the pump ran', style: Furrow.body(13, color: Furrow.muted)),
      child: LineChart(
        data: hist.sublist(max(0, hist.length - 6)),
        value: (p) => p.moisture,
        color: Furrow.water,
        ref: th.dry,
        shadePump: true,
        label: 'Soil moisture over the last 30 minutes against the dry limit',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Columns([
          (7, field),
          (5, Column(children: [pump, const SizedBox(height: 16), readings])),
        ]),
        const SizedBox(height: 16),
        chart,
        const SizedBox(height: 40),
        const SimulatorStrip(),
      ],
    );
  }
}

class _Val extends StatelessWidget {
  final String v, unit;
  const _Val(this.v, this.unit);
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: v, style: Furrow.mono(19)),
        TextSpan(
          text: ' $unit',
          style: Furrow.mono(13, color: Furrow.muted),
        ),
      ],
    ),
  );
}

/// Gridded track with the reading filled in water blue, the needle, and marks
/// for wilting point, dry limit (tangerine), pump stop and field capacity.
class MoistureScale extends StatelessWidget {
  final double soil;
  final Thresholds th;
  const MoistureScale({super.key, required this.soil, required this.th});

  @override
  Widget build(BuildContext context) {
    final scaleMax = ((th.fc + 8) / 5).ceil() * 5.0;
    double pos(double v) => (v / scaleMax).clamp(0, 1).toDouble();
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          Widget mark(double v, {bool dry = false}) => Positioned(
            left: pos(v) * w - (dry ? 1 : .5),
            top: dry ? 10 : 14,
            child: Container(width: dry ? 2 : 1, height: dry ? 30 : 22, color: dry ? Furrow.accent : Furrow.ink),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 18,
                height: 14,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Furrow.ink),
                    borderRadius: BorderRadius.circular(3),
                    color: Furrow.paper2,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        widthFactor: pos(soil),
                        heightFactor: 1,
                        alignment: Alignment.centerLeft,
                        child: Container(color: Furrow.water),
                      ),
                    ],
                  ),
                ),
              ),
              mark(th.wp),
              mark(th.stop),
              mark(th.fc),
              mark(th.dry, dry: true),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: pos(soil) * w - 1.5,
                top: 10,
                child: Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(color: Furrow.ink, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Furrow.grid;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Legend extends StatelessWidget {
  final Thresholds th;
  final String lang;
  const _Legend({required this.th, required this.lang});
  @override
  Widget build(BuildContext context) {
    final items = [
      (tr(lang, 'wp'), th.wp, false),
      (tr(lang, 'drylimit'), th.dry, true),
      (tr(lang, 'stops'), th.stop, false),
      (tr(lang, 'fc'), th.fc, false),
    ];
    Widget cell((String, double, bool) e) => Container(
      padding: const EdgeInsets.only(top: 8, right: 8),
      decoration: BoxDecoration(
        border: e.$3 ? const Border(top: BorderSide(color: Furrow.accent, width: 2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.$1,
            style: Furrow.body(12, color: e.$3 ? Furrow.ink : Furrow.muted, weight: FontWeight.w500),
          ),
          Text('${fmtNum(e.$2)} %', style: Furrow.mono(15)),
        ],
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Furrow.ink)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth < 420 ? 2 : 4;
          return Wrap(
            children: [for (final e in items) SizedBox(width: c.maxWidth / cols, child: cell(e))],
          );
        },
      ),
    );
  }
}

/// Fake faults and speed for the simulated ESP32 (Table 6.4 scenarios).
class SimulatorStrip extends StatelessWidget {
  const SimulatorStrip({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context);
    Widget b(String label, String k) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        textStyle: Furrow.body(13.5, weight: FontWeight.w500),
      ),
      onPressed: () => f.simulateFault(k),
      child: Text(label),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Furrow.gridStrong),
        borderRadius: BorderRadius.circular(Furrow.radiusCard),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Simulator', style: Furrow.display(16).copyWith(letterSpacing: -0.16)),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: f.simEnabled,
                onChanged: (v) => f.setSimEnabled(v ?? false),
                activeColor: Furrow.accent,
                checkColor: Furrow.ink,
              ),
              Text('Run a simulated ESP32 on this device', style: Furrow.body(13.5)),
            ],
          ),
          b('Stuck sensor', 'stuck'),
          b('Out of range', 'range'),
          b('ESP32 offline', 'off'),
          b('Dry the soil', 'dry'),
          b('Clear faults', 'clear'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Speed ', style: Furrow.body(13.5, color: Furrow.muted)),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Furrow.paper2,
                  backgroundColor: Furrow.paper3,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Furrow.radiusPill)),
                ),
                segments: const [
                  ButtonSegment(value: 1, label: Text('1x')),
                  ButtonSegment(value: 5, label: Text('5x')),
                  ButtonSegment(value: 20, label: Text('20x')),
                ],
                selected: {f.speed},
                onSelectionChanged: (s) => f.setSpeed(s.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
