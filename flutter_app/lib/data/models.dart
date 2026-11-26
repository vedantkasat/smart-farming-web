/// Records that travel through Firebase (report Table 7.1).
library;

class HistPoint {
  final double moisture, temperature, humidity;
  final bool pump, ok;
  final int timestamp, seq;
  const HistPoint({
    required this.moisture,
    required this.temperature,
    required this.humidity,
    required this.pump,
    this.ok = true,
    required this.timestamp,
    this.seq = 0,
  });

  factory HistPoint.fromMap(Map m) => HistPoint(
    moisture: _d(m['moisture']),
    temperature: _d(m['temperature']),
    humidity: _d(m['humidity']),
    pump: m['pump'] == true,
    ok: m['ok'] != false,
    timestamp: _i(m['timestamp']),
    seq: _i(m['seq']),
  );

  Map<String, Object?> toMap(int seq) => {
    'moisture': moisture,
    'temperature': temperature,
    'humidity': humidity,
    'pump': pump,
    'ok': ok,
    'timestamp': timestamp,
    'seq': seq,
  };
}

class PumpRun {
  final int t, dur, seq;
  final String mode, why;
  final double moistureAtStart;
  const PumpRun({required this.t, required this.dur, required this.mode, required this.why, required this.moistureAtStart, this.seq = 0});

  factory PumpRun.fromMap(Map m) => PumpRun(
    t: _i(m['t']),
    dur: _i(m['dur']),
    mode: (m['m'] ?? '').toString(),
    why: (m['why'] ?? '').toString(),
    moistureAtStart: _d(m['sm']),
    seq: _i(m['seq']),
  );

  // Field names match what the web app already writes.
  Map<String, Object?> toMap(int seq) => {'t': t, 'dur': dur, 'm': mode, 'why': why, 'sm': moistureAtStart, 'seq': seq};
}

class FarmAlert {
  final String type, title, message;
  final int time;
  bool ack;
  String? key;
  FarmAlert({required this.type, required this.title, required this.message, required this.time, this.ack = false, this.key});

  factory FarmAlert.fromMap(String key, Map m) => FarmAlert(
    type: (m['type'] ?? 'info').toString(),
    title: (m['title'] ?? '').toString(),
    message: (m['message'] ?? '').toString(),
    time: _i(m['time']),
    ack: m['ack'] == true,
    key: key,
  );

  Map<String, Object?> toMap([int? seq]) => {'type': type, 'title': title, 'message': message, 'time': time, 'ack': ack, 'seq': ?seq};
}

class Fault {
  final bool ok;
  final String? code; // nodata, range, stuck
  final String msg;
  const Fault.none() : ok = true, code = null, msg = 'All readings normal';
  const Fault(this.code, this.msg) : ok = false;

  factory Fault.fromMap(Map m) => m['ok'] == false ? Fault(m['code']?.toString(), (m['msg'] ?? 'Fault').toString()) : const Fault.none();
  Map<String, Object?> toMap() => {'ok': ok, 'code': ?code, 'msg': msg};
}

class LeafScan {
  final String crop, disease, label;
  final double confidence;
  final bool accepted;
  final int time;
  const LeafScan({
    required this.crop,
    required this.disease,
    required this.label,
    required this.confidence,
    required this.accepted,
    required this.time,
  });
}

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
