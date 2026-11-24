import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../budgets/budget_screen.dart';
import 'budget_summary.dart';
import 'category_breakdown.dart';
import 'month_comparison.dart';
import 'top_expenses.dart';

/// Thống kê một tháng: thu chi, cơ cấu chi theo danh mục, so với tháng trước,
/// và các khoản chi lớn nhất.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
        actions: [
          IconButton(
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Ngân sách',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const _MonthSwitcher(),
          const SizedBox(height: 16),
          _SummaryRow(monthKey: monthKey),
          const SizedBox(height: 20),
          BudgetSummary(monthKey: monthKey),
          CategoryBreakdown(monthKey: monthKey),
          const SizedBox(height: 20),
          MonthComparison(monthKey: monthKey),
          const SizedBox(height: 20),
          TopExpenses(monthKey: monthKey),
          const SizedBox(height: 16),
          Text(
            'Thống kê chỉ tính thu nhập và chi tiêu. Chuyển tiền giữa các ví, '
            'vay mượn và điều chỉnh số dư không được tính vào đây.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(selectedMonthProvider);
    final isCurrent = monthKey == monthKeyOf(ref.watch(todayProvider));

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Tháng trước',
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              previousMonthKey(monthKey),
        ),
        Expanded(
          child: Center(
            child: Text(
              monthKeyLabel(monthKey),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Tháng sau',
          // Không cho xem tương lai — chưa có gì ở đó cả.
          onPressed: isCurrent
              ? null
              : () => ref.read(selectedMonthProvider.notifier).state =
                  nextMonthKey(monthKey),
        ),
      ],
    );
  }
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow({required this.monthKey});

  final int monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(monthTotalsProvider(monthKey));

    return totals.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Lỗi: $e'),
      data: (t) => Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Thu vào',
              value: t.income,
              color: incomeColor(context),
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Chi ra',
              value: t.expense,
              color: expenseColor(context),
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Còn lại',
              value: t.net,
              color: amountColor(context, t.net),
              icon: Icons.savings_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
        ),
      ),
    );
  }
}
