import 'farm.dart';
import 'rules.dart';

/// "Ask an expert": answers only from the app's own data and never gives
/// pesticide products or doses.
String answer(Farm f, String question) {
  final q = question.toLowerCase();
  final t = f.t, c = f.cfg;
  bool has(String re) => RegExp(re).hasMatch(q);
  if (has(r'dose|how much.*(spray|pesticide|fungicide)|spray|pesticide|fungicide|chemical|insecticide|medicine')) {
    return 'I do not give products or doses. Call the Kisan Call Centre on $kccNumber or your KVK, and share your leaf check with them.';
  }
  if (has(r'why.*pump|pump.*(start|on|run)')) {
    return f.pump
        ? 'The pump is running in ${f.mode == 'auto' ? 'Auto' : 'Manual'} mode. In Auto it starts at the dry limit (${fmtNum(t.dry)}%) and stops at field capacity (${fmtNum(t.fc)}%).'
        : 'The pump is off. In Auto it starts when moisture reaches ${fmtNum(t.dry)}%; the reading now is ${fmtNum(f.soil)}%.';
  }
  if (has(r'dry limit|threshold|when.*water|moist|soil')) {
    return 'Soil moisture is ${fmtNum(f.soil)}%. For ${c.cropInfo.name} (${c.stageInfo.name.toLowerCase()}) in ${c.soilInfo.name.toLowerCase()} soil, '
        'p is ${fmtNum(t.p)}, so the dry limit is ${fmtNum(t.fc)} − ${fmtNum(t.p)} × (${fmtNum(t.fc)} − ${fmtNum(t.wp)}) = ${fmtNum(t.dry)}%.';
  }
  if (has(r'fault|sensor|error|offline')) {
    return 'Faults: no reading for 3 cycles, a reading outside 0 to 100%, or moisture flat for 30 min with the pump on. '
        'A fault switches the pump off and blocks Auto. Now: ${f.fault.msg}.';
  }
  if (has(r'disease|leaf|spot|blight|virus|last scan')) {
    final s = f.lastScan;
    if (s == null) return 'Open Leaf check and take or choose a photo first.';
    return s.accepted
        ? 'Your last leaf check found ${s.disease} on ${s.crop} at ${(s.confidence * 100).toStringAsFixed(0)}% confidence. Confirm with your KVK before treating.'
        : 'Your last leaf check was not confident enough. Retake the photo in daylight with one leaf filling the frame.';
  }
  if (has(r'temp|humid|weather')) return 'Temperature ${fmtNum(f.temp)} °C, humidity ${fmtNum(f.hum)}%.';
  return 'I can explain the pump, the dry limit, sensor faults and your last leaf check. For anything else, call the Kisan Call Centre on $kccNumber.';
}
