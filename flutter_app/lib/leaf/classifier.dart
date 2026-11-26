import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/rules.dart';
import 'diseases.dart';
import 'engine_stub.dart' if (dart.library.js_interop) 'engine_web.dart' if (dart.library.io) 'engine_tflite.dart' as engine;

class LeafResult {
  final String label, crop, name, advice;
  final double p; // renormalised within the chosen crop
  const LeafResult(this.label, this.crop, this.name, this.advice, this.p);
}

/// MobileNetV2 leaf model from model/. Android runs leaf.tflite with TFLite,
/// the web build runs the same network with TensorFlow.js.
class LeafClassifier {
  static final instance = LeafClassifier._();
  LeafClassifier._();

  List<String>? labels;
  Map? metrics;
  bool ready = false;

  Future<void> load() async {
    if (ready) return;
    labels ??= (jsonDecode(await rootBundle.loadString('assets/model/labels.json')) as List).cast<String>();
    await engine.load();
    ready = true;
  }

  Future<Map?> loadMetrics() async {
    try {
      return metrics ??= jsonDecode(await rootBundle.loadString('assets/model/metrics.json')) as Map;
    } catch (_) {
      return null;
    }
  }

  /// Classifies a photo, keeping only the chosen crop's classes (then renormalised).
  Future<List<LeafResult>> classify(Uint8List imageBytes, String crop) async {
    await load();
    final probs = await engine.predict(imageBytes);
    final idx = <int>[];
    for (var i = 0; i < labels!.length; i++) {
      if (describe(labels![i]).$1 == crop) idx.add(i);
    }
    final sum = idx.fold<double>(0, (a, i) => a + probs[i]);
    final out = idx.map((i) {
      final d = describe(labels![i]);
      return LeafResult(labels![i], d.$1, d.$2, d.$3, sum > 0 ? probs[i] / sum : 0);
    }).toList()..sort((a, b) => b.p.compareTo(a.p));
    return out;
  }

  static bool accepted(LeafResult r) => r.p >= minLeafConfidence;
}
