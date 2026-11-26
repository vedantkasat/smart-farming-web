"""Convert the web model in model/ (TF.js layers model, float16 weights as
base64 in weights.json) into model/leaf.tflite for the Flutter Android app.

Same network: Rescaling(1/127.5, -1) -> MobileNetV2 (no top, avg pool) ->
Dense(23, softmax). Input is 224x224x3 RGB in 0..255, output 23 probabilities
in the order of model/labels.json.

    python training/tfjs_to_tflite.py model/ model/leaf.tflite
"""
import base64, json, os, sys
import numpy as np
import tensorflow as tf

src, out = sys.argv[1], sys.argv[2]
mj = json.load(open(os.path.join(src, 'model.json')))
wj = json.load(open(os.path.join(src, 'weights.json')))
raw = base64.b64decode(wj['b64'])

# Decode weights in manifest order. Each weight is stored as float16.
specs = [w for g in mj['weightsManifest'] for w in g['weights']]
weights, off = {}, 0
for s in specs:
    n = int(np.prod(s['shape'])) if s['shape'] else 1
    q = (s.get('quantization') or {}).get('dtype', 'float32')
    dt = {'float16': np.float16, 'float32': np.float32}[q]
    size = n * np.dtype(dt).itemsize
    weights[s['name']] = np.frombuffer(raw, dt, n, off).astype(np.float32).reshape(s['shape'])
    off += size
assert off == len(raw), (off, len(raw))

inp = tf.keras.Input((224, 224, 3), name='image')
x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(inp)
base = tf.keras.applications.MobileNetV2(input_shape=(224, 224, 3), include_top=False, weights=None, pooling='avg')
x = base(x)
o = tf.keras.layers.Dense(len(json.load(open(os.path.join(src, 'labels.json')))), activation='softmax', name='dense')(x)
model = tf.keras.Model(inp, o)

used = 0
for layer in [*base.layers, model.get_layer('dense')]:
    if not layer.weights:
        continue
    vals = []
    for v in layer.weights:
        name = v.name.split('/')[-1].split(':')[0]
        if isinstance(layer, tf.keras.layers.DepthwiseConv2D) and name == 'kernel':
            name = 'depthwise_kernel'  # Keras 3 name vs the TF.js export
        vals.append(weights[f'{layer.name}/{name}'])
        used += 1
    layer.set_weights(vals)
assert used == len(weights), (used, len(weights))

conv = tf.lite.TFLiteConverter.from_keras_model(model)
conv.optimizations = [tf.lite.Optimize.DEFAULT]
conv.target_spec.supported_types = [tf.float16]
open(out, 'wb').write(conv.convert())

# Check the TFLite model against the Keras model on random images.
it = tf.lite.Interpreter(model_path=out)
it.allocate_tensors()
z = (np.random.default_rng(42).random((4, 224, 224, 3)) * 255).astype('float32')
k = model.predict(z, verbose=0)
diff = 0.0
for i in range(len(z)):
    it.set_tensor(it.get_input_details()[0]['index'], z[i:i + 1])
    it.invoke()
    diff = max(diff, float(np.abs(it.get_tensor(it.get_output_details()[0]['index']) - k[i]).max()))
print(f'wrote {out}, {os.path.getsize(out) / 1e6:.2f} MB, max prob diff vs Keras {diff:.5f}')
