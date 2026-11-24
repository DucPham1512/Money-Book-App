import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class MonthSummaryCard extends ConsumerWidget {
  const MonthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(currentMonthTotalsProvider);
    // Xem todayProvider chứ không gọi DateTime.now(): qua nửa đêm mà không có
    // giao dịch mới thì thẻ này vẫn phải chia cho đúng số ngày.
    final today = ref.watch(todayProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthKeyLabel(monthKeyOf(today)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 14),
            totals.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (t) => Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Thu',
                      value: t.income,
                      color: incomeColor(context),
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Chi',
                      value: t.expense,
                      color: expenseColor(context),
                    ),
                  ),
                  Expanded(
                    // Thay cho "Còn lại" (Thu trừ Chi): với người chưa ghi thu
                    // nhập thì con số đó chỉ là ô "Chi" lặp lại kèm dấu trừ.
                    // Chi mỗi ngày nói lên nhịp độ, thứ thực sự dùng được.
                    child: _MiniStat(
                      label: 'Chi/ngày',
                      value: dailyAverageSpend(t.expense, today: today),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chi trung bình mỗi ngày tính trên số ngày đã trôi qua của tháng chứa
/// [today].
int dailyAverageSpend(int monthExpense, {required DateTime today}) {
  final elapsed = daysElapsedIn(monthKeyOf(today), now: today);
  if (elapsed <= 0) return 0;
  return monthExpense ~/ elapsed;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatVndShort(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
