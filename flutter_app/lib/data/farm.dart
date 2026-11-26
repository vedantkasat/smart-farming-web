import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'models.dart';
import 'rules.dart';

/// One ESP32 cycle is 60 s of simulated time.
const cycleSec = 60;

class _RunStart {
  final int t, simStart;
  final String mode;
  final double soil;
  _RunStart(this.t, this.mode, this.soil, this.simStart);
}

/// Everything the screens show. Firebase is the meeting point for the ESP32
/// and every open app. Until the hardware exists, one open copy of the app
/// acts as a simulated ESP32 and writes the ESP32's paths. It steps aside when
/// `device.source == "esp32"`.
class Farm extends ChangeNotifier {
  Farm();

  final cfg = FieldConfig();
  String lang = 'en';

  // ---- live state (what the ESP32 reports) ----
  double soil = 22, temp = 29, hum = 58;
  int ts = DateTime.now().millisecondsSinceEpoch;
  bool pump = false;
  String mode = 'auto'; // auto | manual
  int runMin = 0;
  Fault fault = const Fault.none();
  List<HistPoint> hist = [];
  List<PumpRun> runs = [];
  List<FarmAlert> alerts = [];
  LeafScan? lastScan;

  // ---- simulator internals ----
  double? _trueSoil, _stuckVal;
  _RunStart? _runStart;
  bool fStuck = false, fRange = false, fOff = false;
  int _missed = 0;
  double? _flatV;
  int _flatSince = 0;
  int simT = 0;
  int? _lastH;
  bool simEnabled = true;
  int speed = 5;
  final _rnd = Random();

