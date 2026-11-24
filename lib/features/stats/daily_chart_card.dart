import 'package:flutter/material.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import 'daily_chart_painter.dart';
import 'dart:math' as math;

/// Biểu đồ chi theo ngày, chuyển được giữa "mỗi ngày" và "cộng dồn".
///
/// Có hạn mức thì vẽ thêm đường tham chiếu trên CÙNG trục: ở chế độ mỗi ngày là
/// mức trung bình được tiêu một ngày, ở chế độ cộng dồn là nhịp đều của hạn
/// mức — đường thực tế nằm trên nó nghĩa là đang tiêu nhanh hơn nhịp.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.daily,
    required this.monthDays,
    required this.budget,
    required this.cumulative,
    required this.selectedDay,
    required this.onModeChanged,
    required this.onSelectDay,
  });

  final List<int> daily;
  final int monthDays;
  final BudgetProgress? budget;
  final bool cumulative;
  final int? selectedDay;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = daily.length;
    final selected = (selectedDay ?? days).clamp(1, days);

    final values = <int>[];
    var running = 0;
    for (final v in daily) {
      running += v;
      values.add(cumulative ? running : v);
    }

    // Đường tham chiếu, null nếu không có hạn mức.
    double? reference(int day) {
      final b = budget;
      if (b == null || monthDays == 0) return null;
      return cumulative
          ? b.limitAmount * day / monthDays
          : b.limitAmount / monthDays;
    }

    final selectedValue = values[selected - 1];
    final ref = reference(selected);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Mỗi ngày')),
                ButtonSegment(value: true, label: Text('Cộng dồn')),
              ],
              selected: {cumulative},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onModeChanged(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 14),
            // Dòng đọc số của ngày đang chọn — chạm hoặc kéo trên biểu đồ để
            // đổi ngày.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Ngày $selected: ',
                  style: TextStyle(fontSize: 13, color: scheme.outline),
                ),
                Text(
                  formatVnd(selectedValue),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (cumulative) ...[
                  Text(
                    ' đã chi',
                    style: TextStyle(fontSize: 13, color: scheme.outline),
                  ),
                ],
                const Spacer(),
                if (ref != null)
                  Text(
                    cumulative
                        ? 'nhịp đều ${formatVndShort(ref.round())}'
                        : 'mức ${formatVndShort(ref.round())}/ngày',
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  void pick(Offset p) {
                    final plotLeft = DailyChartPainter.leftGutter;
                    final w = constraints.maxWidth - plotLeft;
                    if (w <= 0) return;
                    final slot = w / days;
                    final day = ((p.dx - plotLeft) / slot).floor() + 1;
                    onSelectDay(day.clamp(1, days));
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => pick(d.localPosition),
                    onHorizontalDragUpdate: (d) => pick(d.localPosition),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: DailyChartPainter(
                        values: values,
                        cumulative: cumulative,
                        reference: budget == null ? null : reference,
                        selectedDay: selected,
                        barColor: scheme.primary,
                        referenceColor: scheme.onSurfaceVariant,
                        gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
                        labelColor: scheme.outline,
                        highlightColor: scheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (budget != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _LegendSwatch(color: scheme.primary, dashed: false),
                  const SizedBox(width: 6),
                  Text(
                    cumulative ? 'Đã chi cộng dồn' : 'Chi trong ngày',
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                  const SizedBox(width: 16),
                  _LegendSwatch(color: scheme.onSurfaceVariant, dashed: true),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      cumulative ? 'Nhịp đều của hạn mức' : 'Mức mỗi ngày',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 10),
      painter: _SwatchPainter(color: color, dashed: dashed),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 3, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.color != color || old.dashed != dashed;
}
