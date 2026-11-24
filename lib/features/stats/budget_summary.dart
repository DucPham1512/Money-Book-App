import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../budgets/budget_screen.dart';
import '../budgets/widgets/pace_widgets.dart';

/// Những hạn mức đang gần chạm hoặc đã vượt.
///
/// Chỉ hiện khi có gì đáng chú ý — không có thì im lặng, để màn thống kê khỏi
/// dài thêm mà chẳng nói gì.
class BudgetSummary extends ConsumerWidget {
  const BudgetSummary({super.key, required this.monthKey});

  final int monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider(monthKey));
    final list = budgets.valueOrNull ?? const <BudgetProgress>[];
    // Gồm cả những hạn mức tuy chưa chạm trần nhưng đang tiêu nhanh hơn nhịp —
    // biết sớm thì còn kịp điều chỉnh.
    final alerts = list.where((b) => b.needsAttention).toList();

    if (alerts.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngân sách cần để ý',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetScreen()),
                ),
                child: const Text('Xem hết'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < alerts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  _BudgetAlertRow(progress: alerts[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tiền trả dùm cho người khác không tính vào đây.',
            style: TextStyle(fontSize: 11.5, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _BudgetAlertRow extends StatelessWidget {
  const _BudgetAlertRow({required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = paceStyle(context, progress.pace);
    final canStillSpend = progress.daysRemaining > 0 && progress.spendable > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(style.icon, size: 18, color: style.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress.categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                progress.isOver
                    ? 'Vượt ${formatVndShort(-progress.remaining)}'
                    : 'Còn ${formatVndShort(progress.remaining)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: style.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PaceMarkerBar(progress: progress, color: style.color, height: 6),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              canStillSpend
                  ? 'Dưới ${formatVndShort(progress.remainingDailyAllowance)}/ngày · ${progress.daysRemaining} ngày'
                  : progress.isOver
                  ? 'Hạn mức tháng này đã dùng hết'
                  : progress.daysRemaining > 0
                  ? 'Ví đã hết tiền tiêu được'
                  : 'Hết tháng · dư ${formatVndShort(progress.remaining)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          if (progress.isLimitedByCash) ...[
            const SizedBox(height: 6),
            CashLimitNote(progress: progress),
          ],
        ],
      ),
    );
  }
}
