import 'dart:js_interop';
import 'dart:typed_data';

@JS('leafModel.load')
external JSPromise<JSAny?> _load(JSString base);

@JS('leafModel.predict')
external JSPromise<JSFloat32Array> _predict(JSUint8Array bytes);

/// Model files are served from assets/assets/model/ in the web build.
Future<void> load() async {
  await _load('assets/assets/model/'.toJS).toDart;
}

Future<List<double>> predict(Uint8List bytes) async {
  final r = await _predict(bytes.toJS).toDart;
  return r.toDart.map((e) => e.toDouble()).toList();
}
