import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

Interpreter? _it;

Future<void> load() async {
  _it ??= await Interpreter.fromAsset('assets/model/leaf.tflite', options: InterpreterOptions()..threads = 4);
}

/// 224x224 RGB in 0..255 (the model rescales to -1..1 itself), bilinear resize like the web app.
Future<List<double>> predict(Uint8List bytes) async {
  await load();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Could not read this photo');
  final im = img.resize(img.bakeOrientation(decoded), width: 224, height: 224, interpolation: img.Interpolation.linear);
  final input = Float32List(224 * 224 * 3);
  var k = 0;
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final p = im.getPixel(x, y);
      input[k++] = p.r.toDouble();
      input[k++] = p.g.toDouble();
      input[k++] = p.b.toDouble();
    }
  }
  final n = _it!.getOutputTensor(0).shape.last;
  final out = [List<double>.filled(n, 0)];
  _it!.run(input.reshape([1, 224, 224, 3]), out);
  return out[0];
}
