import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/rules.dart';
import '../i18n.dart';
import '../leaf/classifier.dart';
import '../leaf/diseases.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LeafCheckScreen extends StatefulWidget {
  const LeafCheckScreen({super.key});
  @override
  State<LeafCheckScreen> createState() => _LeafCheckScreenState();
}

class _LeafCheckScreenState extends State<LeafCheckScreen> {
  String crop = 'Tomato';
  Uint8List? photo;
  bool busy = false;
  String modelStatus = 'Model loads on first use';
  ChipKind modelKind = ChipKind.plain;
  String? acc;
  List<LeafResult>? result;
  String? error;
  int? when;

  @override
  void initState() {
    super.initState();
    LeafClassifier.instance.loadMetrics().then((m) {
      if (m != null && mounted) setState(() => acc = '${((m['test_accuracy'] as num) * 100).toStringAsFixed(1)} %');
    });
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 92);
      if (x == null) return;
      final b = await x.readAsBytes();
      setState(() {
        photo = b;
        result = null;
        error = null;
      });
      _warmUp();
    } catch (e) {
      setState(() => error = 'Could not open the ${src == ImageSource.camera ? 'camera' : 'gallery'}: $e');
    }
  }

  Future<void> _warmUp() async {
    if (LeafClassifier.instance.ready) return;
    setState(() => modelStatus = 'Loading model');
    try {
      await LeafClassifier.instance.load();
      if (mounted) {
        setState(() {
          modelStatus = 'Model ready';
          modelKind = ChipKind.ok;
        });
      }
    } catch (_) {}
  }

  Future<void> _analyze() async {
    final f = FarmScope.of(context);
    setState(() => busy = true);
    try {
      final res = await LeafClassifier.instance.classify(photo!, crop);
      final top = res.first, ok = LeafClassifier.accepted(top);
      when = DateTime.now().millisecondsSinceEpoch;
      f.recordScan(LeafScan(crop: top.crop, disease: top.name, label: top.label, confidence: top.p, accepted: ok, time: when!));
      setState(() {
        result = res;
        error = null;
        modelStatus = 'Model ready';
        modelKind = ChipKind.ok;
      });
    } catch (e) {
      setState(() {
        error = 'The model could not load ($e). Check your connection and try again.';
        modelStatus = 'Model not loaded';
        modelKind = ChipKind.bad;
      });
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context), L = f.lang;
    final input = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: crop,
            decoration: InputDecoration(labelText: tr(L, 'crop')),
            items: [for (final c in leafCrops) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() {
              crop = v ?? crop;
              result = null;
            }),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(Furrow.radiusCard),
            onTap: () => _pick(ImageSource.gallery),
            child: Container(
              constraints: const BoxConstraints(minHeight: 220),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Furrow.paper,
                border: Border.all(color: Furrow.muted),
                borderRadius: BorderRadius.circular(Furrow.radiusCard),
              ),
              child: photo == null
                  ? Text(
                      'Take or choose a leaf photo',
                      style: Furrow.body(15, color: Furrow.muted),
                      textAlign: TextAlign.center,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(Furrow.radiusCard),
                      child: Image.memory(photo!, height: 260, fit: BoxFit.contain, semanticLabel: 'Leaf photo to check'),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!kIsWeb || defaultTargetPlatform == TargetPlatform.android)
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(tr(L, 'camera')),
                ),
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(tr(L, 'gallery')),
              ),
              FilledButton(onPressed: photo == null || busy ? null : _analyze, child: Text(busy ? 'Checking' : tr(L, 'analyze'))),
            ],
          ),
          Note(
            'MobileNetV2 trained on PlantVillage (23 classes: tomato, potato, maize, grape, bell pepper), runs on this device. '
            'Test accuracy ${acc ?? '--'} on held-out PlantVillage images; field photos are not tested yet. Results below 0.70 confidence are rejected.',
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHead(tr(L, 'leaf'), trailing: StatusChip(modelStatus, kind: modelKind)),
        Columns([(6, input), (6, _result(context))]),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final grid = BoxDecoration(color: Furrow.paper2, image: null);
    Widget notebook(List<Widget> c) => CustomPaint(
      painter: const _NotebookGrid(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        padding: const EdgeInsets.all(20),
        decoration: grid.copyWith(color: Colors.transparent),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: c),
      ),
    );
    if (error != null) {
      return EntryCard(
        head: const Text('Could not check'),
        headTrailing: const Text('--'),
        children: [
          notebook([Text(error!, style: Furrow.body(15))]),
        ],
      );
    }
    final res = result;
    if (res == null) {
      return EntryCard(
        head: const Text('Result'),
        headTrailing: const Text('--'),
        children: [
          notebook([Text('Take or choose a photo and press Analyze.', style: Furrow.body(15, color: Furrow.muted))]),
        ],
      );
    }
    final top = res.first, ok = LeafClassifier.accepted(top), healthy = top.name == 'Healthy';
    return EntryCard(
      head: Text(ok ? top.name : 'Not sure'),
      headTrailing: Text(fmtTime(when)),
      children: [
        notebook([
          if (ok) ...[
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(top.crop, kind: healthy ? ChipKind.ok : ChipKind.warn),
                Text('${(top.p * 100).toStringAsFixed(1)} %', style: Furrow.mono(15)),
                Text('confidence', style: Furrow.body(15)),
              ],
            ),
            const SizedBox(height: 12),
            if (top.advice.isNotEmpty) ...[
              Text(top.advice, style: Furrow.body(15)),
              const SizedBox(height: 12),
              Text(
                'Before any spray, ask your KVK or the Kisan Call Centre ($kccNumber) which product and dose to use.',
                style: Furrow.body(13.5, color: Furrow.muted),
              ),
            ] else
              Text(healthy ? 'No disease found on this leaf.' : 'No care notes for this class yet. Ask your KVK.', style: Furrow.body(15)),
          ] else
            Text(
              'Confidence is below 0.70, so no result is given. Retake the photo: one leaf, filling the frame, in daylight, on a plain background.',
              style: Furrow.body(15),
            ),
          const SizedBox(height: 16),
          for (final r in res.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: Furrow.body(13.5, color: Furrow.muted)),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: r.p,
                            minHeight: 8,
                            color: Furrow.water,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text('${(r.p * 100).toStringAsFixed(0)} %', textAlign: TextAlign.right, style: Furrow.mono(13.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (ok && !healthy) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.findAncestorStateOfType<ShellState>()?.go(4),
              child: Text(tr(FarmScope.of(context).lang, 'ask')),
            ),
          ],
        ]),
      ],
    );
  }
}

class _NotebookGrid extends CustomPainter {
  const _NotebookGrid();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Furrow.paper2);
    final p = Paint()..color = Furrow.grid;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
