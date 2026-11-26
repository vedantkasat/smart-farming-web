import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme.dart';

/// Line chart of one history field, with an optional dry-limit line and
/// shading where the pump ran. Same drawing as the web app's canvas charts.
class LineChart extends StatelessWidget {
  final List<HistPoint> data;
  final double Function(HistPoint p) value;
  final Color color;
  final double? ref;
  final bool shadePump;
  final String label;
  const LineChart({
    super.key,
    required this.data,
    required this.value,
    required this.color,
    this.ref,
    this.shadePump = false,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox(
      height: 220,
      width: double.infinity,
      child: CustomPaint(painter: _ChartPainter(this)),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  final LineChart c;
  _ChartPainter(this.c);

  void _text(Canvas canvas, String s, Offset o, TextStyle st) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: st),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final d = c.data, w = size.width, h = size.height;
    final small = Furrow.mono(12, color: Furrow.muted);
    if (d.length < 2) {
      _text(canvas, 'Collecting readings', const Offset(8, 12), small);
      return;
    }
    final vals = d.map(c.value).toList();
    var mn = vals.reduce(min), mx = vals.reduce(max);
    if (c.ref != null) {
      mn = min(mn, c.ref!);
      mx = max(mx, c.ref!);
    }
    final pad = (mx - mn) * .15 == 0 ? 1.0 : (mx - mn) * .15;
    mn -= pad;
    mx += pad;
    const l = 40.0, r = 8.0, tp = 10.0, b = 22.0;
    double x(int i) => l + (w - l - r) * i / (d.length - 1);
    double y(double v) => tp + (h - tp - b) * (1 - (v - mn) / (mx - mn));

    final grid = Paint()
      ..color = Furrow.rule
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = mn + (mx - mn) * i / 3, yy = y(v);
      canvas.drawLine(Offset(l, yy), Offset(w - r, yy), grid);
      _text(canvas, v.toStringAsFixed(mx - mn < 6 ? 1 : 0), Offset(4, yy - 8), small);
    }
    if (c.shadePump) {
      final shade = Paint()..color = Furrow.water.withValues(alpha: .14);
      for (var i = 0; i < d.length - 1; i++) {
        if (d[i].pump) canvas.drawRect(Rect.fromLTRB(x(i), tp, x(i + 1), h - b), shade);
      }
    }
    if (c.ref != null) {
      final ry = y(c.ref!);
      final dash = Paint()
        ..color = Furrow.accent
        ..strokeWidth = 2;
      for (var sx = l; sx < w - r; sx += 10) {
        canvas.drawLine(Offset(sx, ry), Offset(min(sx + 6, w - r), ry), dash);
      }
      _text(canvas, 'Dry limit ${c.ref} %', Offset(l + 6, ry - 20), Furrow.body(12, color: Furrow.ink2, weight: FontWeight.w500));
    }
    final path = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < d.length; i++) {
      path.lineTo(x(i), y(vals[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = c.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final lab = Furrow.body(12, color: Furrow.muted);
    _text(canvas, 'Earlier', Offset(l, h - 16), lab);
    _text(canvas, 'Now', Offset(w - r - 26, h - 16), lab);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
