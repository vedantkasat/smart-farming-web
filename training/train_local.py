"""Train the leaf disease model on your own computer and export it for both apps.

Same recipe as the model in model/ (see training/README.md):
  MobileNetV2 (ImageNet, frozen) + softmax head, 224x224, PlantVillage colour,
  up to 320 images per class, 70/15/15 split, seed 42.
Optional: --finetune-epochs N unfreezes the top of MobileNetV2 for N more epochs.
Optional: --field DIR tests the trained model on your own leaf photos.

    python training/train_local.py --data ~/datasets/plantvillage/color

Writes to --out (default: training/out/) and, with --install, into model/:
  labels.json, metrics.json        class list and measured results
  model.json + weights.json        web app (TF.js, float16 weights as base64)
  leaf.tflite                      Flutter Android app
  leaf_model.keras                 full Keras model, for later work
"""
import argparse, base64, glob, json, os, random, shutil, sys, time

ap = argparse.ArgumentParser()
ap.add_argument('--data', required=True, help='PlantVillage "color" folder, one sub-folder per class')
ap.add_argument('--out', default=os.path.join(os.path.dirname(__file__), 'out'))
ap.add_argument('--per-class', type=int, default=320, help='max images per class (0 = all)')
ap.add_argument('--all-classes', action='store_true', help='use every class folder, not only the 23 in model/labels.json')
ap.add_argument('--head-epochs', type=int, default=40)
ap.add_argument('--finetune-epochs', type=int, default=0, help='unfreeze the top of MobileNetV2 for this many epochs (GPU recommended)')
ap.add_argument('--finetune-from', default='block_13_expand', help='first MobileNetV2 layer to unfreeze')
ap.add_argument('--batch', type=int, default=32)
ap.add_argument('--field', help='folder of your own leaf photos, same sub-folder names, to test on after training')
ap.add_argument('--install', action='store_true', help='copy the results into model/ (replaces the current model)')
ap.add_argument('--seed', type=int, default=42)
args = ap.parse_args()

import numpy as np
import tensorflow as tf

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MODEL_DIR = os.path.join(REPO, 'model')
IMG = (224, 224)
random.seed(args.seed); np.random.seed(args.seed); tf.random.set_seed(args.seed)
os.makedirs(args.out, exist_ok=True)
t0 = time.time()

# ---------- data ----------
if not os.path.isdir(args.data):
    sys.exit(f'No folder at {args.data}. Point --data at PlantVillage "color" (one folder per class).')
found = sorted(d for d in os.listdir(args.data) if os.path.isdir(os.path.join(args.data, d)))
if args.all_classes:
    classes = found
else:
    wanted = json.load(open(os.path.join(MODEL_DIR, 'labels.json')))
    missing = [c for c in wanted if c not in found]
    if missing:
        sys.exit('These class folders are missing from --data:\n  ' + '\n  '.join(missing) +
                 '\nUse the PlantVillage "color" folder, or pass --all-classes.')
    classes = wanted
print(f'{len(classes)} classes')

EXT = ('.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG')
files, labels = [], []
for i, c in enumerate(classes):
    fs = sorted(f for f in glob.glob(os.path.join(args.data, c, '*')) if f.endswith(EXT))
    if args.per_class and len(fs) > args.per_class:
        fs = sorted(random.Random(args.seed + i).sample(fs, args.per_class))
    files += fs; labels += [i] * len(fs)
    print(f'  {len(fs):5d}  {c}')
idx = np.random.permutation(len(files))
files = [files[i] for i in idx]; labels = np.array(labels)[idx]
n = len(files); ntr = int(.70 * n); nva = int(.15 * n)
split = dict(train=(files[:ntr], labels[:ntr]), val=(files[ntr:ntr + nva], labels[ntr:ntr + nva]),
             test=(files[ntr + nva:], labels[ntr + nva:]))
print(f'{n} images: train {ntr}, val {nva}, test {n - ntr - nva}')


