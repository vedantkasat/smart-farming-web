# Smart Farming: Flutter app

The report's app (Flutter + Firebase + on-device model), built from one codebase for **Android** and the **web**.
It is a full port of the web app in `../index.html`: same screens, same rules, same Firebase paths, same look (Hallmark "Furrow").

| Screen | What it does |
|---|---|
| Dashboard | Survey map with the sensor node, live soil moisture against wilting point, dry limit, pump stop and field capacity; temperature, humidity and sensor health; pump ON / OFF / Return to Auto, each with a confirm tap; last 30 minutes chart; simulator controls. |
| History | Moisture, temperature and humidity from `sensors/history`, pump run log from `pump/runs`. |
| Leaf check | Camera or gallery photo, then MobileNetV2 on the device (TFLite on Android, TF.js on the web). Only the chosen crop's classes are compared. Below 0.70 confidence there is no result. Writes `disease/{push}` and a `disease` alert. |
| Alerts | Mirrors `alerts/`, acknowledge one or all, clear all (with a confirm). |
| Ask an expert | Answers only from the app's own data, never products or doses; Kisan Call Centre and WhatsApp share. |
| Field setup | Crop, stage, soil, location, area, maximum run, written to `config`; shows the dry-limit working. |

English, Hindi and Marathi labels (`lib/i18n.dart`).

## Run it

Install Flutter 3.50 (stable), then from this folder:

```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # a connected Android phone (USB debugging on)
flutter test                   # rules, simulator, expert and app-shell tests
```

Build an APK to share with the team: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
GitHub Actions (`.github/workflows/flutter.yml`) also builds the APK and the web app on every push that touches the app or the model; download them from the run's **Artifacts**.
The release build is signed with the debug key, which is fine for the team's phones but not for the Play Store.

## Firebase

`lib/firebase_options.dart` holds the web config for project `smart-farming-app-49954` (the same as the web app).

**Android needs one step in the Firebase console:** add an Android app with package `com.aissmsioit.b18.smartfarming`,
then copy its App ID (it contains `:android:`) into `FirebaseConfig.androidAppId`. Running `flutterfire configure` does the same.
Until then the Android app runs the **offline demo** (the simulator on the phone, nothing synced), and the chip in the top bar says so.

Data contract: see `CLAUDE.md` / report Table 7.1. All reads and writes are in `lib/data/farm.dart`.

## How the parts fit

```
lib/
  main.dart              app shell: rail on wide screens, bottom bar on phones, language menu, connection chip
  theme.dart             Furrow colours and Red Hat fonts (bundled in assets/fonts, no download needed)
  data/rules.dart        Tables 6.2 and 6.3, dry limit (6.2), config document
  data/farm.dart         simulated ESP32 (6.2 to 6.4), Firebase sync, who simulates (one copy at a time)
  data/expert.dart       Ask an expert
  leaf/                  classifier: engine_tflite.dart (Android), engine_web.dart + web/leaf_model.js (web)
  screens/, widgets/     the six screens, chart, survey map, confirm button
```

The simulator follows the web app exactly: one open copy (web or phone) becomes the simulated ESP32 and writes the ESP32's paths;
it steps aside when `device/source` is `"esp32"` or another copy holds a fresh heartbeat.

## The leaf model

`assets/model` is a link to the repo's `model/` folder, so the web app and the Flutter app always use the same files:
`leaf.tflite` for Android, `model.json` + `weights.json` for the web, `labels.json`, `metrics.json`.
To retrain on your own computer, see `../training/README.md`; `--install` updates `model/` and both apps pick it up.

On Windows, git may check out the link as a small text file. Fix it once with
`git config core.symlinks true` and a fresh clone (run the terminal as administrator or turn on Developer Mode),
or replace `flutter_app/assets/model` with a copy of `model/`.