  // ---- cloud ----
  bool booted = false, live = false, owner = false;
  String? cloudError;
  final String me = List.generate(8, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(36)]).join();
  Map dev = {};
  int _offset = 0;
  final Map<String, int> _seq = {'h': 0, 'a': 0, 'r': 0, 'd': 0};
  Map<String, Object?> _q = {};
  DatabaseReference? _db;
  final List<StreamSubscription> _subs = [];
  Timer? _timer;

  int now() => DateTime.now().millisecondsSinceEpoch + _offset;
  Thresholds get t => cfg.thresholds;
  int get unacked => alerts.where((a) => !a.ack).length;
  String get deviceSource => (dev['source'] ?? '').toString();

  int get runMinutes {
    if (!pump) return 0;
    final rs = _runStart;
    return rs != null ? ((simT - rs.simStart) / 60).round() : runMin;
  }

  // ====================== boot ======================
  Future<void> start() async {
    await _loadPrefs();
    live = await _initCloud();
    booted = true;
    if (live) {
      _step();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _step());
    } else {
      _trueSoil ??= soil;
      for (var i = 0; i < 8; i++) {
        _tick(8);
      }
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick(speed));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('sf-cfg2');
      if (s != null) cfg.apply(jsonDecode(s) as Map);
      lang = p.getString('sf-lang') ?? 'en';
    } catch (_) {}
    cfg.normalise();
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('sf-cfg2', jsonEncode(cfg.toJson()));
      await p.setString('sf-lang', lang);
    } catch (_) {}
  }

  void setLang(String l) {
    lang = l;
    _savePrefs();
    notifyListeners();
  }

  // ====================== simulated ESP32 (report 6.2 to 6.4) ======================
  void _setPump(bool on, [String why = '']) {
    if (on == pump) return;
    pump = on;
    if (on) {
      _runStart = _RunStart(DateTime.now().millisecondsSinceEpoch, mode, soil, simT);
    } else if (_runStart != null) {
      final rs = _runStart!;
      final r = PumpRun(
        t: rs.t,
        dur: max(1, ((simT - rs.simStart) / 60).round()),
        mode: rs.mode == 'auto' ? 'Auto' : 'Manual',
        why: why,
        moistureAtStart: rs.soil,
      );
      runs.insert(0, r);
      if (runs.length > 20) runs.removeLast();
      _out('r', r.toMap(0), 20, 'pump/runs');
      _runStart = null;
    }
    final m = mode == 'auto' ? 'Auto' : 'Manual';
    _alert(
      'pump',
      on ? 'Pump ON' : 'Pump OFF',
      (on ? '$m, moisture ${soil.toStringAsFixed(1)}%' : 'Moisture ${soil.toStringAsFixed(1)}%') + (why.isNotEmpty ? ', $why' : ''),
    );
  }

  void _command(String c) {
    if (c == 'AUTO') {
      mode = 'auto';
      if (pump) _setPump(false, 'returned to Auto');
    } else if (c == 'ON') {
      mode = 'manual';
      if (fault.code != 'nodata') _setPump(true);
    } else if (c == 'OFF') {
      mode = 'manual';
      _setPump(false);
    }
    notifyListeners();
  }

  void _alert(String type, String title, String message) {
    final a = FarmAlert(type: type, title: title, message: message, time: now());
    alerts.insert(0, a);
    if (alerts.length > 50) alerts.removeLast();
    _out('a', a.toMap(), 50, 'alerts');
  }

  @visibleForTesting
  void tickForTest(int speed) => _tick(speed);

  void _tick(int speed) {
    final th = t;
    final steps = max(1, (speed * 2 * 30 / cycleSec).round());
    for (var k = 0; k < steps; k++) {
      _cycle(th);
    }
    notifyListeners();
  }

  void _cycle(Thresholds th) {
    simT += cycleSec;
    var ts0 = _trueSoil ?? soil;
    final evap = .012 * (1 + (temp - 25) / 20);
    ts0 = (ts0 - evap + (pump && !fStuck ? 0.55 : 0)).clamp(2, th.fc + 6).toDouble();
    _trueSoil = ts0;
    temp = _r1(29 + 4 * sin(simT / 5400) + (_rnd.nextDouble() - .5) * .3);
    hum = (58 - 8 * sin(simT / 5400) + (_rnd.nextDouble() - .5) * 2).roundToDouble();
    var fresh = false;
    if (fOff) {
      _missed++;
    } else {
      _missed = 0;
      fresh = true;
      var v = ts0 + (_rnd.nextDouble() - .5) * .2;
      if (fStuck) {
        _stuckVal ??= soil;
        v = _stuckVal!;
      }
      if (fRange) v = -3 + _rnd.nextDouble();
      soil = _r1(v);
      ts = now();
    }
    final f = _detect(fresh);
    if (!f.ok && f.code != 'range') {
      if (pump) _setPump(false, 'sensor fault');
    } else if (f.ok && mode == 'auto') {
      if (!pump && soil <= th.dry) {
        _alert('dry', 'Dry soil', 'Moisture ${fmtNum(soil)}% reached the dry limit of ${fmtNum(th.dry)}%.');
        _setPump(true);
      } else if (pump && soil >= th.stop) {
        _setPump(false, 'field capacity reached');
      }
    }
    // Maximum run applies in both modes.
    if (pump && _runStart != null && (simT - _runStart!.simStart) / 60 >= cfg.maxRunMin) {
      _alert('fault', 'Maximum run time', 'Pump stopped after ${cfg.maxRunMin} min.');
      _setPump(false, 'maximum run time');
    }
    if (_lastH == null || simT - _lastH! >= 300) {
      _lastH = simT;
      final p = HistPoint(moisture: soil, temperature: temp, humidity: hum, pump: pump, ok: f.ok, timestamp: now());
      hist.add(p);
      if (hist.length > 400) hist.removeAt(0);
      _out('h', p.toMap(0), 400, 'sensors/history');
    }
    fault = f;
  }

  /// Table 6.4 fault rules.
  Fault _detect(bool fresh) {
    final was = fault.code;
    String? code;
    var msg = 'All readings normal';
    if (_missed >= 3) {
      code = 'nodata';
      msg = 'No valid reading for 3 cycles';
    } else if (fresh && (soil < 0 || soil > 100)) {
      code = 'range';
      msg = 'Reading out of range (${fmtNum(soil)}%), rejected';
    } else if (pump) {
      if (_flatV == null || (soil - _flatV!).abs() >= .5) {
        _flatV = soil;
        _flatSince = simT;
      } else if (simT - _flatSince >= 1800) {
        code = 'stuck';
        msg = 'Moisture flat for 30 min with the pump ON: sensor or pump fault';
      }
    } else {
      _flatV = null;
      _flatSince = 0;
    }
    if (code != null && was != code) _alert('fault', 'Sensor fault', msg);
    return code != null ? Fault(code, msg) : const Fault.none();
  }

  void _applyFault(String k) {
    switch (k) {
      case 'stuck':
        fStuck = true;
        _stuckVal = null;
      case 'range':
        fRange = true;
      case 'off':
        fOff = true;
      case 'dry':
        _trueSoil = t.dry - .3;
      case 'clear':
        fStuck = fRange = fOff = false;
        _stuckVal = null;
        _missed = 0;
        _flatV = null;
        _flatSince = 0;
        fault = const Fault.none();
    }
    notifyListeners();
  }

  static double _r1(double v) => (v * 10).roundToDouble() / 10;

  // ====================== user actions ======================
  /// Pump command (pump/command). The screen asks for confirmation first.
  void pumpCommand(String c) {
    if (live && !owner) {
      _db!.child('pump/command').set({'command': c, 'requestedAt': now()});
    } else {
      _command(c);
    }
    notifyListeners();
  }

  void simulateFault(String k) {
    if (live && !owner) {
      _db!.child('device/simFaults').set({'k': k, 'ts': now()});
    } else {
      _applyFault(k);
    }
  }

  void setSimEnabled(bool v) {
    simEnabled = v;
    notifyListeners();
  }

  void setSpeed(int v) {
    speed = v;
    notifyListeners();
  }

  void saveConfig(void Function(FieldConfig c) change) {
    change(cfg);
    cfg.normalise();
    _savePrefs();
    if (live) _db!.child('config').set(cfg.toDoc(now()));
    notifyListeners();
  }

  void ack(FarmAlert a) {
    a.ack = true;
    if (live && a.key != null) _db!.child('alerts/${a.key}/ack').set(true);
    notifyListeners();
  }

  void ackAll() {
    final up = <String, Object?>{};
    for (final a in alerts) {
      a.ack = true;
      if (a.key != null) up['alerts/${a.key}/ack'] = true;
    }
    if (live && up.isNotEmpty) _db!.update(up);
    notifyListeners();
  }

  void clearAlerts() {
    alerts = [];
    if (live) _db!.child('alerts').remove();
    notifyListeners();
  }

  /// Saves a leaf check to disease/{push} and raises an alert when a disease is found.
  void recordScan(LeafScan s) {
    lastScan = s;
    final sick = s.accepted && s.disease != 'Healthy';
    final msg = '${s.crop}: ${s.disease}, ${(s.confidence * 100).toStringAsFixed(0)}% confidence';
    if (live) {
      _db!.child('disease').push().set({
        'class': s.label,
        'crop': s.crop,
        'name': s.disease,
        'confidence': double.parse(s.confidence.toStringAsFixed(3)),
        'accepted': s.accepted,
        'time': now(),
      });
      if (sick) {
        _db!.child('alerts').push().set(FarmAlert(type: 'disease', title: 'Disease detected', message: msg, time: now()).toMap());
      }
    } else if (sick) {
      alerts.insert(0, FarmAlert(type: 'disease', title: 'Disease detected', message: msg, time: now()));
    }
    notifyListeners();
  }

  // ====================== Firebase ======================
  void _out(String k, Map<String, Object?> obj, int ring, String path) {
    if (!live || !owner) return;
    final s = _seq[k]!;
    _seq[k] = s + 1;
    obj['seq'] = s;
    _q['$path/${s % ring}'] = obj;
  }

  Future<bool> _initCloud() async {
    final opts = FirebaseConfig.current;
    if (opts == null) {
      cloudError = 'Firebase is not set up for this platform yet';
      return false;
    }
    try {
      final app = await Firebase.initializeApp(options: opts).timeout(const Duration(seconds: 8));
      await FirebaseAuth.instanceFor(app: app).signInAnonymously().timeout(const Duration(seconds: 8));
      _db = FirebaseDatabase.instanceFor(app: app, databaseURL: FirebaseConfig.databaseURL).ref();
      final d = await _db!.child('device').get().timeout(const Duration(seconds: 8));
      dev = (d.value as Map?) ?? {};
      _mergeSeq(dev['seq']);
      _listen();
      return true;
    } catch (e) {
      cloudError = '$e';
      debugPrint('Firebase not reachable, running the offline demo: $e');
      return false;
    }
  }

  void _mergeSeq(Object? s) {
    if (s is Map) {
      s.forEach((k, v) {
        if (v is num) _seq['$k'] = v.toInt();
      });
    }
  }

  List<Map> _vals(Object? v) {
    if (v is Map) return v.values.whereType<Map>().toList();
    if (v is List) return v.whereType<Map>().toList();
    return [];
  }

  void _on(String path, void Function(Object? v) f) {
    _subs.add(_db!.child(path).onValue.listen((e) => f(e.snapshot.value)));
  }

  void _listen() {
    _on('.info/serverTimeOffset', (v) => _offset = (v as num?)?.toInt() ?? 0);
    _on('device', (v) {
      dev = (v as Map?) ?? {};
      if (!owner) {
        _mergeSeq(dev['seq']);
        if (dev['fault'] is Map) fault = Fault.fromMap(dev['fault'] as Map);
        if (dev['simT'] is num) simT = (dev['simT'] as num).toInt();
      }
      notifyListeners();
    });
    _on('sensors/latest', (v) {
      if (owner || v is! Map) return;
      soil = (v['moisture'] as num?)?.toDouble() ?? soil;
      temp = (v['temperature'] as num?)?.toDouble() ?? temp;
      hum = (v['humidity'] as num?)?.toDouble() ?? hum;
      ts = (v['timestamp'] as num?)?.toInt() ?? ts;
      notifyListeners();
    });
    _on('pump/status', (v) {
      if (owner || v is! Map) return;
      pump = v['state'] == 'ON';
      mode = v['mode'] == 'MANUAL' ? 'manual' : 'auto';
      runMin = (v['runMin'] as num?)?.toInt() ?? 0;
      _runStart = null;
      notifyListeners();
    });
    _on('sensors/history', (v) {
      if (owner) return;
      hist = _vals(v).map(HistPoint.fromMap).toList()..sort((a, b) => a.seq.compareTo(b.seq));
      notifyListeners();
    });
    _on('pump/runs', (v) {
      if (owner) return;
      runs = _vals(v).map(PumpRun.fromMap).toList()..sort((a, b) => b.seq.compareTo(a.seq));
      notifyListeners();
    });
    _on('alerts', (v) {
      final out = <FarmAlert>[];
      if (v is Map) {
        v.forEach((k, x) {
          if (x is Map) out.add(FarmAlert.fromMap('$k', x));
        });
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          if (v[i] is Map) out.add(FarmAlert.fromMap('$i', v[i] as Map));
        }
      }
      alerts = out..sort((a, b) => b.time.compareTo(a.time));
      notifyListeners();
    });
    _on('config', (v) {
      if (v is! Map) return;
      cfg.apply(v);
      _savePrefs();
      notifyListeners();
    });
    _on('pump/command', (v) {
      if (v is! Map || !owner) return;
      _db!.child('pump/command').remove();
      _command('${v['command']}');
    });
    _on('device/simFaults', (v) {
      if (v is! Map || !owner) return;
      _db!.child('device/simFaults').remove();
      _applyFault('${v['k']}');
    });
  }

  /// Every 2 s: decide who simulates the ESP32, then simulate or watch.
  void _step() {
    final d = dev, n = now();
    final hb = (d['heartbeat'] as num?)?.toInt() ?? 0;
    final free = d['owner'] == null || d['owner'] == me || n - hb > 10000;
    final was = owner;
    owner = simEnabled && d['source'] != 'esp32' && free;
    if (owner && !was) {
      _trueSoil = soil;
      if (hist.isEmpty) {
        for (var i = 0; i < 8; i++) {
          _tick(8);
        }
      }
      if (d['owner'] == null) {
        _db!.child('config').get().then((x) {
          if (!x.exists) _db!.child('config').set(cfg.toDoc(now()));
        });
      }
      for (final p in ['pump/command', 'device/simFaults']) {
        _db!.child(p).get().then((x) {
          final c = x.value;
          if (c is! Map) return;
          _db!.child(p).remove();
          p == 'pump/command' ? _command('${c['command']}') : _applyFault('${c['k']}');
        });
      }
    }
    if (owner) {
      _tick(speed);
      _publish();
    } else {
      if (n - hb > 3 * cycleSec * 1000 / max(1, speed) && n - hb > 15000) {
        fault = const Fault('nodata', 'No heartbeat from the ESP32');
      }
      notifyListeners();
    }
  }

  void _publish() {
    final n = now(), up = _q;
    _q = {};
    if (!fOff) up['sensors/latest'] = {'moisture': soil, 'temperature': temp, 'humidity': hum, 'timestamp': n};
    final rs = _runStart;
    up['pump/status'] = {
      'state': pump ? 'ON' : 'OFF',
      'mode': mode == 'auto' ? 'AUTO' : 'MANUAL',
      'startTime': pump && rs != null ? rs.t : null,
      'runMin': pump && rs != null ? ((simT - rs.simStart) / 60).round() : 0,
    };
    up.addAll({
      'device/owner': me,
      'device/heartbeat': n,
      'device/source': 'simulator',
      'device/firmware': 'flutter-sim-1.0',
      'device/rssi': null,
      'device/simT': simT,
      'device/fault': fault.toMap(),
      'device/seq': Map<String, int>.from(_seq),
    });
    _db!.update(up).catchError((e) => debugPrint('Firebase write failed: $e'));
  }
}