def load(p):
    img = tf.io.decode_image(tf.io.read_file(p), channels=3, expand_animations=False)
    return tf.image.resize(img, IMG)


def dataset(fs, ys=None, aug=False, shuffle=False):
    ds = tf.data.Dataset.from_tensor_slices(fs).map(load, num_parallel_calls=tf.data.AUTOTUNE)
    if aug:
        ds = ds.map(lambda x: tf.image.random_flip_left_right(tf.image.random_brightness(x, 25)),
                    num_parallel_calls=tf.data.AUTOTUNE)
    if ys is not None:
        ds = tf.data.Dataset.zip((ds, tf.data.Dataset.from_tensor_slices(ys)))
    if shuffle:
        ds = ds.shuffle(1024, seed=args.seed)
    return ds.batch(args.batch).prefetch(tf.data.AUTOTUNE)


# ---------- model: Rescaling -> MobileNetV2 -> Dense ----------
inp = tf.keras.Input((*IMG, 3), name='image')
x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(inp)
base = tf.keras.applications.MobileNetV2(input_shape=(*IMG, 3), include_top=False, weights='imagenet', pooling='avg')
base.trainable = False
x = base(x, training=False)
x = tf.keras.layers.Dropout(.3)(x)
out = tf.keras.layers.Dense(len(classes), activation='softmax', name='dense')(x)
model = tf.keras.Model(inp, out)

# Stage 1: frozen base. Features are cached so the head trains in seconds.
cache = os.path.join(args.out, f'feats_{len(classes)}_{n}_{args.seed}.npz')
feat = tf.keras.Model(inp, base(tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(inp), training=False))
if os.path.exists(cache):
    z = np.load(cache); F = {k: z[k] for k in split}
    print('features loaded from cache')
else:
    print('extracting MobileNetV2 features (the slow part on a CPU)...')
    F = {k: feat.predict(dataset(split[k][0]), verbose=1) for k in split}
    np.savez(cache, **F)
head = tf.keras.Sequential([tf.keras.Input((1280,)), tf.keras.layers.Dropout(.3),
                            tf.keras.layers.Dense(len(classes), activation='softmax')])
head.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss='sparse_categorical_crossentropy', metrics=['accuracy'])
head.fit(F['train'], split['train'][1], validation_data=(F['val'], split['val'][1]), epochs=args.head_epochs,
         batch_size=64, verbose=2,
         callbacks=[tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True)])
model.get_layer('dense').set_weights(head.layers[-1].get_weights())

# Stage 2 (optional): fine-tune the top of MobileNetV2 end to end.
if args.finetune_epochs:
    base.trainable = True
    on = False
    for l in base.layers:
        on = on or l.name == args.finetune_from
        l.trainable = on and not isinstance(l, tf.keras.layers.BatchNormalization)
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    model.fit(dataset(*split['train'], aug=True, shuffle=True), validation_data=dataset(*split['val']),
              epochs=args.finetune_epochs, verbose=1,
              callbacks=[tf.keras.callbacks.EarlyStopping(patience=3, restore_best_weights=True)])


# ---------- evaluate on held-out test images ----------
def evaluate(fs, ys, names):
    pred = model.predict(dataset(fs), verbose=0).argmax(1)
    conf = np.zeros((len(names), len(names)), int)
    for a, b in zip(ys, pred):
        conf[a, b] += 1
    rec = {names[i]: float(conf[i, i] / conf[i].sum()) for i in range(len(names)) if conf[i].sum()}
    return float((pred == ys).mean()), rec, conf


acc, per, conf = evaluate(*split['test'], classes)
print(f'TEST ACCURACY {acc * 100:.1f}% on {len(split["test"][0])} images')
tom = [i for i, c in enumerate(classes) if c.startswith('Tomato')]
mask = np.isin(split['test'][1], tom)
tom_acc = float((conf[np.ix_(tom, tom)].trace()) / conf[tom].sum()) if tom else None

