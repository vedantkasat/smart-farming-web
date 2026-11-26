import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The plot as a survey map: contours, a stream, a lane, hedges, a shed,
/// fold creases, the holding edged in tangerine and the sensor node pinned
/// with its live reading. The static base is cached as a picture.
class SurveyMap extends StatelessWidget {
  final String plotName;
  final bool pump, ok;
  final double soil;
  final String time;
  const SurveyMap({super.key, required this.plotName, required this.pump, required this.ok, required this.soil, required this.time});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Survey map of the plot with the sensor node pinned',
    child: SizedBox(
      height: 300,
      width: double.infinity,
      child: CustomPaint(painter: _MapPainter(this)),
    ),
  );
}

double _height(double x, double y) =>
    sin(x * .011 + 1.3) * cos(y * .013 - .4) * 1.1 +
    sin((x + y) * .007 + 2) * .9 +
    cos(x * .004 - y * .009) * 1.4 +
    sin(x * .023 + y * .017) * .25;

final _cache = <String, ui.Picture>{};

ui.Picture _base(Size s, String plotName) {
  final key = '${s.width.round()}x${s.height.round()}|$plotName';
  final hit = _cache[key];
  if (hit != null) return hit;
  if (_cache.length > 6) _cache.clear();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final w = s.width, h = s.height;
  c.drawRect(Offset.zero & s, Paint()..color = Furrow.paper);

  // paper grain
  final r = Random(7);
  final grain = Paint();
  for (var i = 0; i < w * h / 90; i++) {
    grain.color = Furrow.paper3.withValues(alpha: .35 * r.nextDouble());
    c.drawRect(Rect.fromLTWH(r.nextDouble() * w, r.nextDouble() * h, 1, 1), grain);
  }

  // contours by marching squares
  const st = 6.0;
  final nx = (w / st).ceil() + 1, ny = (h / st).ceil() + 1;
  final g = List<double>.generate(nx * ny, (k) => _height((k % nx) * st, (k ~/ nx) * st));
  var k = 0;
  for (var lv = -3.0; lv <= 3.0001; lv += .25, k++) {
    final major = k % 5 == 0;
    final p = Paint()
      ..color = Furrow.contour.withValues(alpha: major ? .9 : .55)
      ..strokeWidth = major ? 1.4 : .7
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var j = 0; j < ny - 1; j++) {
      for (var i = 0; i < nx - 1; i++) {
        final a = g[j * nx + i], b = g[j * nx + i + 1], d = g[(j + 1) * nx + i], e = g[(j + 1) * nx + i + 1];
        final x = i * st, y = j * st, pts = <Offset>[];
        double t(double u, double v) => (lv - u) / (v - u);
        if ((a < lv) != (b < lv)) pts.add(Offset(x + st * t(a, b), y));
        if ((b < lv) != (e < lv)) pts.add(Offset(x + st, y + st * t(b, e)));
        if ((d < lv) != (e < lv)) pts.add(Offset(x + st * t(d, e), y + st));
        if ((a < lv) != (d < lv)) pts.add(Offset(x, y + st * t(a, d)));
        for (var q = 0; q + 1 < pts.length; q += 2) {
          path
            ..moveTo(pts[q].dx, pts[q].dy)
            ..lineTo(pts[q + 1].dx, pts[q + 1].dy);
        }
      }
    }
    c.drawPath(path, p);
  }

  // stream
  c.drawPath(
    Path()
      ..moveTo(.02 * w, h)
      ..cubicTo(.18 * w, .7 * h, .06 * w, .4 * h, .16 * w, 0),
    Paint()
      ..color = Furrow.water
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke,
  );

  // lane
  final ink1 = Paint()
    ..color = Furrow.ink
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  for (final x in [.9 * w, .94 * w]) {
    c.drawLine(Offset(x, 0), Offset(x - .04 * w, h), ink1);
  }

  // hedges, dotted
  final hold = [Offset(.24 * w, .2 * h), Offset(.72 * w, .14 * h), Offset(.8 * w, .7 * h), Offset(.3 * w, .82 * h)];
  final hedge = Paint()..color = Furrow.hedge;
  for (final (a, b) in [(hold[0], Offset(.24 * w, 0)), (hold[3], Offset(.3 * w, h)), (hold[1], Offset(.88 * w, .1 * h))]) {
    final n = (b - a).distance / 5;
    for (var i = 0; i < n; i++) {
      c.drawCircle(Offset.lerp(a, b, i / n)!, 1.3, hedge);
    }
  }

  // shed, hatched
  c.save();
  c.translate(.84 * w, .78 * h);
  c.drawRect(const Rect.fromLTWH(0, 0, 26, 18), ink1);
  c.clipRect(const Rect.fromLTWH(0, 0, 26, 18));
  final hatch = Paint()
    ..color = Furrow.ink.withValues(alpha: .5)
    ..strokeWidth = 1;
  for (var i = -18.0; i < 26; i += 4) {
    c.drawLine(Offset(i, 18), Offset(i + 18, 0), hatch);
  }
  c.restore();

  // fold creases
  final crease1 = Paint()..color = Furrow.paper2.withValues(alpha: .5);
  final crease2 = Paint()..color = Furrow.gridStrong.withValues(alpha: .5);
  c.drawLine(Offset(w / 3, 0), Offset(w / 3, h), crease1);
  c.drawLine(Offset(0, h / 2), Offset(w, h / 2), crease1);
  c.drawLine(Offset(w / 3 + 1, 0), Offset(w / 3 + 1, h), crease2);
  c.drawLine(Offset(0, h / 2 + 1), Offset(w, h / 2 + 1), crease2);

  // the holding, edged in tangerine
  c.drawPath(
    Path()..addPolygon(hold, true),
    Paint()
      ..color = Furrow.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke,
  );

  // plot name along its edge
  c.save();
  c.translate(hold[0].dx + 10, hold[0].dy + 8);
  c.rotate(atan2(hold[1].dy - hold[0].dy, hold[1].dx - hold[0].dx));
  final tp = TextPainter(
    text: TextSpan(
      text: plotName,
      style: Furrow.body(13, color: Furrow.ink2, weight: FontWeight.w500),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w * .6);
  tp.paint(c, Offset.zero);
  c.restore();

  return _cache[key] = rec.endRecording();
}

