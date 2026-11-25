# Smart Farming web app

Web dashboard for **AI-Enabled Crop Monitoring and Irrigation System** (Group B-18, AISSMS IOIT, 2026–27).

It follows the Stage-I report: the soil and crop values in Tables 6.2 and 6.3, the fault rules in Table 6.4, the alerts in Table 6.5 and the Firebase paths in Table 7.1.

## What it does

| Screen | What it shows |
|---|---|
| Dashboard | Live soil moisture against the crop's dry limit and field capacity, temperature, humidity, sensor health, pump state. Pump ON, OFF and Return to Auto, each with a confirm step. |
| History | Moisture, temperature and humidity charts from `sensors/history`, and the pump run log. |
| Leaf check | Photo, then MobileNetV2 in the browser, then disease, confidence and general care advice. Results below 0.70 confidence are rejected. |
| Alerts | Dry soil, pump changes, sensor faults and disease results, each with an acknowledge button. |
| Ask an expert | Answers only from the app's own data and never gives spray doses. Kisan Call Centre (1800-180-1551) and a WhatsApp share of the last leaf check. |
| Field setup | Crop, growth stage, soil type, plot details and maximum pump run, written to `config` for the ESP32. |

English, Hindi and Marathi labels.

## Irrigation rule (report 6.2)

`Dry limit = FC − p × (FC − WP)`. The pump starts at the dry limit and stops at field capacity. In a sensitive growth stage `p` is cut by 25%.

## Firebase (report Table 7.1)

Project `smart-farming-app-49954`, Realtime Database in `asia-southeast1`, anonymous sign-in, rules in `firebase/database.rules.json`.

| Path | Written by | Fields |
|---|---|---|
| `sensors/latest` | ESP32 | `moisture`, `temperature`, `humidity`, `timestamp` |
| `sensors/history/{0..399}` | ESP32 | same plus `pump`, `seq` (ring buffer, one point per 5 min) |
| `pump/command` | App | `command`: `ON`, `OFF` or `AUTO`, `requestedAt`. The ESP32 deletes it once applied. |
| `pump/status` | ESP32 | `state` (`ON`/`OFF`), `mode` (`AUTO`/`MANUAL`), `startTime`, `runMin` |
| `pump/runs/{0..19}` | ESP32 | run log |
| `config` | App | `crop`, `stage`, `soil`, `fc`, `wp`, `p`, `dryLimit`, `maxRunMin`, `loc`, `area` |
| `alerts/{key}` | ESP32, App | `type`, `title`, `message`, `time`, `ack` |
| `disease/{push id}` | App | `class`, `crop`, `name`, `confidence`, `accepted`, `time` |
| `device` | ESP32 | `heartbeat`, `firmware`, `rssi`, `source`, `fault` |

## Running without hardware

Until the ESP32 is ready, one open copy of the app acts as the field unit: it runs the report's rules on simulated sensor data and writes the same paths the ESP32 will write. Every other open copy just reads. The simulator buttons fake a stuck sensor, an out-of-range reading, a dead ESP32 or dry soil. When the real ESP32 writes `device/source = "esp32"`, the simulator stops by itself.

## Leaf disease model

- MobileNetV2 (ImageNet weights, frozen) with a softmax head, 224 × 224 input.
- PlantVillage colour images, up to 320 per class, 23 classes (tomato 10, potato 3, maize 4, grape 4, bell pepper 2), 7,192 images, split 70/15/15.
- **Test accuracy 91.5%** on 1,080 held-out images. The browser model (float16 weights) gives the same result as the Python model on a 200-image check.
- The app only compares classes of the crop the user picks.
- Not yet tested on field photos. The guide requires that test in Stage II.
- `training/` has the scripts. `model/metrics.json` has per-class recall.

The care advice is general and gives no products or doses. Users are pointed to their KVK or the Kisan Call Centre before any spray.
