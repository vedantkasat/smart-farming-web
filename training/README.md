# Training the leaf disease model on your own computer

`train_local.py` retrains the model in `model/` and exports it for both apps:
the web app (`model.json` + `weights.json`) and the Flutter Android app (`leaf.tflite`).

The recipe is the one in the report and `model/metrics.json`: MobileNetV2 (ImageNet, frozen)
with a softmax head, 224 × 224, PlantVillage colour images, up to 320 per class, 23 classes,
70/15/15 split, seed 42.

## 1. Get the data (one time)

The images are not in this repo (about 1 GB). Download **PlantVillage**, the colour version:

- Kaggle: search "PlantVillage dataset" (`abdallahalidev/plantvillage-dataset`), unzip, and use the `color` folder.
- or GitHub: `spMohanty/PlantVillage-Dataset`, folder `raw/color`.

You need one folder per class, named like `Tomato___Early_blight`. The 23 names the app uses are in
`model/labels.json`, and the script stops and lists any that are missing.

## 2. Set up Python (one time)

Python 3.10 to 3.13. From the repo folder:

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r training/requirements.txt
```

## 3. Train

```bash
python training/train_local.py --data path/to/plantvillage/color
```

On a laptop CPU this takes about 15–30 minutes. Most of that is the one-time feature extraction,
which is cached in `training/out/`, so later runs are fast. Results go to `training/out/`.
When the accuracy looks right, copy them into `model/`:

```bash
python training/train_local.py --data path/to/plantvillage/color --install
```

### Options

| Option | What it does |
|---|---|
| `--finetune-epochs 5` | Also fine-tunes the top of MobileNetV2 (open work item 4). Slow on a CPU; use an NVIDIA GPU, WSL2 on Windows, or Colab. |
| `--field my_photos/` | Tests the trained model on your own leaf photos (the guide requires this). Use the same sub-folder names as the classes, e.g. `my_photos/Tomato___Early_blight/IMG_001.jpg`. The result goes into `metrics.json` as `field_test`. |
| `--per-class 0` | Uses every image instead of 320 per class. |
| `--all-classes` | Trains on every class folder in `--data`, not only the 23 in `labels.json`. The Flutter and web apps need disease names for any new class (`DIS` in `index.html`, `flutter_app/lib/leaf/diseases.dart`). |
| `--install` | Copies the results into `model/`. |

TensorFlow has no GPU support on native Windows; it runs on the CPU there, which is fine for the frozen recipe.

## 4. After training

- Report numbers come from `training/out/metrics.json` (`test_accuracy`, `per_class_recall`, `tomato_test_accuracy`, `field_test`). Don't round them up or copy them from elsewhere.
- Commit `model/` with a plain message. Don't commit `training/out/`; it is ignored.

## Other scripts

- `train.py`, `to_h5.py`, `h5_to_tfjs.py`: the original run that produced the current model (paths are from that machine).
- `tfjs_to_tflite.py`: makes `model/leaf.tflite` from the current web model without retraining.
