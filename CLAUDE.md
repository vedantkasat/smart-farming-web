# Smart Farming capstone: context for Claude Code

Final-year E&TC capstone, Group B-18, AISSMS IOIT Pune (SPPU), 2026–27.
Title: **AI-Enabled Crop Monitoring and Irrigation System**.
Team: Vedant Kasat, Aditi Singh, Gauri Meher. Guide: Mrs. R. S. Pawar. Coordinator: Rohit Deshmukh.

The Stage-I report is the source of truth. When code and report disagree, follow the report or flag it.

## What is in this repo

- `index.html`: the whole web app (HTML, CSS, JS in one file). No build step. Live on GitHub Pages at https://vedantkasat.github.io/smart-farming-web/. The Flutter web build is served at `/app/`. `.github/workflows/pages.yml` deploys both on every push to `main` (Pages source: GitHub Actions).
- `model/`: leaf disease model for TensorFlow.js. `model.json` is the topology. `weights.json` holds base64 of the float16 weights, because the claude.ai artifact host can't serve `.bin`. `labels.json` lists 23 classes; `metrics.json` has the measured results.
- `flutter_app/`: the Flutter app (Android + web), a full port of `index.html`. `assets/model` links to `model/`. Firebase sync and the simulator are in `lib/data/farm.dart`.
- `model/leaf.tflite`: the same model for Android (made by `training/tfjs_to_tflite.py`).
- `training/`: scripts that trained and converted the model (MobileNetV2 frozen + softmax head, PlantVillage colour, ≤320 images per class, 70/15/15 split, seed 42). `train_local.py` retrains on a laptop and exports for both apps (see `training/README.md`).
- `firebase/database.rules.json`: Realtime Database rules (already published).
- The design follows the "Hallmark" Furrow theme (warm paper, ink rules, one tangerine accent, Red Hat fonts). Keep that look.

## Firebase

Project `smart-farming-app-49954`, Realtime Database in `asia-southeast1`, anonymous sign-in enabled. The web API key is public by design and restricted to 6 Firebase APIs. `vedantkasat.github.io` is an authorised domain.

Data contract (report Table 7.1). Change it here first, then in the app and the firmware:

| Path | Writer | Fields |
|---|---|---|
| `sensors/latest` | ESP32 | moisture, temperature, humidity, timestamp |
| `sensors/history/{0..399}` | ESP32 | + pump, seq (ring buffer, one point per 5 min) |
| `pump/command` | App | command: ON / OFF / AUTO, requestedAt (ESP32 deletes it after applying) |
| `pump/status` | ESP32 | state ON/OFF, mode AUTO/MANUAL, startTime, runMin |
| `pump/runs/{0..19}` | ESP32 | run log |
| `config` | App | crop, stage, soil, fc, wp, p, dryLimit, maxRunMin, loc |
| `alerts/{key}` | ESP32, App | type, title, message, time, ack |
| `disease/{push}` | App | class, crop, name, confidence, accepted, time |
| `device` | ESP32 | heartbeat, firmware, rssi, source ("esp32" or "simulator"), fault |

Until the hardware exists, one open copy of the app acts as a **simulated ESP32** and writes those paths. It steps aside when `device.source == "esp32"`.

## Rules the system follows (from the report)

- Dry limit = FC − p × (FC − WP). Pump starts at the dry limit and stops at field capacity. Sensitive growth stage: p × 0.75.
- Soils (FC/WP %): sandy 12/5, loam 25/12, clay or black cotton 36/22. Crops (p): tomato 0.40, onion 0.30, maize 0.55.
- Faults (Table 6.4): no valid reading for 3 cycles; reading outside 0–100% is rejected; moisture changes < 0.5% for 30 min while the pump is ON. A fault switches the pump off and blocks Auto. Maximum run 30 min.
- Manual ON/OFF takes priority over Auto; "Return to Auto" ends manual mode. Every pump command needs a confirm step.
- Design decisions: no rain sensor, no water tank or water-quantity measurement. No plot area and no plot map in the apps (dropped Nov 2026; area was records-only). Field location is kept. **Report Table 7.1 still lists `area`: update the report.** Keep the hardware asset-light.
- Farmers get alerts on WhatsApp/SMS (from the ESP32's 4G module). The app supports English, Hindi and Marathi.
- Disease results below 0.70 confidence are rejected. The "Ask an expert" chat answers only from the app's own data and **never gives pesticide products or doses**; it points to the Kisan Call Centre (1800-180-1551) or the local KVK.

## Measured results (do not invent numbers)

- Classical models on 2,728 PlantVillage tomato test images: SVM 97.58%, Random Forest 96.04%, KNN 94.9%, Decision Tree 84.8%, Naive Bayes 68.1%.
- MobileNetV2 in the team's Colab run (5 frozen + 5 fine-tune epochs, same 2,728 images): 87.3% (macro F1 0.84), int8 TFLite 84.4%, 2.74 MB, 11.9 ms per image.
- Web model in `model/` (23 classes, 1,080 test images): 91.5%. Tomato-only on 492 test images: 86.4%. DenseNet121 on the same split: 91.7% tomato, 94.5% all classes, 7.4 MB.
- Never fill a results table with made-up numbers. Unmeasured entries say "Not measured" or "Stage II".

## Open work

1. Flutter app built in `flutter_app/` (Android + web). Android app is registered in Firebase (App ID in `lib/firebase_options.dart`). CI publishes the APK as the `apk-latest` pre-release. Both apps are live (web root and `/app/`); keep them in step until the team retires `index.html`.
2. ESP32 firmware (when hardware is finalised): follow the data contract, set `device.source = "esp32"`, use NTP time, enforce max run in manual mode too.
3. Replace anonymous sign-in with email login for the team before a real pump is connected.
4. Field-test the disease model on the team's own leaf photos (the guide requires it). Fine-tune MobileNetV2 for longer on a Colab GPU to approach the published ~98%.
5. Disease detection must cover more crops than tomato; the web model already has tomato, potato, maize, grape and bell pepper.

## Working style

- Vedant prefers things built right away; changes come later.
- Keep commits small and describe them plainly. Don't commit service-account keys or other secrets.
