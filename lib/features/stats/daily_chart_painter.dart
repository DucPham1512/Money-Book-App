import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import 'dart:math' as math;

class DailyChartPainter extends CustomPainter {
  DailyChartPainter({
    required this.values,
    required this.cumulative,
    required this.reference,
    required this.selectedDay,
    required this.barColor,
    required this.referenceColor,
    required this.gridColor,
    required this.labelColor,
    required this.highlightColor,
  });

  static const leftGutter = 40.0;
  static const bottomGutter = 20.0;

  final List<int> values;
  final bool cumulative;
  final double? Function(int day)? reference;
  final int selectedDay;
  final Color barColor;
  final Color referenceColor;
  final Color gridColor;
  final Color labelColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final days = values.length;
    if (days == 0) return;

    final plot = Rect.fromLTRB(
      leftGutter,
      6,
      size.width,
      size.height - bottomGutter,
    );
    final slot = plot.width / days;

    // Trục y phải chứa cả đường tham chiếu, nếu không nó có thể bị cắt mất.
    var maxValue = values.fold<int>(0, math.max).toDouble();
    if (reference != null) {
      maxValue = math.max(maxValue, reference!(days) ?? 0);
    }
    // Bước vạch là số tròn, trần là bội của bước, nên mọi nhãn đều gọn.
    final tick = _niceStep(maxValue / 3);
    final ticks = math.max(1, (maxValue / tick).ceil());
    final top = tick * ticks;
    double yOf(num v) => plot.bottom - (v / top) * plot.height;
    double xCenter(int day) => plot.left + slot * (day - 0.5);

    // Lưới ngang mờ, nhãn bên trái.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= ticks; i++) {
      final v = tick * i;
      final y = yOf(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        formatVndShort(v.round()),
        Offset(leftGutter - 6, y),
        align: TextAlign.right,
        anchorRight: true,
      );
    }

    // Nhãn trục x: ngày 1, vài mốc ở giữa, và ngày cuối.
    final step = days <= 10 ? 2 : (days <= 20 ? 5 : 7);
    for (var d = 1; d <= days; d++) {
      final show = d == 1 || d == days || (d % step == 0 && days - d >= 2);
      if (!show) continue;
      _text(
        canvas,
        '$d',
        Offset(xCenter(d), plot.bottom + 4),
        align: TextAlign.center,
        centered: true,
      );
    }

    if (cumulative) {
      _paintLine(canvas, plot, xCenter, yOf);
    } else {
      _paintBars(canvas, slot, xCenter, yOf, plot);
    }

    if (reference != null) {
      _paintReference(canvas, plot, xCenter, yOf);
    }
  }

  void _paintBars(
    Canvas canvas,
    double slot,
    double Function(int) xCenter,
    double Function(num) yOf,
    Rect plot,
  ) {
    // Cột mảnh, cách nhau ít nhất 2px, đầu bo tròn và chân bám đường đáy.
    final width = math.max(2.0, math.min(14.0, slot - 2));
    for (var d = 1; d <= values.length; d++) {
      final v = values[d - 1];
      final isSelected = d == selectedDay;
      if (v <= 0) {
        if (isSelected) {
          canvas.drawLine(
            Offset(xCenter(d) - width / 2, plot.bottom),
            Offset(xCenter(d) + width / 2, plot.bottom),
            Paint()
              ..color = highlightColor
              ..strokeWidth = 2,
          );
        }
        continue;
      }
      final rect = Rect.fromLTRB(
        xCenter(d) - width / 2,
        math.min(yOf(v), plot.bottom - 2),
        xCenter(d) + width / 2,
        plot.bottom,
      );
      final radius = Radius.circular(math.min(4, width / 2));
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        Paint()
          ..color = isSelected ? barColor : barColor.withValues(alpha: 0.5),
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    Rect plot,
    double Function(int) xCenter,
    double Function(num) yOf,
  ) {
    final path = Path()..moveTo(xCenter(1), yOf(values.first));
    for (var d = 2; d <= values.length; d++) {
      path.lineTo(xCenter(d), yOf(values[d - 1]));
    }
    final area = Path.from(path)
      ..lineTo(xCenter(values.length), plot.bottom)
      ..lineTo(xCenter(1), plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = barColor.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = barColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Đánh dấu ngày đang chọn, viền màu nền để tách khỏi đường.
    final c = Offset(xCenter(selectedDay), yOf(values[selectedDay - 1]));
    canvas.drawLine(
      Offset(c.dx, plot.top),
      Offset(c.dx, plot.bottom),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );
    canvas.drawCircle(c, 5, Paint()..color = barColor);
  }

  void _paintReference(
    Canvas canvas,
    Rect plot,
    double Function(int) xCenter,
    double Function(num) yOf,
  ) {
    final paint = Paint()
      ..color = referenceColor
      ..strokeWidth = 1.5;
    // Cộng dồn: đường chéo từ gốc. Mỗi ngày: đường ngang.
    final start = cumulative
        ? Offset(plot.left, plot.bottom)
        : Offset(plot.left, yOf(reference!(1)!));
    final end = Offset(plot.right, yOf(reference!(values.length)!));
    _dashed(canvas, start, end, paint);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (double t = 0; t < total; t += 8) {
      canvas.drawLine(a + dir * t, a + dir * math.min(t + 4, total), paint);
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    TextAlign align = TextAlign.left,
    bool anchorRight = false,
    bool centered = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 10, color: labelColor),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = anchorRight
        ? at.dx - tp.width
        : centered
        ? at.dx - tp.width / 2
        : at.dx;
    final dy = anchorRight ? at.dy - tp.height / 2 : at.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  /// Làm tròn lên một bước dễ đọc: 1, 2, 2.5, 5 nhân luỹ thừa của 10.
  static double _niceStep(double v) {
    if (v <= 1000) return 1000;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (v <= m * exp) return m * exp;
    }
    return 10 * exp;
  }

  @override
  bool shouldRepaint(DailyChartPainter old) =>
      old.values != values ||
      old.cumulative != cumulative ||
      old.selectedDay != selectedDay ||
      old.barColor != barColor ||
      (old.reference == null) != (reference == null);
}