class _MapPainter extends CustomPainter {
  final SurveyMap m;
  _MapPainter(this.m);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawPicture(_base(size, m.plotName));
    final px = .52 * w, py = .5 * h;
    if (m.pump) {
      final p = Paint()
        ..color = Furrow.water
        ..strokeWidth = 2;
      final pts = [Offset(.9 * w, .62 * h), Offset(.78 * w, .6 * h), Offset(px, py)];
      for (var s = 0; s < pts.length - 1; s++) {
        final a = pts[s], b = pts[s + 1], len = (b - a).distance;
        for (var d = 0.0; d < len; d += 11) {
          canvas.drawLine(Offset.lerp(a, b, d / len)!, Offset.lerp(a, b, min(d + 6, len) / len)!, p);
        }
      }
    }
    canvas.drawCircle(Offset(px, py), 8, Paint()..color = m.ok ? Furrow.accent : Furrow.error);
    canvas.drawCircle(
      Offset(px, py),
      8,
      Paint()
        ..color = Furrow.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final txt = 'Node 1   ${m.ok ? '${m.soil.toStringAsFixed(1)} %' : 'fault'}   ${m.time}';
    final tp = TextPainter(
      text: TextSpan(
        text: txt,
        style: Furrow.mono(12, color: Furrow.paper2, weight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tw = tp.width + 16;
    // Right of the node, else left of it, else centred underneath (narrow phones).
    var tx = px + 14, ty = py - 12;
    if (tx + tw > w - 4) tx = px - 14 - tw;
    if (tx < 4) {
      tx = (px - tw / 2).clamp(4, max(4, w - tw - 4)).toDouble();
      ty = py + 14;
    }
    canvas.drawRect(Rect.fromLTWH(tx, ty, tw, 24), Paint()..color = Furrow.ink);
    tp.paint(canvas, Offset(tx + 8, ty + 12 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.m.pump != m.pump || old.m.ok != m.ok || old.m.soil != m.soil || old.m.time != m.time || old.m.plotName != m.plotName;
}
