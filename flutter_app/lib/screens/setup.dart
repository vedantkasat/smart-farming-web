import 'package:material_ui/material_ui.dart';

import '../data/rules.dart';
import '../i18n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _loc = TextEditingController(), _maxRun = TextEditingController();
  final _locF = FocusNode(), _maxF = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = FarmScope.of(context).cfg;
    // Keep text fields in step with config from Firebase unless the user is typing.
    if (!_locF.hasFocus) _loc.text = c.loc;
    if (!_maxF.hasFocus) _maxRun.text = '${c.maxRunMin}';
  }

  @override
  void dispose() {
    for (final x in [_loc, _maxRun]) {
      x.dispose();
    }
    for (final x in [_locF, _maxF]) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context), c = f.cfg, th = f.t, st = c.stageInfo;
    Widget gap() => const SizedBox(height: 12);
    final form = Panel(
      title: 'This plot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('crop-${c.crop}'),
            initialValue: c.crop,
            decoration: InputDecoration(labelText: tr(f.lang, 'crop')),
            items: [for (final e in crops.entries) DropdownMenuItem(value: e.key, child: Text(e.value.name))],
            onChanged: (v) => f.saveConfig((c) => c.crop = v!),
          ),
          gap(),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('stage-${c.crop}-${c.stage}'),
            initialValue: c.stage,
            decoration: const InputDecoration(labelText: 'Growth stage, set by the farmer'),
            items: [
              for (final s in c.cropInfo.stages)
                DropdownMenuItem(value: s.key, child: Text('${s.name}${s.sensitive ? ' (sensitive)' : ''}')),
            ],
            onChanged: (v) => f.saveConfig((c) => c.stage = v!),
          ),
          gap(),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('soil-${c.soil}'),
            initialValue: c.soil,
            decoration: const InputDecoration(labelText: 'Soil type'),
            items: [for (final e in soils.entries) DropdownMenuItem(value: e.key, child: Text(e.value.name))],
            onChanged: (v) => f.saveConfig((c) => c.soil = v!),
          ),
          gap(),
          TextField(
            controller: _loc,
            focusNode: _locF,
            decoration: const InputDecoration(labelText: 'Field location', hintText: 'Pune, Maharashtra'),
            onSubmitted: (v) => f.saveConfig((c) => c.loc = v.trim()),
            onTapOutside: (_) {
              if (_locF.hasFocus) {
                _locF.unfocus();
                f.saveConfig((c) => c.loc = _loc.text.trim());
              }
            },
          ),
          gap(),
          TextField(
            controller: _maxRun,
            focusNode: _maxF,
            keyboardType: TextInputType.number,
            style: Furrow.mono(15),
            decoration: const InputDecoration(labelText: 'Longest pump run in minutes'),
            onSubmitted: (v) => f.saveConfig((c) => c.maxRunMin = (int.tryParse(v) ?? defaultMaxRunMin).clamp(1, 120)),
            onTapOutside: (_) {
              if (_maxF.hasFocus) {
                _maxF.unfocus();
                f.saveConfig((c) => c.maxRunMin = (int.tryParse(_maxRun.text) ?? defaultMaxRunMin).clamp(1, 120));
              }
            },
          ),
        ],
      ),
    );

    Widget row(String k, Widget v, {bool total = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: total ? const BorderSide(color: Furrow.ink, width: 2) : BorderSide.none,
          bottom: const BorderSide(color: Furrow.rule),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: Furrow.body(14, weight: FontWeight.w500)),
          ),
          Flexible(child: v),
        ],
      ),
    );
    final mono = Furrow.mono(14);
    final calc = Panel(
      sheet: true,
      title: 'Irrigation threshold',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('Crop', Text('${c.cropInfo.name}, p ${fmtNum(c.cropInfo.p)}', style: Furrow.body(14))),
          row('Growth stage', Text('${st.name}${st.sensitive ? ', sensitive: p × 0.75' : ''}', style: Furrow.body(14))),
          row('Depletion p used', Text(fmtNum(th.p), style: mono)),
          row('Field capacity (FC)', Text('${fmtNum(th.fc)} %', style: mono)),
          row('Wilting point (WP)', Text('${fmtNum(th.wp)} %', style: mono)),
          row('Dry limit, pump starts', Text('${fmtNum(th.dry)} %', style: Furrow.mono(14, weight: FontWeight.w500)), total: true),
          row('Pump stops', Text('${fmtNum(th.stop)} % (FC)', style: Furrow.mono(14, weight: FontWeight.w500))),
          row('Maximum run', Text('${c.maxRunMin} min', style: mono)),
          const Note(
            'Dry limit = FC − p × (FC − WP), report section 6.2. The pump starts at the dry limit and stops at field capacity. '
            'In a sensitive stage p is cut by 25%. Soil values are the report\'s Table 6.2 defaults until the field soil is calibrated.',
          ),
          const Note('Saved to Firebase config, which the ESP32 reads. Paths follow the report\'s Table 7.1.'),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHead(tr(f.lang, 'setup')),
        Columns([(5, form), (7, calc)]),
      ],
    );
  }
}
