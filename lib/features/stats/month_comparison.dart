import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// So sánh tháng này với tháng trước.
class MonthComparison extends ConsumerWidget {
  const MonthComparison({super.key, required this.monthKey});

  final int monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(monthTotalsProvider(monthKey));
    final previous =
        ref.watch(monthTotalsProvider(previousMonthKey(monthKey)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'So với tháng trước',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: (current.valueOrNull == null || previous.valueOrNull == null)
                ? const LinearProgressIndicator()
                : Builder(
                    builder: (context) {
                      final now = current.value!;
                      final before = previous.value!;
                      final maxValue = [
                        now.income,
                        now.expense,
                        before.income,
                        before.expense,
                      ].reduce((a, b) => a > b ? a : b);

                      return Column(
                        children: [
                          _ComparisonRow(
                            label: monthKeyLabel(previousMonthKey(monthKey)),
                            income: before.income,
                            expense: before.expense,
                            maxValue: maxValue,
                            muted: true,
                          ),
                          const SizedBox(height: 16),
                          _ComparisonRow(
                            label: monthKeyLabel(monthKey),
                            income: now.income,
                            expense: now.expense,
                            maxValue: maxValue,
                          ),
                          const Divider(height: 28),
                          _DeltaLine(
                            label: 'Chi tiêu',
                            current: now.expense,
                            previous: before.expense,
                            // Chi ít hơn tháng trước là tin tốt.
                            lowerIsBetter: true,
                          ),
                          const SizedBox(height: 8),
                          _DeltaLine(
                            label: 'Thu nhập',
                            current: now.income,
                            previous: before.income,
                            lowerIsBetter: false,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendDot(color: incomeColor(context), label: 'Thu'),
            const SizedBox(width: 16),
            _LegendDot(color: expenseColor(context), label: 'Chi'),
          ],
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.income,
    required this.expense,
    required this.maxValue,
    this.muted = false,
  });

  final String label;
  final int income;
  final int expense;
  final int maxValue;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final opacity = muted ? 0.45 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: muted ? FontWeight.normal : FontWeight.w600,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        _Bar(
          value: income,
          maxValue: maxValue,
          color: incomeColor(context).withValues(alpha: opacity),
        ),
        const SizedBox(height: 6),
        _Bar(
          value: expense,
          maxValue: maxValue,
          color: expenseColor(context).withValues(alpha: opacity),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: Text(
            formatVndShort(value),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine({
    required this.label,
    required this.current,
    required this.previous,
    required this.lowerIsBetter,
  });

  final String label;
  final int current;
  final int previous;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delta = current - previous;

    if (previous == 0 && current == 0) {
      return Row(
        children: [
          Text(label, style: TextStyle(color: scheme.outline, fontSize: 13)),
          const Spacer(),
          Text('Không có dữ liệu',
              style: TextStyle(color: scheme.outline, fontSize: 13)),
        ],
      );
    }

    final good = lowerIsBetter ? delta <= 0 : delta >= 0;
    final color = delta == 0
        ? scheme.outline
        : good
            ? incomeColor(context)
            : expenseColor(context);
    final percent = previous == 0
        ? null
        : (delta / previous * 100);

    return Row(
      children: [
        Text(label, style: TextStyle(color: scheme.outline, fontSize: 13)),
        const Spacer(),
        Icon(
          delta == 0
              ? Icons.remove
              : delta > 0
                  ? Icons.trending_up
                  : Icons.trending_down,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          delta == 0
              ? 'không đổi'
              : '${formatVndSigned(delta)}'
                  '${percent == null ? '' : ' (${percent > 0 ? '+' : ''}'
                      '${percent.toStringAsFixed(0)}%)'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