metrics = {
    'test_accuracy': acc, 'n_images': n, 'split': [ntr, nva, n - ntr - nva],
    'per_class_recall': per, 'confusion': conf.tolist(),
    'tomato_test_accuracy': tom_acc, 'tomato_test_images': int(mask.sum()),
    'dataset': f'PlantVillage (color), up to {args.per_class or "all"} images per class, {len(classes)} classes',
    'split_ratio': '70/15/15', 'seed': args.seed,
    'base': 'MobileNetV2 ImageNet, frozen; softmax head' +
            (f'; fine-tuned from {args.finetune_from} for up to {args.finetune_epochs} epochs' if args.finetune_epochs else ''),
    'weights': 'float16', 'trained_on': time.strftime('%Y-%m-%d'),
}

# ---------- field test on your own photos ----------
if args.field:
    ff, fy = [], []
    for i, c in enumerate(classes):
        for f in sorted(glob.glob(os.path.join(args.field, c, '*'))):
            if f.endswith(EXT):
                ff.append(f); fy.append(i)
    if ff:
        facc, fper, _ = evaluate(ff, np.array(fy), classes)
        probs = model.predict(dataset(ff), verbose=0)
        rejected = float((probs.max(1) < .70).mean())
        metrics['field_test'] = {'accuracy': facc, 'images': len(ff), 'per_class_recall': fper,
                                 'rejected_below_0_70': rejected}
        print(f'FIELD TEST {facc * 100:.1f}% on {len(ff)} of your photos, {rejected * 100:.0f}% rejected below 0.70')
    else:
        print(f'No photos found in {args.field} (need sub-folders named like the classes)')

# ---------- export ----------
model.save(os.path.join(args.out, 'leaf_model.keras'))
json.dump(classes, open(os.path.join(args.out, 'labels.json'), 'w'))
json.dump(metrics, open(os.path.join(args.out, 'metrics.json'), 'w'), indent=1)

# TF.js: reuse model/model.json's topology and write new float16 weights in its manifest order.
mj = json.load(open(os.path.join(MODEL_DIR, 'model.json')))
specs = [w for g in mj['weightsManifest'] for w in g['weights']]
ours = {}
for layer in [*base.layers, model.get_layer('dense')]:
    for v in layer.weights:
        name = v.name.split('/')[-1].split(':')[0]
        if isinstance(layer, tf.keras.layers.DepthwiseConv2D) and name == 'kernel':
            name = 'depthwise_kernel'
        ours[f'{layer.name}/{name}'] = np.asarray(v.numpy(), np.float32)
for s in specs:
    if s['name'].startswith('dense/'):
        s['shape'] = list(ours[s['name']].shape)
for l in mj['modelTopology']['model_config']['config']['layers']:
    if l['config']['name'] == 'dense':
        l['config']['units'] = len(classes)
blob = b''.join(ours[s['name']].astype(np.float16).tobytes() for s in specs)
json.dump(mj, open(os.path.join(args.out, 'model.json'), 'w'))
json.dump({'format': 'float16', 'bytes': len(blob), 'b64': base64.b64encode(blob).decode()},
          open(os.path.join(args.out, 'weights.json'), 'w'))

# TFLite for the Flutter Android app.
conv = tf.lite.TFLiteConverter.from_keras_model(model)
conv.optimizations = [tf.lite.Optimize.DEFAULT]
conv.target_spec.supported_types = [tf.float16]
open(os.path.join(args.out, 'leaf.tflite'), 'wb').write(conv.convert())

print(f'Exported to {args.out} in {(time.time() - t0) / 60:.1f} min')
if args.install:
    for f in ['labels.json', 'metrics.json', 'model.json', 'weights.json', 'leaf.tflite']:
        shutil.copy(os.path.join(args.out, f), os.path.join(MODEL_DIR, f))
    print('Copied into model/. Both apps now load the new model. Update the README and report numbers from metrics.json.')
else:
    print('Not installed. Re-run with --install, or copy the files into model/ yourself.')
